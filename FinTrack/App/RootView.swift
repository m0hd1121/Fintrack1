import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]
    @Query private var settings: [AppSettings]
    @Query(filter: #Predicate<Transaction> { $0.isRecurring }) private var recurringTxs: [Transaction]
    @Query(filter: #Predicate<Transaction> { $0.isScheduled }) private var scheduledTxs: [Transaction]
    @Query private var bills: [Bill]
    @Query private var allTransactions: [Transaction]
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CurrencyService.self) private var currencyService

    private var preferredScheme: ColorScheme? {
        switch settings.first?.theme {
        case .light:  return .light
        case .dark:   return .dark
        default:      return nil
        }
    }

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else if appState.isLocked {
                LockScreenView()
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(preferredScheme)
        .dismissKeyboardOnTap()
        .onAppear {
            ensureDefaults()
            if appState.hasCompletedOnboarding,
               let setting = settings.first,
               setting.useBiometrics || setting.usePIN {
                appState.lock()
            }
            processRecurringTransactions()
            processScheduledTransactions()
            processBillAlerts()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background,
               let setting = settings.first,
               setting.useBiometrics || setting.usePIN,
               appState.hasCompletedOnboarding {
                appState.lock()
            }
            if phase == .active {
                processRecurringTransactions()
                processScheduledTransactions()
                processBillAlerts()
            }
        }
    }

    /// Posts overdue scheduled transactions and updates account balances.
    private func processScheduledTransactions() {
        let now = Date()
        var didChange = false
        for tx in scheduledTxs {
            guard let due = tx.scheduledDate, due <= now else { continue }
            tx.isScheduled = false
            tx.scheduledDate = nil
            // Now update account balance (was withheld until posting)
            if let account = tx.account {
                let delta = currencyService.convert(tx.amount, from: tx.currency, to: account.currency)
                switch tx.type {
                case .income:   account.balance += delta
                case .expense:  account.balance -= delta
                case .transfer: account.balance += delta
                }
            }
            didChange = true
        }
        if didChange { try? context.save() }
    }

    private func processBillAlerts() {
        let currency = appState.baseCurrency
        BillService.shared.scheduleAllReminders(for: bills)
        BillService.shared.checkAllAlerts(bills: bills, transactions: allTransactions, currency: currency)
        if context.hasChanges { try? context.save() }
    }

    private func ensureDefaults() {
        if profiles.isEmpty { context.insert(UserProfile()) }
        if settings.isEmpty { context.insert(AppSettings(useBiometrics: false)) }
        try? context.save()
    }

    /// Generates overdue recurring transaction instances and advances nextDueDate.
    private func processRecurringTransactions() {
        let now = Date()
        var didInsert = false
        for tx in recurringTxs {
            guard var rule = tx.recurringRule else { continue }
            while rule.nextDueDate <= now {
                // Create the next instance
                let next = Transaction(
                    title: tx.title, amount: tx.amount, currency: tx.currency,
                    amountInBaseCurrency: tx.amountInBaseCurrency, type: tx.type,
                    category: tx.category, date: rule.nextDueDate,
                    notes: tx.notes, isRecurring: false,
                    merchant: tx.merchant, paymentMethod: tx.paymentMethod
                )
                next.account = tx.account
                context.insert(next)
                // Update account balance
                if let account = tx.account {
                    let delta = currencyService.convert(tx.amount, from: tx.currency, to: account.currency)
                    switch tx.type {
                    case .income:   account.balance += delta
                    case .expense:  account.balance -= delta
                    case .transfer: break
                    }
                }
                // Advance due date
                let cal = Calendar.current
                let advance: DateComponents
                switch rule.frequency {
                case .daily:     advance = DateComponents(day: rule.interval)
                case .weekly:    advance = DateComponents(weekOfYear: rule.interval)
                case .biweekly:  advance = DateComponents(weekOfYear: rule.interval * 2)
                case .monthly:   advance = DateComponents(month: rule.interval)
                case .quarterly: advance = DateComponents(month: rule.interval * 3)
                case .yearly:    advance = DateComponents(year: rule.interval)
                }
                rule.nextDueDate = cal.date(byAdding: advance, to: rule.nextDueDate) ?? rule.nextDueDate
                tx.recurringRule = rule
                didInsert = true
            }
        }
        if didInsert { try? context.save() }
    }
}

