import SwiftUI
import SwiftData

/// A screen or setting that Search can open by name. Every module is listed,
/// so a feature can be found without knowing which tab it lives in.
private enum AppScreen: String, CaseIterable, Identifiable, Hashable {
    case reviewQueue, importSync, budgets, bills, goals, income, debt, household, planningTools
    case netWorth, investments, assets, insights, healthScore, reports
    case settings, notifications, appearance, security, backup, emailBackup, homeLayout, siri
    case privacy, terms

    var id: Self { self }

    var title: String {
        switch self {
        case .reviewQueue:   return "To Review"
        case .importSync:    return "Import & Sync"
        case .budgets:       return "Budgets"
        case .bills:         return "Bills & Payments"
        case .goals:         return "Goals"
        case .income:        return "Income"
        case .debt:          return "Debt"
        case .household:     return "Household"
        case .planningTools: return "Planning Tools"
        case .netWorth:      return "Net Worth"
        case .investments:   return "Investments"
        case .assets:        return "Property & Assets"
        case .insights:      return "Insights"
        case .healthScore:   return "Financial Health Score"
        case .reports:       return "Reports"
        case .settings:      return "Settings"
        case .notifications: return "Notifications"
        case .appearance:    return "Appearance"
        case .security:      return "Face ID & Passcode"
        case .backup:        return "Backup & Restore"
        case .emailBackup:   return "Email Backup"
        case .homeLayout:    return "Home Screen Layout"
        case .siri:          return "Siri & Shortcuts"
        case .privacy:       return "Privacy Policy"
        case .terms:         return "Terms of Service"
        }
    }

    /// Where it lives, shown under the title so people learn the structure.
    var location: String {
        switch self {
        case .reviewQueue, .importSync: return "Activity"
        case .budgets, .bills, .goals, .income, .debt, .household, .planningTools: return "Plan"
        case .netWorth, .investments, .assets: return "Wealth"
        case .insights, .healthScore, .reports: return "Home"
        default: return "Settings"
        }
    }

    /// Extra words people might type for this screen.
    var keywords: String {
        switch self {
        case .reviewQueue:   return "review queue imported pending approve email sms apple pay"
        case .importSync:    return "import sync email gmail outlook sms apple pay csv ofx qif statement bank rules"
        case .budgets:       return "budget envelope zero-based template ramadan eid summer limit"
        case .bills:         return "bill subscription calendar recurring dewa utilities rent upcoming payments due emi installment minimum payment"
        case .goals:         return "goal savings emergency fund hajj umrah down payment"
        case .income:        return "income salary freelance rental rent dividend passive stability"
        case .debt:          return "debt loan payoff snowball avalanche calculator lent borrowed bnpl tabby tamara utilization credit card"
        case .household:     return "family household allowance children shared goals permissions members"
        case .planningTools: return "retirement life events estate zakat cfo smart cash education planning"
        case .netWorth:      return "net worth history forecast allocation milestones snapshot"
        case .investments:   return "investments portfolio stocks etf crypto bitcoin gold dividends capital gains"
        case .assets:        return "assets property real estate vehicle car personal digital"
        case .insights:      return "insights ai anomalies patterns forecast savings coach negotiate esg twin chat ask"
        case .healthScore:   return "health score grade intelligence predictions"
        case .reports:       return "reports export pdf csv cash flow spending vat tax annual merchants cheques"
        case .settings:      return "settings preferences profile name currency"
        case .notifications: return "notifications alerts reminders digest"
        case .appearance:    return "appearance theme dark mode accent contrast week fiscal year"
        case .security:      return "security face id touch id passcode pin lock privacy"
        case .backup:        return "backup restore export import file clear delete data"
        case .emailBackup:   return "email backup restore"
        case .homeLayout:    return "home dashboard layout customize sections"
        case .siri:          return "siri shortcuts voice automation"
        case .privacy:       return "privacy policy"
        case .terms:         return "terms of service legal"
        }
    }

    var symbol: String {
        switch self {
        case .reviewQueue:   return "tray.full"
        case .importSync:    return "arrow.down.circle"
        case .budgets:       return "chart.pie"
        case .bills:         return "calendar.badge.clock"
        case .goals:         return "star"
        case .income:        return "banknote"
        case .debt:          return "creditcard"
        case .household:     return "person.3"
        case .planningTools: return "compass.drawing"
        case .netWorth:      return "chart.line.uptrend.xyaxis"
        case .investments:   return "chart.bar.xaxis.ascending"
        case .assets:        return "house.lodge"
        case .insights:      return "sparkles"
        case .healthScore:   return "heart.text.square"
        case .reports:       return "doc.text.magnifyingglass"
        case .settings:      return "gearshape"
        case .notifications: return "bell.badge"
        case .appearance:    return "paintbrush"
        case .security:      return "faceid"
        case .backup:        return "externaldrive"
        case .emailBackup:   return "envelope.badge.shield.half.filled"
        case .homeLayout:    return "square.grid.2x2"
        case .siri:          return "mic"
        case .privacy:       return "checkmark.shield"
        case .terms:         return "doc.text"
        }
    }

