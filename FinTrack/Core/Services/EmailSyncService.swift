import Foundation
import SwiftData
import AuthenticationServices
import BackgroundTasks
import CryptoKit
import Observation
import UIKit

// MARK: - Errors

enum EmailSyncError: LocalizedError {
    case notConfigured(EmailProvider)
    case authCancelled
    case authFailed(String)
    case network(String)
    case providerUnsupported

    var errorDescription: String? {
        switch self {
        case .notConfigured(let provider):
            return "\(provider.rawValue) OAuth is not configured. Add the client ID to Info.plist, or use Paste Email / Sample Import."
        case .authCancelled:
            return "Sign-in was cancelled."
        case .authFailed(let message):
            return "Sign-in failed: \(message)"
        case .network(let message):
            return "Network error: \(message)"
        case .providerUnsupported:
            return "This provider has no sync API — use Paste Email import instead."
        }
    }
}

// MARK: - EmailSyncService

/// Orchestrates the email → pending-transaction pipeline.
///
/// Privacy model:
///   · OAuth 2.0 + PKCE only (read-only scopes) — we never see a password
///   · Fetch is restricted to whitelisted bank senders
///   · Parsing happens entirely on-device; nothing is uploaded anywhere
///   · Tokens live in the Keychain; SwiftData stores metadata only
///   · Raw bodies are discarded after parsing — only a short snippet is kept
@Observable
@MainActor
final class EmailSyncService: NSObject {
    static let shared = EmailSyncService()

    var isSyncing = false
    var isConnecting = false
    var lastSyncError: String?
    var lastSyncSummary: String?

    private var authSession: ASWebAuthenticationSession?

    // MARK: - OAuth configuration (from Info.plist)

    private struct ProviderConfig {
        let clientId: String
        let authURL: String
        let tokenURL: String
        let scope: String
        let redirectURI: String
        let callbackScheme: String
    }

    /// Client IDs can come from Info.plist (build-time) or be pasted by the
    /// user in the in-app OAuth setup screen (stored in UserDefaults).
    static func storedClientId(for provider: EmailProvider) -> String? {
        let defaultsKey: String
        let plistKey: String
        switch provider {
        case .gmail:   defaultsKey = "gmail_oauth_client_id";   plistKey = "GmailOAuthClientID"
        case .outlook: defaultsKey = "outlook_oauth_client_id"; plistKey = "OutlookOAuthClientID"
        default: return nil
        }
        if let saved = UserDefaults.standard.string(forKey: defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !saved.isEmpty {
            return saved
        }
        if let fromPlist = (Bundle.main.infoDictionary?[plistKey] as? String), !fromPlist.isEmpty {
            return fromPlist
        }
        return nil
    }

    static func saveClientId(_ clientId: String, for provider: EmailProvider) {
        let key: String
        switch provider {
        case .gmail:   key = "gmail_oauth_client_id"
        case .outlook: key = "outlook_oauth_client_id"
        default: return
        }
        UserDefaults.standard.set(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: key)
    }

    private func config(for provider: EmailProvider) -> ProviderConfig? {
        switch provider {
        case .gmail:
            guard let clientId = Self.storedClientId(for: .gmail) else { return nil }
            // Google requires the reversed-client-ID scheme for installed apps
            let reversed = clientId.split(separator: ".").reversed().joined(separator: ".")
            return ProviderConfig(
                clientId: clientId,
                authURL: "https://accounts.google.com/o/oauth2/v2/auth",
                tokenURL: "https://oauth2.googleapis.com/token",
                scope: "https://www.googleapis.com/auth/gmail.readonly",
                redirectURI: "\(reversed):/oauth2redirect",
                callbackScheme: reversed
            )
        case .outlook:
            guard let clientId = Self.storedClientId(for: .outlook) else { return nil }
            return ProviderConfig(
                clientId: clientId,
                authURL: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                tokenURL: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
                scope: "https://graph.microsoft.com/Mail.Read offline_access openid email",
                redirectURI: "fintrack://oauth-callback",
                callbackScheme: "fintrack"
            )
        case .icloud, .imap:
            return nil
        }
    }

    func isConfigured(_ provider: EmailProvider) -> Bool {
        config(for: provider) != nil
    }

    // MARK: - Connect (OAuth 2.0 + PKCE)

    /// Runs the OAuth flow and returns a connected EmailAccount (inserted into context).
    func connect(provider: EmailProvider, context: ModelContext) async throws -> EmailAccount {
        guard provider.supportsOAuthSync else { throw EmailSyncError.providerUnsupported }
        guard let cfg = config(for: provider) else { throw EmailSyncError.notConfigured(provider) }

        isConnecting = true
        defer { isConnecting = false }

        // PKCE pair
        let verifier = Self.randomVerifier()
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(string: cfg.authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: cfg.clientId),
            URLQueryItem(name: "redirect_uri", value: cfg.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: cfg.scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        let code = try await authorizationCode(authURL: components.url!, callbackScheme: cfg.callbackScheme)
        let token = try await exchangeToken(config: cfg, body: [
            "client_id": cfg.clientId,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": cfg.redirectURI,
        ])

        // Fetch the mailbox address for display
        let email = try await fetchProfileEmail(provider: provider, accessToken: token.accessToken)

        let account = EmailAccount(emailAddress: email, provider: provider)
        try KeychainStore.save(token, key: account.tokenKeychainKey)
        context.insert(account)
        try? context.save()
        AuditLogService.log(context: context, "Connected \(provider.rawValue) account \(email) via OAuth (read-only scope)")
        return account
    }

    private func authorizationCode(authURL: URL, callbackScheme: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                if let error {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    continuation.resume(throwing: cancelled ? EmailSyncError.authCancelled : EmailSyncError.authFailed(error.localizedDescription))
                    return
                }
                guard let url,
                      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: EmailSyncError.authFailed("No authorization code returned"))
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }
    }

