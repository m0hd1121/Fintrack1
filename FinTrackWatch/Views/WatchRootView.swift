import SwiftUI

struct WatchRootView: View {
    @StateObject private var dataSource = WatchDataSource.shared

    var body: some View {
        TabView {
            WatchBalanceView()
                .tabItem { Label("Balance", systemImage: "chart.line.uptrend.xyaxis") }

            WatchTransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet") }

            WatchQuickExpenseView()
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
        }
        .environmentObject(dataSource)
        .onAppear { dataSource.reload() }
    }
}

// MARK: – Shared data source (reads App Group UserDefaults)

final class WatchDataSource: ObservableObject {
    static let shared = WatchDataSource()
    private init() {}

    private let suiteName = "group.com.fintrack.shared"

    @Published var netWorth: Double = 0
    @Published var currency: String = "AED"
    @Published var transactions: [WatchTransaction] = []
    @Published var budgets: [WatchBudget] = []
    @Published var bills: [WatchBill] = []

    func reload() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        netWorth = defaults.double(forKey: "widget_net_worth")
        currency = defaults.string(forKey: "widget_currency") ?? "AED"

        if let data = defaults.data(forKey: "widget_recent_transactions"),
           let items = try? JSONDecoder().decode([WatchTransaction].self, from: data) {
            transactions = items
        }
        if let data = defaults.data(forKey: "widget_budgets"),
           let items = try? JSONDecoder().decode([WatchBudget].self, from: data) {
            budgets = items
        }
        if let data = defaults.data(forKey: "widget_bills"),
           let items = try? JSONDecoder().decode([WatchBill].self, from: data) {
            bills = items.filter { !$0.isPaid }
        }
    }

    func enqueuePendingTransaction(_ tx: WatchPendingTransaction) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        var queue: [WatchPendingTransaction] = []
        if let data = defaults.data(forKey: "pending_transactions"),
           let existing = try? JSONDecoder().decode([WatchPendingTransaction].self, from: data) {
            queue = existing
        }
        queue.append(tx)
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: "pending_transactions")
        }
    }
}

// MARK: – Lightweight watch-local data models (Codable mirrors of WidgetDataService types)

struct WatchTransaction: Codable, Identifiable {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var type: String
    var date: Date
    var categoryIcon: String
}

struct WatchBudget: Codable, Identifiable {
    var id: UUID
    var name: String
    var spent: Double
    var total: Double
    var currency: String
    var color: String
    var icon: String
    var progress: Double { total > 0 ? min(spent / total, 1.0) : 0 }
}

struct WatchBill: Codable, Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var currency: String
    var dueDate: Date
    var icon: String
    var isPaid: Bool
}

struct WatchPendingTransaction: Codable {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var type: String
    var categoryName: String
    var date: Date
    var createdAt: Date
}
