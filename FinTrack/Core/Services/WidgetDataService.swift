import Foundation
import WidgetKit

/// Writes lightweight data into the shared App Group UserDefaults
/// so FinTrackWidget can display it without accessing SwiftData directly.
final class WidgetDataService {
    static let shared = WidgetDataService()
    private init() {}

    private let suiteName = "group.com.fintrack.shared"

    /// Store for the SMS and Apple Pay queues, which — unlike the widget
    /// snapshots — are only ever written and read **inside this app's own
    /// process**: `LogTransactionFromText`/`LogApplePayTransaction` run in the
    /// app itself (the project has a single application target, no App Intents
    /// Extension), and `RootView.drainPendingSMSTexts()` reads them back.
    ///
    /// So this is deliberately `.standard`, not the App Group suite. App
    /// Groups need a paid Apple Developer Program membership, and without that
    /// entitlement the suite is not merely unavailable — it fails *silently*:
    /// `UserDefaults(suiteName:)` still returns a perfectly valid object (it
    /// only returns nil for a nil name, the app's own bundle id, or the global
    /// domain), so a `?? .standard` fallback never fires. Values written to it
    /// live in that process's in-memory cache and are never persisted, because
    /// the container directory the plist belongs in doesn't exist. The
    /// Shortcuts automation background-launches the app, the intent writes and
    /// reports success, the process is suspended, and the queue is empty by
    /// the time the user opens the app — which is exactly the "the shortcut
    /// says Got it but nothing reaches the review queue" symptom.
    ///
    /// `.standard` is the app's own container: it always exists, always
    /// persists, and is shared between the intent and the UI because they are
    /// the same process. Both enqueue and dequeue resolve through here, so the
    /// two sides can never disagree about which store they're using.
    private var smsDefaults: UserDefaults { .standard }

    /// Anything stranded in the App Group suite by an earlier build (on an
    /// install where the entitlement *was* provisioned) is moved across the
    /// first time we look, so a queued message isn't lost to the fix.
    private func migrateLegacyQueue(forKey key: String) {
        guard let legacy = UserDefaults(suiteName: suiteName),
              let data = legacy.data(forKey: key) else { return }
        legacy.removeObject(forKey: key)
        guard smsDefaults.data(forKey: key) == nil else { return }
        smsDefaults.set(data, forKey: key)
    }

    // MARK: – Full update (preferred)

    /// Snapshot stores, in the order they're written.
    ///
    /// `.standard` is the one that actually works today and is what the App
    /// Intents read: they run in this app's process (single application
    /// target, no App Intents Extension), so the app's own container is
    /// shared with them and always persists. The App Group suite is written
    /// too — it is inert without the paid entitlement, but costs nothing and
    /// means a future widget/Watch target works the moment it's provisioned.
    ///
    /// Before this, every snapshot went **only** to the App Group. That write
    /// is silently discarded (see `smsDefaults`), so `GetBalanceIntent` read
    /// back 0 and confidently told the user their net worth was zero, and
    /// `GetBudgetStatusIntent` always said there was no budget data.
    private var snapshotStores: [UserDefaults] {
        var stores: [UserDefaults] = [.standard]
        if let group = UserDefaults(suiteName: suiteName), group != .standard {
            stores.append(group)
        }
        return stores
    }

