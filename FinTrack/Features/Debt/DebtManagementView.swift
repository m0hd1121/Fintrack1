import SwiftUI
import SwiftData
import Charts

// MARK: - DebtManagementView

struct DebtManagementView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Loan> { $0.isActive }) private var loans: [Loan]
    @Query(filter: #Predicate<CreditCard> { $0.isActive }) private var creditCards: [CreditCard]
    @Query private var moneyLent: [MoneyLent]
    @Query private var moneyBorrowed: [MoneyBorrowed]

    @State private var selectedTab = 0
    @State private var showingAddLent = false
    @State private var showingAddBorrowed = false
    @State private var editingLent: MoneyLent? = nil
    @State private var editingBorrowed: MoneyBorrowed? = nil
    @State private var snowballExtra: Double = 100
    @State private var avalancheExtra: Double = 100
    @State private var calculatorSelectedIndex: Int = 0
    @State private var calculatorExtra: Double = 200
    @State private var utilSummary: CreditUtilizationSummary? = nil
    @State private var snowballPlan: DebtPayoffPlan? = nil
    @State private var avalanchePlan: DebtPayoffPlan? = nil
    @State private var interestResult: InterestSavingsResult? = nil
    @State private var selectedLent: MoneyLent? = nil
    @State private var selectedBorrowed: MoneyBorrowed? = nil

    private let tabs = ["Overview", "Snowball", "Avalanche", "Calculator", "Lent", "Borrowed", "Utilization"]

    private var baseCurrency: String { appState.baseCurrency }

    // MARK: - Computed

    private var activeLoans: [Loan] { loans.filter { $0.isActive } }
    private var activeCards: [CreditCard] { creditCards.filter { $0.isActive } }

    private var debtItems: [DebtItem] {
        DebtService.shared.debtItems(loans: Array(loans), creditCards: Array(creditCards))
    }

    private var totalDebt: Double {
        debtItems.reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency) }
    }

    private var totalMinimumPayments: Double {
        debtItems.reduce(0) { $0 + currencyService.convert($1.minimumPayment, from: $1.currency, to: baseCurrency) }
    }

    private var activeLentItems: [MoneyLent] { moneyLent.filter { !$0.isFullyRepaid } }
    private var activeBorrowedItems: [MoneyBorrowed] { moneyBorrowed.filter { !$0.isFullyRepaid } }

    private var totalLent: Double {
        moneyLent.reduce(0) { $0 + currencyService.convert($1.remainingBalance, from: $1.currency, to: baseCurrency) }
    }

    private var totalBorrowed: Double {
        moneyBorrowed.reduce(0) { $0 + currencyService.convert($1.remainingBalance, from: $1.currency, to: baseCurrency) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                VStack(spacing: 0) {
                    tabBar
                        .padding(.top, FTSpacing.xs)

                    ScrollView {
                        activeTabView()
                            .padding(.bottom, FTSpacing.xxl + FTSpacing.lg)
                    }
                }
            }
            .navigationTitle("Debt Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .sheet(isPresented: $showingAddLent) {
                AddMoneyLentSheet()
            }
            .sheet(isPresented: $showingAddBorrowed) {
                AddMoneyBorrowedSheet()
            }
            .sheet(item: $editingLent) { item in
                AddMoneyLentSheet(editing: item)
            }
            .sheet(item: $editingBorrowed) { item in
                AddMoneyBorrowedSheet(editing: item)
            }
            .sheet(item: $selectedLent) { item in
                MoneyLentDetailSheet(item: item)
            }
            .sheet(item: $selectedBorrowed) { item in
                MoneyBorrowedDetailSheet(item: item)
            }
        }
        .onAppear { recomputeAll() }
        .onChange(of: snowballExtra) { _, _ in recomputeSnowball() }
        .onChange(of: avalancheExtra) { _, _ in recomputeAvalanche() }
        .onChange(of: calculatorSelectedIndex) { _, _ in recomputeCalculator() }
        .onChange(of: calculatorExtra) { _, _ in recomputeCalculator() }
        .onChange(of: creditCards.count) { _, _ in recomputeUtilization() }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { selectedTab = i }
                    } label: {
                        FTChip(symbol: tabIcon(i), title: tabs[i], selected: selectedTab == i)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.xs)
        }
    }

    private func tabIcon(_ i: Int) -> String {
        switch i {
        case 0: return "creditcard.fill"
        case 1: return "snowflake"
        case 2: return "chart.line.downtrend.xyaxis"
        case 3: return "function"
        case 4: return "hand.raised.fill"
        case 5: return "hand.point.down.fill"
        case 6: return "gauge.medium"
        default: return "circle"
        }
    }

    // AnyView erases the complex 7-branch _ConditionalContent type that would
    // otherwise create deeply nested generic stack frames and overflow on open.
    private func activeTabView() -> AnyView {
        switch selectedTab {
        case 1: return AnyView(snowballTab)
        case 2: return AnyView(avalancheTab)
        case 3: return AnyView(calculatorTab)
        case 4: return AnyView(lentTab)
        case 5: return AnyView(borrowedTab)
        case 6: return AnyView(utilizationTab)
        default: return AnyView(overviewTab)
        }
    }

    // MARK: - Add Button

    @ViewBuilder
    private var addButton: some View {
        if selectedTab == 4 || selectedTab == 5 {
            Button {
                if selectedTab == 4 { showingAddLent = true }
                else { showingAddBorrowed = true }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FTColor.accent)
            }
        }
    }

    // MARK: - Recompute

    private func recomputeAll() {
        recomputeSnowball()
        recomputeAvalanche()
        recomputeCalculator()
        recomputeUtilization()
    }

    private func recomputeSnowball() {
        guard !debtItems.isEmpty else { snowballPlan = nil; return }
        snowballPlan = DebtService.shared.snowballPlan(items: debtItems, extraMonthlyPayment: snowballExtra)
    }

    private func recomputeAvalanche() {
        guard !debtItems.isEmpty else { avalanchePlan = nil; return }
        avalanchePlan = DebtService.shared.avalanchePlan(items: debtItems, extraMonthlyPayment: avalancheExtra)
    }

    private func recomputeCalculator() {
        guard !debtItems.isEmpty, debtItems.indices.contains(calculatorSelectedIndex) else {
            interestResult = nil; return
        }
        interestResult = DebtService.shared.calculateInterestSavings(
            item: debtItems[calculatorSelectedIndex],
            extraMonthlyPayment: calculatorExtra
        )
    }

    private func recomputeUtilization() {
        utilSummary = DebtService.shared.utilizationSummary(creditCards: Array(creditCards))
    }

    // MARK: - Section Header Helper

    private func debtSectionHeader(_ title: String, symbol: String, tint: Color = FTColor.textSecondary) -> some View {
        HStack(spacing: FTSpacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(title.uppercased())
                .font(.ftLabel)
                .tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
        }
    }

    // MARK: - Empty State Helper

    private func debtEmptyState(
        symbol: String,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: FTSpacing.lg) {
            FTIconTile(symbol: symbol, tint: FTColor.accent, size: 60)

            VStack(spacing: FTSpacing.xs) {
                Text(title)
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text(message)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.ftPrimary)
                    .frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.xxl)
        .padding(.horizontal, FTSpacing.xl)
        .ftGlass(FTRadius.lg)
    }

    // MARK: - TAB 0: OVERVIEW

    private var overviewTab: some View {
        VStack(spacing: FTSpacing.lg) {
            // Hero card
            debtHeroCard
                .padding(.horizontal, FTSpacing.screen)

            // Active Loans
            if !activeLoans.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    debtSectionHeader("Active Loans", symbol: "banknote.fill", tint: FTColor.expense)
                        .padding(.horizontal, FTSpacing.screen)

                    VStack(spacing: FTSpacing.sm) {
                        ForEach(activeLoans, id: \.id) { loan in
                            LoanDebtCard(loan: loan, baseCurrency: baseCurrency, currencyService: currencyService)
                                .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            }

            // Credit Cards
            if !activeCards.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    debtSectionHeader("Credit Cards", symbol: "creditcard.fill", tint: FTColor.catPurple)
                        .padding(.horizontal, FTSpacing.screen)

                    VStack(spacing: FTSpacing.sm) {
                        ForEach(activeCards, id: \.id) { card in
                            CreditCardDebtCard(card: card, baseCurrency: baseCurrency, currencyService: currencyService)
                                .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            }

            // Empty state
            if activeLoans.isEmpty && activeCards.isEmpty {
                debtEmptyState(
                    symbol: "creditcard",
                    title: "No Active Debts",
                    message: "Add your loans and credit cards to start tracking your debt.",
                    buttonTitle: nil,
                    action: nil
                )
                .padding(.horizontal, FTSpacing.screen)
            }
        }
        .padding(.top, FTSpacing.md)
    }

    private var debtHeroCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TOTAL DEBT")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            Text(totalDebt.formatted(as: baseCurrency))
                .font(.ftDisplay)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            HStack(spacing: 0) {
                DebtSummaryMetric(
                    label: "Loans",
                    value: "\(activeLoans.count)",
                    valueColor: .white
                )
                Divider()
                    .frame(width: 1, height: 30)
                    .background(.white.opacity(0.3))
                    .padding(.horizontal, FTSpacing.lg)
                DebtSummaryMetric(
                    label: "Cards",
                    value: "\(activeCards.count)",
                    valueColor: .white
                )
                Divider()
                    .frame(width: 1, height: 30)
                    .background(.white.opacity(0.3))
                    .padding(.horizontal, FTSpacing.lg)
                DebtSummaryMetric(
                    label: "Min/Month",
                    value: totalMinimumPayments.asCompact(currency: baseCurrency),
                    valueColor: .white
                )
            }
        }
        .padding(FTSpacing.xl)
        .background(
            LinearGradient(
                colors: [Color(hex: 0xC0392B), Color(hex: 0x8B1A1A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: FTRadius.xl)
        )
        .shadow(color: Color(hex: 0x8B1A1A).opacity(0.35), radius: 20, y: 8)
    }

    // MARK: - TAB 1: SNOWBALL PLANNER

    private var snowballTab: some View {
        VStack(spacing: FTSpacing.lg) {
            if debtItems.isEmpty {
                debtEmptyState(
                    symbol: "snowflake",
                    title: "No Debts to Plan",
                    message: "Add loans or credit cards to use the Snowball planner."
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                // Extra payment control
                ExtraPaymentControl(
                    title: "Extra Monthly Payment",
                    amount: $snowballExtra,
                    tint: FTColor.catBlue
                )
                .padding(.horizontal, FTSpacing.screen)

                if let plan = snowballPlan {
                    // Summary card
                    snowballSummaryCard(plan: plan, tint: FTColor.catBlue, label: "Snowball")

                    // Repayment sequence
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        debtSectionHeader("Repayment Sequence", symbol: "list.number", tint: FTColor.catBlue)
                            .padding(.horizontal, FTSpacing.screen)

                        VStack(spacing: FTSpacing.sm) {
                            ForEach(plan.entries.sorted { $0.payoffOrder < $1.payoffOrder }) { entry in
                                PayoffEntryCard(entry: entry, tint: FTColor.catBlue, baseCurrency: baseCurrency)
                                    .padding(.horizontal, FTSpacing.screen)
                            }
                        }
                    }
                } else {
                    ProgressView("Computing snowball plan…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FTSpacing.xxl)
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 2: AVALANCHE PLANNER

    private var avalancheTab: some View {
        VStack(spacing: FTSpacing.lg) {
            if debtItems.isEmpty {
                debtEmptyState(
                    symbol: "chart.line.downtrend.xyaxis",
                    title: "No Debts to Plan",
                    message: "Add loans or credit cards to use the Avalanche planner."
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                // Comparison card
                if let snow = snowballPlan, let aval = avalanchePlan {
                    let saved = snow.totalInterestPaid - aval.totalInterestPaid
                    if abs(saved) > 0.01 {
                        HStack(spacing: FTSpacing.md) {
                            Image(systemName: saved > 0 ? "chart.line.downtrend.xyaxis" : "chart.line.uptrend.xyaxis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(saved > 0 ? FTColor.income : FTColor.expense)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(saved > 0 ? "Avalanche saves more interest" : "Snowball saves more interest")
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.textPrimary)
                                Text("\(abs(saved).formatted(as: baseCurrency)) less total interest paid")
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(FTSpacing.lg)
                        .background(FTColor.income.opacity(0.08), in: .rect(cornerRadius: FTRadius.md))
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                }

                ExtraPaymentControl(
                    title: "Extra Monthly Payment",
                    amount: $avalancheExtra,
                    tint: FTColor.catCoral
                )
                .padding(.horizontal, FTSpacing.screen)

                if let plan = avalanchePlan {
                    snowballSummaryCard(plan: plan, tint: FTColor.catCoral, label: "Avalanche")

                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        debtSectionHeader("Repayment Sequence", symbol: "list.number", tint: FTColor.catCoral)
                            .padding(.horizontal, FTSpacing.screen)

                        VStack(spacing: FTSpacing.sm) {
                            ForEach(plan.entries.sorted { $0.payoffOrder < $1.payoffOrder }) { entry in
                                PayoffEntryCard(entry: entry, tint: FTColor.catCoral, baseCurrency: baseCurrency)
                                    .padding(.horizontal, FTSpacing.screen)
                            }
                        }
                    }
                } else {
                    ProgressView("Computing avalanche plan…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FTSpacing.xxl)
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    @ViewBuilder
    private func snowballSummaryCard(plan: DebtPayoffPlan, tint: Color, label: String) -> some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: label == "Snowball" ? "snowflake" : "chart.line.downtrend.xyaxis", tint: tint, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Debt-Free by \(plan.payoffDate.formatted)")
                        .font(.ftHeadline)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("\(plan.totalMonthsToPayoff) months to payoff")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Total Interest")
                        .font(.ftLabel)
                        .tracking(0.5)
                        .foregroundStyle(FTColor.textSecondary)
                    Text(plan.totalInterestPaid.formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.expense)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Debts")
                        .font(.ftLabel)
                        .tracking(0.5)
                        .foregroundStyle(FTColor.textSecondary)
                    Text("\(plan.entries.count)")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
        .padding(.horizontal, FTSpacing.screen)
    }

    // MARK: - TAB 3: INTEREST SAVINGS CALCULATOR

    private var calculatorTab: some View {
        VStack(spacing: FTSpacing.lg) {
            if debtItems.isEmpty {
                debtEmptyState(
                    symbol: "function",
                    title: "No Debts Found",
                    message: "Add loans or credit cards to use the interest calculator."
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                // Debt selector
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    debtSectionHeader("Select Debt", symbol: "list.bullet", tint: FTColor.accent)
                        .padding(.horizontal, FTSpacing.screen)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FTSpacing.sm) {
                            ForEach(debtItems.indices, id: \.self) { i in
                                let item = debtItems[i]
                                Button {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        calculatorSelectedIndex = i
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.ftCallout)
                                            .foregroundStyle(calculatorSelectedIndex == i ? .white : FTColor.textPrimary)
                                            .lineLimit(1)
                                        Text(item.outstandingBalance.asCompact(currency: item.currency))
                                            .font(.ftLabel)
                                            .tracking(0.3)
                                            .foregroundStyle(calculatorSelectedIndex == i ? .white.opacity(0.8) : FTColor.textSecondary)
                                    }
                                    .padding(.horizontal, FTSpacing.md)
                                    .padding(.vertical, FTSpacing.sm + 2)
                                    .background {
                                        if calculatorSelectedIndex == i {
                                            RoundedRectangle(cornerRadius: FTRadius.sm)
                                                .fill(FTColor.accentGradient)
                                        } else {
                                            RoundedRectangle(cornerRadius: FTRadius.sm)
                                                .fill(.regularMaterial)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: FTRadius.sm)
                                                        .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                                                )
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, FTSpacing.screen)
                        .padding(.vertical, FTSpacing.xs)
                    }
                }

                // Extra payment control
                ExtraPaymentControl(
                    title: "Extra Monthly Payment",
                    amount: $calculatorExtra,
                    tint: FTColor.accent
                )
                .padding(.horizontal, FTSpacing.screen)

                // Results
                if let result = interestResult {
                    // Comparison card
                    VStack(spacing: FTSpacing.md) {
                        HStack(spacing: FTSpacing.md) {
                            // Standard column
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("STANDARD")
                                    .font(.ftLabel)
                                    .tracking(1.2)
                                    .foregroundStyle(FTColor.textSecondary)
                                Text(result.standardTotalInterest.formatted(as: baseCurrency))
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.expense)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(result.standardPayoffDate.formatted)
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textSecondary)
                                Text("\(result.standardMonths) months")
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(FTSpacing.md)
                            .background(FTColor.expense.opacity(0.07), in: .rect(cornerRadius: FTRadius.sm))

                            // Accelerated column
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("WITH EXTRA")
                                    .font(.ftLabel)
                                    .tracking(1.2)
                                    .foregroundStyle(FTColor.accent)
                                Text(result.acceleratedTotalInterest.formatted(as: baseCurrency))
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.income)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(result.acceleratedPayoffDate.formatted)
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textSecondary)
                                Text("\(result.acceleratedMonths) months")
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(FTSpacing.md)
                            .background(FTColor.income.opacity(0.07), in: .rect(cornerRadius: FTRadius.sm))
                        }
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.lg)
                    .padding(.horizontal, FTSpacing.screen)

                    // Savings highlight
                    if result.interestSaved > 0 {
                        VStack(spacing: FTSpacing.xs) {
                            Text("You save")
                                .font(.ftLabel)
                                .tracking(1.0)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(result.interestSaved.formatted(as: baseCurrency))
                                .font(.ftAmount)
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            Text("in interest · \(result.monthsReduced) months faster")
                                .font(.ftCaption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FTSpacing.xl)
                        .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.xl))
                        .shadow(color: FTColor.accent.opacity(0.35), radius: 18, y: 8)
                        .padding(.horizontal, FTSpacing.screen)
                    }

                    // Balance chart
                    if !result.monthlySavingsBreakdown.isEmpty {
                        BalanceComparisonChart(breakdown: result.monthlySavingsBreakdown, baseCurrency: baseCurrency)
                            .padding(.horizontal, FTSpacing.screen)
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 4: MONEY LENT

    private var lentTab: some View {
        VStack(spacing: FTSpacing.lg) {
            // Summary header
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "hand.raised.fill", tint: FTColor.income, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Total Lent Outstanding")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("\(activeLentItems.count) active records")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(totalLent.formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.income)
                    Text("remaining")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.textMuted)
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)

            if moneyLent.isEmpty {
                debtEmptyState(
                    symbol: "hand.raised",
                    title: "No Money Lent",
                    message: "Track money you've lent to friends and family.",
                    buttonTitle: "Record Loan",
                    action: { showingAddLent = true }
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    debtSectionHeader("All Records", symbol: "list.bullet", tint: FTColor.income)
                        .padding(.horizontal, FTSpacing.screen)

                    VStack(spacing: FTSpacing.sm) {
                        ForEach(moneyLent.sorted { $0.lendingDate > $1.lendingDate }, id: \.id) { item in
                            MoneyLentCard(item: item, baseCurrency: baseCurrency, currencyService: currencyService) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    selectedLent = item
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    context.delete(item)
                                    try? context.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { editingLent = item } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(FTColor.accent)
                            }
                            .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 5: MONEY BORROWED

    private var borrowedTab: some View {
        VStack(spacing: FTSpacing.lg) {
            // Summary header
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "hand.point.down.fill", tint: FTColor.expense, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Total Borrowed Outstanding")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("\(activeBorrowedItems.count) active records")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(totalBorrowed.formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.expense)
                    Text("remaining")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.textMuted)
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)

            if moneyBorrowed.isEmpty {
                debtEmptyState(
                    symbol: "hand.point.down",
                    title: "No Money Borrowed",
                    message: "Track money you've borrowed from friends and family.",
                    buttonTitle: "Record Debt",
                    action: { showingAddBorrowed = true }
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    debtSectionHeader("All Records", symbol: "list.bullet", tint: FTColor.expense)
                        .padding(.horizontal, FTSpacing.screen)

                    VStack(spacing: FTSpacing.sm) {
                        ForEach(moneyBorrowed.sorted { $0.borrowDate > $1.borrowDate }, id: \.id) { item in
                            MoneyBorrowedCard(item: item, baseCurrency: baseCurrency, currencyService: currencyService) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    selectedBorrowed = item
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    context.delete(item)
                                    try? context.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { editingBorrowed = item } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(FTColor.accent)
                            }
                            .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 6: CREDIT UTILIZATION

    private var utilizationTab: some View {
        VStack(spacing: FTSpacing.lg) {
            if creditCards.isEmpty {
                debtEmptyState(
                    symbol: "gauge.medium",
                    title: "No Credit Cards",
                    message: "Add your credit cards to monitor utilization and get recommendations."
                )
                .padding(.horizontal, FTSpacing.screen)
            } else if let summary = utilSummary {
                // Aggregate hero
                utilizationHeroCard(summary: summary)
                    .padding(.horizontal, FTSpacing.screen)

                // Per-card breakdown
                if !summary.cards.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        debtSectionHeader("Card Breakdown", symbol: "creditcard.fill", tint: FTColor.catPurple)
                            .padding(.horizontal, FTSpacing.screen)

                        VStack(spacing: FTSpacing.sm) {
                            ForEach(summary.cards) { cardUtil in
                                CardUtilizationRow(cardUtil: cardUtil, baseCurrency: baseCurrency, currencyService: currencyService)
                                    .padding(.horizontal, FTSpacing.screen)
                            }
                        }
                    }
                }

                // Recommendations
                if !summary.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        debtSectionHeader("Recommendations", symbol: "sparkles", tint: FTColor.gold)
                            .padding(.horizontal, FTSpacing.screen)

                        VStack(spacing: FTSpacing.sm) {
                            ForEach(summary.recommendations, id: \.self) { rec in
                                HStack(alignment: .top, spacing: FTSpacing.md) {
                                    FTIconTile(symbol: "sparkles", tint: FTColor.gold, size: 36)
                                    Text(rec)
                                        .font(.ftBody)
                                        .foregroundStyle(FTColor.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding(FTSpacing.lg)
                                .ftGlass(FTRadius.lg)
                                .padding(.horizontal, FTSpacing.screen)
                            }
                        }
                    }
                }
            } else {
                ProgressView("Computing utilization…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FTSpacing.xxl)
                    .onAppear { recomputeUtilization() }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    private func utilizationHeroCard(summary: CreditUtilizationSummary) -> some View {
        let statusColor = Color.fromString(summary.aggregateStatus.colorName)

        return VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                VStack(alignment: .leading, spacing: FTSpacing.xs) {
                    Text("OVERALL UTILIZATION")
                        .font(.ftLabel)
                        .tracking(1.4)
                        .foregroundStyle(FTColor.textSecondary)
                    HStack(alignment: .lastTextBaseline, spacing: FTSpacing.sm) {
                        Text(summary.aggregateUtilization.asPercentage())
                            .font(.ftAmount)
                            .foregroundStyle(FTColor.textPrimary)
                        HStack(spacing: FTSpacing.xs) {
                            Image(systemName: summary.aggregateStatus.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(summary.aggregateStatus.rawValue)
                                .font(.ftCallout)
                        }
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, FTSpacing.sm + 2)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.14), in: .capsule)
                    }
                }
                Spacer()
            }

            FTProgressBar(
                value: min(summary.aggregateUtilization, 1),
                color: statusColor,
                height: 10
            )

            HStack(spacing: 0) {
                DebtSummaryMetric(
                    label: "Outstanding",
                    value: summary.totalOutstanding.asCompact(currency: baseCurrency),
                    valueColor: FTColor.expense
                )
                Spacer()
                DebtSummaryMetric(
                    label: "Credit Limit",
                    value: summary.totalLimit.asCompact(currency: baseCurrency),
                    valueColor: FTColor.textPrimary
                )
                Spacer()
                DebtSummaryMetric(
                    label: "Available",
                    value: summary.availableCredit.asCompact(currency: baseCurrency),
                    valueColor: FTColor.income
                )
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - LoanDebtCard

private struct LoanDebtCard: View {
    let loan: Loan
    let baseCurrency: String
    let currencyService: CurrencyService

    var body: some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: loan.loanType.icon, tint: FTColor.expense, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(loan.name)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                    Text(loan.lenderName.isEmpty ? loan.loanType.rawValue : loan.lenderName)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(currencyService.convert(loan.outstandingBalance, from: loan.currency, to: baseCurrency).formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.expense)
                    Text("outstanding")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.textMuted)
                }
            }

            HStack(spacing: FTSpacing.lg) {
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "percent")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                    Text(loan.interestRate.asPercentage())
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                    Text(loan.nextPaymentDate.relativeFormatted)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }

            VStack(spacing: FTSpacing.xs) {
                HStack {
                    Text("\(loan.paidInstallments) of \(loan.totalInstallments) installments")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.textMuted)
                    Spacer()
                    let progress = loan.totalInstallments > 0 ? Double(loan.paidInstallments) / Double(loan.totalInstallments) : 0
                    Text((progress * 100).asPercentage(decimals: 0))
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.textSecondary)
                }
                let progress = loan.totalInstallments > 0 ? Double(loan.paidInstallments) / Double(loan.totalInstallments) : 0
                FTProgressBar(
                    value: min(max(progress, 0), 1),
                    color: FTColor.income,
                    height: 7
                )
            }
        }
        .padding(FTSpacing.lg)
        .ftGlassInteractive(FTRadius.lg)
    }
}

// MARK: - CreditCardDebtCard

private struct CreditCardDebtCard: View {
    let card: CreditCard
    let baseCurrency: String
    let currencyService: CurrencyService

    private var utilizationColor: Color {
        let rate = card.utilizationRate
        if rate < 0.30 { return FTColor.income }
        if rate < 0.50 { return FTColor.gold }
        return FTColor.expense
    }

    var body: some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "creditcard.fill", tint: Color.fromString(card.color), size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                    Text("\(card.bankName) •••• \(card.last4Digits)")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(currencyService.convert(card.outstandingBalance, from: card.currency, to: baseCurrency).formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.expense)
                    Text("of \(currencyService.convert(card.creditLimit, from: card.currency, to: baseCurrency).asCompact(currency: baseCurrency))")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.textMuted)
                }
            }

            VStack(spacing: FTSpacing.xs) {
                HStack {
                    Text("Utilization: \(card.utilizationRate.asPercentage())")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Text("Available: \(currencyService.convert(card.availableCredit, from: card.currency, to: baseCurrency).asCompact(currency: baseCurrency))")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.income)
                }
                FTProgressBar(
                    value: min(max(card.utilizationRate, 0), 1),
                    color: utilizationColor,
                    height: 7
                )
            }

            HStack {
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(card.isPaymentDueSoon ? FTColor.expense : FTColor.textMuted)
                    Text("Due \(card.dueDate.relativeFormatted)")
                        .font(.ftCaption)
                        .foregroundStyle(card.isPaymentDueSoon ? FTColor.expense : FTColor.textSecondary)
                }
                Spacer()
                if card.isOverLimit {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Over Limit")
                            .font(.ftLabel)
                            .tracking(0.3)
                    }
                    .foregroundStyle(FTColor.expense)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlassInteractive(FTRadius.lg)
    }
}

// MARK: - MoneyLentCard

private struct MoneyLentCard: View {
    let item: MoneyLent
    let baseCurrency: String
    let currencyService: CurrencyService
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: FTSpacing.md) {
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "person.fill", tint: Color.fromString(item.color), size: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.borrowerName)
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                            .lineLimit(1)
                        Text("Lent \(item.lendingDate.relativeFormatted)")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(currencyService.convert(item.remainingBalance, from: item.currency, to: baseCurrency).formatted(as: baseCurrency))
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.income)
                        Text("remaining")
                            .font(.ftLabel)
                            .tracking(0.3)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }

                VStack(spacing: FTSpacing.xs) {
                    HStack {
                        HStack(spacing: FTSpacing.xs) {
                            Image(systemName: item.computedStatus.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(item.computedStatus.displayColor)
                            Text(item.computedStatus.rawValue)
                                .font(.ftLabel)
                                .tracking(0.3)
                                .foregroundStyle(item.computedStatus.displayColor)
                        }
                        Spacer()
                        if let dueDate = item.dueDate {
                            Text("Due \(dueDate.formatted)")
                                .font(.ftLabel)
                                .tracking(0.3)
                                .foregroundStyle(dueDate < Date() ? FTColor.expense : FTColor.textSecondary)
                        }
                    }
                    FTProgressBar(
                        value: min(max(item.progressFraction, 0), 1),
                        color: item.isFullyRepaid ? FTColor.income : Color.fromString(item.color),
                        height: 7
                    )
                }
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MoneyBorrowedCard

private struct MoneyBorrowedCard: View {
    let item: MoneyBorrowed
    let baseCurrency: String
    let currencyService: CurrencyService
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: FTSpacing.md) {
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "person.fill", tint: Color.fromString(item.color), size: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.lenderName)
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                            .lineLimit(1)
                        Text("Borrowed \(item.borrowDate.relativeFormatted)")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(currencyService.convert(item.remainingBalance, from: item.currency, to: baseCurrency).formatted(as: baseCurrency))
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.expense)
                        Text("remaining")
                            .font(.ftLabel)
                            .tracking(0.3)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }

                VStack(spacing: FTSpacing.xs) {
                    HStack {
                        HStack(spacing: FTSpacing.xs) {
                            Image(systemName: item.computedStatus.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(item.computedStatus.displayColor)
                            Text(item.computedStatus.rawValue)
                                .font(.ftLabel)
                                .tracking(0.3)
                                .foregroundStyle(item.computedStatus.displayColor)
                        }
                        Spacer()
                        if let dueDate = item.dueDate {
                            Text("Due \(dueDate.formatted)")
                                .font(.ftLabel)
                                .tracking(0.3)
                                .foregroundStyle(dueDate < Date() ? FTColor.expense : FTColor.textSecondary)
                        }
                    }
                    FTProgressBar(
                        value: min(max(item.progressFraction, 0), 1),
                        color: item.isFullyRepaid ? FTColor.income : Color.fromString(item.color),
                        height: 7
                    )
                }
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CardUtilizationRow

private struct CardUtilizationRow: View {
    let cardUtil: CreditUtilizationSummary.CardUtilization
    let baseCurrency: String
    let currencyService: CurrencyService

    private var statusColor: Color { Color.fromString(cardUtil.utilizationStatus.colorName) }

    var body: some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "creditcard.fill", tint: Color.fromString(cardUtil.color), size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cardUtil.cardName)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                    Text(cardUtil.bankName)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: cardUtil.utilizationStatus.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)
                    Text(cardUtil.utilizationRate.asPercentage())
                        .font(.ftBodySemibold)
                        .foregroundStyle(statusColor)
                }
                .padding(.horizontal, FTSpacing.sm + 2)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12), in: .capsule)
            }

            FTProgressBar(
                value: min(max(cardUtil.utilizationRate, 0), 1),
                color: statusColor,
                height: 7
            )

            HStack {
                Text("Outstanding: \(currencyService.convert(cardUtil.outstandingBalance, from: cardUtil.currency, to: baseCurrency).formatted(as: baseCurrency))")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                Spacer()
                Text("Limit: \(currencyService.convert(cardUtil.creditLimit, from: cardUtil.currency, to: baseCurrency).asCompact(currency: baseCurrency))")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - DebtSummaryMetric

private struct DebtSummaryMetric: View {
    let label: String
    let value: String
    var valueColor: Color = FTColor.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.ftLabel)
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.ftCallout)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - ExtraPaymentControl

