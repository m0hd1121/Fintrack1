import Foundation
import SwiftData

// MARK: - Email Provider

enum EmailProvider: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case gmail   = "Gmail"
    case outlook = "Outlook"
    case icloud  = "iCloud Mail"
    case imap    = "Other (IMAP)"

    var icon: String {
        switch self {
        case .gmail:   return "envelope.circle.fill"
        case .outlook: return "envelope.badge.fill"
        case .icloud:  return "icloud.circle.fill"
        case .imap:    return "tray.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .gmail:   return "red"
        case .outlook: return "blue"
        case .icloud:  return "teal"
        case .imap:    return "gray"
        }
    }

    /// Providers with a full OAuth + REST sync implementation.
    var supportsOAuthSync: Bool {
        switch self {
        case .gmail, .outlook: return true
        case .icloud, .imap:   return false
        }
    }

    /// Providers that sign in directly with an app-specific password over IMAP.
    var connectsViaIMAP: Bool {
        switch self {
        case .icloud, .imap:   return true
        case .gmail, .outlook: return false
        }
    }
}

// MARK: - EmailAccount

/// A connected mailbox. Only metadata lives here — OAuth tokens are kept in the
/// Keychain under a key derived from `id`, never in the SwiftData store.
@Model
final class EmailAccount {
    var id: UUID
    var emailAddress: String
    var providerRaw: String
    var connectedAt: Date
    var lastSyncAt: Date?
    var syncEnabled: Bool
    var totalEmailsScanned: Int
    var totalTransactionsParsed: Int
    /// Gmail/Graph message IDs already processed, so re-syncs never duplicate.
    var seenMessageIdsData: Data
    /// IMAP server host for app-password accounts (empty for OAuth providers)
    var imapHost: String = ""

    var provider: EmailProvider {
        EmailProvider(rawValue: providerRaw) ?? .imap
    }

    var seenMessageIds: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: seenMessageIdsData)) ?? [] }
        set { seenMessageIdsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// Keychain key for this account's OAuth tokens.
    var tokenKeychainKey: String { "ft_email_oauth_\(id.uuidString)" }

    init(
        id: UUID = UUID(),
        emailAddress: String,
        provider: EmailProvider
    ) {
        self.id = id
        self.emailAddress = emailAddress
        self.providerRaw = provider.rawValue
        self.connectedAt = Date()
        self.lastSyncAt = nil
        self.syncEnabled = true
        self.totalEmailsScanned = 0
        self.totalTransactionsParsed = 0
        self.seenMessageIdsData = Data()
        self.imapHost = ""
    }
}

// MARK: - BankEmailRule

