import Foundation

/// Which loan a review-queue item is a repayment on, chosen in the edit sheet.
///
/// Kept beside the queue rather than on `PendingEmailTransaction`: adding a
/// field to that `@Model` means a schema change, and this app `fatalError`s if
/// its container can't load — a failed migration here would lock the user out
/// of their data. A small keyed store in UserDefaults carries no such risk, and
/// the choice is short-lived anyway: it only needs to survive until the item is
/// approved or rejected.
///
/// `EmailSyncService.approveToLedger` reads it, so every approval route —
/// swipe, bulk, the sheet, the duplicate confirmation — honours the choice
/// without each having to pass it along.
@MainActor
enum PendingLoanLinkStore {
    private static let key = "ft_pending_loan_links_v1"

    private static var links: [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    static func loanId(for itemId: UUID) -> UUID? {
        links[itemId.uuidString].flatMap(UUID.init(uuidString:))
    }

    /// Pass nil to clear the link.
    static func set(_ loanId: UUID?, for itemId: UUID) {
        var all = links
        if let loanId { all[itemId.uuidString] = loanId.uuidString }
        else { all.removeValue(forKey: itemId.uuidString) }
        UserDefaults.standard.set(all, forKey: key)
    }

    static func clear(itemId: UUID) { set(nil, for: itemId) }

    /// Drops links for items that are no longer waiting in the queue
    /// (rejected, deleted, approved elsewhere), so the store can't grow without
    /// bound. Called when the queue appears.
    static func prune(keeping pendingIds: Set<UUID>) {
        let all = links
        let kept = all.filter { entry in
            UUID(uuidString: entry.key).map(pendingIds.contains) ?? false
        }
        if kept.count != all.count { UserDefaults.standard.set(kept, forKey: key) }
    }
}
