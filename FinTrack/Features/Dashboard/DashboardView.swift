import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context

    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]
    @Query private var investments: [Investment]
    @Query private var cryptoHoldings: [CryptoHolding]
    @Query private var bnplPlans: [BNPLPlan]
    @Query private var budgets: [Budget]
    @Query private var goldHoldings: [GoldHolding]
    @Query private var giftCards: [GiftCard]
    @Query(filter: #Predicate<Bill> { $0.isActive }) private var bills: [Bill]
    @Query(filter: #Predicate<SalaryRecord> { $0.isActive }) private var salaryRecords: [SalaryRecord]
    @Query(filter: #Predicate<FreelanceProject> { $0.isArchived == false }) private var freelanceProjects: [FreelanceProject]
    @Query(filter: #Predicate<RentalProperty> { $0.isActive }) private var rentalProperties: [RentalProperty]
    @Query private var moneyLent: [MoneyLent]
    @Query private var moneyBorrowed: [MoneyBorrowed]
    @Query(filter: #Predicate<RealEstateProperty> { $0.isArchived == false }) private var realEstateProperties: [RealEstateProperty]
    @Query(filter: #Predicate<Vehicle> { $0.isArchived == false }) private var vehicles: [Vehicle]
    @Query(filter: #Predicate<PersonalAsset> { $0.isArchived == false }) private var personalAssets: [PersonalAsset]
    @Query(filter: #Predicate<DigitalAsset> { $0.isArchived == false }) private var digitalAssets: [DigitalAsset]
    @Query private var netWorthMilestones: [NetWorthMilestone]
    @Query(filter: #Predicate<SavingsGoal> { $0.isArchived == false && $0.isCompleted == false }) private var activeGoals: [SavingsGoal]

    @Query private var dashSettings: [AppSettings]

    @State private var showingProfile = false
    @State private var showingReports = false
    @State private var showingAI = false
    @State private var showingBills = false
    @State private var showingIncome = false
    @State private var showingDebt = false
    @State private var showingPortfolio = false
    @State private var showingAssets = false
    @State private var showingNetWorth = false
    @State private var showingGoals = false
    @State private var showingUpcomingPayments = false

    private var baseCurrency: String { appState.baseCurrency }

    private func isWidgetVisible(_ widget: DashboardWidget) -> Bool {
        let hidden = dashSettings.first?.dashboardHiddenWidgets ?? ""
        return !hidden.split(separator: ",").map(String.init).contains(widget.rawValue)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    /// Cached, derived dashboard values so body evaluations don't recompute O(n) aggregates.
    private struct DashboardMetrics {
        var monthlyIncome: Double = 0
        var monthlyExpenses: Double = 0
        var monthlyNet: Double = 0
        var savingsRate: Double = 0
        var netWorth: Double = 0
        var totalBalance: Double = 0
        var spendingByCategory: [(category: TransactionCategory, amount: Double)] = []
        var upcomingPayments: [(name: String, amount: Double, date: Date, type: String)] = []
        var recentTransactions: [Transaction] = []

        static let empty = DashboardMetrics()
    }

    @State private var metrics: DashboardMetrics = .empty
    @State private var cachedInsights: [FinancialInsight] = []

    // Cheap key that changes when any queried collection changes size.
    // Tradeoff: in-place edits don't change counts, so we also refresh on .onAppear (tab return).
    private var dataStamp: Int {
        let a = transactions.count &* 31 &+ accounts.count &* 7 &+ loans.count &* 13 &+ creditCards.count &* 17
        let b = investments.count &* 19 &+ cryptoHoldings.count &* 23 &+ bnplPlans.count &* 29
        let c = goldHoldings.count &* 37 &+ giftCards.count &* 41 &+ bills.count &* 43
        let d = salaryRecords.count &* 47 &+ freelanceProjects.count &* 53 &+ rentalProperties.count &* 59
            &+ moneyLent.count &* 61 &+ moneyBorrowed.count &* 67
        return a &+ b &+ c &+ d
    }

    private func computeMetrics() -> DashboardMetrics {
        var m = DashboardMetrics()
        let now = Date()

        // Single pass: monthly income/expenses + category spending.
        // spendingPairs handles splits, excludes pending/scheduled automatically.
        var spendingTotals: [TransactionCategory: Double] = [:]
        for tx in transactions where tx.date.isSameMonth(as: now) {
            if tx.type == .income && !tx.isPending && !tx.isScheduled {
                m.monthlyIncome += tx.amountInBaseCurrency
            }
            for (cat, amount) in tx.spendingPairs {
                m.monthlyExpenses += amount
                spendingTotals[cat, default: 0] += amount
            }
        }
        m.monthlyNet = m.monthlyIncome - m.monthlyExpenses
        m.savingsRate = m.monthlyIncome > 0
            ? ((m.monthlyIncome - m.monthlyExpenses) / m.monthlyIncome) * 100 : 0

        m.spendingByCategory = spendingTotals
            .map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
            .prefix(6)
            .map { $0 }

        m.totalBalance = accounts.filter { !$0.isArchived && !$0.isHidden }
            .reduce(0) { $0 + currencyService.convert($1.balance, from: $1.currency, to: baseCurrency) }

        let investmentValue = investments.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        let cryptoValue = cryptoHoldings.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        let goldValue = goldHoldings.filter { !$0.isArchived }.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        let giftCardValue = giftCards.filter { !$0.isUsedUp && !$0.isExpired }.reduce(0) {
            $0 + currencyService.convert($1.balance, from: $1.currency, to: baseCurrency)
        }
        let totalDebt = loans.filter { $0.isActive }.reduce(0) {
            $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency)
        }
        let ccDebt = creditCards.filter { $0.isActive }.reduce(0) {
            $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency)
        }
        m.netWorth = m.totalBalance + investmentValue + cryptoValue + goldValue + giftCardValue - totalDebt - ccDebt

        var payments: [(name: String, amount: Double, date: Date, type: String)] = []
        loans.filter { $0.isActive }.forEach { loan in
            payments.append((loan.name, loan.emiAmount, loan.nextPaymentDate, "Loan"))
        }
        creditCards.filter { $0.isActive }.forEach { card in
            payments.append((card.name, card.minimumPayment, card.dueDate, "Credit Card"))
        }
        bnplPlans.filter { !$0.isCompleted }.forEach { plan in
            payments.append((plan.name, plan.installmentAmount, plan.nextPaymentDate, "BNPL"))
        }
        bills.forEach { bill in
            payments.append((bill.name, currencyService.convert(bill.amount, from: bill.currency, to: baseCurrency), bill.nextDueDate, "Bill"))
        }
        m.upcomingPayments = payments.sorted { $0.date < $1.date }.prefix(5).map { $0 }

        m.recentTransactions = transactions
            .sorted(by: { $0.date > $1.date })
            .prefix(5)
            .map { $0 }

        return m
    }

    /// Single refresh path for both cached metrics and AI insights.
    private func refreshDashboard() {
        metrics = computeMetrics()

        let now = Date()
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        let currentMonthTransactions = transactions.filter { $0.date.isSameMonth(as: now) }
        let prevTransactions = transactions.filter { $0.date.isSameMonth(as: previousMonth) }
        cachedInsights = AICategorizationService.shared.generateInsights(
            transactions: currentMonthTransactions,
            previousMonthTransactions: prevTransactions,
            baseCurrency: baseCurrency
        )

        pushWidgetData()
        SpotlightService.shared.indexTransactions(Array(transactions.prefix(200)))
        SpotlightService.shared.indexAccounts(accounts)
    }

    private func pushWidgetData() {
        let txSnapshots = transactions.prefix(10).map { tx in
            WidgetTxSnapshot(
                id: tx.id,
                title: tx.title,
                amount: tx.amount,
                currency: tx.currency,
                type: tx.type.rawValue,
                date: tx.date,
                categoryIcon: tx.category.icon
            )
        }

        let now = Date()
        let budgetSnapshots = budgets.map { b -> WidgetBudgetSnapshot in
            let spent = transactions
                .filter { $0.date.isSameMonth(as: now) }
                .flatMap { $0.spendingPairs }
                .filter { $0.0 == b.category }
                .reduce(0) { $0 + $1.1 }
            return WidgetBudgetSnapshot(
                id: b.id,
                name: b.name.isEmpty ? b.category.rawValue : b.name,
                spent: spent,
                total: b.amount,
                currency: baseCurrency,
                color: "#0E9C8A",
                icon: b.category.icon
            )
        }

        let billSnapshots = bills.map { bill in
            WidgetBillSnapshot(
                id: bill.id,
                name: bill.name,
                amount: bill.amount,
                currency: bill.currency,
                dueDate: bill.nextDueDate,
                icon: bill.icon,
                isPaid: false
            )
        }

        let billPayments = bills.map { bill in
            WidgetPaymentSnapshot(id: bill.id, name: bill.name, amount: bill.amount,
                                  currency: bill.currency, dueDate: bill.nextDueDate,
                                  icon: bill.icon, kind: "bill")
        }
        let bnplPayments = bnplPlans.filter { !$0.isCompleted }.map { plan in
            WidgetPaymentSnapshot(id: plan.id,
                                  name: "\(plan.name) · \(plan.provider.rawValue)",
                                  amount: plan.installmentAmount,
                                  currency: plan.currency,
                                  dueDate: plan.nextPaymentDate,
                                  icon: plan.provider.logo,
                                  kind: "bnpl")
        }
        let scheduledPayments = transactions
            .filter { $0.isScheduled && $0.scheduledDate != nil && $0.type == .expense }
            .map { tx in
                WidgetPaymentSnapshot(id: tx.id, name: tx.title, amount: tx.amount,
                                      currency: tx.currency, dueDate: tx.scheduledDate!,
                                      icon: tx.category.icon, kind: "scheduled")
            }
        let allPayments = (billPayments + bnplPayments + scheduledPayments)
            .sorted { $0.dueDate < $1.dueDate }

        WidgetDataService.shared.updateAll(
            netWorth: metrics.netWorth,
            currency: baseCurrency,
            transactions: Array(txSnapshots),
            budgets: budgetSnapshots,
            bills: billSnapshots,
            payments: allPayments
        )
    }

    private let chartPalette: [Color] = [
        FTColor.accent, FTColor.catTeal, FTColor.catBlue, FTColor.gold,
        FTColor.catCoral, FTColor.catPurple, FTColor.income, FTColor.expense
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: FTSpacing.lg) {
                            header
                            netWorthHero
                        }
                        .padding(.horizontal, FTSpacing.screen)

                        if !activeAccounts.isEmpty {
                            accountsRow
                        }

                        VStack(spacing: FTSpacing.lg) {
                            if isWidgetVisible(.metrics) && !metrics.spendingByCategory.isEmpty {
                                spendingChartSection
                            }

                            if isWidgetVisible(.bills) && !bills.isEmpty {
                                billsAlertCard
                            }

                            if isWidgetVisible(.income) {
                                incomeOverviewCard
                            }

                            if isWidgetVisible(.investments) {
                                portfolioOverviewCard
                            }

                            if isWidgetVisible(.goals) {
                                savingsGoalsCard
                            }

                            assetsOverviewCard

                            if isWidgetVisible(.debt) {
                                debtOverviewCard
                            }

                            if isWidgetVisible(.bills) && !metrics.upcomingPayments.isEmpty {
                                upcomingPaymentsSection
                            }

                            if isWidgetVisible(.aiInsights) && !cachedInsights.isEmpty {
                                insightsSection
                            }

                            recentTransactionsSection
                        }
                        .padding(.horizontal, FTSpacing.screen)
                    }
                    .padding(.top, FTSpacing.sm)
                    .padding(.bottom, 120)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingReports) {
                ReportsView()
            }
            .sheet(isPresented: $showingProfile) {
                SettingsView()
            }
            .sheet(isPresented: $showingAI) {
                AIAssistantView()
            }
            .sheet(isPresented: $showingBills) {
                BillsView()
            }
            .sheet(isPresented: $showingIncome) {
                IncomeManagementView()
            }
            .sheet(isPresented: $showingDebt) {
                DebtManagementView()
            }
            .sheet(isPresented: $showingPortfolio) {
                InvestmentPortfolioView()
            }
            .sheet(isPresented: $showingGoals) {
                SavingsGoalsView()
            }
            .sheet(isPresented: $showingAssets) {
                AssetsLiabilitiesView()
            }
            .sheet(isPresented: $showingNetWorth) {
                NetWorthDashboardView()
            }
            .sheet(isPresented: $showingUpcomingPayments) {
                UpcomingPaymentsView()
            }
            .task(id: dataStamp) { refreshDashboard() }
            .onAppear { refreshDashboard() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
                Text("Your Finances")
                    .font(.ftTitle)
                    .foregroundStyle(FTColor.textPrimary)
            }
            Spacer()
            HStack(spacing: FTSpacing.sm) {
                Button {
                    showingAI = true
                } label: {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                        .frame(width: 44, height: 44)
                        .ftGlass(FTRadius.md)
                }
                .accessibilityLabel("AI Assistant")

                Button {
                    showingReports = true
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                        .frame(width: 44, height: 44)
                        .ftGlass(FTRadius.md)
                }
                .accessibilityLabel("Reports")

                Button {
                    showingProfile = true
                } label: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                        .frame(width: 44, height: 44)
                        .ftGlass(FTRadius.md)
                }
                .accessibilityLabel("Profile and Settings")
            }
        }
    }

    // MARK: - Net Worth Hero

    private var netWorthHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TOTAL NET WORTH")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            Group {
                if appState.hideBalances {
                    Text("••••••")
                        .font(.ftDisplay)
                        .foregroundStyle(.white)
                } else {
                    Text(metrics.netWorth.formatted(as: baseCurrency))
                        .font(.ftDisplay)
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: metrics.savingsRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(metrics.savingsRate.asPercentage())
                        .font(.ftCaption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.white.opacity(0.2), in: .capsule)

                if !appState.hideBalances {
                    Text((metrics.monthlyNet >= 0 ? "+" : "") + metrics.monthlyNet.formatted(as: baseCurrency) + " this month")
                        .font(.ftCaption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(FTSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appState.hideBalances
            ? "Total Net Worth, hidden"
            : "Total Net Worth, \(metrics.netWorth.formatted(as: baseCurrency)), savings rate \(metrics.savingsRate.asPercentage())")
    }

    // MARK: - Accounts Row

    private var accountsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.md) {
                ForEach(activeAccounts.prefix(8)) { account in

                    Button {
                        appState.selectedTab = .accounts
                    } label: {
                        VStack(alignment: .leading, spacing: FTSpacing.md) {
                            FTIconTile(symbol: account.icon, tint: Color.fromString(account.color), size: 38)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.name)
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textSecondary)
                                    .lineLimit(1)
                                if appState.hideBalances {
                                    Text("••••").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                                } else {
                                    Text(account.balance.formatted(as: account.currency))
                                        .font(.ftHeadline)
                                        .foregroundStyle(FTColor.textPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                        }
                        .padding(15)
                        .frame(width: 150, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground), in: .rect(cornerRadius: FTRadius.lg))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(account.name), \(appState.hideBalances ? "balance hidden" : account.balance.formatted(as: account.currency))")
                    .accessibilityHint("Open Accounts")
                }
            }
            .padding(.leading, FTSpacing.screen)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Spending Chart

    private var spendingChartSection: some View {
        let totalSpending = metrics.spendingByCategory.reduce(0) { $0 + $1.amount }
        let indexed = Array(metrics.spendingByCategory.enumerated())

        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Text("Spending this month")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Button("View all") { appState.selectedTab = .reports }
                    .font(.ftCallout).foregroundStyle(FTColor.accent)
            }

            VStack(spacing: 0) {
                ZStack {
                    Chart(indexed, id: \.element.category) { pair in
                        SectorMark(
                            angle: .value("Amount", pair.element.amount),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(chartPalette[pair.offset % chartPalette.count])
                        .cornerRadius(4)
                    }
                    .chartLegend(.hidden)
                    .chartPlotStyle { $0.background(Color.clear) }
                    .frame(height: 180)
                    .padding(FTSpacing.lg)
                    .animation(.snappy(duration: 0.3), value: metrics.spendingByCategory.count)

                    VStack(spacing: FTSpacing.xs) {
                        Text("TOTAL")
                            .font(.ftLabel).tracking(1.6)
                            .foregroundStyle(FTColor.textMuted)
                        Text(totalSpending.formatted(as: baseCurrency))
                            .font(.ftAmount)
                            .foregroundStyle(FTColor.textPrimary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(.horizontal, FTSpacing.md)
                    }
                }

                Divider().padding(.horizontal, FTSpacing.lg)

                VStack(spacing: 0) {
                    let legend = Array(metrics.spendingByCategory.prefix(5).enumerated())
                    ForEach(legend, id: \.element.category) { idx, item in
                        HStack {
                            HStack(spacing: FTSpacing.sm) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(chartPalette[idx % chartPalette.count])
                                    .frame(width: 10, height: 10)
                                Image(systemName: item.category.icon)
                                    .font(.ftCaption)
                                    .foregroundStyle(chartPalette[idx % chartPalette.count])
                                Text(item.category.rawValue)
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textPrimary)
                            }
                            Spacer()
                            Text(item.amount.formatted(as: baseCurrency))
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .padding(.vertical, FTSpacing.sm + 2)

                        if idx < legend.count - 1 {
                            Divider().padding(.leading, FTSpacing.lg)
                        }
                    }
                }
                .padding(.vertical, FTSpacing.xs)
            }
            .ftGlass(FTRadius.xl)
        }
    }

    // MARK: - Bills Alert Card

    private var billsAlertCard: some View {
        let overdueBills = bills.filter { $0.isOverdue }
        let dueSoonBills = bills.filter { !$0.isOverdue && $0.daysUntilDue <= 7 }
        let totalMonthly = bills.reduce(0) { $0 + $1.monthlyEquivalent }

        return Button { showingBills = true } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(
                    symbol: overdueBills.isEmpty ? "calendar.badge.clock" : "calendar.badge.exclamationmark",
                    tint: overdueBills.isEmpty ? FTColor.accent : FTColor.expense,
                    size: 44
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bills & Subscriptions")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if !overdueBills.isEmpty {
                        Text("\(overdueBills.count) overdue · \(totalMonthly.formatted(as: baseCurrency))/mo")
                            .font(.ftCaption).foregroundStyle(FTColor.expense)
                    } else if !dueSoonBills.isEmpty {
                        Text("\(dueSoonBills.count) due soon · \(totalMonthly.formatted(as: baseCurrency))/mo")
                            .font(.ftCaption).foregroundStyle(.orange)
                    } else {
                        Text("\(bills.count) active · \(totalMonthly.formatted(as: baseCurrency))/mo")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FTColor.textMuted)
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Income Overview Card

    private var incomeOverviewCard: some View {
        let activeStreams = (salaryRecords.isEmpty ? 0 : 1)
            + (freelanceProjects.isEmpty ? 0 : 1)
            + (rentalProperties.isEmpty ? 0 : 1)

        let monthlyIncome = transactions
            .filter { $0.type == .income && !$0.isPending && !$0.isScheduled && $0.date.isSameMonth(as: Date()) }
            .reduce(0) { $0 + $1.amountInBaseCurrency }

        let overdueInvoices = freelanceProjects.flatMap { $0.overdueInvoices }
        let overdueRent = rentalProperties.flatMap { $0.overduePayments }

        return Button { showingIncome = true } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(
                    symbol: overdueInvoices.isEmpty && overdueRent.isEmpty
                        ? "banknote.fill"
                        : "exclamationmark.triangle.fill",
                    tint: overdueInvoices.isEmpty && overdueRent.isEmpty
                        ? FTColor.income
                        : FTColor.expense,
                    size: 44
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Income Management")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if !overdueInvoices.isEmpty || !overdueRent.isEmpty {
                        let count = overdueInvoices.count + overdueRent.count
                        Text("\(count) overdue · \(monthlyIncome.asCompact(currency: baseCurrency))/mo")
                            .font(.ftCaption).foregroundStyle(FTColor.expense)
                    } else if activeStreams > 0 {
                        Text("\(activeStreams) active stream\(activeStreams == 1 ? "" : "s") · \(monthlyIncome.asCompact(currency: baseCurrency))/mo")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    } else {
                        Text("Track salary, freelance & rental income")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FTColor.textMuted)
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Debt Overview Card

    private var debtOverviewCard: some View {
        let activeLoans = loans.filter { $0.isActive }
        let activeCards = creditCards.filter { $0.isActive }
        let totalDebt = activeLoans.reduce(0) {
            $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency)
        } + activeCards.reduce(0) {
            $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency)
        }
        let overdueLoans = activeLoans.filter { $0.nextPaymentDate < Date() }
        let overdueLent  = moneyLent.filter { !$0.isFullyRepaid && ($0.dueDate ?? .distantFuture) < Date() }
        let hasAlert     = !overdueLoans.isEmpty || !overdueLent.isEmpty
        let debtCount    = activeLoans.count + activeCards.count

        return Button { showingDebt = true } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(
                    symbol: hasAlert ? "creditcard.trianglebadge.exclamationmark" : "creditcard.fill",
                    tint: hasAlert ? FTColor.expense : FTColor.catPurple,
                    size: 44
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debt Management")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if hasAlert {
                        Text("\(overdueLoans.count + overdueLent.count) overdue · \(totalDebt.asCompact(currency: baseCurrency)) total")
                            .font(.ftCaption).foregroundStyle(FTColor.expense)
                    } else if debtCount > 0 {
                        Text("\(debtCount) active debt\(debtCount == 1 ? "" : "s") · \(totalDebt.asCompact(currency: baseCurrency)) outstanding")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    } else {
                        Text("Track loans, cards & personal debts")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FTColor.textMuted)
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Portfolio Overview Card

    private var portfolioOverviewCard: some View {
        let svc = InvestmentService.shared
        let totalVal = svc.totalValue(
            investments: investments, cryptos: cryptoHoldings,
            golds: goldHoldings, currencyService: currencyService,
            baseCurrency: baseCurrency)
        let pnl = svc.unrealizedPnL(
            investments: investments, cryptos: cryptoHoldings,
            golds: goldHoldings, currencyService: currencyService,
            baseCurrency: baseCurrency)
        let isGain = pnl >= 0
        let assetCount = investments.count + cryptoHoldings.count + goldHoldings.filter { !$0.isArchived }.count

        return Button { showingPortfolio = true } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "chart.line.uptrend.xyaxis.circle.fill",
                           tint: isGain ? FTColor.income : FTColor.expense,
                           size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Investment Portfolio")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if assetCount > 0 {
                        Text("\(assetCount) asset\(assetCount == 1 ? "" : "s") · \(totalVal.asCompact(currency: baseCurrency)) · \(isGain ? "+" : "")\(pnl.asCompact(currency: baseCurrency)) P&L")
                            .font(.ftCaption)
                            .foregroundStyle(isGain ? FTColor.income : FTColor.expense)
                    } else {
                        Text("Track stocks, crypto, gold & more")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FTColor.textMuted)
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Assets Overview Card

    // MARK: - Savings Goals Card

    private var savingsGoalsCard: some View {
        let totalSaved = activeGoals.reduce(0) {
            $0 + currencyService.convert($1.currentAmount, from: $1.currency, to: baseCurrency)
        }
        let totalTarget = activeGoals.reduce(0) {
            $0 + currencyService.convert($1.targetAmount, from: $1.currency, to: baseCurrency)
        }
        let overallProgress = totalTarget > 0 ? min(totalSaved / totalTarget, 1.0) : 0
        let goalCount = activeGoals.count
        let conflict = SavingsGoalService.shared.analyzeConflicts(
            goals: activeGoals,
            transactions: transactions,
            currencyService: currencyService,
            base: baseCurrency
        )

        return Button { showingGoals = true } label: {
            VStack(spacing: FTSpacing.sm) {
                HStack(spacing: FTSpacing.md) {
                    ZStack(alignment: .topTrailing) {
                        FTIconTile(symbol: "star.fill", tint: FTColor.income, size: 44)
                        if conflict.hasConflict {
                            Circle()
                                .fill(FTColor.gold)
                                .frame(width: 10, height: 10)
                                .offset(x: 4, y: -4)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Savings Goals")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        if goalCount > 0 {
                            Text("\(goalCount) active goal\(goalCount == 1 ? "" : "s") · \(totalSaved.asCompact(currency: baseCurrency)) saved")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        } else {
                            Text("Set savings goals to track your progress")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                    }
                    Spacer()
                    if goalCount > 0 {
                        Text("\(Int(overallProgress * 100))%")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                }
                if goalCount > 0 {
                    FTProgressBar(value: overallProgress, color: FTColor.income)
                }
                if conflict.hasConflict {
                    HStack(spacing: FTSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11)).foregroundStyle(FTColor.gold)
                        Text("Goal funding conflict — \(conflict.shortfall.asCompact(currency: baseCurrency))/mo shortfall")
                            .font(.ftCaption).foregroundStyle(FTColor.gold)
                    }
                }
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Assets Overview Card

    private var assetsOverviewCard: some View {
        let svc = NetWorthService.shared
        let reTotal = svc.realEstateTotal(realEstate: realEstateProperties, currencyService: currencyService, base: baseCurrency)
        let vhTotal = svc.vehicleTotal(vehicles: vehicles, currencyService: currencyService, base: baseCurrency)
        let paTotal = svc.personalAssetTotal(assets: personalAssets, currencyService: currencyService, base: baseCurrency)
        let daTotal = svc.digitalAssetTotal(assets: digitalAssets, currencyService: currencyService, base: baseCurrency)
        let totalHard = reTotal + vhTotal + paTotal + daTotal
        let assetCount = realEstateProperties.count + vehicles.count + personalAssets.count + digitalAssets.count

        let unacknowledged = netWorthMilestones.filter { !$0.isAcknowledged }

        return VStack(spacing: FTSpacing.sm) {
            Button { showingAssets = true } label: {
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "building.columns.fill", tint: FTColor.catTeal, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assets & Liabilities")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        if assetCount > 0 {
                            Text("\(assetCount) asset\(assetCount == 1 ? "" : "s") · \(totalHard.asCompact(currency: baseCurrency)) total value")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        } else {
                            Text("Track real estate, vehicles & valuables")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                }
                .padding(FTSpacing.lg)
                .ftGlassInteractive(FTRadius.lg)
            }
            .buttonStyle(.plain)

            Button { showingNetWorth = true } label: {
                HStack(spacing: FTSpacing.md) {
                    ZStack(alignment: .topTrailing) {
                        FTIconTile(symbol: "chart.line.uptrend.xyaxis", tint: FTColor.gold, size: 44)
                        if !unacknowledged.isEmpty {
                            Circle()
                                .fill(FTColor.income)
                                .frame(width: 10, height: 10)
                                .offset(x: 4, y: -4)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Worth")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        if !unacknowledged.isEmpty {
                            Text("🎉 \(unacknowledged.count) milestone\(unacknowledged.count == 1 ? "" : "s") reached!")
                                .font(.ftCaption).foregroundStyle(FTColor.income)
                        } else {
                            Text("Track, forecast & benchmark your wealth")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                }
                .padding(FTSpacing.lg)
                .ftGlassInteractive(FTRadius.lg)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Upcoming Payments

    private var upcomingPaymentsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Text("Upcoming Payments")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Button("See All") { showingUpcomingPayments = true }
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.accent)
                    .accessibilityLabel("See all upcoming payments")
            }

            VStack(spacing: 0) {
                ForEach(metrics.upcomingPayments.indices, id: \.self) { index in
                    let payment = metrics.upcomingPayments[index]
                    UpcomingPaymentRow(
                        name: payment.name,
                        amount: payment.amount,
                        currency: baseCurrency,
                        date: payment.date,
                        type: payment.type
                    )
                    if index < metrics.upcomingPayments.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("AI Insights")
                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.md) {
                    ForEach(cachedInsights) { insight in
                        InsightCard(insight: insight)
                            .frame(width: 260)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Text("Recent Transactions")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Button("See all") { appState.selectedTab = .transactions }
                    .font(.ftCallout).foregroundStyle(FTColor.accent)
            }

            if transactions.isEmpty {
                EmptyStateView(
                    icon: "arrow.left.arrow.right.circle",
                    title: "No Transactions Yet",
                    message: "Add your first transaction to get started",
                    actionTitle: "Add Transaction"
                ) {
                    appState.showingAddTransaction = true
                }
                .ftGlass(FTRadius.lg)
            } else {
                let recent = metrics.recentTransactions
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { idx, tx in
                        TransactionRowView(transaction: tx, baseCurrency: baseCurrency)
                        if idx < recent.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .padding(.horizontal, FTSpacing.lg)
                .ftGlass(FTRadius.lg)
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let amount: Double
    let currency: String
    let icon: String
    let color: Color
    var isHidden: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.ftCaption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            if isHidden {
                Text("••••")
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
            } else {
                Text(amount.asCompact(currency: currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(FTSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }
}

struct UpcomingPaymentRow: View {
    let name: String
    let amount: Double
    let currency: String
    let date: Date
    let type: String

    private var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
    }

    private var urgencyColor: Color {
        if daysUntil <= 3 { return FTColor.expense }
        if daysUntil <= 7 { return FTColor.gold }
        return FTColor.textSecondary
    }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "calendar.badge.clock", tint: urgencyColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text(type)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amount.formatted(as: currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text(daysUntil == 0 ? "Today" : "in \(daysUntil)d")
                    .font(.ftCaption)
                    .foregroundStyle(urgencyColor)
            }
        }
        .padding(.vertical, 13)
    }
}

struct InsightCard: View {
    let insight: FinancialInsight

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: FTSpacing.sm) {
                FTIconTile(symbol: insight.severity.icon,
                           tint: Color.fromString(insight.severity.color), size: 32)
                Text(insight.title)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Spacer()
            }

            Text(insight.message)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    let baseCurrency: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack(alignment: .bottomTrailing) {
                FTIconTile(symbol: transaction.category.icon,
                           tint: Color.fromString(transaction.category.color))
                if transaction.isPending {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(FTColor.gold, in: Circle())
                        .offset(x: 4, y: 4)
                } else if transaction.isScheduled {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(FTColor.accent, in: Circle())
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.title)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                    if transaction.isDuplicate {
                        Text("DUP")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(FTColor.expense, in: Capsule())
                    }
                    if transaction.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(FTColor.income)
                    }
                    if transaction.isSplit {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
                Text(transaction.displaySubtitle)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
                    .lineLimit(1)
                if !transaction.tags.isEmpty {
                    Text(transaction.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.accent.opacity(0.8))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text((transaction.type == .expense ? "-" : "+") + transaction.amount.formatted(as: transaction.currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(
                        transaction.isPending || transaction.isScheduled
                            ? FTColor.textMuted
                            : transaction.type == .expense ? FTColor.expense : FTColor.income
                    )
                Text(transaction.date.formatted)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(.vertical, 13)
        .opacity(transaction.isPending || transaction.isScheduled ? 0.75 : 1)
    }
}