private struct ExtraPaymentControl: View {
    let title: String
    @Binding var amount: Double
    var tint: Color = FTColor.accent
    let step: Double = 50
    let range: ClosedRange<Double> = 0...5000

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text(title)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)

            HStack(spacing: FTSpacing.md) {
                Button {
                    withAnimation(.snappy(duration: 0.15)) {
                        amount = max(amount - step, range.lowerBound)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(amount <= range.lowerBound ? FTColor.textMuted : tint)
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: .circle)
                        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(amount <= range.lowerBound)

                Spacer()

                VStack(spacing: 2) {
                    Text(amount.formatted(as: "AED"))
                        .font(.ftTitle)
                        .foregroundStyle(FTColor.textPrimary)
                        .monospacedDigit()
                    Text("/ month extra")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.textMuted)
                }

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.15)) {
                        amount = min(amount + step, range.upperBound)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(amount >= range.upperBound ? FTColor.textMuted : tint)
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: .circle)
                        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(amount >= range.upperBound)
            }
            .padding(FTSpacing.md)
            .background(.regularMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - PayoffEntryCard

private struct PayoffEntryCard: View {
    let entry: DebtPayoffPlan.DebtOrderEntry
    let tint: Color
    let baseCurrency: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            // Order badge
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(entry.payoffOrder)")
                    .font(.ftBodySemibold)
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .lineLimit(1)
                Text("Min: \(entry.minimumPayment.formatted(as: baseCurrency))/mo · \(entry.monthsToPayoff) months")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.payoffDate.formatted)
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.textPrimary)
                Text(entry.totalInterestPaid.formatted(as: baseCurrency))
                    .font(.ftLabel)
                    .tracking(0.3)
                    .foregroundStyle(FTColor.expense)
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - BalanceComparisonChart