    func matches(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query) || keywords.localizedCaseInsensitiveContains(query)
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .reviewQueue:   EmailReviewQueueView()
        case .importSync:    ImportIntegrationView()
        case .budgets:       BudgetView(embedInNavigationStack: false)
        case .bills:         BillsView(embedInNavigationStack: false)
        case .goals:         SavingsGoalsView()
        case .income:        IncomeManagementView()
        case .debt:          DebtManagementView()
        case .household:     FamilyFinanceView()
        case .planningTools: PlanningToolsView()
        case .netWorth:      NetWorthDashboardView(embedInNavigationStack: false)
        case .investments:   InvestmentPortfolioView()
        case .assets:        AssetsLiabilitiesView()
        case .insights:      AIAssistantView(embedInNavigationStack: false)
        case .healthScore:   FinancialIntelligenceView()
        case .reports:       ReportsView()
        case .settings:      SettingsView()
        case .notifications: NotificationSettingsView()
        case .appearance:    AppearanceView()
        case .security:      SecurityPrivacyView()
        case .backup:        LocalBackupView()
        case .emailBackup:   EmailBackupView()
        case .homeLayout:    DashboardCustomizerView()
        case .siri:          SiriShortcutsView()
        case .privacy:       PrivacyPolicyView()
        case .terms:         TermsOfServiceView()
        }
    }
}

/// The Search tab (`Tab(role: .search)`): transactions, accounts, bills, goals
/// and every screen or setting by name. Transactions are fetched on demand
/// with a bounded, sorted `FetchDescriptor` rather than an unbounded `@Query`.
struct GlobalSearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Query(sort: \SavingsGoal.name) private var goals: [SavingsGoal]

    @State private var query = ""
    @State private var transactionResults: [Transaction] = []
    @State private var selectedTransaction: Transaction? = nil
    @State private var selectedAccount: Account? = nil
    @State private var path = NavigationPath()
    @FocusState private var isSearchFocused: Bool

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var screenResults: [AppScreen] {
        trimmed.isEmpty ? [] : AppScreen.allCases.filter { $0.matches(trimmed) }
    }
    private var accountResults: [Account] {
        trimmed.isEmpty ? [] : accounts.filter {
            !$0.isArchived && ($0.name.localizedCaseInsensitiveContains(trimmed)
                               || $0.effectiveBankName.localizedCaseInsensitiveContains(trimmed))
        }
    }
    private var billResults: [Bill] {
        trimmed.isEmpty ? [] : bills.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
    private var goalResults: [SavingsGoal] {
        trimmed.isEmpty ? [] : goals.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
    private var hasResults: Bool {
        !screenResults.isEmpty || !accountResults.isEmpty || !billResults.isEmpty
            || !goalResults.isEmpty || !transactionResults.isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if trimmed.isEmpty {
                    suggestions
                } else {
                    results
                }
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Search")
            // Top placement: on iPhone the bottom edge belongs to the tab bar.
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Merchants, accounts, bills, settings")
            .searchFocused($isSearchFocused)
            .overlay {
                if !trimmed.isEmpty && !hasResults {
                    ContentUnavailableView.search(text: trimmed)
                }
            }
            .navigationDestination(for: AppScreen.self) { $0.destination }
            .navigationDestination(for: SavingsGoal.self) { SavingsGoalDetailView(goal: $0) }
            .sheet(item: $selectedTransaction) { TransactionDetailView(transaction: $0) }
            .sheet(item: $selectedAccount) { AccountDetailView(account: $0) }
            // Debounced so typing doesn't fetch on every keystroke.
            .task(id: trimmed) {
                guard trimmed.count >= 2 else { transactionResults = []; return }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                transactionResults = fetchTransactions(matching: trimmed)
            }
            .onChange(of: appState.popToRootTick) { path = NavigationPath() }
            // Choosing Search in the tab bar starts a search, as the system
            // search tab does (only when nothing has been typed yet).
            .onChange(of: appState.selectedTab) { _, tab in
                if tab == .search && trimmed.isEmpty && path.isEmpty { isSearchFocused = true }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var suggestions: some View {
        Section("Go to") {
            ForEach([AppScreen.reviewQueue, .budgets, .bills, .goals, .netWorth, .reports, .insights, .settings]) { screen in
                NavigationLink(value: screen) { screenLabel(screen) }
            }
        }
        Section {
            Text("Search for a merchant, an account, a bill, a goal, or any screen or setting by name.")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
    }

    @ViewBuilder
    private var results: some View {
        if !screenResults.isEmpty {
            Section("Screens & settings") {
                ForEach(screenResults) { screen in
                    NavigationLink(value: screen) { screenLabel(screen) }
                }
            }
        }
        if !transactionResults.isEmpty {
            Section("Transactions") {
                ForEach(transactionResults) { tx in
                    Button { selectedTransaction = tx } label: {
                        TransactionRowView(transaction: tx, baseCurrency: appState.baseCurrency)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if !accountResults.isEmpty {
            Section("Accounts") {
                ForEach(accountResults) { account in
                    Button { selectedAccount = account } label: {
                        AccountRow(account: account, baseCurrency: appState.baseCurrency)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if !billResults.isEmpty {
            Section("Bills") {
                ForEach(billResults) { bill in
                    NavigationLink(value: AppScreen.bills) {
                        LabeledContent(bill.name, value: bill.amount.formatted(as: bill.currency))
                    }
                }
            }
        }
        if !goalResults.isEmpty {
            Section("Goals") {
                ForEach(goalResults) { goal in
                    NavigationLink(value: goal) {
                        LabeledContent(goal.name, value: goal.currentAmount.formatted(as: goal.currency))
                    }
                }
            }
        }
    }

    private func screenLabel(_ screen: AppScreen) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(screen.title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Text(screen.location).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        } icon: {
            Image(systemName: screen.symbol).foregroundStyle(FTColor.accent)
        }
    }

    private func fetchTransactions(matching text: String) -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.title.localizedStandardContains(text) },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return (try? context.fetch(descriptor)) ?? []
    }
}
