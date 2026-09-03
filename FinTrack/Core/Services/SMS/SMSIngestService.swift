import Foundation
import SwiftData
import CryptoKit

/// Turns a raw SMS message into a `PendingEmailTransaction` and drives the
/// same review-queue / auto-approve / ledger pipeline the email importer
/// uses — see `EmailSyncService.processEmail` / `.approveToLedger`.
///
/// SMS items are *tagged*, not modeled separately: `PendingEmailTransaction
/// .senderAddress` and `BankEmailRule.senderEmail` carry an `"sms:<bank
/// slug>"` sentinel instead of an email address (the same trick this
/// codebase already uses for `AppSettings.cloudSyncEnabled`), so this
/// feature needed no new `@Model` and no schema bump.
@MainActor
enum SMSIngestService {

    /// Auto-approve only ever fires for a template-matched (never a
    /// model-guessed) parse, at a high bar — the same spirit as the email
    /// importer's per-bank rule, used here as the *default* when no
    /// `BankEmailRule` has been configured for the bank via `SMSImportView`.
    private static let minTemplateAutoApproveConfidence = 0.92

    static func senderTag(bankName: String) -> String {
        "sms:" + BankSMSTemplateStore.slug(bankName)
    }

    /// Parses and files one SMS. Returns true when at least one pending item
    /// was created (a message can contain more than one transaction).
    @discardableResult
    static func ingest(rawText: String, senderId: String?, receivedAt: Date, context: ModelContext) async -> Bool {
        // Sender IDs the user typed into a bank's SMS setup sheet — tried
        // ahead of the bundled best-effort list (see BankSMSTemplateStore).
        let userTemplates: [BankSMSTemplate] = ((try? context.fetch(FetchDescriptor<BankEmailRule>())) ?? [])
            .filter { $0.isEnabled && $0.senderEmail.hasPrefix("sms:") && !$0.keywords.isEmpty }
            .map { BankSMSTemplate(bankId: BankSMSTemplateStore.slug($0.bankName), bankName: $0.bankName, senderIds: $0.keywords) }

        let outcome = await BankSMSParser.parse(rawText: rawText, senderId: senderId, userTemplates: userTemplates)
        guard !outcome.results.isEmpty else { return false }

        var created = false
        for parsed in outcome.results
        where file(parsed, source: outcome.source, rawText: rawText, receivedAt: receivedAt, context: context) {
            created = true
        }
        if created { try? context.save() }
        return created
    }