/// One bank configured in the setup wizard (or, tagged `"sms:<slug>"` on
/// `senderEmail`, an SMS bank configured from `SMSImportView`). Drives
/// detection (sender/subject/keyword matching beyond the built-in UAE
/// whitelist) and which account a match posts to. `autoApprove`/
/// `confidenceThreshold` are kept for backward-compat model shape but are no
/// longer read anywhere — every automated import (email or SMS) always
/// waits in the review queue for the user's own approval.
@Model
final class BankEmailRule {
    var id: UUID
    var bankName: String
    var nickname: String
    var senderEmail: String          // e.g. alerts@bank.com
    var senderDomain: String         // e.g. bank.com (optional, broader match)
    var subjectPattern: String       // optional substring the subject must contain
    var keywords: [String]           // optional body/subject keywords that boost detection
    var currency: String
    var country: String
    var timezoneIdentifier: String
    var accountTypeRaw: String
    /// Ledger account transactions from this bank should post to (overrides card-digit matching)
    var linkedAccountId: UUID?
    // Unused — kept only so old backups/rows still decode; see class doc.
    var autoApprove: Bool
    var confidenceThreshold: Double
    var isEnabled: Bool
    var createdAt: Date
    var matchedCount: Int            // how many emails this rule has caught

    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRaw) ?? .current }
        set { accountTypeRaw = newValue.rawValue }
    }

    var displayName: String { nickname.isEmpty ? bankName : nickname }

    /// True when the given sender matches this rule.
    func matchesSender(_ sender: String) -> Bool {
        let lower = sender.lowercased()
        if !senderEmail.isEmpty, lower.contains(senderEmail.lowercased()) { return true }
        if !senderDomain.isEmpty, lower.contains(senderDomain.lowercased()) { return true }
        return false
    }

    /// Full match: sender + optional subject pattern.
    func matches(sender: String, subject: String) -> Bool {
        guard isEnabled, matchesSender(sender) else { return false }
        if !subjectPattern.isEmpty {
            return subject.lowercased().contains(subjectPattern.lowercased())
        }
        return true
    }

    init(
        id: UUID = UUID(),
        bankName: String,
        nickname: String = "",
        senderEmail: String,
        senderDomain: String = "",
        subjectPattern: String = "",
        keywords: [String] = [],
        currency: String = "AED",
        country: String = "United Arab Emirates",
        timezoneIdentifier: String = TimeZone.current.identifier,
        accountType: AccountType = .current,
        linkedAccountId: UUID? = nil,
        autoApprove: Bool = false,
        confidenceThreshold: Double = 0.9
    ) {
        self.id = id
        self.bankName = bankName
        self.nickname = nickname
        self.senderEmail = senderEmail
        self.senderDomain = senderDomain
        self.subjectPattern = subjectPattern
        self.keywords = keywords
        self.currency = currency
        self.country = country
        self.timezoneIdentifier = timezoneIdentifier
        self.accountTypeRaw = accountType.rawValue
        self.linkedAccountId = linkedAccountId
        self.autoApprove = autoApprove
        self.confidenceThreshold = confidenceThreshold
        self.isEnabled = true
        self.createdAt = Date()
        self.matchedCount = 0
    }
}

// MARK: - Pending Import Status

enum PendingImportStatus: String, Codable {
    case pending  = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"
}

// MARK: - Parsed Direction

enum ParsedDirection: String, Codable {
    case debit  = "Debit"
    case credit = "Credit"

    var transactionType: TransactionType { self == .debit ? .expense : .income }
}

// MARK: - PendingEmailTransaction

/// One transaction detected in a bank email, waiting in the review queue.
/// Stores only the extracted fields plus a short snippet for context —
/// never the full raw email body.
@Model
final class PendingEmailTransaction {
    var id: UUID
    var createdAt: Date

    // Source metadata (for audit trail / explainability)
    var accountId: UUID?            // EmailAccount.id, nil for manual paste
    var bankName: String
    var senderAddress: String
    var emailSubject: String
    var emailSnippet: String        // first ~200 chars of relevant body text only
    var receivedAt: Date
    var messageId: String           // provider message id or hash for paste imports

    // Parsed transaction fields
    var amount: Double
    var currency: String
    var merchantRaw: String         // exactly as it appeared in the email
    var merchantNormalized: String  // cleaned / learned display name
    var transactionDate: Date
    var cardLast4: String?
    var directionRaw: String        // ParsedDirection rawValue
    var availableBalance: Double?
    var referenceNumber: String?

    // AI assessment
    var suggestedCategoryRaw: String
    var confidence: Double          // 0...1 overall parse + classification confidence
    var suggestedTags: [String]
    var parseExplanation: String    // human-readable "why this was detected"
    var isSuspiciousParse: Bool
    var suspiciousReason: String?

    // Duplicate detection
    var fingerprint: String
    var isPossibleDuplicate: Bool
    var duplicateReason: String?

    // Review state
    var statusRaw: String
    var reviewedAt: Date?
    var approvedTransactionId: UUID?
    var wasAutoApproved: Bool = false
    /// BankEmailRule that matched this email, if any
    var matchedRuleId: UUID?
    /// Ledger Account recognized from the email (bank name + card last-4);
    /// user-overridable in the edit sheet, used on approval
    var matchedAccountId: UUID?
    /// Why that account was recognized, e.g. "card ••4821 · Emirates NBD"
    var accountMatchReason: String?
    /// BNPL resolution for Tabby/Tamara-style merchants:
    /// nil = not chosen yet (approval blocked), "none" = BNPL with no linked
    /// plan, otherwise a BNPLPlan UUID string
    var bnplSelectionRaw: String?

