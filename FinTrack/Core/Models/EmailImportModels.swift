import Foundation
import SwiftData

// MARK: - Email Provider

enum EmailProvider: String, Codable, CaseIterable {
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
    /// iCloud/IMAP have no OAuth REST API — they use manual paste/share import.
    var supportsOAuthSync: Bool {
        switch self {
        case .gmail, .outlook: return true
        case .icloud, .imap:   return false
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
    }
}