private struct BalanceComparisonChart: View {
    let breakdown: [(month: Int, standardBalance: Double, acceleratedBalance: Double)]
    let baseCurrency: String

    private struct BalancePoint: Identifiable {
        let id = UUID()
        let month: Int
        let balance: Double
        let type: String
    }

    private var chartData: [BalancePoint] {
        let limit = min(breakdown.count, 36)
        var result: [BalancePoint] = []
        for entry in breakdown.prefix(limit) {
            result.append(BalancePoint(month: entry.month, balance: entry.standardBalance, type: "Standard"))
            result.append(BalancePoint(month: entry.month, balance: entry.acceleratedBalance, type: "With Extra"))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FTColor.textSecondary)
                Text("BALANCE PROJECTION")
                    .font(.ftLabel)
                    .tracking(1.4)
                    .foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text("First 36 months")
                    .font(.ftLabel)
                    .tracking(0.3)
                    .foregroundStyle(FTColor.textMuted)
            }

            Chart(chartData) { point in
                LineMark(
                    x: .value("Month", point.month),
                    y: .value("Balance", point.balance)
                )
                .foregroundStyle(by: .value("Type", point.type))
                .interpolationMethod(.catmullRom)
            }
            .chartForegroundStyleScale([
                "Standard": FTColor.expense,
                "With Extra": FTColor.income
            ])
            .chartLegend(position: .bottom, alignment: .center, spacing: FTSpacing.sm)
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .stride(by: 6)) { _ in
                    AxisValueLabel()
                        .foregroundStyle(FTColor.textMuted)
                        .font(.ftLabel)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel()
                        .foregroundStyle(FTColor.textMuted)
                        .font(.ftLabel)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - MoneyLentDetailSheet

struct MoneyLentDetailSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState

    let item: MoneyLent
    @State private var showingRepaymentSheet = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    private var baseCurrency: String { appState.baseCurrency }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Header
                        VStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: "person.fill", tint: Color.fromString(item.color), size: 60)
                            Text(item.borrowerName)
                                .font(.ftTitle)
                                .foregroundStyle(FTColor.textPrimary)
                            HStack(spacing: FTSpacing.xs) {
                                Image(systemName: item.computedStatus.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(item.computedStatus.rawValue)
                                    .font(.ftCallout)
                            }
                            .foregroundStyle(item.computedStatus.displayColor)
                            .padding(.horizontal, FTSpacing.md)
                            .padding(.vertical, FTSpacing.xs + 2)
                            .background(item.computedStatus.displayColor.opacity(0.14), in: .capsule)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, FTSpacing.lg)

                        // Amount summary
                        VStack(spacing: FTSpacing.md) {
                            HStack {
                                amountMetric(label: "Original", value: item.amount.formatted(as: item.currency), tint: FTColor.textPrimary)
                                Spacer()
                                amountMetric(label: "Repaid", value: item.totalRepaid.formatted(as: item.currency), tint: FTColor.income)
                                Spacer()
                                amountMetric(label: "Remaining", value: item.remainingBalance.formatted(as: item.currency), tint: FTColor.expense)
                            }

                            FTProgressBar(
                                value: min(max(item.progressFraction, 0), 1),
                                color: Color.fromString(item.color),
                                height: 10
                            )
                            Text("\(Int(item.progressFraction * 100))% repaid")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        // Details
                        VStack(spacing: 0) {
                            detailRow(label: "Lending Date", value: item.lendingDate.formatted)
                            Divider().padding(.leading, FTSpacing.screen)
                            if let due = item.dueDate {
                                detailRow(label: "Due Date", value: due.formatted, valueColor: due < Date() ? FTColor.expense : FTColor.textPrimary)
                                Divider().padding(.leading, FTSpacing.screen)
                            }
                            if let contact = item.contactInfo, !contact.isEmpty {
                                detailRow(label: "Contact", value: contact)
                                Divider().padding(.leading, FTSpacing.screen)
                            }
                            if let notes = item.notes, !notes.isEmpty {
                                detailRow(label: "Notes", value: notes)
                            }
                        }
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        // Repayment history
                        if !item.repayments.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                HStack(spacing: FTSpacing.xs) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(FTColor.textSecondary)
                                    Text("REPAYMENT HISTORY")
                                        .font(.ftLabel)
                                        .tracking(1.4)
                                        .foregroundStyle(FTColor.textSecondary)
                                }
                                .padding(.horizontal, FTSpacing.screen)

                                VStack(spacing: 1) {
                                    ForEach(item.repayments.sorted { $0.date > $1.date }) { repayment in
                                        HStack(spacing: FTSpacing.md) {
                                            FTIconTile(symbol: "arrow.down.circle.fill", tint: FTColor.income, size: 36)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(repayment.amount.formatted(as: item.currency))
                                                    .font(.ftBodySemibold)
                                                    .foregroundStyle(FTColor.income)
                                                Text(repayment.date.formatted)
                                                    .font(.ftCaption)
                                                    .foregroundStyle(FTColor.textSecondary)
                                                if let notes = repayment.notes, !notes.isEmpty {
                                                    Text(notes)
                                                        .font(.ftCaption)
                                                        .foregroundStyle(FTColor.textMuted)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, FTSpacing.screen)
                                        .padding(.vertical, FTSpacing.sm)
                                    }
                                }
                                .ftGlass(FTRadius.lg)
                                .padding(.horizontal, FTSpacing.screen)
                            }
                        }

                        // Record repayment button
                        if !item.isFullyRepaid {
                            Button {
                                showingRepaymentSheet = true
                            } label: {
                                Label("Record Repayment", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.ftPrimary)
                            .padding(.horizontal, FTSpacing.screen)
                        }

                        Spacer(minLength: FTSpacing.xxl)
                    }
                }
            }
            .navigationTitle("Money Lent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(FTColor.expense)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: FTSpacing.md) {
                        Button("Edit") { showingEdit = true }
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.accent)
                        Button("Done") { dismiss() }
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.accent)
                    }
                }
            }
            .sheet(isPresented: $showingRepaymentSheet) {
                RecordLentRepaymentSheet(item: item)
            }
            .sheet(isPresented: $showingEdit) {
                AddMoneyLentSheet(editing: item)
            }
            .confirmationDialog("Delete this record?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    context.delete(item)
                    try? context.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func amountMetric(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.ftLabel)
                .tracking(0.5)
                .foregroundStyle(FTColor.textSecondary)
            Text(value)
                .font(.ftCallout)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func detailRow(label: String, value: String, valueColor: Color = FTColor.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - RecordLentRepaymentSheet

private struct RecordLentRepaymentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: MoneyLent

    @State private var amount: String = ""
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: FTSpacing.md) {
                            formRow(label: "Amount (\(item.currency))") {
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Date") {
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(FTColor.accent)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Notes") {
                                TextField("Optional notes", text: $notes)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        Text("Remaining: \(item.remainingBalance.formatted(as: item.currency))")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, FTSpacing.screen)

                        Button("Save Repayment") { save() }
                            .buttonStyle(.ftPrimary)
                            .padding(.horizontal, FTSpacing.screen)
                            .disabled(Double(amount) == nil || (Double(amount) ?? 0) <= 0)
                    }
                    .padding(.top, FTSpacing.lg)
                }
            }
            .navigationTitle("Record Repayment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.accent)
                }
            }
            .onAppear {
                amount = String(format: "%.2f", item.remainingBalance)
            }
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            content()
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }

    private func save() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        let record = RepaymentRecord(
            date: date,
            amount: amountValue,
            notes: notes.isEmpty ? nil : notes
        )
        var repayments = item.repayments
        repayments.append(record)
        item.repayments = repayments
        item.updatedAt = Date()

        let tx = Transaction(
            title: "Repayment from \(item.borrowerName)",
            amount: amountValue,
            currency: item.currency,
            type: .income,
            category: .personalLentRepayment,
            date: date,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(tx)
        try? context.save()
        dismiss()
    }
}

