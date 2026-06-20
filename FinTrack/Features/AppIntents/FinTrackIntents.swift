import AppIntents
import Foundation

// MARK: – Entity types

/// Lightweight transaction entity exposed to the Shortcuts app.
struct TransactionEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Transaction" }
    static var defaultQuery = TransactionEntityQuery()

    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var type: String
    var categoryName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title) — \(currency) \(String(format: "%.2f", amount))")
    }
}

struct TransactionEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TransactionEntity] { [] }
    func suggestedEntities() async throws -> [TransactionEntity] { [] }
}

// MARK: – Log Expense Intent

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Quickly log an expense in FinTrack.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount", description: "Amount in your base currency")
    var amount: Double

    @Parameter(title: "Category", description: "Category name", default: "Shopping")
    var category: String

    @Parameter(title: "Description", description: "What was this expense for?", default: "Expense")
    var title_: String

    @Parameter(title: "Currency", description: "3-letter currency code", default: "AED")
    var currency: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tx = PendingWidgetTransaction(
            title: title_,
            amount: amount,
            currency: currency,
            type: "expense",
            categoryName: category
        )
        WidgetDataService.shared.enqueuePendingTransaction(tx)
        return .result(dialog: "Logged \(currency) \(String(format: "%.2f", amount)) for \(title_) in \(category).")
    }
}

// MARK: – Log Income Intent

struct LogIncomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Income"
    static var description = IntentDescription("Log an income entry in FinTrack.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount", description: "Amount received")
    var amount: Double

    @Parameter(title: "Source", description: "Source of income", default: "Income")
    var source: String

    @Parameter(title: "Currency", default: "AED")
    var currency: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tx = PendingWidgetTransaction(
            title: source,
            amount: amount,
            currency: currency,
            type: "income",
            categoryName: "Income"
        )
        WidgetDataService.shared.enqueuePendingTransaction(tx)
        return .result(dialog: "Logged \(currency) \(String(format: "%.2f", amount)) income from \(source).")
    }
}

// MARK: – Get Balance Intent

struct GetBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Net Worth"
    static var description = IntentDescription("Get your current net worth from FinTrack.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        guard let defaults = UserDefaults(suiteName: "group.com.fintrack.shared") else {
            return .result(value: 0, dialog: "Net worth unavailable.")
        }
        let netWorth = defaults.double(forKey: "widget_net_worth")
        let currency = defaults.string(forKey: "widget_currency") ?? "AED"
        let formatted = formatCompact(netWorth, currency: currency)
        return .result(value: netWorth, dialog: "Your current net worth is \(formatted).")
    }

    private func formatCompact(_ value: Double, currency: String) -> String {
        let abs = Swift.abs(value)
        if abs >= 1_000_000 { return "\(currency) \(String(format: "%.1fM", abs / 1_000_000))" }
        if abs >= 1_000    { return "\(currency) \(String(format: "%.1fK", abs / 1_000))" }
        return "\(currency) \(String(format: "%.2f", value))"
    }
}

// MARK: – Get Budget Status Intent

struct GetBudgetStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Budget Status"
    static var description = IntentDescription("Check your current budget usage in FinTrack.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Budget Name", description: "Leave blank to get the top budget")
    var budgetName: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let defaults = UserDefaults(suiteName: "group.com.fintrack.shared"),
              let data = defaults.data(forKey: "widget_budgets"),
              let budgets = try? JSONDecoder().decode([BudgetIntentSnapshot].self, from: data),
              !budgets.isEmpty
        else {
            return .result(dialog: "No budget data available. Open FinTrack to set up budgets.")
        }

        let target: BudgetIntentSnapshot
        if let name = budgetName?.lowercased(),
           let match = budgets.first(where: { $0.name.lowercased().contains(name) }) {
            target = match
        } else {
            target = budgets[0]
        }

        let pct = target.total > 0 ? Int(min(target.spent / target.total, 1.0) * 100) : 0
        let remaining = max(target.total - target.spent, 0)
        let overBudget = target.spent > target.total

        if overBudget {
            let over = target.spent - target.total
            return .result(dialog: "'\(target.name)' is over budget by \(target.currency) \(String(format: "%.2f", over)). You've spent \(pct)%.")
        } else {
            return .result(dialog: "'\(target.name)' is at \(pct)%. \(target.currency) \(String(format: "%.2f", remaining)) remaining of \(target.currency) \(String(format: "%.2f", target.total)).")
        }
    }
}

// Lightweight snapshot for App Intents (no @Model dependency)
private struct BudgetIntentSnapshot: Codable {
    var id: UUID
    var name: String
    var spent: Double
    var total: Double
    var currency: String
}

// MARK: – AppShortcutsProvider

struct FinTrackShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Add expense to \(.applicationName)",
                "Record spending in \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "arrow.up.circle.fill"
        )
        AppShortcut(
            intent: LogIncomeIntent(),
            phrases: [
                "Log income in \(.applicationName)",
                "Add income to \(.applicationName)",
                "Record income in \(.applicationName)"
            ],
            shortTitle: "Log Income",
            systemImageName: "arrow.down.circle.fill"
        )
        AppShortcut(
            intent: GetBalanceIntent(),
            phrases: [
                "What's my net worth in \(.applicationName)",
                "Check my balance in \(.applicationName)",
                "How much do I have in \(.applicationName)"
            ],
            shortTitle: "Check Balance",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: GetBudgetStatusIntent(),
            phrases: [
                "Check my budget in \(.applicationName)",
                "How's my budget in \(.applicationName)",
                "Budget status in \(.applicationName)"
            ],
            shortTitle: "Budget Status",
            systemImageName: "chart.pie.fill"
        )
    }
}
