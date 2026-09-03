import Foundation
import WidgetKit

/// Writes lightweight data into the shared App Group UserDefaults
/// so FinTrackWidget can display it without accessing SwiftData directly.
final class WidgetDataService {
    static let shared = WidgetDataService()
    private init() {}

    private let suiteName = "group.com.fintrack.shared"

    // MARK: – Full update (preferred)

    func updateAll(
        netWorth: Double,
        currency: String,
        transactions: [WidgetTxSnapshot],
        budgets: [WidgetBudgetSnapshot],
        bills: [WidgetBillSnapshot],
        payments: [WidgetPaymentSnapshot] = []
    ) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
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
        WidgetCenter.shared.reloadAllTimelines()
    }

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

    func enqueuePendingSMS(_ sms: PendingSMSText) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        var queue: [PendingSMSText] = []
        if let data = defaults.data(forKey: "pending_sms_texts"),
           let existing = try? JSONDecoder().decode([PendingSMSText].self, from: data) {
            queue = existing
        }
        queue.append(sms)
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: "pending_sms_texts")
        }
    }

    func dequeuePendingSMS() -> [PendingSMSText] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "pending_sms_texts"),
              let queue = try? JSONDecoder().decode([PendingSMSText].self, from: data)
        else { return [] }
        defaults.removeObject(forKey: "pending_sms_texts")
        return queue
    }
}

// MARK: – Shared snapshot types

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