// MARK: - MoneyBorrowedDetailSheet

struct MoneyBorrowedDetailSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState

    let item: MoneyBorrowed
    @State private var showingRepaymentSheet = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    private var baseCurrency: String { appState.baseCurrency }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Header
                        VStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: "person.fill", tint: Color.fromString(item.color), size: 60)
                            Text(item.lenderName)
                                .font(.ftTitle)
                                .foregroundStyle(FTColor.textPrimary)
                            HStack(spacing: FTSpacing.xs) {
                                Image(systemName: item.computedStatus.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(item.computedStatus.rawValue)
                                    .font(.ftCallout)
                            }
                            .foregroundStyle(item.computedStatus.displayColor)
                            .padding(.horizontal, FTSpacing.md)
                            .padding(.vertical, FTSpacing.xs + 2)
                            .background(item.computedStatus.displayColor.opacity(0.14), in: .capsule)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, FTSpacing.lg)

                        // Amount summary
                        VStack(spacing: FTSpacing.md) {
                            HStack {
                                borrowedAmountMetric(label: "Borrowed", value: item.amount.formatted(as: item.currency), tint: FTColor.textPrimary)
                                Spacer()
                                borrowedAmountMetric(label: "Repaid", value: item.totalRepaid.formatted(as: item.currency), tint: FTColor.income)
                                Spacer()
                                borrowedAmountMetric(label: "Remaining", value: item.remainingBalance.formatted(as: item.currency), tint: FTColor.expense)
                            }

                            FTProgressBar(
                                value: min(max(item.progressFraction, 0), 1),
                                color: Color.fromString(item.color),
                                height: 10
                            )
                            Text("\(Int(item.progressFraction * 100))% repaid")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        // Details
                        VStack(spacing: 0) {
                            borrowedDetailRow(label: "Borrow Date", value: item.borrowDate.formatted)
                            Divider().padding(.leading, FTSpacing.screen)
                            if let due = item.dueDate {
                                borrowedDetailRow(label: "Due Date", value: due.formatted, valueColor: due < Date() ? FTColor.expense : FTColor.textPrimary)
                                Divider().padding(.leading, FTSpacing.screen)
                            }
                            if let contact = item.contactInfo, !contact.isEmpty {
                                borrowedDetailRow(label: "Contact", value: contact)
                                Divider().padding(.leading, FTSpacing.screen)
                            }
                            if let notes = item.notes, !notes.isEmpty {
                                borrowedDetailRow(label: "Notes", value: notes)
                            }
                        }
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        // Repayment history
                        if !item.repayments.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                HStack(spacing: FTSpacing.xs) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(FTColor.textSecondary)
                                    Text("REPAYMENT HISTORY")
                                        .font(.ftLabel)
                                        .tracking(1.4)
                                        .foregroundStyle(FTColor.textSecondary)
                                }
                                .padding(.horizontal, FTSpacing.screen)

                                VStack(spacing: 1) {
                                    ForEach(item.repayments.sorted { $0.date > $1.date }) { repayment in
                                        HStack(spacing: FTSpacing.md) {
                                            FTIconTile(symbol: "arrow.up.circle.fill", tint: FTColor.expense, size: 36)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(repayment.amount.formatted(as: item.currency))
                                                    .font(.ftBodySemibold)
                                                    .foregroundStyle(FTColor.expense)
                                                Text(repayment.date.formatted)
                                                    .font(.ftCaption)
                                                    .foregroundStyle(FTColor.textSecondary)
                                                if let notes = repayment.notes, !notes.isEmpty {
                                                    Text(notes)
                                                        .font(.ftCaption)
                                                        .foregroundStyle(FTColor.textMuted)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, FTSpacing.screen)
                                        .padding(.vertical, FTSpacing.sm)
                                    }
                                }
                                .ftGlass(FTRadius.lg)
                                .padding(.horizontal, FTSpacing.screen)
                            }
                        }

                        if !item.isFullyRepaid {
                            Button {
                                showingRepaymentSheet = true
                            } label: {
                                Label("Record Repayment", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.ftPrimary)
                            .padding(.horizontal, FTSpacing.screen)
                        }

                        Spacer(minLength: FTSpacing.xxl)
                    }
                }
            }
            .navigationTitle("Money Borrowed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(FTColor.expense)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: FTSpacing.md) {
                        Button("Edit") { showingEdit = true }
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.accent)
                        Button("Done") { dismiss() }
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.accent)
                    }
                }
            }
            .sheet(isPresented: $showingRepaymentSheet) {
                RecordBorrowedRepaymentSheet(item: item)
            }
            .sheet(isPresented: $showingEdit) {
                AddMoneyBorrowedSheet(editing: item)
            }
            .confirmationDialog("Delete this record?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    context.delete(item)
                    try? context.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func borrowedAmountMetric(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.ftLabel)
                .tracking(0.5)
                .foregroundStyle(FTColor.textSecondary)
            Text(value)
                .font(.ftCallout)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func borrowedDetailRow(label: String, value: String, valueColor: Color = FTColor.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - RecordBorrowedRepaymentSheet

private struct RecordBorrowedRepaymentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: MoneyBorrowed

    @State private var amount: String = ""
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: FTSpacing.md) {
                            formRow(label: "Amount (\(item.currency))") {
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Date") {
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(FTColor.accent)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Notes") {
                                TextField("Optional notes", text: $notes)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        Text("Remaining: \(item.remainingBalance.formatted(as: item.currency))")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, FTSpacing.screen)

                        Button("Save Repayment") { save() }
                            .buttonStyle(.ftPrimary)
                            .padding(.horizontal, FTSpacing.screen)
                            .disabled(Double(amount) == nil || (Double(amount) ?? 0) <= 0)
                    }
                    .padding(.top, FTSpacing.lg)
                }
            }
            .navigationTitle("Record Repayment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.accent)
                }
            }
            .onAppear {
                amount = String(format: "%.2f", item.remainingBalance)
            }
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            content()
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }

    private func save() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        let record = RepaymentRecord(
            date: date,
            amount: amountValue,
            notes: notes.isEmpty ? nil : notes
        )
        var repayments = item.repayments
        repayments.append(record)
        item.repayments = repayments
        item.updatedAt = Date()

        let tx = Transaction(
            title: "Repaid to \(item.lenderName)",
            amount: amountValue,
            currency: item.currency,
            type: .expense,
            category: .loanRepayment,
            date: date,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(tx)
        try? context.save()
        dismiss()
    }
}

