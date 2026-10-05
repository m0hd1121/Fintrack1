import SwiftUI
import SwiftData
import CoreSpotlight

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(CryptoPriceService.self) private var cryptoPriceService
    @Environment(StockPriceService.self) private var stockPriceService
    @Query private var profiles: [UserProfile]
    @Query private var settings: [AppSettings]
    @Query private var cryptoHoldings: [CryptoHolding]
    @Query private var investments: [Investment]
    @Query(filter: #Predicate<Transaction> { $0.isRecurring }) private var recurringTxs: [Transaction]
    @Query(filter: #Predicate<Transaction> { $0.isScheduled }) private var scheduledTxs: [Transaction]
    @Query private var bills: [Bill]
    @Query(filter: #Predicate<SalaryRecord> { $0.isActive }) private var salaryRecords: [SalaryRecord]
    @Query(filter: #Predicate<FreelanceProject> { $0.isArchived == false }) private var freelanceProjects: [FreelanceProject]
    @Query(filter: #Predicate<RentalProperty> { $0.isActive }) private var rentalProperties: [RentalProperty]
    @Query private var moneyLent: [MoneyLent]
    @Query private var moneyBorrowed: [MoneyBorrowed]
    @Query(filter: #Predicate<CreditCard> { $0.isActive }) private var activeCreditCards: [CreditCard]
    /// Drives the app-icon badge — "Pending" is `PendingImportStatus.pending.rawValue`.
    @Query(filter: #Predicate<PendingEmailTransaction> { $0.statusRaw == "Pending" })
    private var pendingReviewItems: [PendingEmailTransaction]
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CurrencyService.self) private var currencyService

    private var preferredScheme: ColorScheme? {
        switch settings.first?.theme {
        case .light:             return .light
        case .dark, .oled:       return .dark
        default:                 return nil
        }
    }

    private var resolvedAccentColor: Color {
        Color.ftAccent(named: settings.first?.accentColorName ?? "teal")
    }

    private var isGoogleDriveBackupEnabled: Bool { DisableableFeature.googleDriveBackup.isEnabled }

    /// True only on a reinstall where the store is empty but the device still
    /// holds the protected Keychain snapshot. Cheap synchronous checks, so the
    /// normal launch path never waits.
    @State private var isRestoringSnapshot: Bool = !UserDefaults.standard.bool(forKey: "has_completed_onboarding")
        && LocalBackupService.shared.hasDeviceSnapshot

    private var snapshotRestoreScreen: some View {
        ZStack {
            VStack(spacing: FTSpacing.lg) {
                ProgressView().scaleEffect(1.2)
                Text("Restoring your data…")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { FTBackdrop() }
        .task {
            let restored = await LocalBackupService.shared
                .restoreFromDeviceSnapshotIfNeeded(container: context.container)
            if restored {
                // Data is back, so skip onboarding.
                appState.completeOnboarding(currency: appState.baseCurrency)
            }
            isRestoringSnapshot = false
        }
    }

    var body: some View {
        Group {
            if isRestoringSnapshot {
                // Fresh install on a device that still holds a protected copy
                // (Keychain survives app deletion) — rehydrate before deciding
                // whether to show onboarding, so the user never sees a blank app.
                snapshotRestoreScreen
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else if appState.isLocked {
                LockScreenView()
            } else {
                // One adaptive TabView: a tab bar on compact width, a sidebar
                // on regular width (iPad, a foldable's inner display).
                MainTabView()
            }
        }
        .preferredColorScheme(preferredScheme)
        .environment(\.isOLEDMode, settings.first?.oledMode ?? false)
        .environment(\.isHighContrast, settings.first?.highContrastMode ?? false)
        .tint(resolvedAccentColor)
        // Text follows Dynamic Type (see the Font tokens); the largest
        // accessibility sizes are capped because many rows use fixed frames.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .dismissKeyboardOnTap()
        // Keep the icon badge equal to the real review-queue count, so it clears
        // once everything is reviewed instead of sticking at an old number.
        .onChange(of: pendingReviewItems.count) { _, count in
            NotificationService.shared.setBadgeCount(count)
        }
        .onAppear {
            ensureDefaults()
            if let s = settings.first {
                NotificationService.shared.apply(settings: s)
                UserDefaults.standard.set(s.firstDayOfWeek, forKey: Calendar.firstWeekdayKey)
            }
            NotificationService.shared.setBadgeCount(pendingReviewItems.count)
            if appState.hasCompletedOnboarding,
               let setting = settings.first,
               setting.useBiometrics || setting.usePIN {
                appState.lock()
            }
            processRecurringTransactions()
            processScheduledTransactions()
            processBillAlerts()
            processIncomeAlerts()
            processDebtAlerts()
            drainPendingIntentQueue()
            drainPendingSMSTexts()
            drainPendingApplePay()
            drainPendingNavigation()
            if isGoogleDriveBackupEnabled { GoogleDriveBackupService.shared.syncIfDue(context: context) }
            EmailBackupService.shared.scheduleAutomaticBackupIfNeeded(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                EmailSyncService.scheduleBackgroundRefresh()
                if let setting = settings.first,
                   setting.useBiometrics || setting.usePIN,
                   appState.hasCompletedOnboarding {
                    appState.lock()
                }
                if isGoogleDriveBackupEnabled { GoogleDriveBackupService.shared.syncIfDue(context: context) }
                EmailBackupService.shared.scheduleAutomaticBackupIfNeeded(context: context)
            }
            if phase == .active {
                // A notification may have stamped a badge while backgrounded.
                NotificationService.shared.setBadgeCount(pendingReviewItems.count)
                Task { await EmailSyncService.shared.runSyncPass(context: context) }
                processRecurringTransactions()
                processScheduledTransactions()
                processBillAlerts()
                processIncomeAlerts()
                processDebtAlerts()
                drainPendingIntentQueue()
                drainPendingSMSTexts()
                drainPendingApplePay()
                drainPendingNavigation()
                if isGoogleDriveBackupEnabled { GoogleDriveBackupService.shared.syncIfDue(context: context) }
                EmailBackupService.shared.scheduleAutomaticBackupIfNeeded(context: context)
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            handleSpotlightActivity(activity)
        }
        .onChange(of: cryptoPriceService.lastUpdated) {
            cryptoPriceService.updateHoldings(Array(cryptoHoldings), currencyService: currencyService)
            try? context.save()
        }
        .onChange(of: stockPriceService.lastUpdated) {
            stockPriceService.updateHoldings(Array(investments))
            try? context.save()
        }
        .task {
            EmailSyncService.shared.startAutoSync(context: context)
            // Back up after each edit rather than on a launch/resume schedule.
            LocalBackupService.shared.startObservingChanges(container: context.container)
            if isGoogleDriveBackupEnabled { GoogleDriveBackupService.shared.startAutoSync(context: context) }
            EmailBackupService.shared.startAutoBackup(context: context)
            await cryptoPriceService.fetchPrices()
            cryptoPriceService.updateHoldings(Array(cryptoHoldings), currencyService: currencyService)
            let symbols = investments.map { $0.symbol }.filter { !$0.isEmpty }
            await stockPriceService.fetchPrices(symbols: symbols)
            stockPriceService.updateHoldings(Array(investments))
            try? context.save()
        }
    }

    // MARK: – Pending intent queue (Siri / Apple Watch)

    private func drainPendingIntentQueue() {
        let pending = WidgetDataService.shared.dequeuePendingTransactions()
        guard !pending.isEmpty else { return }

        for pending in pending {
            let type = TransactionType(rawValue: pending.type.capitalized) ?? .expense
            let category = TransactionCategory.allCases
                .first { $0.rawValue.lowercased().contains(pending.categoryName.lowercased()) }
                ?? (type == .income ? .salary : .other)
            let tx = Transaction(
                title: pending.title,
                amount: pending.amount,
                currency: pending.currency,
                amountInBaseCurrency: currencyService.convert(pending.amount, from: pending.currency, to: appState.baseCurrency),
                type: type,
                category: category,
                date: pending.date,
                notes: "Added via Siri / Apple Watch"
            )
            context.insert(tx)
        }
        try? context.save()
    }

    /// Drains `LogTransactionFromText`'s queue — parsing (template match /
    /// on-device model) runs here, on the main app process, not inside the
    /// AppIntent itself; see `SMSIngestService`.
    private func drainPendingSMSTexts() {
        let pending = WidgetDataService.shared.dequeuePendingSMS()
        guard !pending.isEmpty else { return }
        Task {
            for sms in pending {
                await SMSIngestService.ingest(
                    rawText: sms.rawText, senderId: sms.senderId,
                    receivedAt: sms.receivedAt, queueId: sms.id, context: context
                )
            }
        }
    }

    /// Applies a section requested by one of the Open… intents. Those run
    /// with `openAppWhenRun`, which brings the app forward but gives the
    /// intent no handle on the live `AppState`, so it leaves a request behind
    /// and this picks it up — the same shape as the other drains above.
    /// `consume()` clears as it reads, so a request is never applied twice.
    private func drainPendingNavigation() {
        guard let target = NavigationRequestStore.consume() else { return }
        appState.selectedTab = target.tab
        // Pop any screen the target tab still had pushed, so the section the
        // user asked for is actually what they land on.
        appState.popToRootTick &+= 1
    }

    /// Drains `LogApplePayTransaction`'s queue. Wallet's fields arrive
    /// already structured, so unlike the SMS drain there's nothing to parse —
    /// see `ApplePayIngestService`.
    private func drainPendingApplePay() {
        let pending = WidgetDataService.shared.dequeuePendingApplePay()
        guard !pending.isEmpty else { return }
        for tx in pending {
            ApplePayIngestService.ingest(
                amount: tx.amount, merchant: tx.merchant, currency: tx.currency,
                date: tx.date, walletCategory: tx.walletCategory, card: tx.card,
                isRefund: tx.isRefund, context: context
            )
        }
    }

    // MARK: – Spotlight deep linking

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let link = SpotlightService.shared.handleUserActivity(activity) else { return }
        switch link {
        case .transaction:
            appState.selectedTab = .transactions
        case .account:
            appState.selectedTab = .accounts
        case .unknown:
            break
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
                case .transfer:
                    account.balance -= delta   // debit source
                    if let toAccount = tx.toAccount {
                        let toDelta = currencyService.convert(tx.amount, from: tx.currency, to: toAccount.currency)
                        toAccount.balance += toDelta  // credit destination
                    }
                }
            }
            didChange = true
        }
        if didChange { try? context.save() }
    }

    private func processIncomeAlerts() {
        IncomeService.shared.checkSalaryAlerts(records: salaryRecords)
        IncomeService.shared.checkLateRentAlerts(properties: rentalProperties)
        let overdueInvoices = IncomeService.shared.checkOverdueInvoices(projects: Array(freelanceProjects))
        for (project, invoice) in overdueInvoices {
            IncomeService.shared.sendOverdueInvoiceAlert(project: project, invoice: invoice)
        }
        if context.hasChanges { try? context.save() }
    }

    private func processDebtAlerts() {
        let now = Date()
        // Money lent reminders
        for lent in moneyLent where !lent.isFullyRepaid && lent.reminderEnabled {
            if let due = lent.dueDate {
                NotificationService.shared.scheduleLentReminder(
                    id: lent.id.uuidString,
                    borrowerName: lent.borrowerName,
                    amount: lent.remainingBalance,
                    currency: lent.currency,
                    dueDate: due,
                    daysBefore: lent.reminderDaysBefore
                )
            }
        }
        // Money borrowed reminders
        for borrowed in moneyBorrowed where !borrowed.isFullyRepaid && borrowed.reminderEnabled {
            if let due = borrowed.dueDate {
                NotificationService.shared.scheduleBorrowedReminder(
                    id: borrowed.id.uuidString,
                    lenderName: borrowed.lenderName,
                    amount: borrowed.remainingBalance,
                    currency: borrowed.currency,
                    dueDate: due,
                    daysBefore: borrowed.reminderDaysBefore
                )
            }
        }
        // Credit utilization alerts for cards above 75%
        for card in activeCreditCards where card.utilizationRate > 0.75 {
            let daysSinceAlert = UserDefaults.standard.double(forKey: "utilAlert_\(card.id)")
            if now.timeIntervalSince1970 - daysSinceAlert > 86400 * 7 {
                NotificationService.shared.sendHighUtilizationAlert(
                    cardName: card.name,
                    utilization: card.utilizationRate
                )
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "utilAlert_\(card.id)")
            }
        }
    }

    private func processBillAlerts() {
        let currency = appState.baseCurrency
        BillService.shared.scheduleAllReminders(for: bills)
        // Fetched on demand and bounded: auto-pay checks only look a few days
        // around each due date. A root-level `@Query` over the whole ledger
        // used to re-evaluate this view — which wraps the entire app — on
        // every transaction insert or edit.
        let since = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        let recent = (try? context.fetch(FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= since }))) ?? []
        BillService.shared.checkAllAlerts(bills: bills, transactions: recent, currency: currency)
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
                // Stop at the rule's end date instead of generating forever.
                if let end = rule.endDate, rule.nextDueDate > end { break }
                // Create the next instance
                let next = Transaction(
                    title: tx.title, amount: tx.amount, currency: tx.currency,
                    amountInBaseCurrency: tx.amountInBaseCurrency, type: tx.type,
                    category: tx.category, date: rule.nextDueDate,
                    notes: tx.notes, isRecurring: false,
                    merchant: tx.merchant, paymentMethod: tx.paymentMethod
                )
                next.account = tx.account
                next.toAccount = tx.type == .transfer ? tx.toAccount : nil
                context.insert(next)
                // Update account balances (a transfer moves money between both accounts)
                if let account = tx.account {
                    let delta = currencyService.convert(tx.amount, from: tx.currency, to: account.currency)
                    switch tx.type {
                    case .income:   account.balance += delta
                    case .expense:  account.balance -= delta
                    case .transfer: account.balance -= delta
                    }
                }
                if tx.type == .transfer, let to = tx.toAccount {
                    to.balance += currencyService.convert(tx.amount, from: tx.currency, to: to.currency)
                }
                rule.nextDueDate = rule.occurrence(after: rule.nextDueDate)
                tx.recurringRule = rule
                didInsert = true
            }
        }
        if didInsert { try? context.save() }
    }
}

// MARK: – Main tab container

/// Native, adaptive tab container. On compact width it is the system Liquid
/// Glass tab bar (Home · Activity · Plan · Wealth + the Search tab) with the
/// Add Transaction accessory above it; on regular width `.sidebarAdaptable`
/// shows a sidebar whose sections also list every module, so iPad and a
/// foldable's inner display get the same hierarchy one level flatter.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// "Pending" is `PendingImportStatus.pending.rawValue`.
    @Query(filter: #Predicate<PendingEmailTransaction> { $0.statusRaw == "Pending" })
    private var pendingReviewItems: [PendingEmailTransaction]

    /// Every selection (including re-selecting the current tab) bumps
    /// `popToRootTick`, which each tab root watches to pop back to its main page.
    private var selection: Binding<AppTab> {
        Binding(get: { appState.selectedTab },
                set: { newValue in
                    appState.popToRootTick &+= 1
                    appState.selectedTab = newValue
                })
    }

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: selection) {
            Tab("Home", systemImage: AppTab.dashboard.icon, value: AppTab.dashboard) {
                DashboardView()
            }
            Tab("Activity", systemImage: AppTab.transactions.icon, value: AppTab.transactions) {
                TransactionsListView()
            }
            .badge(pendingReviewItems.count)
            Tab("Plan", systemImage: AppTab.budget.icon, value: AppTab.budget) {
                PlanView()
            }
            Tab("Wealth", systemImage: AppTab.accounts.icon, value: AppTab.accounts) {
                AccountsView()
            }

            // Sidebar-only destinations (hidden from the compact tab bar).
            TabSection("Plan") {
                Tab("Budgets", systemImage: AppTab.budgets.icon, value: AppTab.budgets) {
                    BudgetView()
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Bills & Payments", systemImage: AppTab.bills.icon, value: AppTab.bills) {
                    BillsView()
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Goals", systemImage: AppTab.goals.icon, value: AppTab.goals) {
                    NavigationStack { SavingsGoalsView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Income", systemImage: AppTab.income.icon, value: AppTab.income) {
                    NavigationStack { IncomeManagementView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Debt", systemImage: AppTab.debt.icon, value: AppTab.debt) {
                    NavigationStack { DebtManagementView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Household", systemImage: AppTab.household.icon, value: AppTab.household) {
                    NavigationStack { FamilyFinanceView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Planning Tools", systemImage: AppTab.planningTools.icon, value: AppTab.planningTools) {
                    NavigationStack { PlanningToolsView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
            }

            TabSection("Wealth") {
                Tab("Net Worth", systemImage: AppTab.netWorth.icon, value: AppTab.netWorth) {
                    NavigationStack { NetWorthDashboardView(embedInNavigationStack: false) }
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Investments", systemImage: AppTab.investments.icon, value: AppTab.investments) {
                    NavigationStack { InvestmentPortfolioView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Property & Assets", systemImage: AppTab.assets.icon, value: AppTab.assets) {
                    NavigationStack { AssetsLiabilitiesView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
            }

            TabSection("More") {
                Tab("Insights", systemImage: AppTab.insights.icon, value: AppTab.insights) {
                    AIAssistantView()
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Reports", systemImage: AppTab.reports.icon, value: AppTab.reports) {
                    NavigationStack { ReportsView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Import & Sync", systemImage: AppTab.importSync.icon, value: AppTab.importSync) {
                    NavigationStack { ImportIntegrationView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Settings", systemImage: AppTab.settings.icon, value: AppTab.settings) {
                    NavigationStack { SettingsView() }
                }
                .defaultVisibility(.hidden, for: .tabBar)
            }

            Tab(value: AppTab.search, role: .search) {
                GlobalSearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            AddTransactionAccessory()
        }
        // A sidebar-only destination has no tab on compact width; fall back
        // to the tab that owns it when the window narrows.
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if sizeClass == .compact {
                appState.selectedTab = appState.selectedTab.compactParent
            }
        }
        .sheet(isPresented: $appState.showingAddTransaction) {
            AddTransactionView()
        }
    }
}

/// The labelled "Add Transaction" button shown above the tab bar on every tab
/// (`tabViewBottomAccessory`). Replaces the custom bar's icon-only centre "+".
struct AddTransactionAccessory: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.showingAddTransaction = true
        } label: {
            Label("Add Transaction", systemImage: "plus.circle.fill")
                .font(.ftBodySemibold)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(FTColor.accent)
        .accessibilityHint("Record an expense, income or transfer")
        .keyboardShortcut("n", modifiers: .command)
    }
}