    // MARK: - Connect (IMAP with app-specific password)

    struct IMAPCredentials: Codable {
        let host: String
        let username: String
        let password: String
    }

    /// Known IMAP hosts by mail domain; anything else gets an "imap." guess
    /// the user can edit before connecting.
    static func suggestedIMAPHost(for email: String) -> String {
        let domain = email.components(separatedBy: "@").last?.lowercased() ?? ""
        switch domain {
        case "gmail.com", "googlemail.com":                return "imap.gmail.com"
        case "outlook.com", "hotmail.com", "live.com",
             "msn.com", "office365.com":                   return "outlook.office365.com"
        case "icloud.com", "me.com", "mac.com":            return "imap.mail.me.com"
        case "yahoo.com", "ymail.com":                     return "imap.mail.yahoo.com"
        case "aol.com":                                    return "imap.aol.com"
        case "fastmail.com", "fastmail.fm":                return "imap.fastmail.com"
        default:                                            return domain.isEmpty ? "" : "imap.\(domain)"
        }
    }

    /// Verifies the credentials by signing in once, then stores them in the
    /// Keychain and creates the account. The password goes only to the mail
    /// server over TLS — never anywhere else, never logged.
    func connectIMAP(email: String, password: String, host: String,
                     provider: EmailProvider, context: ModelContext) async throws -> EmailAccount {
        isConnecting = true
        defer { isConnecting = false }

        let client = IMAPClient(host: host)
        try await client.connect()
        try await client.login(user: email, password: password)
        try? await client.logout()

        let account = EmailAccount(emailAddress: email, provider: provider)
        account.imapHost = host
        try KeychainStore.save(
            IMAPCredentials(host: host, username: email, password: password),
            key: account.tokenKeychainKey)
        context.insert(account)
        try? context.save()
        AuditLogService.log(context: context,
            "Connected \(email) via IMAP (app-specific password, stored in Keychain)")
        return account
    }

    // MARK: - Disconnect

    /// Instant disconnect: token wiped from Keychain, account and its
    /// unreviewed queue items removed.
    func disconnect(account: EmailAccount, context: ModelContext, pendingItems: [PendingEmailTransaction]) {
        KeychainStore.delete(key: account.tokenKeychainKey)
        let accountId = account.id
        for item in pendingItems where item.accountId == accountId && item.status == .pending {
            context.delete(item)
        }
        AuditLogService.log(context: context, "Disconnected email account \(account.emailAddress); token deleted from Keychain")
        context.delete(account)
        try? context.save()
    }

    // MARK: - Continuous sync
    //
    // Triggers sharing one pipeline: app launch, foreground return, a
    // 15-minute loop while active, manual refresh, and (when the project
    // enables the Background Modes capability + BGTaskSchedulerPermittedIdentifiers)
    // a BGAppRefreshTask. A future push backend slots in as another trigger.

    static let backgroundTaskIdentifier = "com.fintrack.email-sync"
    private var autoSyncTask: Task<Void, Never>?

    /// One sync pass over every connected account.
    func runSyncPass(context: ModelContext) async {
        let accounts = (try? context.fetch(FetchDescriptor<EmailAccount>())) ?? []
        guard !accounts.isEmpty else { return }
        await syncAll(accounts: accounts, context: context)
    }

    /// Foreground engine: immediate pass, then every 15 minutes while the app lives.
    func startAutoSync(context: ModelContext) {
        guard autoSyncTask == nil else { return }
        autoSyncTask = Task {
            while !Task.isCancelled {
                await runSyncPass(context: context)
                try? await Task.sleep(for: .seconds(900))
            }
        }
    }

    func stopAutoSync() {
        autoSyncTask?.cancel()
        autoSyncTask = nil
    }