    func updateAll(
        netWorth: Double,
        currency: String,
        transactions: [WidgetTxSnapshot],
        budgets: [WidgetBudgetSnapshot],
        bills: [WidgetBillSnapshot],
        payments: [WidgetPaymentSnapshot] = [],
        accounts: [WidgetAccountSnapshot] = [],
        goals: [WidgetGoalSnapshot] = []
    ) {
        for defaults in snapshotStores {
            defaults.set(netWorth, forKey: "widget_net_worth")
            defaults.set(currency, forKey: "widget_currency")
            if let data = try? JSONEncoder().encode(transactions) {
                defaults.set(data, forKey: "widget_recent_transactions")
            }
            if let data = try? JSONEncoder().encode(budgets) {
                defaults.set(data, forKey: "widget_budgets")
            }
            if let data = try? JSONEncoder().encode(bills) {
                defaults.set(data, forKey: "widget_bills")
            }
            if let data = try? JSONEncoder().encode(payments) {
                defaults.set(data, forKey: "widget_upcoming_payments")
            }
            // Only overwrite when the caller supplied them, so a legacy call
            // site can't blank out entities Siri resolves against.
            if !accounts.isEmpty, let data = try? JSONEncoder().encode(accounts) {
                defaults.set(data, forKey: "widget_accounts")
            }
            if !goals.isEmpty, let data = try? JSONEncoder().encode(goals) {
                defaults.set(data, forKey: "widget_goals")
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Read side for the App Intents — always the store that persists.
    func snapshot<T: Decodable>(_ type: [T].Type, forKey key: String) -> [T] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([T].self, from: data)
        else { return [] }
        return decoded
    }

    var snapshotNetWorth: Double { UserDefaults.standard.double(forKey: "widget_net_worth") }
    var snapshotCurrency: String { UserDefaults.standard.string(forKey: "widget_currency") ?? "AED" }

    // MARK: – Legacy (transactions only)

    func update(netWorth: Double, currency: String, recentTransactions: [WidgetTxSnapshot]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(netWorth, forKey: "widget_net_worth")
        defaults.set(currency, forKey: "widget_currency")
        if let data = try? JSONEncoder().encode(recentTransactions) {
            defaults.set(data, forKey: "widget_recent_transactions")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: – Pending Siri intent queue

    func enqueuePendingTransaction(_ tx: PendingWidgetTransaction) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        var queue: [PendingWidgetTransaction] = []
        if let data = defaults.data(forKey: "pending_transactions"),
           let existing = try? JSONDecoder().decode([PendingWidgetTransaction].self, from: data) {
            queue = existing
        }
        queue.append(tx)
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: "pending_transactions")
        }
    }

    func dequeuePendingTransactions() -> [PendingWidgetTransaction] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "pending_transactions"),
              let queue = try? JSONDecoder().decode([PendingWidgetTransaction].self, from: data)
        else { return [] }
        defaults.removeObject(forKey: "pending_transactions")
        return queue
    }

    // MARK: – Pending SMS queue (parsed by SMSIngestService on next foreground)

    /// `LogTransactionFromText` reports the returned value rather than
    /// assuming success, so this reads the queue back after writing: a store
    /// that accepts a write and drops it is precisely the failure mode this
    /// queue has already been bitten by (see `smsDefaults`).
    @discardableResult
    func enqueuePendingSMS(_ sms: PendingSMSText) -> Bool {
        migrateLegacyQueue(forKey: "pending_sms_texts")
        let defaults = smsDefaults
        var queue: [PendingSMSText] = []
        if let data = defaults.data(forKey: "pending_sms_texts"),
           let existing = try? JSONDecoder().decode([PendingSMSText].self, from: data) {
            queue = existing
        }
        queue.append(sms)
        guard let data = try? JSONEncoder().encode(queue) else { return false }
        defaults.set(data, forKey: "pending_sms_texts")
        return defaults.data(forKey: "pending_sms_texts") == data
    }

    /// Messages sitting in the queue that no drain has picked up yet. Read by
    /// `SMSImportView`'s diagnostics: a non-zero count means the Shortcuts
    /// automation delivered something but `RootView` hasn't processed it.
    var pendingSMSCount: Int {
        guard let data = smsDefaults.data(forKey: "pending_sms_texts"),
              let queue = try? JSONDecoder().decode([PendingSMSText].self, from: data)
        else { return 0 }
        return queue.count
    }

    func dequeuePendingSMS() -> [PendingSMSText] {
        migrateLegacyQueue(forKey: "pending_sms_texts")
        let defaults = smsDefaults
        guard let data = defaults.data(forKey: "pending_sms_texts"),
              let queue = try? JSONDecoder().decode([PendingSMSText].self, from: data)
        else { return [] }
        defaults.removeObject(forKey: "pending_sms_texts")
        return queue
    }

    // MARK: – Pending Apple Pay queue

    /// Verified the same way as `enqueuePendingSMS`.
    @discardableResult
    func enqueuePendingApplePay(_ tx: PendingApplePayTransaction) -> Bool {
        migrateLegacyQueue(forKey: "pending_applepay")
        let defaults = smsDefaults
        var queue: [PendingApplePayTransaction] = []
        if let data = defaults.data(forKey: "pending_applepay"),
           let existing = try? JSONDecoder().decode([PendingApplePayTransaction].self, from: data) {
            queue = existing
        }
        queue.append(tx)
        guard let data = try? JSONEncoder().encode(queue) else { return false }
        defaults.set(data, forKey: "pending_applepay")
        return defaults.data(forKey: "pending_applepay") == data
    }

    /// Peek, without draining — see `pendingSMSCount`.
    var pendingApplePayCount: Int {
        guard let data = smsDefaults.data(forKey: "pending_applepay"),
              let queue = try? JSONDecoder().decode([PendingApplePayTransaction].self, from: data)
        else { return 0 }
        return queue.count
    }

    func dequeuePendingApplePay() -> [PendingApplePayTransaction] {
        migrateLegacyQueue(forKey: "pending_applepay")
        let defaults = smsDefaults
        guard let data = defaults.data(forKey: "pending_applepay"),
              let queue = try? JSONDecoder().decode([PendingApplePayTransaction].self, from: data)
        else { return [] }
        defaults.removeObject(forKey: "pending_applepay")
        return queue
    }
}

