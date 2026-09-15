import AppIntents
import Foundation

// MARK: – Entity data source

/// Where the entity queries below get their data.
///
/// An `AppIntent` cannot reliably build a `ModelContext` (PROJECT_MAP §8), so
/// entities resolve against the lightweight snapshots `DashboardView` writes
/// through `WidgetDataService` on every refresh. Those live in
/// `UserDefaults.standard`, which is this app's own container — and since the
/// intents run in this app's process (single application target, no App
/// Intents Extension), reading it here is reading the same store the app just
/// wrote.
///
/// The snapshot is therefore as fresh as the last dashboard refresh. That is
/// the right trade for name resolution: Siri needs names and headline figures,
/// not live balances to the cent, and this keeps intents off SwiftData
/// entirely.
@MainActor
enum IntentSnapshotSource {
    static var accounts: [WidgetAccountSnapshot] {
        WidgetDataService.shared.snapshot([WidgetAccountSnapshot].self, forKey: "widget_accounts")
    }
    static var budgets: [BudgetIntentSnapshot] {
        WidgetDataService.shared.snapshot([BudgetIntentSnapshot].self, forKey: "widget_budgets")
    }
    static var goals: [WidgetGoalSnapshot] {
        WidgetDataService.shared.snapshot([WidgetGoalSnapshot].self, forKey: "widget_goals")
    }

    /// Case- and substring-insensitive name match, so "salary" finds
    /// "Salary Account" and Siri's transcription doesn't have to be exact.
    static func matches(_ name: String, _ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return name.lowercased().contains(needle)
    }
}

// MARK: – Account

struct AccountEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Account" }
    static var defaultQuery = AccountEntityQuery()

    var id: UUID
    var name: String
    var balance: Double
    var currency: String
    var bankName: String
    var accountType: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(currency) \(String(format: "%.2f", balance))"
        )
    }

    init(snapshot: WidgetAccountSnapshot) {
        id = snapshot.id
        name = snapshot.name
        balance = snapshot.balance
        currency = snapshot.currency
        bankName = snapshot.bankName
        accountType = snapshot.type
    }
}

/// `EntityStringQuery` rather than plain `EntityQuery`: the string variant is
/// what lets Siri and Shortcuts resolve "my Emirates NBD account" to an entity
/// from spoken or typed text. Without it a parameter can only be picked from a
/// list.
struct AccountEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [AccountEntity] {
        await MainActor.run {
            IntentSnapshotSource.accounts
                .filter { identifiers.contains($0.id) }
                .map(AccountEntity.init(snapshot:))
        }
    }

    func entities(matching string: String) async throws -> [AccountEntity] {
        await MainActor.run {
            IntentSnapshotSource.accounts
                .filter { IntentSnapshotSource.matches($0.name, string) || IntentSnapshotSource.matches($0.bankName, string) }
                .map(AccountEntity.init(snapshot:))
        }
    }

    func suggestedEntities() async throws -> [AccountEntity] {
        await MainActor.run {
            IntentSnapshotSource.accounts.map(AccountEntity.init(snapshot:))
        }
    }
}

// MARK: – Budget

struct BudgetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Budget" }
    static var defaultQuery = BudgetEntityQuery()

    var id: UUID
    var name: String
    var spent: Double
    var total: Double
    var currency: String

    /// Clamped for display only; `spent` keeps the true figure so an
    /// over-budget category still reports the real overspend.
    var percentUsed: Int {
        total > 0 ? Int((min(spent / total, 1.0) * 100).rounded()) : 0
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(percentUsed)% of \(currency) \(String(format: "%.2f", total))"
        )
    }

    init(snapshot: BudgetIntentSnapshot) {
        id = snapshot.id
        name = snapshot.name
        spent = snapshot.spent
        total = snapshot.total
        currency = snapshot.currency
    }
}

struct BudgetEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [BudgetEntity] {
        await MainActor.run {
            IntentSnapshotSource.budgets
                .filter { identifiers.contains($0.id) }
                .map(BudgetEntity.init(snapshot:))
        }
    }

    func entities(matching string: String) async throws -> [BudgetEntity] {
        await MainActor.run {
            IntentSnapshotSource.budgets
                .filter { IntentSnapshotSource.matches($0.name, string) }
                .map(BudgetEntity.init(snapshot:))
        }
    }

    func suggestedEntities() async throws -> [BudgetEntity] {
        await MainActor.run {
            IntentSnapshotSource.budgets.map(BudgetEntity.init(snapshot:))
        }
    }
}

// MARK: – Savings goal

struct GoalEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Savings Goal" }
    static var defaultQuery = GoalEntityQuery()

    var id: UUID
    var name: String
    var current: Double
    var target: Double
    var currency: String
    var isCompleted: Bool

    var percentComplete: Int {
        target > 0 ? Int((min(current / target, 1.0) * 100).rounded()) : 0
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(percentComplete)% of \(currency) \(String(format: "%.2f", target))"
        )
    }

    init(snapshot: WidgetGoalSnapshot) {
        id = snapshot.id
        name = snapshot.name
        current = snapshot.current
        target = snapshot.target
        currency = snapshot.currency
        isCompleted = snapshot.isCompleted
    }
}