    /// Registers the background refresh handler. Must run before the app
    /// finishes launching. Safe no-op if the identifier isn't declared in
    /// Info.plist (registration simply returns false).
    static func registerBackgroundSync(container: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            let syncWork = Task { @MainActor in
                await EmailSyncService.shared.runSyncPass(context: container.mainContext)
                Self.scheduleBackgroundRefresh()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = {
                syncWork.cancel()
                task.setTaskCompleted(success: false)
            }
        }
    }

    /// Asks iOS for a wake-up in ~15 minutes. Call when entering background.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Sync

    func syncAll(accounts: [EmailAccount], context: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        var imported = 0, scanned = 0
        for account in accounts where account.syncEnabled
            && (account.provider.supportsOAuthSync || account.provider.connectsViaIMAP) {
            do {
                let result = try await sync(account: account, context: context)
                imported += result.imported
                scanned += result.scanned
            } catch {
                lastSyncError = error.localizedDescription
            }
        }
        lastSyncSummary = "Scanned \(scanned) bank emails · \(imported) new in review queue"
        try? context.save()
    }

    private func sync(account: EmailAccount, context: ModelContext) async throws -> (scanned: Int, imported: Int) {
        // User bank rules extend the sender whitelist for fetching
        let rules = (try? context.fetch(FetchDescriptor<BankEmailRule>())) ?? []
        // SMS-only rules (senderEmail tagged "sms:…", configured from
        // SMSImportView) aren't email senders — never fold them into the
        // fetch whitelist.
        let ruleSenders = rules.filter { $0.isEnabled && !$0.senderEmail.hasPrefix("sms:") }
            .flatMap { [$0.senderEmail, $0.senderDomain] }
            .filter { !$0.isEmpty }

        // Accounts connected with an app password carry an imapHost and sync
        // over IMAP regardless of provider (e.g. Gmail without OAuth setup).
        let emails: [FetchedEmail]
        if !account.imapHost.isEmpty {
            emails = try await fetchIMAPMessages(account: account, seen: account.seenMessageIds, extraSenders: ruleSenders)
        } else {
            switch account.provider {
            case .gmail:
                let token = try await validAccessToken(for: account)
                emails = try await fetchGmailMessages(accessToken: token, seen: account.seenMessageIds, extraSenders: ruleSenders)
            case .outlook:
                let token = try await validAccessToken(for: account)
                emails = try await fetchOutlookMessages(accessToken: token, seen: account.seenMessageIds, extraSenders: ruleSenders)
            case .icloud, .imap:
                emails = try await fetchIMAPMessages(account: account, seen: account.seenMessageIds, extraSenders: ruleSenders)
            }
        }

        var imported = 0
        var seen = account.seenMessageIds
        for email in emails {
            seen.insert(email.messageId)
            if processEmail(email, accountId: account.id, context: context) { imported += 1 }
        }
        account.seenMessageIds = seen
        account.totalEmailsScanned += emails.count
        account.totalTransactionsParsed += imported
        account.lastSyncAt = Date()
        return (emails.count, imported)
    }

    // MARK: - Shared pipeline (sync · paste · samples all go through here)

    struct FetchedEmail {
        let messageId: String
        let sender: String
        let subject: String
        let body: String
        let receivedAt: Date
    }