/// Structured Apple Pay transaction queued by `LogApplePayTransaction`.
/// Wallet hands Shortcuts real fields rather than text, so unlike
/// `PendingSMSText` there is nothing here left to parse.
struct PendingApplePayTransaction: Codable {
    var id: UUID
    var amount: Double
    var merchant: String
    var currency: String?
    var date: Date?
    var walletCategory: String?
    var card: String?
    var isRefund: Bool

    init(amount: Double, merchant: String, currency: String? = nil, date: Date? = nil,
         walletCategory: String? = nil, card: String? = nil, isRefund: Bool = false) {
        self.id = UUID()
        self.amount = amount
        self.merchant = merchant
        self.currency = currency
        self.date = date
        self.walletCategory = walletCategory
        self.card = card
        self.isRefund = isRefund
    }
}

// MARK: – Shared snapshot types

/// Account and goal snapshots exist for the App Intents (`AccountEntity`,
/// `GoalEntity`) rather than for any widget — Siri resolves names against
/// these without the intent needing a `ModelContext`, which AppIntents can't
/// reliably build (see PROJECT_MAP §8).
struct WidgetAccountSnapshot: Codable, Identifiable {
    var id: UUID
    var name: String
    var type: String
    var balance: Double
    var currency: String
    var bankName: String
}

struct WidgetGoalSnapshot: Codable, Identifiable {
    var id: UUID
    var name: String
    var current: Double
    var target: Double
    var currency: String
    var isCompleted: Bool
}

struct WidgetTxSnapshot: Codable, Identifiable {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var type: String   // "income" | "expense" | "transfer"
    var date: Date
    var categoryIcon: String
}

struct WidgetBudgetSnapshot: Codable, Identifiable {
    var id: UUID
    var name: String
    var spent: Double
    var total: Double
    var currency: String
    var color: String
    var icon: String

    var progress: Double { total > 0 ? min(spent / total, 1.0) : 0 }
    var remaining: Double { max(total - spent, 0) }
    var isOverBudget: Bool { spent > total }
}

struct WidgetBillSnapshot: Codable, Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var currency: String
    var dueDate: Date
    var icon: String
    var isPaid: Bool

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                        to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
    }
}

struct WidgetPaymentSnapshot: Codable, Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var currency: String
    var dueDate: Date
    var icon: String
    var kind: String  // "bill" | "bnpl" | "scheduled"

    var daysUntilDue: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: dueDate)
        ).day ?? 0
    }
}

struct PendingWidgetTransaction: Codable {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var type: String  // "income" | "expense"
    var categoryName: String
    var date: Date
    var createdAt: Date

    init(title: String, amount: Double, currency: String = "AED",
         type: String, categoryName: String) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.currency = currency
        self.type = type
        self.categoryName = categoryName
        self.date = Date()
        self.createdAt = Date()
    }
}

/// Raw SMS text queued by `LogTransactionFromText` — an AppIntent process
/// can't reliably touch SwiftData, so it only captures the message; parsing
/// (template match / on-device model) and filing into the review queue
/// happen in `SMSIngestService` when the app is next foregrounded, exactly
/// like `PendingWidgetTransaction` above.
struct PendingSMSText: Codable {
    var id: UUID
    var rawText: String
    var senderId: String?
    var receivedAt: Date

    init(rawText: String, senderId: String? = nil) {
        self.id = UUID()
        self.rawText = rawText
        self.senderId = senderId
        self.receivedAt = Date()
    }
}
