import Foundation
import SwiftData
@preconcurrency import UserNotifications

/// "Clear All Data": removes the user's data from everywhere the app keeps it,
/// not just the database.
///
/// The old implementation deleted from a hand-kept list of model types and
/// stopped there. That list had fallen behind the schema (the review queue was
/// missing), and a clear only reached the database — so after it the user's
/// merchants and balances were still in Spotlight, in what Siri reads back, in
/// the raw SMS log, in the learned-merchant dictionaries, in the on-device
/// backup and the uninstall-proof Keychain snapshot, and in reminders for
/// records that no longer existed.
///
/// What is deliberately **kept** is exactly what the confirmation dialog
/// promises — settings, preferences and connections — see `keptTypes`.
@MainActor
enum DataResetService {

    /// Model types a reset leaves alone, and why. Everything else in
    /// `AppSchema.modelTypes` is deleted, so a model added later is covered
    /// without anyone remembering to update this file.
    ///
    /// - `AppSettings`, `UserProfile`: preferences. The dialog says they stay.
    /// - `EmailAccount`: a connected mailbox, which is a connection, not data.
    ///   **It must stay for a second reason:** it holds `seenMessageIds`, the
    ///   record of which emails were already imported. Delete it and the next
    ///   sync re-reads ~30 days of bank email and refills the review queue.
    /// - `BankEmailRule`: which bank senders to watch — configuration. Only its
    ///   link to a ledger account is stale after a clear (see `scrubKeptRecords`).
    private static let keptTypes: Set<ObjectIdentifier> = [
        ObjectIdentifier(AppSettings.self),
        ObjectIdentifier(UserProfile.self),
        ObjectIdentifier(EmailAccount.self),
        ObjectIdentifier(BankEmailRule.self),
    ]

    /// Reminders that come from the user's *settings* rather than from a record
    /// — everything else pending is tied to a bill, loan, goal, etc. that a
    /// clear has just deleted.
    private static let settingsDrivenReminders: Set<String> = ["weekly_digest", "monthly_digest"]

    /// Clears everything. Returns the names of any model types that still had
    /// rows afterwards — empty means the database really is clear. The caller
    /// should tell the user otherwise rather than let a failure pass silently.
    static func clearAll(context: ModelContext) async -> [String] {
        var leftover: [String] = []
        // Automatic backups are held off for the whole wipe and every on-device
        // backup copy is erased at the end — see `eraseBackupsAround`.
        await LocalBackupService.shared.eraseBackupsAround {
            leftover = wipeDatabase(context)
            scrubKeptRecords(context)
            wipeDerivedData()
        }
        return leftover
    }

    // MARK: - Database

    private static func wipeDatabase(_ context: ModelContext) -> [String] {
        var remaining = AppSchema.modelTypes.filter { !keptTypes.contains(ObjectIdentifier($0)) }
        // A second pass, because a type that couldn't be deleted first time may
        // have been held up by something deleted later in the list.
        for _ in 0..<2 {
            remaining = remaining.filter { !deleteAll($0, in: context) }
            if remaining.isEmpty { break }
        }
        return remaining.map { String(describing: $0) }
    }

    /// Fetch-and-delete rather than `delete(model:)`: deleting the objects goes
    /// through each relationship's delete rule, where a batch delete can leave
    /// related rows behind. Saves per type so one type that can't be deleted
    /// rolls back alone instead of failing the whole clear, and re-counts to
    /// confirm — `try?` around a bulk delete is how this used to fail silently.
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) -> Bool {
        do {
            for object in try context.fetch(FetchDescriptor<T>()) {
                context.delete(object)
            }
            try context.save()
            return try context.fetchCount(FetchDescriptor<T>()) == 0
        } catch {
            context.rollback()
            return false
        }
    }

    /// Records that are kept, but whose contents point at data that is gone.
    /// Their identity — and, for a mailbox, `seenMessageIds` — is left intact.
    private static func scrubKeptRecords(_ context: ModelContext) {
        for rule in (try? context.fetch(FetchDescriptor<BankEmailRule>())) ?? [] {
            rule.linkedAccountId = nil          // the ledger account it pointed at is deleted
            rule.matchedCount = 0
        }
        for account in (try? context.fetch(FetchDescriptor<EmailAccount>())) ?? [] {
            account.totalEmailsScanned = 0
            account.totalTransactionsParsed = 0
        }
        try? context.save()
    }

    // MARK: - Everything outside the database

    private static func wipeDerivedData() {
        // System-wide surfaces that outlive the database.
        SpotlightService.shared.clearAllIndexes()
        WidgetDataService.shared.clearAll()      // Siri/widget snapshots + unprocessed queues
        LiveActivityService.shared.end()

        // Learned from the user's own merchants and edits.
        CategoryLearningService.shared.clearAll()
        TagSuggestionService.shared.clearAll()
        ImportLearningService.shared.clearAll()
        MerchantCategoryService.shared.clearCache()

        // Import diagnostics — the SMS log holds raw bank-message text.
        SMSIngestService.clearReceived()
        ApplePayIngestService.clearReceived()
        PendingLoanLinkStore.prune(keeping: [])
        _ = NavigationRequestStore.consume()
        // Queued Siri/SMS/Apple Pay items not yet drained into the app.
        _ = WidgetDataService.shared.dequeuePendingTransactions()
        _ = WidgetDataService.shared.dequeuePendingSMS()
        _ = WidgetDataService.shared.dequeuePendingApplePay()
        let defaults = UserDefaults.standard
        for channel in [ImportChannel.email, .sms, .applePay] {
            defaults.removeObject(forKey: channel.lastImportKey)
        }

        // Notifications that quote merchants and amounts, and reminders for
        // records that no longer exist. The digest schedules are settings.
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        // The completion handler runs off the main actor, so it must not capture
        // `center` (not `Sendable`) or read this type's main-actor-isolated
        // static. It takes a copy of the keep-list and asks for the shared
        // center again instead.
        let keep = settingsDrivenReminders
        center.getPendingNotificationRequests { requests in
            let stale = requests.map(\.identifier).filter { !keep.contains($0) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: stale)
        }
        NotificationService.shared.setBadgeCount(0)
        NotificationService.shared.resetPreferences()
    }
}