    var direction: ParsedDirection {
        get { ParsedDirection(rawValue: directionRaw) ?? .debit }
        set { directionRaw = newValue.rawValue }
    }

    var suggestedCategory: TransactionCategory {
        get { TransactionCategory(rawValue: suggestedCategoryRaw) ?? .other }
        set { suggestedCategoryRaw = newValue.rawValue }
    }

    var status: PendingImportStatus {
        get { PendingImportStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var confidencePercent: Int { Int((confidence * 100).rounded()) }

    init(
        id: UUID = UUID(),
        accountId: UUID? = nil,
        bankName: String,
        senderAddress: String,
        emailSubject: String,
        emailSnippet: String,
        receivedAt: Date,
        messageId: String,
        amount: Double,
        currency: String,
        merchantRaw: String,
        merchantNormalized: String,
        transactionDate: Date,
        cardLast4: String? = nil,
        direction: ParsedDirection,
        availableBalance: Double? = nil,
        referenceNumber: String? = nil,
        suggestedCategory: TransactionCategory,
        confidence: Double,
        suggestedTags: [String] = [],
        parseExplanation: String,
        isSuspiciousParse: Bool = false,
        suspiciousReason: String? = nil,
        fingerprint: String,
        isPossibleDuplicate: Bool = false,
        duplicateReason: String? = nil
    ) {
        self.id = id
        self.createdAt = Date()
        self.accountId = accountId
        self.bankName = bankName
        self.senderAddress = senderAddress
        self.emailSubject = emailSubject
        self.emailSnippet = emailSnippet
        self.receivedAt = receivedAt
        self.messageId = messageId
        self.amount = amount
        self.currency = currency
        self.merchantRaw = merchantRaw
        self.merchantNormalized = merchantNormalized
        self.transactionDate = transactionDate
        self.cardLast4 = cardLast4
        self.directionRaw = direction.rawValue
        self.availableBalance = availableBalance
        self.referenceNumber = referenceNumber
        self.suggestedCategoryRaw = suggestedCategory.rawValue
        self.confidence = confidence
        self.suggestedTags = suggestedTags
        self.parseExplanation = parseExplanation
        self.isSuspiciousParse = isSuspiciousParse
        self.suspiciousReason = suspiciousReason
        self.fingerprint = fingerprint
        self.isPossibleDuplicate = isPossibleDuplicate
        self.duplicateReason = duplicateReason
        self.statusRaw = PendingImportStatus.pending.rawValue
        self.reviewedAt = nil
        self.approvedTransactionId = nil
        self.wasAutoApproved = false
        self.matchedRuleId = nil
        self.matchedAccountId = nil
        self.accountMatchReason = nil
        self.bnplSelectionRaw = nil
    }
}

// MARK: - BNPL detection on pending items

extension PendingEmailTransaction {
    /// Merchants that are BNPL providers — installments must be linked to a
    /// plan (or explicitly marked plan-less) before approval.
    static let bnplKeywords = ["tabby", "tamara", "postpay", "spotii",
                               "cashew", "atome", "valu", "baseeta"]

    var isBNPLMerchant: Bool {
        let haystack = "\(merchantRaw) \(merchantNormalized) \(senderAddress)".lowercased()
        return Self.bnplKeywords.contains { haystack.contains($0) }
    }

    /// True once the user has made a BNPL choice (a plan or explicitly none).
    var bnplResolved: Bool { bnplSelectionRaw != nil }

    var linkedBNPLPlanId: UUID? {
        guard let raw = bnplSelectionRaw, raw != "none" else { return nil }
        return UUID(uuidString: raw)
    }
}
