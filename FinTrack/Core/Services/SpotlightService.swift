import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Indexes transactions and accounts in CoreSpotlight so they're searchable from iOS Spotlight.
final class SpotlightService {
    static let shared = SpotlightService()
    private init() {}

    private let transactionDomain = "com.fintrack.transactions"
    private let accountDomain    = "com.fintrack.accounts"

    // MARK: – Indexing

    func indexTransactions(_ transactions: [Transaction]) {
        let items = transactions.map { tx in
            let attr = CSSearchableItemAttributeSet(contentType: .text)
            attr.title = tx.title
            attr.contentDescription = [
                "\(tx.currency) \(String(format: "%.2f", tx.amount))",
                tx.category.rawValue,
                tx.merchant ?? "",
                tx.notes ?? ""
            ].filter { !$0.isEmpty }.joined(separator: " · ")
            attr.keywords = [tx.title, tx.category.rawValue, tx.merchant ?? "", tx.type.rawValue].filter { !$0.isEmpty }
            attr.timestamp = tx.date
            attr.displayName = tx.title
            attr.identifier = tx.id.uuidString

            return CSSearchableItem(
                uniqueIdentifier: tx.id.uuidString,
                domainIdentifier: transactionDomain,
                attributeSet: attr
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    func indexAccounts(_ accounts: [Account]) {
        let items = accounts.filter { !$0.isArchived }.map { account in
            let attr = CSSearchableItemAttributeSet(contentType: .text)
            attr.title = account.name
            attr.contentDescription = "\(account.type.rawValue) · \(account.currency) \(String(format: "%.2f", account.balance))"
            attr.keywords = [account.name, account.type.rawValue, account.currency, account.bankName].filter { !$0.isEmpty }
            attr.displayName = account.name
            attr.identifier = account.id.uuidString

            return CSSearchableItem(
                uniqueIdentifier: account.id.uuidString,
                domainIdentifier: accountDomain,
                attributeSet: attr
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    // MARK: – Deletion

    func removeTransactionFromIndex(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { _ in }
    }

    func removeAccountFromIndex(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { _ in }
    }

    func clearTransactionIndex() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [transactionDomain]) { _ in }
    }

    func clearAllIndexes() {
        CSSearchableIndex.default().deleteAllSearchableItems { _ in }
    }

    // MARK: – Activity handling

    /// Call from the SwiftUI .onContinueUserActivity modifier or AppDelegate.
    /// Returns the entity type and UUID encoded in the activity's userInfo.
    func handleUserActivity(_ activity: NSUserActivity) -> SpotlightDeepLink? {
        guard activity.activityType == CSSearchableItemActionType,
              let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let uuid = UUID(uuidString: id)
        else { return nil }

        if let domain = activity.userInfo?["kCSSearchableItemDomainIdentifier"] as? String {
            if domain == transactionDomain { return .transaction(uuid) }
            if domain == accountDomain { return .account(uuid) }
        }

        // Fallback: try to determine type from search index metadata
        return .unknown(uuid)
    }
}

enum SpotlightDeepLink {
    case transaction(UUID)
    case account(UUID)
    case unknown(UUID)
}