    /// Classify → parse → learn → categorize → dedup → enqueue → auto-approve.
    /// Detection accepts either the built-in UAE whitelist or a user-defined
    /// BankEmailRule from the setup wizard. Returns true when a pending item
    /// was created.
    @discardableResult
    func processEmail(_ email: FetchedEmail, accountId: UUID?, context: ModelContext) -> Bool {
        let parser = BankEmailParser.shared
        let bankRules = (try? context.fetch(FetchDescriptor<BankEmailRule>())) ?? []
        let matchedRule = bankRules.first { $0.matches(sender: email.sender, subject: email.subject) }

        let builtInMatch = parser.isLikelyBankTransactionEmail(sender: email.sender, subject: email.subject)
        guard builtInMatch || matchedRule != nil else { return false }

        guard var parsed = parser.parse(
            sender: email.sender, subject: email.subject,
            body: email.body, receivedAt: email.receivedAt
        ) else { return false }

        // A user-configured rule enriches the parse result
        if let rule = matchedRule {
            if parsed.bankName == "Unknown Bank" { parsed.bankName = rule.displayName }
            parsed.explanationLines.append("Matched your “\(rule.displayName)” bank rule")
            parsed.confidence = min(0.99, parsed.confidence + 0.1)
            if !rule.keywords.isEmpty {
                let haystack = (email.subject + " " + email.body).lowercased()
                if rule.keywords.contains(where: { haystack.contains($0.lowercased()) }) {
                    parsed.explanationLines.append("Contains your configured keywords")
                    parsed.confidence = min(0.99, parsed.confidence + 0.03)
                }
            }
        }

        let learning = ImportLearningService.shared
        let normalized = learning.normalizedMerchant(for: parsed.merchant)

        // Category prediction reuses the app-wide engine (rules → learned → keywords)
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

        // Exact re-parse of an email that was already queued/approved → skip silently.
        // Scoped to the same account: IMAP UIDs (messageId "imap-<uid>") are
        // assigned independently per mailbox, so two different accounts can
        // share the same UID for two completely unrelated emails.
        if pendingItems.contains(where: { $0.messageId == email.messageId && $0.accountId == accountId }) { return false }

        let verdict = learning.duplicateCheck(
            fingerprint: fingerprint, amount: parsed.amount, currency: parsed.currency,
            date: parsed.date, cardLast4: parsed.cardLast4, merchant: parsed.merchant,
            reference: parsed.referenceNumber,
            existingTransactions: existingTxs, pendingItems: pendingItems
        )

        var explanation = parsed.explanationLines
        explanation.append("Category \(prediction.category.rawValue) — \(prediction.confidenceLabel)")

        let snippet = String(BankEmailParser.normalize(body: email.body).prefix(200))
        let item = PendingEmailTransaction(
            accountId: accountId,
            bankName: parsed.bankName,
            senderAddress: email.sender,
            emailSubject: email.subject,
            emailSnippet: snippet,
            receivedAt: email.receivedAt,
            messageId: email.messageId,
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

        // Recognize which of the user's accounts this email belongs to
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        if let match = Self.recognizeAccount(
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

        // Auto-approval: only via an explicit per-bank opt-in, and never for
        // duplicates, suspicious parses, or BNPL charges — those always
        // require human eyes (BNPL needs a plan selection).
        if let rule = matchedRule,
           rule.autoApprove,
           !verdict.isDuplicate,
           !parsed.isSuspicious,
           !item.isBNPLMerchant,
           item.confidence >= rule.confidenceThreshold {
            approveToLedger(item: item, context: context, autoApproved: true)
        }

        let pendingStatusRaw = PendingImportStatus.pending.rawValue
        let pendingCount = (try? context.fetchCount(
            FetchDescriptor<PendingEmailTransaction>(
                predicate: #Predicate { $0.statusRaw == pendingStatusRaw }
            )
        )) ?? 0

        NotificationService.shared.sendEmailImportAlert(
            merchant: item.merchantNormalized,
            amount: item.amount,
            currency: item.currency,
            category: item.suggestedCategory.rawValue,
            autoApproved: item.status == PendingImportStatus.approved,
            pendingReviewCount: pendingCount
        )

        // When rules/learning/keywords all came up empty, ask the maps
        // services what kind of place this merchant is (async — the queue
        // item updates in place when the answer arrives).
        if prediction.confidence <= 0.5 {
            enrichCategoryFromMaps(itemId: item.id, context: context)
        }
        return true
    }

    /// Looks the merchant up via Google Places / OpenStreetMap and refines
    /// the suggested category — including the already-created transaction
    /// when the item was auto-approved.
    private func enrichCategoryFromMaps(itemId: UUID, context: ModelContext) {
        Task { @MainActor in
            let items = (try? context.fetch(FetchDescriptor<PendingEmailTransaction>())) ?? []
            guard let item = items.first(where: { $0.id == itemId }) else { return }
            guard let result = await MerchantCategoryService.shared.lookupCategory(for: item.merchantNormalized) else { return }
            item.suggestedCategoryRaw = result.category.rawValue
            item.parseExplanation += "\nCategory \(result.category.rawValue) via \(result.source)"
            if item.status == .approved,
               let txId = item.approvedTransactionId,
               let tx = ((try? context.fetch(FetchDescriptor<Transaction>())) ?? []).first(where: { $0.id == txId }) {
                tx.category = result.category
            }
            try? context.save()
        }
    }

    // MARK: - Account recognition

    /// Matches a parsed email against the user's existing accounts using the
    /// card's last-4 digits and the bank name derived from the sender.
    /// Card digits are near-certain identity; bank name narrows it further
    /// (or stands alone when the email carries no card digits).
    static func recognizeAccount(
        bankName: String, cardLast4: String?, currency: String, accounts: [Account]
    ) -> (account: Account, reason: String)? {
        let bankTokens = bankName.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        func bankMatches(_ account: Account) -> Bool {
            let haystack = "\(account.bankName) \(account.name)".lowercased()
            return !bankTokens.isEmpty && bankTokens.allSatisfy { haystack.contains($0) }
        }

        var best: (account: Account, score: Double, reason: [String])?
        for account in accounts where !account.isArchived {
            var score = 0.0
            var reasons: [String] = []
            if let last4 = cardLast4, let number = account.accountNumber,
               !number.isEmpty, number.hasSuffix(last4) {
                score += 0.6
                reasons.append("card ••\(last4)")
            }
            if bankMatches(account) {
                score += 0.3
                reasons.append(bankName)
            }
            if account.currency == currency { score += 0.1 }
            if score > (best?.score ?? 0), score >= 0.3 {
                best = (account, score, reasons)
            }
        }
        guard let best else { return nil }
        return (best.account, best.reason.joined(separator: " · "))
    }

    // MARK: - Ledger posting (shared by auto-approval and the review queue)

    /// Creates the permanent Transaction for a queue item, links the right
    /// account (bank rule's linked account first, then card last-4 match),
    /// adjusts its balance, and feeds the learning loops.
    func approveToLedger(item: PendingEmailTransaction, context: ModelContext, autoApproved: Bool = false) {
        guard item.status == .pending else { return }
        // BNPL charges must have a plan selection (or an explicit "no plan")
        // before they can enter the ledger.
        guard !item.isBNPLMerchant || item.bnplResolved else { return }

        let type = item.direction.transactionType
        let baseCurrency = UserDefaults.standard.string(forKey: "base_currency") ?? "AED"
        let baseAmount = CurrencyService.shared.convert(item.amount, from: item.currency, to: baseCurrency)

        var notes = "Imported from \(item.bankName) email"
        if let reference = item.referenceNumber { notes += " · Ref: \(reference)" }
        if autoApproved { notes += " · Auto-approved at \(item.confidencePercent)% confidence" }

        // BNPL: record as an installment payment against the linked plan
        var linkedPlan: BNPLPlan?
        if item.isBNPLMerchant, let planId = item.linkedBNPLPlanId,
           let plans = try? context.fetch(FetchDescriptor<BNPLPlan>()) {
            linkedPlan = plans.first { $0.id == planId }
            if let plan = linkedPlan {
                notes += " · BNPL installment \(min(plan.paidInstallments + 1, plan.totalInstallments))/\(plan.totalInstallments) for \(plan.name)"
            }
        }

        let paymentMethod: PaymentMethod = item.isBNPLMerchant
            ? .bnpl
            : (item.cardLast4 != nil ? .debitCard : .bankTransfer)

        let tx = Transaction(
            title: item.merchantNormalized,
            amount: item.amount,
            currency: item.currency,
            amountInBaseCurrency: baseAmount,
            type: type,
            category: item.suggestedCategory,
            date: item.transactionDate,
            notes: notes,
            merchant: item.merchantNormalized,
            paymentMethod: paymentMethod,
            tags: item.suggestedTags,
            isVerified: true
        )

        // Advance the BNPL plan: one installment paid, next due a month out
        if let plan = linkedPlan, type == .expense {
            tx.linkedBNPL = plan
            plan.paidInstallments = min(plan.paidInstallments + 1, plan.totalInstallments)
            if plan.paidInstallments >= plan.totalInstallments {
                plan.isCompleted = true
            } else {
                plan.nextPaymentDate = Calendar.current.date(
                    byAdding: .month, value: 1, to: plan.nextPaymentDate) ?? plan.nextPaymentDate
            }
        }

        // Account resolution: recognized/user-chosen account first, then the
        // bank rule's linked account, then raw card last-4 as a final fallback
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        var target: Account?
        if let matchedId = item.matchedAccountId {
            target = accounts.first { $0.id == matchedId && !$0.isArchived }
        }
        if target == nil,
           let ruleId = item.matchedRuleId,
           let rules = try? context.fetch(FetchDescriptor<BankEmailRule>()),
           let linkedId = rules.first(where: { $0.id == ruleId })?.linkedAccountId {
            target = accounts.first { $0.id == linkedId && !$0.isArchived }
        }
        if target == nil, let last4 = item.cardLast4 {
            target = accounts.first { !$0.isArchived && ($0.accountNumber?.hasSuffix(last4) ?? false) }
        }
        if let account = target {
            tx.account = account
            let delta = CurrencyService.shared.convert(item.amount, from: item.currency, to: account.currency)
            switch type {
            case .income:  account.balance += delta
            case .expense: account.balance -= delta
            default: break
            }
        }

        context.insert(tx)
        item.status = .approved
        item.reviewedAt = Date()
        item.approvedTransactionId = tx.id
        item.wasAutoApproved = autoApproved

        CategoryLearningService.shared.recordCorrection(
            merchant: item.merchantNormalized, category: item.suggestedCategory)
        ImportLearningService.shared.recordApprovedTags(
            rawMerchant: item.merchantRaw, tags: item.suggestedTags)

        AuditLogService.log(context: context,
            "\(autoApproved ? "Auto-approved" : "Approved") email import: \(item.merchantNormalized) \(item.currency) \(String(format: "%.2f", item.amount)) from \(item.bankName)\(autoApproved ? " (\(item.confidencePercent)% ≥ threshold)" : "")")
        try? context.save()
    }

    // MARK: - Manual paste import (works for iCloud / IMAP / any provider)

    /// Parses a pasted or share-sheet email. Header lines ("From:", "Subject:")
    /// are honored when present.
    @discardableResult
    func importPastedEmail(_ text: String, context: ModelContext) -> Bool {
        var sender = "pasted@manual.import"
        var subject = "Pasted bank email"
        for line in text.components(separatedBy: .newlines).prefix(20) {
            let lower = line.lowercased()
            if lower.hasPrefix("from:") { sender = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
            if lower.hasPrefix("subject:") { subject = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
        }
        // Manual imports bypass the sender whitelist (user vouches for the email),
        // but still go through the full parse/dedup pipeline.
        if BankEmailParser.shared.bankName(forSender: sender) == nil {
            subject = subject.isEmpty ? "transaction alert" : subject + " transaction alert"
        }
        let hash = SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined().prefix(24)
        let email = FetchedEmail(
            messageId: "paste-\(hash)",
            sender: sender, subject: subject, body: text, receivedAt: Date()
        )
        let created = processEmail(email, accountId: nil, context: context)
        if created {
            AuditLogService.log(context: context, "Manually pasted bank email parsed into review queue")
            try? context.save()
        }
        return created
    }

    // MARK: - Sample import (demo of the full pipeline, no account needed)

    func importSampleEmails(context: ModelContext) -> Int {
        let now = Date()
        let samples: [FetchedEmail] = [
            FetchedEmail(
                messageId: "sample-\(UUID().uuidString)",
                sender: "alerts@emiratesnbd.com",
                subject: "Debit Card Purchase Transaction Alert",
                body: "Dear Customer, Your Debit Card ending 4821 was used for AED 187.50 at CARREFOUR MALL OF EMIRATES on \(Self.sampleDate(now, -1)) 19:42. Available balance AED 12,430.18. Ref: ENB7729145.",
                receivedAt: now.addingTimeInterval(-86_400)),
            FetchedEmail(
                messageId: "sample-\(UUID().uuidString)",
                sender: "notify@adcb.com",
                subject: "ADCB Credit Card Transaction Alert",
                body: "AED 54.00 was spent on your ADCB Credit Card ending 9033 at AMZN Mktp AE on \(Self.sampleDate(now, -1)). Available limit AED 22,105.90. Ref No: ADC5541209.",
                receivedAt: now.addingTimeInterval(-80_000)),
            FetchedEmail(
                messageId: "sample-\(UUID().uuidString)",
                sender: "alerts@bankfab.com",
                subject: "Inward Remittance Credit Alert",
                body: "Dear Customer, your account ending 7710 has been credited with AED 15,000.00 on \(Self.sampleDate(now, -2)) towards SALARY PAYMENT. Available balance AED 27,830.44. Reference: FAB9912873.",
                receivedAt: now.addingTimeInterval(-172_800)),
            FetchedEmail(
                messageId: "sample-\(UUID().uuidString)",
                sender: "alerts@mashreq.com",
                subject: "Card Transaction Alert",
                body: "Your Mashreq Card ending 2265 was used for AED 35.00 at CAREEM* RIDE DUBAI ARE on \(Self.sampleDate(now, 0)) 08:15. Ref: MSQ2216604.",
                receivedAt: now.addingTimeInterval(-7_200)),
            FetchedEmail(
                messageId: "sample-\(UUID().uuidString)",
                sender: "alerts@rakbank.ae",
                subject: "ATM Withdrawal Alert",
                body: "AED 500.00 withdrawn from your account ending 3402 at RAKBANK ATM DEIRA on \(Self.sampleDate(now, 0)) 12:03. Available balance AED 8,904.12. Ref: RAK8837120.",
                receivedAt: now.addingTimeInterval(-3_600)),
            FetchedEmail(
                messageId: "sample-\(UUID().uuidString)",
                sender: "alerts@emiratesnbd.com",
                subject: "Credit Card Purchase Transaction Alert",
                body: "Your Credit Card ending 9033 was used for AED 262.50 at TABBY FZ LLC DUBAI on \(Self.sampleDate(now, 0)) 15:20. Available limit AED 21,843.40. Ref: ENB7731022.",
                receivedAt: now.addingTimeInterval(-1_800)),
        ]
        var imported = 0
        for sample in samples where processEmail(sample, accountId: nil, context: context) {
            imported += 1
        }
        if imported > 0 {
            AuditLogService.log(context: context, "Imported \(imported) sample bank emails (demo mode)")
            try? context.save()
        }
        return imported
    }

    private static func sampleDate(_ from: Date, _ dayOffset: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Calendar.current.date(byAdding: .day, value: dayOffset, to: from) ?? from)
    }

    // MARK: - Gmail REST

    private func fetchGmailMessages(accessToken: String, seen: Set<String>, extraSenders: [String] = []) async throws -> [FetchedEmail] {
        let query = BankEmailParser.gmailSenderQuery(extraSenders: extraSenders)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let listURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=\(query)&maxResults=50")!
        let listData = try await authorizedGet(listURL, token: accessToken)

        struct MessageList: Decodable {
            struct Ref: Decodable { let id: String }
            let messages: [Ref]?
        }
        let refs = (try JSONDecoder().decode(MessageList.self, from: listData)).messages ?? []

        var emails: [FetchedEmail] = []
        for ref in refs where !seen.contains(ref.id) {
            let msgURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(ref.id)?format=full")!
            guard let data = try? await authorizedGet(msgURL, token: accessToken),
                  let message = try? JSONDecoder().decode(GmailMessage.self, from: data) else { continue }
            emails.append(FetchedEmail(
                messageId: ref.id,
                sender: message.header("From") ?? "",
                subject: message.header("Subject") ?? "",
                body: message.bestBody(),
                receivedAt: message.receivedDate
            ))
        }
        return emails
    }

    private struct GmailMessage: Decodable {
        struct Header: Decodable { let name: String; let value: String }
        struct Body: Decodable { let data: String? }
        struct Part: Decodable {
            let mimeType: String?
            let body: Body?
            let parts: [Part]?
        }
        struct Payload: Decodable {
            let headers: [Header]?
            let mimeType: String?
            let body: Body?
            let parts: [Part]?
        }
        let payload: Payload?
        let internalDate: String?

        var receivedDate: Date {
            guard let ms = internalDate, let value = Double(ms) else { return Date() }
            return Date(timeIntervalSince1970: value / 1000)
        }

        func header(_ name: String) -> String? {
            payload?.headers?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        func bestBody() -> String {
            func decode(_ body: Body?) -> String? {
                guard var b64 = body?.data else { return nil }
                b64 = b64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
                while b64.count % 4 != 0 { b64 += "=" }
                guard let data = Data(base64Encoded: b64) else { return nil }
                return String(data: data, encoding: .utf8)
            }
            func search(_ parts: [Part]?, mime: String) -> String? {
                guard let parts else { return nil }
                for part in parts {
                    if part.mimeType == mime, let text = decode(part.body) { return text }
                    if let nested = search(part.parts, mime: mime) { return nested }
                }
                return nil
            }
            return search(payload?.parts, mime: "text/plain")
                ?? search(payload?.parts, mime: "text/html")
                ?? decode(payload?.body)
                ?? ""
        }
    }

    // MARK: - Microsoft Graph

    private func fetchOutlookMessages(accessToken: String, seen: Set<String>, extraSenders: [String] = []) async throws -> [FetchedEmail] {
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages?$top=50&$select=id,subject,from,receivedDateTime,body&$orderby=receivedDateTime desc")!
        let data = try await authorizedGet(url, token: accessToken)

        struct GraphList: Decodable {
            struct Message: Decodable {
                struct From: Decodable {
                    struct Address: Decodable { let address: String? }
                    let emailAddress: Address?
                }
                struct Body: Decodable { let content: String? }
                let id: String
                let subject: String?
                let from: From?
                let receivedDateTime: String?
                let body: Body?
            }
            let value: [Message]?
        }
        let messages = (try JSONDecoder().decode(GraphList.self, from: data)).value ?? []
        let iso = ISO8601DateFormatter()

        // Sender whitelist applied client-side — non-bank mail is dropped
        // immediately and never parsed or stored.
        return messages.compactMap { message in
            guard !seen.contains(message.id) else { return nil }
            let sender = message.from?.emailAddress?.address ?? ""
            let lower = sender.lowercased()
            let matchesRule = extraSenders.contains { lower.contains($0.lowercased()) }
            guard BankEmailParser.shared.bankName(forSender: sender) != nil || matchesRule else { return nil }
            return FetchedEmail(
                messageId: message.id,
                sender: sender,
                subject: message.subject ?? "",
                body: message.body?.content ?? "",
                receivedAt: message.receivedDateTime.flatMap { iso.date(from: $0) } ?? Date()
            )
        }
    }

    // MARK: - IMAP fetch

    /// Searches only whitelisted bank senders (built-in + user rules) from the
    /// last 30 days, then downloads just the unseen matches — the same
    /// minimum-scope behaviour as the OAuth providers.
    private func fetchIMAPMessages(account: EmailAccount, seen: Set<String>, extraSenders: [String]) async throws -> [FetchedEmail] {
        guard let credentials: IMAPCredentials = KeychainStore.load(key: account.tokenKeychainKey) else {
            throw EmailSyncError.authFailed("No stored credentials — reconnect this account")
        }

        let client = IMAPClient(host: credentials.host)
        try await client.connect()
        try await client.login(user: credentials.username, password: credentials.password)
        try await client.selectInbox()
        defer { client.close() }

        let formatter = DateFormatter()
        formatter.dateFormat = "d-MMM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let since = formatter.string(from: Date().addingTimeInterval(-30 * 86_400))

        let domains = Set(BankEmailParser.uaeBanks.flatMap(\.senderDomains)
                          + extraSenders.filter { !$0.isEmpty })

        var uids = Set<Int>()
        for domain in domains {
            let found = (try? await client.uidSearch("SINCE \(since) HEADER FROM \"\(domain)\"")) ?? []
            uids.formUnion(found)
        }

        let newUids = uids.filter { !seen.contains("imap-\($0)") }.sorted().suffix(50)
        var emails: [FetchedEmail] = []
        for uid in newUids {
            guard let (headers, body) = try? await client.fetchMessage(uid: uid) else { continue }
            let dateHeader = MIMEDecoder.headerValue("Date", in: headers)
            let rfcFormatter = DateFormatter()
            rfcFormatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
            rfcFormatter.locale = Locale(identifier: "en_US_POSIX")
            emails.append(FetchedEmail(
                messageId: "imap-\(uid)",
                sender: MIMEDecoder.headerValue("From", in: headers) ?? "",
                subject: MIMEDecoder.headerValue("Subject", in: headers) ?? "",
                body: body,
                receivedAt: dateHeader.flatMap { rfcFormatter.date(from: $0) } ?? Date()
            ))
        }
        try? await client.logout()
        return emails
    }

    // MARK: - Profile lookup

    private func fetchProfileEmail(provider: EmailProvider, accessToken: String) async throws -> String {
        switch provider {
        case .gmail:
            let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile")!
            let data = try await authorizedGet(url, token: accessToken)
            struct Profile: Decodable { let emailAddress: String? }
            return (try JSONDecoder().decode(Profile.self, from: data)).emailAddress ?? "Gmail account"
        case .outlook:
            let url = URL(string: "https://graph.microsoft.com/v1.0/me")!
            let data = try await authorizedGet(url, token: accessToken)
            struct Me: Decodable { let mail: String?; let userPrincipalName: String? }
            let me = try JSONDecoder().decode(Me.self, from: data)
            return me.mail ?? me.userPrincipalName ?? "Outlook account"
        default:
            return "Mail account"
        }
    }

    // MARK: - Token plumbing

    struct OAuthToken: Codable {
        var accessToken: String
        var refreshToken: String?
        var expiresAt: Date
    }

    private func validAccessToken(for account: EmailAccount) async throws -> String {
        guard var token: OAuthToken = KeychainStore.load(key: account.tokenKeychainKey) else {
            throw EmailSyncError.authFailed("No stored credentials — reconnect this account")
        }
        if token.expiresAt > Date().addingTimeInterval(60) { return token.accessToken }
        guard let refresh = token.refreshToken, let cfg = config(for: account.provider) else {
            throw EmailSyncError.authFailed("Session expired — reconnect this account")
        }
        let refreshed = try await exchangeToken(config: cfg, body: [
            "client_id": cfg.clientId,
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        ])
        token.accessToken = refreshed.accessToken
        token.expiresAt = refreshed.expiresAt
        if let newRefresh = refreshed.refreshToken { token.refreshToken = newRefresh }
        try KeychainStore.save(token, key: account.tokenKeychainKey)
        return token.accessToken
    }

    private func exchangeToken(config: ProviderConfig, body: [String: String]) async throws -> OAuthToken {
        var request = URLRequest(url: URL(string: config.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP error"
            throw EmailSyncError.authFailed(String(message.prefix(200)))
        }
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double?
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return OAuthToken(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: Date().addingTimeInterval(decoded.expires_in ?? 3600)
        )
    }

    private func authorizedGet(_ url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw EmailSyncError.network("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) from \(url.host ?? "")")
        }
        return data
    }

    // MARK: - PKCE helpers

    private static func randomVerifier() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return String((0..<64).map { _ in chars.randomElement()! })
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension EmailSyncService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first {
                return window
            }
            if let scene = scenes.first {
                return UIWindow(windowScene: scene)
            }
            // OAuth is only ever launched from on-screen UI, so a window
            // scene always exists by the time this is called.
            preconditionFailure("OAuth presentation requested with no active window scene")
        }
    }
}

// MARK: - KeychainStore

/// Minimal Keychain wrapper for OAuth tokens (kSecClassGenericPassword,
/// device-only, not synced to iCloud). Pure Security-framework calls, no UI
/// dependency — explicitly nonisolated so it can be called synchronously
/// from nonisolated code (e.g. BackupEncryptionService's detached crypto
/// work) as well as from this project's default-MainActor-isolated types.
nonisolated enum KeychainStore {
    static func save<T: Codable>(_ value: T, key: String) throws {
        let data = try JSONEncoder().encode(value)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load<T: Codable>(key: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - AuditLogService helper

/// Thin helper so the import pipeline writes to the existing append-only
/// AuditLogEntry model without repeating boilerplate.
enum AuditLogService {
    @MainActor
    static func log(context: ModelContext, _ description: String) {
        let entry = AuditLogEntry(eventType: .dataImported, description: description)
        context.insert(entry)
    }
}