// MARK: – Main tab container

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        ZStack(alignment: .bottom) {
            // Standard TabView – NO .page style so pickers & swipe gestures work correctly.
            // The native tab bar is hidden; our CustomTabBar is overlaid instead.
            TabView(selection: $appState.selectedTab) {
                DashboardView()
                    .tag(AppTab.dashboard)
                    .toolbar(.hidden, for: .tabBar)

                TransactionsListView()
                    .tag(AppTab.transactions)
                    .toolbar(.hidden, for: .tabBar)

                // .add is never navigated to — the centre + button calls onAdd directly.
                // We include it only so the selection binding has a valid tag.
                Color.clear
                    .tag(AppTab.add)
                    .toolbar(.hidden, for: .tabBar)

                BudgetView()
                    .tag(AppTab.budget)
                    .toolbar(.hidden, for: .tabBar)

                AccountsView()
                    .tag(AppTab.accounts)
                    .toolbar(.hidden, for: .tabBar)
            }
            // Bottom padding so page content isn't hidden behind the floating bar
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }

            // Custom bottom bar with centre + button
            CustomTabBar(
                selectedTab: $appState.selectedTab,
                onAdd: { appState.showingAddTransaction = true }
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .dismissKeyboardOnTap()
        .sheet(isPresented: $appState.showingAddTransaction) {
            AddTransactionView()
        }
    }
}

// MARK: – Custom tab bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    let onAdd: () -> Void

    @Namespace private var selectionNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tabs: [(tab: AppTab, icon: String, selectedIcon: String, label: String)] = [
        (.dashboard,    "square.grid.2x2",               "square.grid.2x2.fill",              "Dashboard"),
        (.transactions, "arrow.left.arrow.right.circle", "arrow.left.arrow.right.circle.fill", "Transactions"),
        (.budget,       "chart.pie",                     "chart.pie.fill",                     "Budget"),
        (.accounts,     "building.columns",              "building.columns.fill",              "Accounts"),
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(tabs.prefix(2), id: \.tab) { item in
                tabButton(item)
            }

            // Centre + button
            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill(FTColor.accentGradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: FTColor.accentDeep.opacity(0.4), radius: 10, y: 3)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Add Transaction")

            ForEach(tabs.suffix(2), id: \.tab) { item in
                tabButton(item)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .opacity(1)
        }
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 6)
        .padding(.horizontal, 24)
        .padding(.bottom, 44)
    }

    @ViewBuilder
    private func tabButton(_ item: (tab: AppTab, icon: String, selectedIcon: String, label: String)) -> some View {
        let isSelected = selectedTab == item.tab

        Button {
            guard selectedTab != item.tab else { return }
            if reduceMotion {
                selectedTab = item.tab
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    selectedTab = item.tab
                }
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    // Pill highlight behind selected icon
                    if isSelected {
                        Capsule()
                            .fill(.thinMaterial)
                            .frame(width: 42, height: 24)
                            .matchedGeometryEffect(id: "tabHighlight", in: selectionNamespace)
                    }

                    Image(systemName: isSelected ? item.selectedIcon : item.icon)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? FTColor.accent : FTColor.textMuted)
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                        .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
                }
                .frame(height: 24)

                Text(item.label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? FTColor.accent : FTColor.textMuted)
                    .animation(reduceMotion ? .none : .easeOut(duration: 0.2), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .frame(minWidth: 44, minHeight: 44) // minimum touch target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