// MARK: - AddMoneyLentSheet (minimal add form)

private struct AddMoneyLentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editing: MoneyLent? = nil

    @State private var borrowerName = ""
    @State private var amount = ""
    @State private var currency = "AED"
    @State private var lendingDate = Date()
    @State private var dueDate: Date? = nil
    @State private var hasDueDate = false
    @State private var notes = ""
    @State private var selectedColor = "blue"
    @State private var contactInfo = ""

    private let colorOptions = ["blue", "green", "teal", "purple", "orange", "pink", "indigo"]

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            formRow(label: "Borrower Name") {
                                TextField("Name", text: $borrowerName)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Amount") {
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.textPrimary)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Currency") {
                                TextField("AED", text: $currency)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .frame(width: 60)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Lending Date") {
                                DatePicker("", selection: $lendingDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(FTColor.accent)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Due Date") {
                                Toggle("", isOn: $hasDueDate)
                                    .labelsHidden()
                                    .tint(FTColor.accent)
                            }
                            if hasDueDate {
                                Divider().padding(.leading, FTSpacing.screen)
                                formRow(label: "") {
                                    DatePicker("", selection: Binding(
                                        get: { dueDate ?? Date() },
                                        set: { dueDate = $0 }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(FTColor.accent)
                                }
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Contact") {
                                TextField("Phone/Email", text: $contactInfo)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Notes") {
                                TextField("Optional", text: $notes)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                            }
                        }
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        // Color picker
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("Color")
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                                .padding(.horizontal, FTSpacing.screen)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: FTSpacing.md) {
                                    ForEach(colorOptions, id: \.self) { colorName in
                                        Button {
                                            selectedColor = colorName
                                        } label: {
                                            Circle()
                                                .fill(Color.fromString(colorName))
                                                .frame(width: 34, height: 34)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(.white, lineWidth: selectedColor == colorName ? 3 : 0)
                                                )
                                                .shadow(color: Color.fromString(colorName).opacity(0.4), radius: 6, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, FTSpacing.screen)
                            }
                        }

                        Button(editing == nil ? "Add Record" : "Save Changes") { save() }
                            .buttonStyle(.ftPrimary)
                            .padding(.horizontal, FTSpacing.screen)
                            .disabled(borrowerName.isEmpty || Double(amount) == nil)
                    }
                    .padding(.top, FTSpacing.lg)
                    .padding(.bottom, FTSpacing.xxl)
                }
            }
            .navigationTitle(editing == nil ? "Lend Money" : "Edit Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.accent)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            if !label.isEmpty {
                Text(label)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            content()
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }

    private func populateIfEditing() {
        guard let e = editing else { return }
        borrowerName = e.borrowerName
        amount = String(format: "%.2f", e.amount)
        currency = e.currency
        lendingDate = e.lendingDate
        hasDueDate = e.dueDate != nil
        dueDate = e.dueDate
        notes = e.notes ?? ""
        contactInfo = e.contactInfo ?? ""
        selectedColor = e.color
    }

    private func save() {
        guard let amountValue = Double(amount), !borrowerName.isEmpty else { return }
        if let e = editing {
            e.borrowerName = borrowerName
            e.amount = amountValue
            e.currency = currency
            e.lendingDate = lendingDate
            e.dueDate = hasDueDate ? dueDate : nil
            e.notes = notes.isEmpty ? nil : notes
            e.contactInfo = contactInfo.isEmpty ? nil : contactInfo
            e.color = selectedColor
            e.updatedAt = Date()
        } else {
            let item = MoneyLent(
                borrowerName: borrowerName,
                amount: amountValue,
                currency: currency,
                lendingDate: lendingDate,
                dueDate: hasDueDate ? dueDate : nil,
                notes: notes.isEmpty ? nil : notes,
                color: selectedColor
            )
            item.contactInfo = contactInfo.isEmpty ? nil : contactInfo
            context.insert(item)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - AddMoneyBorrowedSheet (minimal add form)

private struct AddMoneyBorrowedSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editing: MoneyBorrowed? = nil

    @State private var lenderName = ""
    @State private var amount = ""
    @State private var currency = "AED"
    @State private var borrowDate = Date()
    @State private var dueDate: Date? = nil
    @State private var hasDueDate = false
    @State private var notes = ""
    @State private var selectedColor = "red"
    @State private var contactInfo = ""

    private let colorOptions = ["red", "orange", "pink", "purple", "brown", "gray", "indigo"]

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            formRow(label: "Lender Name") {
                                TextField("Name", text: $lenderName)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Amount") {
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.textPrimary)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Currency") {
                                TextField("AED", text: $currency)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .frame(width: 60)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Borrow Date") {
                                DatePicker("", selection: $borrowDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(FTColor.accent)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Due Date") {
                                Toggle("", isOn: $hasDueDate)
                                    .labelsHidden()
                                    .tint(FTColor.accent)
                            }
                            if hasDueDate {
                                Divider().padding(.leading, FTSpacing.screen)
                                formRow(label: "") {
                                    DatePicker("", selection: Binding(
                                        get: { dueDate ?? Date() },
                                        set: { dueDate = $0 }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(FTColor.accent)
                                }
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Contact") {
                                TextField("Phone/Email", text: $contactInfo)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Notes") {
                                TextField("Optional", text: $notes)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                            }
                        }
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("Color")
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                                .padding(.horizontal, FTSpacing.screen)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: FTSpacing.md) {
                                    ForEach(colorOptions, id: \.self) { colorName in
                                        Button {
                                            selectedColor = colorName
                                        } label: {
                                            Circle()
                                                .fill(Color.fromString(colorName))
                                                .frame(width: 34, height: 34)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(.white, lineWidth: selectedColor == colorName ? 3 : 0)
                                                )
                                                .shadow(color: Color.fromString(colorName).opacity(0.4), radius: 6, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, FTSpacing.screen)
                            }
                        }

                        Button(editing == nil ? "Add Record" : "Save Changes") { save() }
                            .buttonStyle(.ftPrimary)
                            .padding(.horizontal, FTSpacing.screen)
                            .disabled(lenderName.isEmpty || Double(amount) == nil)
                    }
                    .padding(.top, FTSpacing.lg)
                    .padding(.bottom, FTSpacing.xxl)
                }
            }
            .navigationTitle(editing == nil ? "Borrowed Money" : "Edit Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.accent)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            if !label.isEmpty {
                Text(label)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            content()
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }

    private func populateIfEditing() {
        guard let e = editing else { return }
        lenderName = e.lenderName
        amount = String(format: "%.2f", e.amount)
        currency = e.currency
        borrowDate = e.borrowDate
        hasDueDate = e.dueDate != nil
        dueDate = e.dueDate
        notes = e.notes ?? ""
        contactInfo = e.contactInfo ?? ""
        selectedColor = e.color
    }

    private func save() {
        guard let amountValue = Double(amount), !lenderName.isEmpty else { return }
        if let e = editing {
            e.lenderName = lenderName
            e.amount = amountValue
            e.currency = currency
            e.borrowDate = borrowDate
            e.dueDate = hasDueDate ? dueDate : nil
            e.notes = notes.isEmpty ? nil : notes
            e.contactInfo = contactInfo.isEmpty ? nil : contactInfo
            e.color = selectedColor
            e.updatedAt = Date()
        } else {
            let item = MoneyBorrowed(
                lenderName: lenderName,
                amount: amountValue,
                currency: currency,
                borrowDate: borrowDate,
                dueDate: hasDueDate ? dueDate : nil,
                notes: notes.isEmpty ? nil : notes,
                color: selectedColor
            )
            item.contactInfo = contactInfo.isEmpty ? nil : contactInfo
            context.insert(item)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        FTBackdrop()
        DebtManagementView()
    }
    .environment(AppState())
    .environment(CurrencyService.shared)
    .modelContainer(
        for: [
            Loan.self,
            CreditCard.self,
            MoneyLent.self,
            MoneyBorrowed.self,
            Transaction.self,
        ],
        inMemory: true
    )
}
