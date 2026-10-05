import SwiftUI
import SwiftData

/// The screens the Plan tab pushes. One `navigationDestination(item:)` so only
/// one destination is ever active (see the note in `DashboardView`).
private enum PlanRoute: Identifiable, Hashable {
    case budgets, bills, goals, income, debt, household, tools
    var id: Self { self }
}

/// Plan tab: where money should go. A hub that opens the existing module
/// screens — Budgets, Bills & Payments, Goals, Income, Debt, Household
/// and Planning Tools — each with a one-line live summary so the state is
/// readable (and spoken by VoiceOver) without opening it. Creating things goes
/// through the labelled Add menu; navigating goes through the rows.
struct PlanView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    @Query private var budgets: [Budget]
    @Query(filter: #Predicate<Bill> { $0.isActive }, sort: \Bill.nextDueDate) private var bills: [Bill]
    @Query(filter: #Predicate<SavingsGoal> { $0.isArchived == false && $0.isCompleted == false })
    private var goals: [SavingsGoal]
    @Query private var loans: [Loan]
    @Query(filter: #Predicate<SalaryRecord> { $0.isActive }) private var salaryRecords: [SalaryRecord]

    @State private var route: PlanRoute? = nil
    @State private var showingAddBudget = false
    @State private var showingAddBill = false
    @State private var showingAddGoal = false
    @State private var showingAddEnvelope = false

    private var baseCurrency: String { appState.baseCurrency }

    // MARK: Summaries

    private var budgetSummary: String {
        let active = budgets.filter { $0.isInEffect(during: Date()) }.count
        return active == 0 ? "Set spending limits by category" : "\(active) active budget\(active == 1 ? "" : "s")"
    }

    private var billSummary: String {
        guard let next = bills.first else { return "Rent, utilities and subscriptions" }
        if next.isOverdue { return "\(next.name) is overdue" }
        switch next.daysUntilDue {
        case 0:  return "Next: \(next.name), due today"
        case 1:  return "Next: \(next.name), due tomorrow"
        default: return "Next: \(next.name), due in \(next.daysUntilDue) days"
        }
    }

    private var goalSummary: String {
        guard !goals.isEmpty else { return "Save towards a target" }
        let saved = goals.reduce(0) { $0 + currencyService.convert($1.currentAmount, from: $1.currency, to: baseCurrency) }
        return "\(saved.asCompact(currency: baseCurrency)) saved across \(goals.count) goal\(goals.count == 1 ? "" : "s")"
    }

    private var incomeSummary: String {
        salaryRecords.isEmpty
            ? "Salary, freelance, rental and dividends"
            : "\(salaryRecords.count) salary record\(salaryRecords.count == 1 ? "" : "s") · freelance, rental, dividends"
    }

    private var debtSummary: String {
        let active = loans.filter(\.isActive)
        guard !active.isEmpty else { return "Loans, payoff plan, lent & borrowed, BNPL" }
        let owed = active.reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency) }
        return "\(owed.asCompact(currency: baseCurrency)) in \(active.count) loan\(active.count == 1 ? "" : "s") · payoff planner"
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    HubSection(title: nil) {
                        row(.budgets, symbol: "chart.pie.fill", tint: FTColor.accent, title: "Budgets", subtitle: budgetSummary)
                        divider
                        row(.bills, symbol: "calendar.badge.clock", tint: FTColor.catCoral, title: "Bills & Payments", subtitle: billSummary)
                        divider
                        row(.goals, symbol: "star.fill", tint: FTColor.gold, title: "Goals", subtitle: goalSummary)
                        divider
                        row(.income, symbol: "banknote.fill", tint: FTColor.income, title: "Income", subtitle: incomeSummary)
                        divider
                        row(.debt, symbol: "creditcard.fill", tint: FTColor.expense, title: "Debt", subtitle: debtSummary)
                    }
                    HubSection(title: "Household & planning") {
                        row(.household, symbol: "person.3.fill", tint: FTColor.catTeal, title: "Household",
                            subtitle: "Family budget, allowances, shared goals")
                        divider
                        row(.tools, symbol: "compass.drawing", tint: FTColor.catPurple, title: "Planning Tools",
                            subtitle: "Retirement, life events, estate and more")
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.sm)
                .padding(.bottom, FTSpacing.xxl)
            }
            .background { FTBackdrop() }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showingAddBudget = true } label: { Label("Budget", systemImage: "chart.pie") }
                        Button { showingAddBill = true } label: { Label("Bill or Subscription", systemImage: "calendar.badge.plus") }
                        Button { showingAddGoal = true } label: { Label("Goal", systemImage: "star") }
                        Button { showingAddEnvelope = true } label: { Label("Envelope", systemImage: "envelope") }
                    } label: {
                        Label("Add", systemImage: "plus").labelStyle(.titleAndIcon)
                    }
                    .accessibilityLabel("Add a budget, bill, goal or envelope")
                }
            }
            .navigationDestination(item: $route) { route in
                switch route {
                case .budgets:   BudgetView(embedInNavigationStack: false)
                case .bills:     BillsView(embedInNavigationStack: false)
                case .goals:     SavingsGoalsView()
                case .income:    IncomeManagementView()
                case .debt:      DebtManagementView()
                case .household: FamilyFinanceView()
                case .tools:     PlanningToolsView()
                }
            }
            .sheet(isPresented: $showingAddBudget) { AddBudgetView() }
            .sheet(isPresented: $showingAddBill) { AddBillView() }
            .sheet(isPresented: $showingAddGoal) { AddSavingsGoalView() }
            .sheet(isPresented: $showingAddEnvelope) { AddEnvelopeView() }
            // Selecting a tab pops any pushed screen back here.
            .onChange(of: appState.popToRootTick) { route = nil }
        }
    }

    private var divider: some View { Divider().opacity(0.4) }

    private func row(_ target: PlanRoute, symbol: String, tint: Color, title: String, subtitle: String) -> some View {
        Button { route = target } label: {
            HubRow(symbol: symbol, tint: tint, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}
