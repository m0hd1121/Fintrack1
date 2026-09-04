import Foundation
import SwiftData
import CryptoKit

/// Where an automation-fed transaction came from. Only the labelling and the
/// sentinel prefixes differ per channel — everything else about filing one is
/// identical, which is why `ImportFiler` is shared rather than duplicated.
enum ImportChannel {
    case email
    case sms
    case applePay

    /// Prefix on `PendingEmailTransaction.senderAddress` (and the matching
    /// `BankEmailRule.senderEmail`), so a channel's rows stay identifiable
    /// without adding a field to the model. See PROJECT_MAP §8. Email keeps
    /// the real sender address, so it has no prefix — which is exactly how
    /// `of(_:)` recognizes it.
    var tagPrefix: String {
        switch self {
        case .email:    return ""
        case .sms:      return "sms:"
        case .applePay: return "applepay:"
        }
    }

    var messageIdPrefix: String {
        switch self {
        case .email:    return ""
        case .sms:      return "sms-"
        case .applePay: return "applepay-"
        }
    }

    /// Stands in for the email subject line in the review queue's source card.
    var subjectLabel: String {
        switch self {
        case .email:    return ""
        case .sms:      return "SMS transaction alert"
        case .applePay: return "Apple Pay transaction"
        }
    }

    /// UserDefaults key holding the last successful import for this channel.
    var lastImportKey: String {
        switch self {
        case .email:    return "ft_last_email_import_at"
        case .sms:      return "ft_last_sms_import_at"
        case .applePay: return "ft_last_applepay_import_at"
        }
    }

    var displayName: String {
        switch self {
        case .email:    return "email"
        case .sms:      return "SMS"
        case .applePay: return "Apple Pay"
        }
    }

    /// How much to trust this channel's *reading* of a transaction, used by
    /// `ImportDeduper` when the same payment arrives on more than one.
    ///
    /// Apple Pay ranks highest because Wallet hands over typed fields —
    /// amount/merchant/date cannot be misread at all. Email comes next: it's
    /// regex-parsed, but bank emails are verbose and consistent. SMS is last,
    /// being the tersest and most wording-sensitive. Note this measures
    /// *correctness*, not completeness — richer field coverage (reference
    /// number, balance, card digits) is scored separately, which is how a
    /// detailed email can still beat a bare Apple Pay entry.
    var trustWeight: Double {
        switch self {
        case .applePay: return 0.30
        case .email:    return 0.22
        case .sms:      return 0.15
        }
    }

    /// Which channel an existing queue item came from, read back off its
    /// `senderAddress` sentinel.
    static func of(_ item: PendingEmailTransaction) -> ImportChannel {
        if item.senderAddress.hasPrefix(ImportChannel.sms.tagPrefix) { return .sms }
        if item.senderAddress.hasPrefix(ImportChannel.applePay.tagPrefix) { return .applePay }
        return .email
    }
}

/// Turns a parsed transaction from any automation channel into a
/// `PendingEmailTransaction` in the review queue, running the same
/// normalization, categorization, dedup and account-matching the email
/// importer uses (`EmailSyncService.processEmail`).
///
/// Nothing here ever posts to the ledger — every item waits for the user's
/// own approval, per PROJECT_MAP §8.
@MainActor
enum ImportFiler {

    static func tag(channel: ImportChannel, bankName: String) -> String {
        channel.tagPrefix + BankSMSTemplateStore.slug(bankName)
    }

    /// Files one parsed transaction, collapsing it with any queued copy of
    /// the same payment from another channel (`ImportDeduper`) rather than
    /// creating a second row. `nil` means it was an exact repeat of something
    /// already queued and nothing was done.
    ///
    /// `categoryOverride` wins over the merchant-based prediction — used when
    /// the source already told us the category (Apple Pay/Wallet does), which
    /// is more trustworthy than guessing from the merchant name.
    @discardableResult
    static func file(
        _ parsed: ParsedBankEmail,
        channel: ImportChannel,
        rawText: String,
        receivedAt: Date,
        categoryOverride: TransactionCategory? = nil,
        context: ModelContext
    ) -> ImportDeduper.Resolution? {
        let senderTag = tag(channel: channel, bankName: parsed.bankName)
        let bankRules = (try? context.fetch(FetchDescriptor<BankEmailRule>())) ?? []
        let matchedRule = bankRules.first { $0.matches(sender: senderTag, subject: "") }

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

        // One messageId per distinct source payload — a message that yields
        // several transactions shares a prefix but stays distinct per result
        // via the fingerprint-based dedup check below.
        let messageId = channel.messageIdPrefix + hash(rawText + "|\(parsed.amount)|\(parsed.merchant)")
        if pendingItems.contains(where: { $0.messageId == messageId }) { return nil }

        let verdict = learning.duplicateCheck(
            fingerprint: fingerprint, amount: parsed.amount, currency: parsed.currency,
            date: parsed.date, cardLast4: parsed.cardLast4, merchant: parsed.merchant,
            reference: parsed.referenceNumber,
            existingTransactions: existingTxs, pendingItems: pendingItems
        )

        let category = categoryOverride ?? prediction.category
        var explanation = parsed.explanationLines
        if let categoryOverride {
            explanation.append("Category \(categoryOverride.rawValue) — supplied by the source")
        } else {
            explanation.append("Category \(prediction.category.rawValue) — \(prediction.confidenceLabel)")
        }

        let item = PendingEmailTransaction(
            bankName: parsed.bankName,
            senderAddress: senderTag,
            emailSubject: channel.subjectLabel,
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
            suggestedCategory: category,
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

        if item.isBNPLMerchant {
            item.parseExplanation += "\nBNPL provider detected — link an installment plan before approving"
        }

        // One row per real transaction: merge with a queued copy from another
        // channel instead of adding a second flagged duplicate.
        let resolution = ImportDeduper.file(item, channel: channel,
                                            pendingItems: pendingItems, context: context)
        matchedRule?.matchedCount += 1
        UserDefaults.standard.set(Date(), forKey: channel.lastImportKey)

        // Only announce a transaction the user hasn't been told about yet —
        // a merge into an already-queued copy was already announced by
        // whichever channel got here first.
        guard resolution.createdNewRow else { return resolution }

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
        return resolution
    }

    static func hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(24))
    }
}