    @discardableResult
    private static func file(
        _ parsed: ParsedBankEmail, source: String, rawText: String, receivedAt: Date, context: ModelContext
    ) -> Bool {
        let tag = senderTag(bankName: parsed.bankName)
        let bankRules = (try? context.fetch(FetchDescriptor<BankEmailRule>())) ?? []
        let matchedRule = bankRules.first { $0.matches(sender: tag, subject: "") }

        let learning = ImportLearningService.shared
        let normalized = learning.normalizedMerchant(for: parsed.merchant)

        let rules = (try? context.fetch(FetchDescriptor<CategorizationRule>())) ?? []
        let prediction = AICategorizationService.shared.predictCategory(
            for: normalized, merchant: normalized,
            amount: parsed.amount, type: parsed.direction.transactionType,
            rules: rules
        )

        let fingerprint = BankEmailParser.fingerprint(
            amount: parsed.amount, currency: parsed.currency, date: parsed.date,
            cardLast4: parsed.cardLast4, merchant: parsed.merchant, reference: parsed.referenceNumber
        )

        let existingTxs = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let pendingItems = (try? context.fetch(FetchDescriptor<PendingEmailTransaction>())) ?? []

        // One messageId per distinct raw message text — a message that
        // yields several transactions shares a prefix but stays distinct
        // per parsed result via the fingerprint-based dedup check below.
        let messageId = "sms-" + Self.hash(rawText + "|\(parsed.amount)|\(parsed.merchant)")
        if pendingItems.contains(where: { $0.messageId == messageId }) { return false }

        let verdict = learning.duplicateCheck(
            fingerprint: fingerprint, amount: parsed.amount, currency: parsed.currency,
            date: parsed.date, cardLast4: parsed.cardLast4, merchant: parsed.merchant,
            reference: parsed.referenceNumber,
            existingTransactions: existingTxs, pendingItems: pendingItems
        )

        var explanation = parsed.explanationLines
        explanation.append("Category \(prediction.category.rawValue) — \(prediction.confidenceLabel)")

        let item = PendingEmailTransaction(
            bankName: parsed.bankName,
            senderAddress: tag,
            emailSubject: "SMS transaction alert",
            emailSnippet: String(rawText.prefix(200)),
            receivedAt: receivedAt,
            messageId: messageId,
            amount: parsed.amount,
            currency: parsed.currency,
            merchantRaw: parsed.merchant,
            merchantNormalized: normalized,
            transactionDate: parsed.date,
            cardLast4: parsed.cardLast4,
            direction: parsed.direction,
            availableBalance: parsed.availableBalance,
            referenceNumber: parsed.referenceNumber,
            suggestedCategory: prediction.category,
            confidence: min(parsed.confidence, max(prediction.confidence, 0.3)) * 0.3 + parsed.confidence * 0.7,
            suggestedTags: learning.suggestedTags(for: parsed.merchant),
            parseExplanation: explanation.joined(separator: "\n"),
            isSuspiciousParse: parsed.isSuspicious,
            suspiciousReason: parsed.suspiciousReason,
            fingerprint: fingerprint,
            isPossibleDuplicate: verdict.isDuplicate,
            duplicateReason: verdict.reason
        )
        item.matchedRuleId = matchedRule?.id

        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        if let match = EmailSyncService.recognizeAccount(
            bankName: parsed.bankName, cardLast4: parsed.cardLast4,
            currency: parsed.currency, accounts: accounts) {
            item.matchedAccountId = match.account.id
            item.accountMatchReason = match.reason
            item.parseExplanation += "\nRecognized account “\(match.account.name)” (\(match.reason))"
        }

        context.insert(item)
        matchedRule?.matchedCount += 1

        if item.isBNPLMerchant {
            item.parseExplanation += "\nBNPL provider detected — link an installment plan before approving"
        }

        let ruleAutoApprove = matchedRule?.autoApprove == true
            && !verdict.isDuplicate && !parsed.isSuspicious && !item.isBNPLMerchant
            && item.confidence >= (matchedRule?.confidenceThreshold ?? 1)
        let defaultAutoApprove = matchedRule == nil && source == "template"
            && !verdict.isDuplicate && !parsed.isSuspicious && !item.isBNPLMerchant
            && item.confidence >= minTemplateAutoApproveConfidence

        if ruleAutoApprove || defaultAutoApprove {
            EmailSyncService.shared.approveToLedger(item: item, context: context, autoApproved: true)
        }

        let pendingStatusRaw = PendingImportStatus.pending.rawValue
        let pendingCount = (try? context.fetchCount(
            FetchDescriptor<PendingEmailTransaction>(predicate: #Predicate { $0.statusRaw == pendingStatusRaw })
        )) ?? 0
        NotificationService.shared.sendEmailImportAlert(
            merchant: item.merchantNormalized, amount: item.amount, currency: item.currency,
            category: item.suggestedCategory.rawValue,
            autoApproved: item.status == PendingImportStatus.approved,
            pendingReviewCount: pendingCount
        )
        UserDefaults.standard.set(Date(), forKey: lastImportKey)
        return true
    }

    /// Read by `SMSImportView` for its 24-hour "first SMS landed" check.
    static let lastImportKey = "ft_last_sms_import_at"

    private static func hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(24))
    }
}