struct GoalEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [GoalEntity] {
        await MainActor.run {
            IntentSnapshotSource.goals
                .filter { identifiers.contains($0.id) }
                .map(GoalEntity.init(snapshot:))
        }
    }

    func entities(matching string: String) async throws -> [GoalEntity] {
        await MainActor.run {
            IntentSnapshotSource.goals
                .filter { IntentSnapshotSource.matches($0.name, string) }
                .map(GoalEntity.init(snapshot:))
        }
    }

    func suggestedEntities() async throws -> [GoalEntity] {
        await MainActor.run {
            IntentSnapshotSource.goals.map(GoalEntity.init(snapshot:))
        }
    }
}

// MARK: – Querying intents

struct GetAccountBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Account Balance"
    static var description = IntentDescription("Check the balance of one of your FinTrack accounts.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Account")
    var account: AccountEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get the balance of \(\.$account)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        .result(
            value: account.balance,
            dialog: "\(account.name) has \(account.currency) \(String(format: "%.2f", account.balance))."
        )
    }
}

struct GetGoalProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Savings Goal Progress"
    static var description = IntentDescription("Check how far along one of your savings goals is.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Goal")
    var goal: GoalEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get progress for \(\.$goal)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if goal.isCompleted {
            return .result(dialog: "\(goal.name) is complete — you reached \(goal.currency) \(String(format: "%.2f", goal.target)).")
        }
        let remaining = max(goal.target - goal.current, 0)
        return .result(dialog: "\(goal.name) is \(goal.percentComplete)% funded. \(goal.currency) \(String(format: "%.2f", remaining)) to go.")
    }
}

// MARK: – Navigation intents

/// Which screen a navigation intent asked for. Stored rather than applied
/// directly: an intent has no handle on the running `AppState`, so it leaves a
/// request behind and `RootView` picks it up on the next foreground — the same
/// enqueue/drain shape the Siri quick-add and SMS queues already use.
/// Deliberately limited to the four destinations that are real tabs.
///
/// Savings Goals is a `navigationDestination` inside `AccountsView`'s private
/// route state, and Reports has no tab on iPhone (only the iPad split view
/// resolves `AppTab.reports`) — so "open goals" or "open reports" would land
/// on the wrong screen or a blank one. Answering *about* a goal is covered by
/// `GetGoalProgressIntent` instead, which is more useful than navigating
/// anyway.
enum PendingNavigationTarget: String, Codable {
    case dashboard, transactions, budget, accounts

    var tab: AppTab {
        switch self {
        case .dashboard:    return .dashboard
        case .transactions: return .transactions
        case .budget:       return .budget
        case .accounts:     return .accounts
        }
    }
}

@MainActor
enum NavigationRequestStore {
    private static let key = "ft_pending_navigation_v1"

    static func request(_ target: PendingNavigationTarget) {
        UserDefaults.standard.set(target.rawValue, forKey: key)
    }

    /// Reads and clears in one step, so a request is never applied twice.
    static func consume() -> PendingNavigationTarget? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return PendingNavigationTarget(rawValue: raw)
    }
}

/// `openAppWhenRun = true` is the supported way for an intent to bring the app
/// forward; the app itself then decides what to show.
struct OpenFinTrackSectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Section"
    static var description = IntentDescription("Open a section of FinTrack.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Section")
    var section: NavigationSectionAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$section) in FinTrack")
    }

    func perform() async throws -> some IntentResult {
        let target = section.target
        await MainActor.run { NavigationRequestStore.request(target) }
        return .result()
    }
}

enum NavigationSectionAppEnum: String, AppEnum {
    case dashboard, transactions, budget, accounts

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Section" }

    static var caseDisplayRepresentations: [NavigationSectionAppEnum: DisplayRepresentation] {
        [
            .dashboard:    "Dashboard",
            .transactions: "Transactions",
            .budget:       "Budget",
            .accounts:     "Accounts"
        ]
    }

    var target: PendingNavigationTarget {
        switch self {
        case .dashboard:    return .dashboard
        case .transactions: return .transactions
        case .budget:       return .budget
        case .accounts:     return .accounts
        }
    }
}

/// Fixed-target variants. An `AppShortcut` tile takes no parameters, so each
/// spoken phrase needs its own parameterless intent — this is why these exist
/// alongside the configurable `OpenFinTrackSectionIntent` above.
struct OpenTransactionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Transactions"
    static var description = IntentDescription("Open your transaction history in FinTrack.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { NavigationRequestStore.request(.transactions) }
        return .result()
    }
}

struct OpenBudgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Budget"
    static var description = IntentDescription("Open your budget in FinTrack.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { NavigationRequestStore.request(.budget) }
        return .result()
    }
}

struct OpenAccountsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Accounts"
    static var description = IntentDescription("Open your accounts in FinTrack.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { NavigationRequestStore.request(.accounts) }
        return .result()
    }
}
