import SwiftUI
import SwiftData
import Charts

// MARK: - Main Budget View

struct BudgetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \Budget.name) private var budgets: [Budget]
    @Query(sort: \SavingsGoal.name) private var savingsGoals: [SavingsGoal]
    @Query(sort: \BudgetEnvelope.sortOrder) private var envelopes: [BudgetEnvelope]
    @Query private var templates: [BudgetTemplate]
    @Query private var transactions: [Transaction]

    @State private var tab = 0          // 0=Monthly, 1=Annual, 2=Envelopes, 3=Zero-Based
    @State private var selectedMonth = Date()
    @State private var showingAddBudget = false
    @State private var showingAddGoal = false
    @State private var showingAddEnvelope = false
    @State private var showingTemplates = false
    @State private var showingRecommendations = false
    @State private var recommendations: [BudgetRecommendation] = []
    @State private var detailBudget: Budget? = nil
    @State private var detailEnvelope: BudgetEnvelope? = nil
    @State private var showingBills = false
    @State private var showingIncome = false
    @State private var showingDebt = false

    private let tabs = ["Monthly", "Annual", "Envelopes", "Zero-Based"]
    private var baseCurrency: String { appState.baseCurrency }

    // MARK: Spending computation

    private var activeMonthlyBudgets: [Budget] {
        budgets.filter { $0.isActive && $0.period == .monthly }
    }

    private var activeYearlyBudgets: [Budget] {
        budgets.filter { $0.isActive && $0.period == .yearly }
    }

    /// Single-pass spending by category for the selected month.
    private var spentByCategory: [TransactionCategory: Double] {
        var result: [TransactionCategory: Double] = [:]
        for tx in transactions where tx.date.isSameMonth(as: selectedMonth) {
            for (cat, amount) in tx.spendingPairs {
                result[cat, default: 0] += amount
            }
        }
        return result
    }

    /// Single-pass year-to-date spending by category.
    private var ytdSpentByCategory: [TransactionCategory: Double] {
        let yearStart = Date().startOfYear
        var result: [TransactionCategory: Double] = [:]
        for tx in transactions where tx.date >= yearStart {
            for (cat, amount) in tx.spendingPairs {
                result[cat, default: 0] += amount
            }
        }
        return result
    }

    private var monthlyBudgetsWithSpending: [(Budget, Double)] {
        let spent = spentByCategory
        return activeMonthlyBudgets.map { ($0, spent[$0.category] ?? 0) }
    }

    private var totalMonthlyBudgeted: Double {
        activeMonthlyBudgets.reduce(0) { $0 + $1.amount + $1.rolloverAmount }
    }

    private var totalMonthlySpent: Double {
        monthlyBudgetsWithSpending.reduce(0) { $0 + $1.1 }
    }

    /// Current-month income from posted transactions.
    private var currentMonthIncome: Double {
        transactions
            .filter { $0.type == .income && !$0.isPending && !$0.isScheduled && $0.date.isSameMonth(as: Date()) }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    /// Monthly spending by category for bar chart (last 6 months).
    private var last6MonthsSpending: [(month: Date, total: Double)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<6).compactMap { offset -> (Date, Double)? in
            guard let monthStart = cal.date(byAdding: .month, value: -offset, to: now.startOfMonth) else { return nil }
            let total = transactions
                .filter { $0.date.isSameMonth(as: monthStart) }
                .flatMap { $0.spendingPairs }
                .reduce(0) { $0 + $1.1 }
            return (monthStart, total)
        }.reversed()
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                VStack(spacing: 0) {
                    FTSegmentedControl(options: tabs, selection: .init(
                        get: { tab },
                        set: { withAnimation(.snappy(duration: 0.25)) { tab = $0 } }
                    ))
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)

                    ScrollView {
                        VStack(spacing: FTSpacing.lg) {
                            switch tab {
                            case 0: monthlyContent
                            case 1: annualContent
                            case 2: envelopesContent
                            default: zeroBasedContent
                            }
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, FTSpacing.screen)
                        .padding(.top, FTSpacing.lg)
                    }
                }
            }
            .navigationTitle("Budget & Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingAddBudget) { AddBudgetView() }
            .sheet(isPresented: $showingAddGoal) { AddSavingsGoalView() }
            .sheet(isPresented: $showingAddEnvelope) { AddEnvelopeView() }
            .sheet(isPresented: $showingTemplates) {
                BudgetTemplatesView(existingBudgets: budgets)
            }
            .sheet(isPresented: $showingRecommendations) {
                BudgetRecommendationsView(
                    recommendations: $recommendations,
                    budgets: budgets,
                    onCreateBudget: { cat, amount in
                        createBudgetFromRecommendation(category: cat, amount: amount)
                    }
                )
            }
            .sheet(item: $detailBudget) { budget in
                BudgetDetailView(budget: budget, transactions: transactions)
            }
            .sheet(item: $detailEnvelope) { env in
                EnvelopeDetailView(envelope: env, transactions: transactions)
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
            .onAppear {
                BudgetService.shared.processRollovers(budgets: budgets, transactions: transactions)
                recommendations = BudgetService.shared.generateRecommendations(
                    transactions: transactions, budgets: budgets
                )
                checkBudgetAlerts()
                ensureBuiltInTemplates()
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { showingAddBudget = true } label: {
                    Label("Add Budget", systemImage: "chart.pie")
                }
                Button { showingAddGoal = true } label: {
                    Label("Add Goal", systemImage: "star")
                }
                Button { showingAddEnvelope = true } label: {
                    Label("Add Envelope", systemImage: "envelope")
                }
                Divider()
                Button { showingTemplates = true } label: {
                    Label("Seasonal Templates", systemImage: "calendar.badge.plus")
                }
                Button { showingRecommendations = true } label: {
                    Label("AI Recommendations", systemImage: "sparkles")
                }
                Divider()
                Button { showingBills = true } label: {
                    Label("Bills & Subscriptions", systemImage: "calendar.badge.clock")
                }
                Button { showingIncome = true } label: {
                    Label("Income Management", systemImage: "banknote.fill")
                }
                Button { showingDebt = true } label: {
                    Label("Debt Management", systemImage: "creditcard.trianglebadge.exclamationmark")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
    }

    // MARK: - Tab 0: Monthly Content

    private var monthlyContent: some View {
        VStack(spacing: FTSpacing.lg) {
            monthOverviewCard

            if !recommendations.filter({ !$0.isDismissed }).isEmpty {
                aiRecommendationsBanner
            }

            // Forecasts for over-budget projected categories
            let forecasts = monthlyBudgetsWithSpending.compactMap { (budget, spent) -> BudgetForecast? in
                let f = BudgetService.shared.forecastEndOfMonth(for: budget, spent: spent, transactions: transactions)
                return f.isProjectedOverBudget ? f : nil
            }
            if !forecasts.isEmpty {
                forecastBanner(forecasts: forecasts)
            }

            sectionHeader("Monthly Budgets", action: "Add", onAction: { showingAddBudget = true })

            if activeMonthlyBudgets.isEmpty {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "No Monthly Budgets",
                    message: "Set spending limits for each category to track your finances.",
                    actionTitle: "Add Budget"
                ) { showingAddBudget = true }
                .ftGlass(FTRadius.lg)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(monthlyBudgetsWithSpending, id: \.0.id) { (budget, spent) in
                        EnhancedBudgetRow(
                            budget: budget,
                            spent: spent,
                            currency: baseCurrency,
                            forecast: BudgetService.shared.forecastEndOfMonth(for: budget, spent: spent, transactions: transactions)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: FTRadius.md))
                        .onTapGesture { detailBudget = budget }
                        .swipeActions(edge: .leading) {
                            NavigationLink(destination: AddBudgetView(editingBudget: budget)) {
                                Label("Edit", systemImage: "pencil")
                            }.tint(FTColor.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(budget)
                                try? context.save()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }

            addRowButton(title: "Add Monthly Budget", icon: "plus.circle.fill") {
                showingAddBudget = true
            }
            addRowButton(title: "Use Seasonal Template", icon: "calendar.badge.plus") {
                showingTemplates = true
            }

            sectionHeader("Savings Goals", action: "Add", onAction: { showingAddGoal = true })
                .padding(.top, FTSpacing.sm)

            if savingsGoals.isEmpty {
                EmptyStateView(
                    icon: "star.fill",
                    title: "No Goals",
                    message: "Set savings goals to work towards what matters most.",
                    actionTitle: "Add Goal"
                ) { showingAddGoal = true }
                .ftGlass(FTRadius.lg)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(savingsGoals) { goal in
                        SavingsGoalRow(goal: goal, currency: baseCurrency)
                            .ftGlassInteractive(FTRadius.md)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(goal)
                                    try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }

            addRowButton(title: "Add Savings Goal", icon: "plus.circle.fill") {
                showingAddGoal = true
            }
        }
    }

    // MARK: - Tab 1: Annual Content

    private var annualContent: some View {
        VStack(spacing: FTSpacing.lg) {
            annualOverviewCard

            monthlySpendingChart

            sectionHeader("Year-to-Date by Category", action: nil, onAction: nil)

            let ytd = ytdSpentByCategory
            let allAnnualBudgets = budgets.filter { $0.isActive }

            if allAnnualBudgets.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Budgets",
                    message: "Create monthly or yearly budgets to see annual pacing.",
                    actionTitle: "Add Budget"
                ) { showingAddBudget = true }
                .ftGlass(FTRadius.lg)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(allAnnualBudgets, id: \.id) { budget in
                        let spent = ytd[budget.category] ?? 0
                        let annualTarget = annualTarget(for: budget)
                        AnnualBudgetRow(
                            budget: budget,
                            ytdSpent: spent,
                            annualTarget: annualTarget,
                            currency: baseCurrency
                        )
                    }
                }
            }
        }
    }

    private func annualTarget(for budget: Budget) -> Double {
        switch budget.period {
        case .weekly:    return budget.amount * 52
        case .monthly:   return budget.amount * 12
        case .quarterly: return budget.amount * 4
        case .yearly:    return budget.amount
        }
    }

    // MARK: - Tab 2: Envelopes Content

    private var envelopesContent: some View {
        VStack(spacing: FTSpacing.lg) {
            envelopeOverviewCard

            sectionHeader("My Envelopes", action: "Add", onAction: { showingAddEnvelope = true })

            if envelopes.isEmpty {
                EmptyStateView(
                    icon: "envelope.fill",
                    title: "No Envelopes",
                    message: "Create digital envelopes to allocate and control your spending by category.",
                    actionTitle: "Add Envelope"
                ) { showingAddEnvelope = true }
                .ftGlass(FTRadius.lg)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(envelopes) { envelope in
                        EnvelopeRow(
                            envelope: envelope,
                            spent: spentByCategory[envelope.category] ?? 0,
                            currency: baseCurrency
                        )
                        .contentShape(RoundedRectangle(cornerRadius: FTRadius.md))
                        .onTapGesture { detailEnvelope = envelope }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(envelope)
                                try? context.save()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                detailEnvelope = envelope
                            } label: { Label("Fund", systemImage: "plus.circle") }
                            .tint(FTColor.income)
                        }
                    }
                }
            }

            addRowButton(title: "Add Envelope", icon: "envelope.badge.plus") {
                showingAddEnvelope = true
            }

            envelopeExplainer
        }
    }

    // MARK: - Tab 3: Zero-Based Content

    private var zeroBasedContent: some View {
        VStack(spacing: FTSpacing.lg) {
            zeroBasedHeroCard

            sectionHeader("Allocations", action: "Add Category", onAction: { showingAddBudget = true })

            let income = currentMonthIncome
            let totalAllocated = activeMonthlyBudgets.reduce(0) { $0 + $1.amount }
            let unallocated = income - totalAllocated

            if activeMonthlyBudgets.isEmpty {
                EmptyStateView(
                    icon: "equal.circle.fill",
                    title: "No Allocations",
                    message: "Add budgets for each category until every unit of income is accounted for.",
                    actionTitle: "Add Budget"
                ) { showingAddBudget = true }
                .ftGlass(FTRadius.lg)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(activeMonthlyBudgets, id: \.id) { budget in
                        ZeroBasedAllocationRow(budget: budget, currency: baseCurrency)
                            .swipeActions(edge: .leading) {
                                NavigationLink(destination: AddBudgetView(editingBudget: budget)) {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(FTColor.accent)
                            }
                    }
                }
            }

            // Unallocated / Over-allocated card
            if income > 0 {
                unallocatedCard(income: income, totalAllocated: totalAllocated, unallocated: unallocated)
            } else {
                noIncomeCard
            }

            addRowButton(title: "Add Budget Allocation", icon: "plus.circle.fill") {
                showingAddBudget = true
            }
        }
    }

    // MARK: - Card Components

    private var monthOverviewCard: some View {
        let spent = totalMonthlySpent
        let budgeted = totalMonthlyBudgeted
        let progress = budgeted > 0 ? min(spent / budgeted, 1.0) : 0
        let remaining = budgeted - spent

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SPENT THIS MONTH")
                    .font(.ftLabel).tracking(1.6)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(selectedMonth.shortMonthName.uppercased())
                    .font(.ftLabel).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.6))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(spent.formatted(as: baseCurrency))
                    .font(.ftAmount).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text("/ \(budgeted.formatted(as: baseCurrency))")
                    .font(.ftBodySemibold).foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule()
                        .fill(progress >= 1 ? Color.red.opacity(0.9) : Color.white)
                        .frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 9)
            .animation(.snappy, value: progress)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: remaining >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                    Text(remaining >= 0
                         ? "\(remaining.formatted(as: baseCurrency)) remaining"
                         : "\(abs(remaining).formatted(as: baseCurrency)) over budget")
                }
                .font(.ftCaption).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("\(Int(progress * 100))% used")
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(FTSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
    }

    private var annualOverviewCard: some View {
        let ytd = ytdSpentByCategory
        let totalYTD = ytd.values.reduce(0, +)
        let totalAnnual = budgets.filter { $0.isActive }.reduce(0) { $0 + annualTarget(for: $1) }
        let progress = totalAnnual > 0 ? min(totalYTD / totalAnnual, 1.0) : 0

        // Expected progress: dayOfYear / 365
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let expectedProgress = min(Double(dayOfYear) / 365.0, 1.0)
        let isAhead = progress < expectedProgress

        return VStack(alignment: .leading, spacing: 14) {
            Text("YEAR-TO-DATE SPENDING")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(totalYTD.formatted(as: baseCurrency))
                    .font(.ftAmount).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text("/ \(totalAnnual.formatted(as: baseCurrency))")
                    .font(.ftBodySemibold).foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    // Expected pace marker
                    Rectangle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 2, height: 16)
                        .offset(x: geo.size.width * expectedProgress - 1)
                    // Actual progress
                    Capsule().fill(.white)
                        .frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 9)

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: isAhead ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 11))
                    Text(isAhead ? "Ahead of plan" : "Behind plan")
                }
                .foregroundStyle(.white.opacity(0.9))
                .font(.ftCaption)
                Spacer()
                Text("\(Int(progress * 100))% of annual budget used")
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(FTSpacing.xxl)
        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
    }

    private var monthlySpendingChart: some View {
        let data = last6MonthsSpending
        return VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("MONTHLY SPENDING TREND")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(FTColor.textSecondary)

            Chart(data, id: \.month) { item in
                BarMark(
                    x: .value("Month", item.month, unit: .month),
                    y: .value("Spending", item.total)
                )
                .foregroundStyle(
                    item.month.isSameMonth(as: Date())
                    ? FTColor.accentGradient : AnyShapeStyle(FTColor.accent.opacity(0.5))
                )
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { val in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(FTColor.textMuted)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(FTColor.textMuted.opacity(0.2))
                    AxisValueLabel().foregroundStyle(FTColor.textMuted)
                }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 160)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var envelopeOverviewCard: some View {
        let totalAllocated = envelopes.reduce(0) { $0 + $1.allocatedAmount }
        let totalSpent = envelopes.reduce(0) { $0 + (spentByCategory[$1.category] ?? 0) }
        let remaining = totalAllocated - totalSpent
        let progress = totalAllocated > 0 ? min(totalSpent / totalAllocated, 1.0) : 0

        return VStack(alignment: .leading, spacing: 14) {
            Text("ENVELOPE BALANCES")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(remaining.formatted(as: baseCurrency))
                    .font(.ftAmount).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text("remaining")
                    .font(.ftBodySemibold).foregroundStyle(.white.opacity(0.75))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white)
                        .frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 9)
            .animation(.snappy, value: progress)

            HStack {
                Text("Funded: \(totalAllocated.formatted(as: baseCurrency))")
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("Spent: \(totalSpent.formatted(as: baseCurrency))")
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(FTSpacing.xxl)
        .background(
            LinearGradient(colors: [Color(hex: 0x7C5BD0), Color(hex: 0x4A3A8A)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: FTRadius.xl)
        )
    }

    private var zeroBasedHeroCard: some View {
        let income = currentMonthIncome
        let totalAllocated = activeMonthlyBudgets.reduce(0) { $0 + $1.amount }
        let unallocated = income - totalAllocated
        let allAllocated = abs(unallocated) < 1
        let isOver = unallocated < -1

        return VStack(alignment: .leading, spacing: 14) {
            Text("ZERO-BASED BUDGET")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(unallocated.formatted(as: baseCurrency))
                    .font(.ftAmount).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(isOver ? "over-allocated" : "unallocated")
                    .font(.ftBodySemibold).foregroundStyle(.white.opacity(0.75))
            }

            if income > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule()
                            .fill(isOver ? Color.red.opacity(0.8) : (allAllocated ? Color.green.opacity(0.8) : Color.white))
                            .frame(width: max(8, min(geo.size.width, geo.size.width * (totalAllocated / max(income, 1)))))
                    }
                }
                .frame(height: 9)
                .animation(.snappy, value: totalAllocated)
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: allAllocated ? "checkmark.circle.fill" : (isOver ? "xmark.circle.fill" : "circle.dotted"))
                    Text(allAllocated ? "Fully allocated!" : (isOver ? "Over-allocated" : "Keep allocating"))
                }
                .font(.ftCaption).foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("Income: \(income.formatted(as: baseCurrency))")
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(FTSpacing.xxl)
        .background(
            LinearGradient(colors: [Color(hex: 0x1FA463), Color(hex: 0x0A7845)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: FTRadius.xl)
        )
    }

    private func unallocatedCard(income: Double, totalAllocated: Double, unallocated: Double) -> some View {
        let isOver = unallocated < -1
        let allGood = abs(unallocated) < 1

        return HStack(spacing: FTSpacing.md) {
            FTIconTile(
                symbol: allGood ? "checkmark.circle.fill" : (isOver ? "xmark.circle.fill" : "circle.bottomhalf.filled"),
                tint: allGood ? FTColor.income : (isOver ? FTColor.expense : FTColor.gold),
                size: 42
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(allGood ? "Perfectly balanced!" : (isOver ? "Over-allocated" : "Unallocated funds"))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text(allGood
                     ? "Every unit of income is accounted for."
                     : (isOver
                        ? "Reduce some allocations by \(abs(unallocated).formatted(as: baseCurrency))."
                        : "Allocate \(unallocated.formatted(as: baseCurrency)) to a category or savings goal."))
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var noIncomeCard: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "info.circle.fill", tint: FTColor.catBlue, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("No Income Recorded")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("Add income transactions to see your zero-based allocation balance.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var aiRecommendationsBanner: some View {
        Button { showingRecommendations = true } label: {
            HStack(spacing: FTSpacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FTColor.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Recommendations")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text("\(recommendations.filter { !$0.isDismissed }.count) personalized insights based on your spending")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FTColor.textMuted)
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.md)
        }
        .buttonStyle(.plain)
    }

    private func forecastBanner(forecasts: [BudgetForecast]) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FTColor.gold)
                Text("Spending Forecast")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            ForEach(forecasts, id: \.budgetID) { f in
                HStack {
                    FTIconTile(symbol: f.category.icon,
                               tint: Color.fromString(f.category.color), size: 28)
                    Text(f.budgetName)
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text("Projected: \(f.projectedEndOfMonth.formatted(as: baseCurrency))")
                        .font(.ftCallout).foregroundStyle(FTColor.expense)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: FTRadius.md)
                .strokeBorder(FTColor.gold.opacity(0.4), lineWidth: 1)
        )
    }

    private var envelopeExplainer: some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            Image(systemName: "info.circle")
                .foregroundStyle(FTColor.textMuted)
                .font(.system(size: 14))
                .padding(.top, 1)
            Text("Envelopes are digital spending buckets. Fund each envelope at the start of the month and spending is automatically tracked by category.")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, FTSpacing.xs)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, action: String?, onAction: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Spacer()
            if let action, let onAction {
                Button(action: onAction) {
                    Text(action)
                        .font(.ftCallout).foregroundStyle(FTColor.accent)
                }
            }
        }
    }

    private func addRowButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.ftBodySemibold)
            .foregroundStyle(FTColor.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FTSpacing.md)
        }
        .ftGlassInteractive(FTRadius.md)
    }

    private func checkBudgetAlerts() {
        let spent = spentByCategory
        for budget in activeMonthlyBudgets {
            let budgetSpent = spent[budget.category] ?? 0
            BudgetService.shared.checkAndSendAlerts(budget: budget, spent: budgetSpent, currency: baseCurrency)
        }
        try? context.save()
    }

    private func ensureBuiltInTemplates() {
        guard templates.filter({ $0.isBuiltIn }).isEmpty else { return }
        for t in BudgetService.shared.builtInTemplates() {
            context.insert(t)
        }
        try? context.save()
    }

    private func createBudgetFromRecommendation(category: TransactionCategory, amount: Double) {
        let budget = Budget(
            name: category.rawValue,
            category: category,
            amount: amount,
            currency: baseCurrency,
            period: .monthly,
            alertThreshold: 0.8,
            color: category.color
        )
        context.insert(budget)
        try? context.save()
    }
}

// MARK: - Enhanced Budget Progress Row

struct EnhancedBudgetRow: View {
    let budget: Budget
    let spent: Double
    let currency: String
    let forecast: BudgetForecast

    private var effectiveBudget: Double { budget.amount + budget.rolloverAmount }
    private var progress: Double { effectiveBudget > 0 ? min(spent / effectiveBudget, 1.0) : 0 }
    private var isOverBudget: Bool { spent > effectiveBudget }
    private var isNearLimit: Bool { progress >= budget.alertThreshold && !isOverBudget }

    private var tint: Color {
        isOverBudget ? FTColor.expense : isNearLimit ? FTColor.gold : Color.fromString(budget.category.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: FTSpacing.sm) {
                FTIconTile(symbol: budget.category.icon,
                           tint: Color.fromString(budget.category.color), size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    HStack(spacing: 4) {
                        if budget.isRollover && budget.rolloverAmount > 0 {
                            badge(text: "+\(budget.rolloverAmount.formatted(as: currency))", color: FTColor.income)
                        }
                        if budget.isShared {
                            badge(text: "Shared", color: FTColor.catPurple)
                        }
                    }
                }

                Spacer()

                if isOverBudget {
                    BadgeView(text: "Over Budget", color: FTColor.expense)
                } else if forecast.isProjectedOverBudget {
                    BadgeView(text: "At Risk", color: FTColor.gold)
                } else if isNearLimit {
                    BadgeView(text: "Near Limit", color: FTColor.gold)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text(spent.formatted(as: currency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(isOverBudget ? FTColor.expense : FTColor.textPrimary)
                    Text("of \(effectiveBudget.formatted(as: currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }

            FTProgressBar(value: progress, color: tint)

            HStack {
                Text(isOverBudget
                     ? "\(abs(effectiveBudget - spent).formatted(as: currency)) over"
                     : "\((effectiveBudget - spent).formatted(as: currency)) left")
                    .font(.ftCaption)
                    .foregroundStyle(isOverBudget ? FTColor.expense : FTColor.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.md)
        .ftGlassInteractive(FTRadius.md)
    }

    @ViewBuilder
    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Annual Budget Row

struct AnnualBudgetRow: View {
    let budget: Budget
    let ytdSpent: Double
    let annualTarget: Double
    let currency: String

    private var progress: Double { annualTarget > 0 ? min(ytdSpent / annualTarget, 1.0) : 0 }
    private var dayOfYear: Int { Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1 }
    private var expectedProgress: Double { min(Double(dayOfYear) / 365.0, 1.0) }
    private var isAhead: Bool { progress <= expectedProgress }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: FTSpacing.sm) {
                FTIconTile(symbol: budget.category.icon,
                           tint: Color.fromString(budget.category.color), size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text(budget.period.rawValue).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                Spacer()
                BadgeView(
                    text: isAhead ? "Ahead" : "Behind",
                    color: isAhead ? FTColor.income : FTColor.expense
                )
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ytdSpent.formatted(as: currency))
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text("/ \(annualTarget.formatted(as: currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }

            // Dual bar: expected pace (ghost) + actual
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(FTColor.textPrimary.opacity(0.08))
                    // Expected pace ghost
                    Capsule()
                        .fill(FTColor.textPrimary.opacity(0.12))
                        .frame(width: max(4, geo.size.width * expectedProgress))
                    // Actual progress
                    Capsule()
                        .fill(isAhead ? FTColor.income : FTColor.expense)
                        .frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 9)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - Envelope Row

struct EnvelopeRow: View {
    let envelope: BudgetEnvelope
    let spent: Double
    let currency: String

    private var remaining: Double { envelope.allocatedAmount - spent }
    private var progress: Double {
        envelope.allocatedAmount > 0 ? min(spent / envelope.allocatedAmount, 1.0) : 0
    }
    private var isOver: Bool { spent > envelope.allocatedAmount }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: FTSpacing.sm) {
                FTIconTile(symbol: envelope.icon, tint: envelope.color, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(envelope.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text(envelope.category.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                if isOver { BadgeView(text: "Empty", color: FTColor.expense) }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(spent.formatted(as: currency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(isOver ? FTColor.expense : FTColor.textPrimary)
                    Text("of \(envelope.allocatedAmount.formatted(as: currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
            FTProgressBar(value: progress, color: isOver ? FTColor.expense : envelope.color)
            HStack {
                Text(isOver ? "Depleted" : "\(remaining.formatted(as: currency)) remaining")
                    .font(.ftCaption)
                    .foregroundStyle(isOver ? FTColor.expense : FTColor.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))% spent")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.md)
        .ftGlassInteractive(FTRadius.md)
    }
}

// MARK: - Zero-Based Allocation Row

struct ZeroBasedAllocationRow: View {
    let budget: Budget
    let currency: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: budget.category.icon,
                       tint: Color.fromString(budget.category.color), size: 36)
            Text(budget.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
            Spacer()
            Text(budget.amount.formatted(as: currency))
                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.sm)
    }
}

// MARK: - Savings Goal Row

struct SavingsGoalRow: View {
    @Bindable var goal: SavingsGoal
    let currency: String
    @Environment(\.modelContext) private var context
    @State private var showingAddFunds = false
    @State private var addAmount = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: FTSpacing.sm) {
                FTIconTile(symbol: goal.icon, tint: Color.fromString(goal.color), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if let targetDate = goal.targetDate {
                        Text("Target: \(targetDate.formatted)")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                if goal.isCompleted {
                    BadgeView(text: "Complete", color: FTColor.income)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(goal.currentAmount.formatted(as: currency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(Color.fromString(goal.color))
                    Text("of \(goal.targetAmount.formatted(as: currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
            FTProgressBar(value: goal.progress, color: Color.fromString(goal.color))
            HStack {
                Text("\(Int(goal.progress * 100))% complete")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Button("Add Funds") { showingAddFunds = true }
                    .font(.ftCallout).foregroundStyle(FTColor.accent)
            }
        }
        .padding(FTSpacing.md)
        .alert("Add Funds", isPresented: $showingAddFunds) {
            TextField("Amount", text: $addAmount).keyboardType(.decimalPad)
            Button("Add") {
                if let a = Double(addAmount), a > 0 {
                    goal.currentAmount += a
                    if goal.currentAmount >= goal.targetAmount { goal.isCompleted = true }
                    try? context.save()
                }
                addAmount = ""
            }
            Button("Cancel", role: .cancel) { addAmount = "" }
        } message: {
            Text("How much are you adding to \(goal.name)?")
        }
    }
}

// MARK: - Budget Detail View

struct BudgetDetailView: View {
    @Bindable var budget: Budget
    let transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private var currency: String { appState.baseCurrency }

    private var relatedTransactions: [Transaction] {
        transactions
            .filter { tx in
                tx.date.isSameMonth(as: Date())
                && tx.spendingPairs.contains { $0.0 == budget.category }
            }
            .sorted { $0.date > $1.date }
    }

    private var monthlyHistory: [(month: Date, spent: Double)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<6).compactMap { offset -> (Date, Double)? in
            guard let monthStart = cal.date(byAdding: .month, value: -offset, to: now.startOfMonth) else { return nil }
            let total = transactions
                .filter { $0.date.isSameMonth(as: monthStart) }
                .flatMap { $0.spendingPairs }
                .filter { $0.0 == budget.category }
                .reduce(0) { $0 + $1.1 }
            return (monthStart, total)
        }.reversed()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Header card
                        let currentSpent = monthlyHistory.last?.spent ?? 0
                        let effective = budget.amount + budget.rolloverAmount
                        let progress = effective > 0 ? min(currentSpent / effective, 1.0) : 0
                        let tint = currentSpent > effective ? FTColor.expense : Color.fromString(budget.category.color)

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                FTIconTile(symbol: budget.category.icon,
                                           tint: Color.fromString(budget.category.color), size: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(budget.name).font(.ftTitle).foregroundStyle(.white)
                                    Text(budget.period.rawValue).font(.ftCaption).foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(currentSpent.formatted(as: currency))
                                    .font(.ftAmount).foregroundStyle(.white)
                                Text("/ \(effective.formatted(as: currency))")
                                    .font(.ftBodySemibold).foregroundStyle(.white.opacity(0.75))
                            }
                            FTProgressBar(value: progress, color: .white.opacity(0.9))
                                .frame(height: 9)
                            HStack {
                                if budget.isRollover && budget.rolloverAmount > 0 {
                                    Text("Rollover: +\(budget.rolloverAmount.formatted(as: currency))")
                                        .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                                }
                                Spacer()
                                Text("\((effective - currentSpent).formatted(as: currency)) remaining")
                                    .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(FTSpacing.xxl)
                        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
                        .padding(.horizontal, FTSpacing.screen)

                        // Options
                        VStack(spacing: 0) {
                            FTToggleRow(symbol: "arrow.2.circlepath", tint: FTColor.income,
                                        title: "Rollover Unused Amount", isOn: $budget.isRollover)
                            Divider().opacity(0.4).padding(.leading, 56)
                            FTToggleRow(symbol: "person.2.fill", tint: FTColor.catPurple,
                                        title: "Shared Budget", isOn: $budget.isShared)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)

                        // 6-month history chart
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("6-MONTH HISTORY")
                                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                            Chart(monthlyHistory, id: \.month) { item in
                                BarMark(x: .value("Month", item.month, unit: .month),
                                        y: .value("Spent", item.spent))
                                .foregroundStyle(
                                    item.month.isSameMonth(as: Date())
                                    ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.4))
                                )
                                .cornerRadius(4)

                                RuleMark(y: .value("Budget", budget.amount))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .month)) { val in
                                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                                        .foregroundStyle(FTColor.textMuted)
                                }
                            }
                            .chartYAxis {
                                AxisMarks { _ in
                                    AxisGridLine().foregroundStyle(FTColor.textMuted.opacity(0.2))
                                    AxisValueLabel().foregroundStyle(FTColor.textMuted)
                                }
                            }
                            .chartPlotStyle { $0.background(Color.clear) }
                            .frame(height: 160)
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)

                        // This month's transactions
                        if !relatedTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("THIS MONTH'S TRANSACTIONS")
                                    .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                                    .padding(.horizontal, FTSpacing.xs)
                                ForEach(relatedTransactions.prefix(10)) { tx in
                                    HStack(spacing: FTSpacing.md) {
                                        FTIconTile(symbol: tx.category.icon,
                                                   tint: Color.fromString(tx.category.color), size: 34)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tx.title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                            Text(tx.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                        }
                                        Spacer()
                                        Text(tx.amountInBaseCurrency.formatted(as: currency))
                                            .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                                    }
                                    .padding(.vertical, 8).padding(.horizontal, FTSpacing.sm)
                                }
                            }
                            .padding(FTSpacing.lg)
                            .ftGlass(FTRadius.md)
                            .padding(.horizontal, FTSpacing.screen)
                        }

                        Color.clear.frame(height: 40)
                    }
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Budget Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AddBudgetView(editingBudget: budget)) {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
    }
}

// MARK: - Add / Edit Budget (enhanced)

struct AddBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    var editingBudget: Budget? = nil

    @State private var name = ""
    @State private var category: TransactionCategory = .food
    @State private var amount = ""
    @State private var period: BudgetPeriod = .monthly
    @State private var alertThreshold = 0.8
    @State private var hasExpiration = false
    @State private var expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isRollover = false
    @State private var isShared = false
    @State private var sharedMembersText = ""

    private var isEditing: Bool { editingBudget != nil }

    private let expenseCategories: [TransactionCategory] = [
        .food, .shopping, .transportation, .fuel, .utilities, .rent, .mortgage,
        .education, .medical, .entertainment, .travel, .insurance, .subscriptions,
        .gifts, .personalCare, .charity, .childcare, .pets, .bankFees, .other
    ]

    var body: some View {
        let content = ZStack(alignment: .bottom) {
            FTBackdrop()

            ScrollView {
                VStack(spacing: FTSpacing.lg) {
                    // Details card
                    VStack(spacing: 0) {
                        formRow {
                            Text("Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            TextField("e.g. Groceries", text: $name)
                                .multilineTextAlignment(.trailing)
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        }
                        Divider().opacity(0.4)
                        formRow {
                            Text("Category").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Menu {
                                Picker("Category", selection: $category) {
                                    ForEach(expenseCategories, id: \.self) { cat in
                                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                                    }
                                }
                            } label: {
                                Label(category.rawValue, systemImage: category.icon)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                            }
                        }
                        Divider().opacity(0.4)
                        formRow {
                            Text("Period").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Menu {
                                Picker("Period", selection: $period) {
                                    ForEach(BudgetPeriod.allCases, id: \.self) { p in
                                        Text(p.rawValue).tag(p)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(period.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    // Amount
                    VStack(spacing: 0) {
                        formRow {
                            Text("Amount Limit").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                .frame(maxWidth: 120)
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    // Alert threshold
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("Alert at \(Int(alertThreshold * 100))% of budget")
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Text("Also sends automatic alerts at 75%, 90%, and 100%.")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        Slider(value: $alertThreshold, in: 0.5...0.95, step: 0.05)
                            .tint(FTColor.gold)
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    // Rollover + Shared
                    VStack(spacing: 0) {
                        FTToggleRow(symbol: "arrow.2.circlepath", tint: FTColor.income,
                                    title: "Rollover Unused Amount",
                                    isOn: $isRollover)
                        .padding(.horizontal, 0)

                        if isRollover {
                            Divider().opacity(0.4)
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption).foregroundStyle(FTColor.textMuted)
                                Text("Unused budget from previous periods carries forward automatically.")
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 10).padding(.horizontal, 4)
                        }

                        Divider().opacity(0.4)

                        FTToggleRow(symbol: "person.2.fill", tint: FTColor.catPurple,
                                    title: "Shared Budget",
                                    isOn: $isShared)
                        .padding(.horizontal, 0)

                        if isShared {
                            Divider().opacity(0.4)
                            formRow {
                                Text("Members").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Names, comma-separated", text: $sharedMembersText)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    // Expiration
                    VStack(spacing: 0) {
                        Toggle(isOn: $hasExpiration) {
                            Text("Set Expiration Date").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        }
                        .tint(FTColor.accent)
                        .padding(.vertical, 13)

                        if hasExpiration {
                            Divider().opacity(0.4)
                            DatePicker("Expires On", selection: $expirationDate, in: Date()..., displayedComponents: .date)
                                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                .tint(FTColor.accent)
                                .padding(.vertical, 9)
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    Color.clear.frame(height: 70)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.sm)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)

            Button { save() } label: {
                Text(isEditing ? "Update Budget" : "Add Budget")
            }
            .buttonStyle(.ftPrimary)
            .disabled(name.isEmpty || amount.isEmpty)
            .opacity(name.isEmpty || amount.isEmpty ? 0.55 : 1)
            .padding(.horizontal, FTSpacing.screen)
            .padding(.bottom, FTSpacing.sm)
        }
        .navigationTitle(isEditing ? "Edit Budget" : "Add Budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
        }
        .onAppear(perform: loadEditing)
        .dismissKeyboardOnTap()

        if isEditing {
            return AnyView(content)
        } else {
            return AnyView(NavigationStack { content })
        }
    }

    @ViewBuilder
    private func formRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: FTSpacing.md) { content() }
            .padding(.vertical, 13)
    }

    private func loadEditing() {
        guard let b = editingBudget else { return }
        name = b.name
        category = b.category
        amount = String(b.amount)
        period = b.period
        alertThreshold = b.alertThreshold
        isRollover = b.isRollover
        isShared = b.isShared
        sharedMembersText = b.sharedMembers.joined(separator: ", ")
        if let end = b.endDate { hasExpiration = true; expirationDate = end }
    }

    private func save() {
        let members = sharedMembersText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let b = editingBudget {
            b.name = name
            b.category = category
            b.amount = Double(amount) ?? 0
            b.period = period
            b.alertThreshold = alertThreshold
            b.isRollover = isRollover
            b.isShared = isShared
            b.sharedMembers = members
            b.endDate = hasExpiration ? expirationDate : nil
            b.color = category.color
        } else {
            let budget = Budget(
                name: name,
                category: category,
                amount: Double(amount) ?? 0,
                currency: appState.baseCurrency,
                period: period,
                endDate: hasExpiration ? expirationDate : nil,
                alertThreshold: alertThreshold,
                color: category.color,
                isRollover: isRollover,
                isShared: isShared,
                sharedMembers: members
            )
            context.insert(budget)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Add Savings Goal View

struct AddSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var name = ""
    @State private var targetAmount = ""
    @State private var currentAmount = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedIcon = "star"
    @State private var selectedColor = "blue"

    private let icons = ["star", "house", "car", "airplane", "graduationcap", "heart",
                         "gift", "gamecontroller", "laptop", "bag", "💍", "umbrella"]
        .filter { !$0.hasPrefix("💍") } // strip emoji - only SF symbols
    private let sfIcons = ["star", "house", "car.fill", "airplane", "graduationcap", "heart.fill",
                           "gift.fill", "gamecontroller.fill", "laptopcomputer", "bag.fill",
                           "creditcard.fill", "umbrella.fill"]
    private let colors = ["blue", "green", "purple", "orange", "red", "teal", "indigo", "pink"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            rowField("Goal Name") {
                                TextField("e.g. New Car", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            Divider().opacity(0.4)
                            rowField("Target Amount") {
                                Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                TextField("0.00", text: $targetAmount).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 120)
                            }
                            Divider().opacity(0.4)
                            rowField("Current Savings") {
                                Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                TextField("0.00", text: $currentAmount).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 120)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg).ftGlass(FTRadius.md)

                        VStack(spacing: 0) {
                            Toggle(isOn: $hasTargetDate) {
                                Text("Set Target Date").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }.tint(FTColor.accent).padding(.vertical, 13)
                            if hasTargetDate {
                                Divider().opacity(0.4)
                                DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    .tint(FTColor.accent).padding(.vertical, 9)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg).ftGlass(FTRadius.md)

                        // Icon picker
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("ICON").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(sfIcons, id: \.self) { icon in
                                        Button { selectedIcon = icon } label: {
                                            Image(systemName: icon)
                                                .font(.title2)
                                                .foregroundStyle(selectedIcon == icon ? FTColor.accent : FTColor.textSecondary)
                                                .frame(width: 44, height: 44)
                                                .background(selectedIcon == icon ? FTColor.accent.opacity(0.15) : Color.clear)
                                                .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                                                .overlay(RoundedRectangle(cornerRadius: FTRadius.sm)
                                                    .strokeBorder(selectedIcon == icon ? FTColor.accent : Color.clear, lineWidth: 1.5))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(FTSpacing.lg).frame(maxWidth: .infinity, alignment: .leading).ftGlass(FTRadius.md)

                        // Color picker
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("COLOR").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                            HStack(spacing: 12) {
                                ForEach(colors, id: \.self) { color in
                                    Circle()
                                        .fill(Color.fromString(color))
                                        .frame(width: 36, height: 36)
                                        .overlay(Image(systemName: "checkmark").font(.caption).fontWeight(.bold)
                                            .foregroundColor(.white).opacity(selectedColor == color ? 1 : 0))
                                        .overlay(Circle().strokeBorder(.white.opacity(selectedColor == color ? 0.6 : 0), lineWidth: 2))
                                        .onTapGesture { selectedColor = color }
                                }
                            }
                        }
                        .padding(FTSpacing.lg).frame(maxWidth: .infinity, alignment: .leading).ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen).padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively)

                Button { saveGoal() } label: { Text("Add Goal") }
                    .buttonStyle(.ftPrimary)
                    .disabled(name.isEmpty || targetAmount.isEmpty)
                    .opacity(name.isEmpty || targetAmount.isEmpty ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen).padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Add Savings Goal").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .dismissKeyboardOnTap()
        }
    }

    @ViewBuilder
    private func rowField<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            content()
        }.padding(.vertical, 13)
    }

    private func saveGoal() {
        let goal = SavingsGoal(
            name: name,
            targetAmount: Double(targetAmount) ?? 0,
            currentAmount: Double(currentAmount) ?? 0,
            currency: appState.baseCurrency,
            targetDate: hasTargetDate ? targetDate : nil,
            icon: selectedIcon,
            color: selectedColor
        )
        context.insert(goal)
        try? context.save()
        dismiss()
    }
}

// MARK: - Add Envelope View

struct AddEnvelopeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \BudgetEnvelope.sortOrder) private var existingEnvelopes: [BudgetEnvelope]

    @State private var name = ""
    @State private var category: TransactionCategory = .food
    @State private var amount = ""
    @State private var selectedColorHex = "#0E9C8A"
    @State private var selectedIcon = "envelope.fill"

    private let categories: [TransactionCategory] = [
        .food, .shopping, .transportation, .fuel, .utilities, .entertainment,
        .travel, .education, .medical, .personalCare, .gifts, .other
    ]

    private let paletteColors: [(name: String, hex: String)] = [
        ("Teal", "#0E9C8A"), ("Blue", "#2E78C8"), ("Purple", "#7C5BD0"),
        ("Coral", "#E5736B"), ("Gold", "#C8902B"), ("Green", "#1FA463"),
        ("Indigo", "#3F51B5"), ("Pink", "#E91E8C")
    ]

    private let iconOptions = [
        "envelope.fill", "cart.fill", "fork.knife", "car.fill",
        "bolt.fill", "airplane", "heart.fill", "book.fill",
        "cross.fill", "gamecontroller.fill", "gift.fill", "house.fill"
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Food & Dining", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }.padding(.vertical, 13)
                            Divider().opacity(0.4)
                            HStack(spacing: FTSpacing.md) {
                                Text("Category").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Menu {
                                    Picker("Category", selection: $category) {
                                        ForEach(categories, id: \.self) { cat in
                                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Label(category.rawValue, systemImage: category.icon)
                                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                    }
                                }
                            }.padding(.vertical, 13)
                            Divider().opacity(0.4)
                            HStack(spacing: FTSpacing.md) {
                                Text("Funded Amount").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                TextField("0.00", text: $amount).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 120)
                            }.padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg).ftGlass(FTRadius.md)

                        // Icon
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("ICON").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                                ForEach(iconOptions, id: \.self) { icon in
                                    Button { selectedIcon = icon } label: {
                                        Image(systemName: icon).font(.title3)
                                            .foregroundStyle(selectedIcon == icon ? Color(hex: selectedColorHex) : FTColor.textSecondary)
                                            .frame(width: 44, height: 44)
                                            .background(selectedIcon == icon ? Color(hex: selectedColorHex).opacity(0.15) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                                            .overlay(RoundedRectangle(cornerRadius: FTRadius.sm)
                                                .strokeBorder(selectedIcon == icon ? Color(hex: selectedColorHex) : Color.clear, lineWidth: 1.5))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(FTSpacing.lg).ftGlass(FTRadius.md)

                        // Color
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("COLOR").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                            HStack(spacing: 10) {
                                ForEach(paletteColors, id: \.hex) { item in
                                    Circle()
                                        .fill(Color(hex: item.hex))
                                        .frame(width: 36, height: 36)
                                        .overlay(Image(systemName: "checkmark").font(.caption).fontWeight(.bold)
                                            .foregroundColor(.white).opacity(selectedColorHex == item.hex ? 1 : 0))
                                        .onTapGesture { selectedColorHex = item.hex }
                                }
                            }
                        }
                        .padding(FTSpacing.lg).ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen).padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively)

                Button { saveEnvelope() } label: { Text("Create Envelope") }
                    .buttonStyle(.ftPrimary)
                    .disabled(name.isEmpty || amount.isEmpty)
                    .opacity(name.isEmpty || amount.isEmpty ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen).padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("New Envelope").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .dismissKeyboardOnTap()
        }
    }

    private func saveEnvelope() {
        let envelope = BudgetEnvelope(
            name: name,
            icon: selectedIcon,
            colorHex: selectedColorHex,
            allocatedAmount: Double(amount) ?? 0,
            category: category,
            currency: appState.baseCurrency,
            sortOrder: existingEnvelopes.count
        )
        context.insert(envelope)
        try? context.save()
        dismiss()
    }
}

// MARK: - Envelope Detail View

struct EnvelopeDetailView: View {
    @Bindable var envelope: BudgetEnvelope
    let transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \BudgetEnvelope.sortOrder) private var allEnvelopes: [BudgetEnvelope]

    @State private var showingFund = false
    @State private var showingTransfer = false
    @State private var fundAmount = ""
    @State private var transferTarget: BudgetEnvelope? = nil
    @State private var transferAmount = ""

    private var currency: String { appState.baseCurrency }

    private var relatedTransactions: [Transaction] {
        transactions
            .filter { $0.date.isSameMonth(as: Date()) && $0.spendingPairs.contains { $0.0 == envelope.category } }
            .sorted { $0.date > $1.date }
    }

    private var spent: Double {
        relatedTransactions.flatMap { $0.spendingPairs }.filter { $0.0 == envelope.category }.reduce(0) { $0 + $1.1 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Hero
                        let remaining = envelope.allocatedAmount - spent
                        let progress = envelope.allocatedAmount > 0 ? min(spent / envelope.allocatedAmount, 1.0) : 0

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                FTIconTile(symbol: envelope.icon, tint: envelope.color, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(envelope.name).font(.ftTitle).foregroundStyle(.white)
                                    Text(envelope.category.rawValue).font(.ftCaption).foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(remaining.formatted(as: currency))
                                    .font(.ftAmount).foregroundStyle(.white)
                                Text("remaining")
                                    .font(.ftBodySemibold).foregroundStyle(.white.opacity(0.75))
                            }
                            FTProgressBar(value: progress, color: .white.opacity(0.9))
                            HStack {
                                Text("Funded: \(envelope.allocatedAmount.formatted(as: currency))")
                                    .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                                Spacer()
                                Text("Spent: \(spent.formatted(as: currency))")
                                    .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(FTSpacing.xxl)
                        .background(
                            LinearGradient(colors: [envelope.color, envelope.color.opacity(0.7)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: .rect(cornerRadius: FTRadius.xl)
                        )
                        .padding(.horizontal, FTSpacing.screen)

                        // Actions
                        HStack(spacing: FTSpacing.md) {
                            actionButton(icon: "plus.circle.fill", title: "Fund", color: FTColor.income) {
                                showingFund = true
                            }
                            if allEnvelopes.count > 1 {
                                actionButton(icon: "arrow.left.arrow.right.circle.fill", title: "Transfer", color: FTColor.accent) {
                                    showingTransfer = true
                                }
                            }
                        }
                        .padding(.horizontal, FTSpacing.screen)

                        // Transactions
                        if !relatedTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("THIS MONTH")
                                    .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                                    .padding(.horizontal, FTSpacing.xs)
                                ForEach(relatedTransactions.prefix(15)) { tx in
                                    HStack(spacing: FTSpacing.md) {
                                        FTIconTile(symbol: tx.category.icon,
                                                   tint: Color.fromString(tx.category.color), size: 34)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tx.title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                            Text(tx.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                        }
                                        Spacer()
                                        Text(tx.amountInBaseCurrency.formatted(as: currency))
                                            .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                                    }
                                    .padding(.vertical, 8).padding(.horizontal, FTSpacing.sm)
                                }
                            }
                            .padding(FTSpacing.lg).ftGlass(FTRadius.md)
                            .padding(.horizontal, FTSpacing.screen)
                        } else {
                            EmptyStateView(
                                icon: "tray",
                                title: "No Spending Yet",
                                message: "Transactions in the \(envelope.category.rawValue) category will appear here."
                            )
                            .ftGlass(FTRadius.lg)
                            .padding(.horizontal, FTSpacing.screen)
                        }

                        Color.clear.frame(height: 40)
                    }
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Envelope").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
            }
            .alert("Add Funds", isPresented: $showingFund) {
                TextField("Amount", text: $fundAmount).keyboardType(.decimalPad)
                Button("Add") {
                    if let a = Double(fundAmount), a > 0 {
                        envelope.allocatedAmount += a
                        try? context.save()
                    }
                    fundAmount = ""
                }
                Button("Cancel", role: .cancel) { fundAmount = "" }
            } message: {
                Text("How much are you adding to \(envelope.name)?")
            }
            .sheet(isPresented: $showingTransfer) {
                transferSheet
            }
        }
    }

    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.ftBodySemibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: .rect(cornerRadius: FTRadius.md))
        }
        .buttonStyle(.plain)
    }

    private var transferSheet: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                VStack(spacing: FTSpacing.lg) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Transfer To").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Menu {
                                ForEach(allEnvelopes.filter { $0.id != envelope.id }, id: \.id) { env in
                                    Button(env.name) { transferTarget = env }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(transferTarget?.name ?? "Select Envelope")
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11)).foregroundStyle(FTColor.textMuted)
                                }
                            }
                        }.padding(.vertical, 13)
                        Divider().opacity(0.4)
                        HStack {
                            Text("Amount").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            TextField("0.00", text: $transferAmount).keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                .frame(maxWidth: 120)
                        }.padding(.vertical, 13)
                    }
                    .padding(.horizontal, FTSpacing.lg).ftGlass(FTRadius.md)

                    Spacer()

                    Button {
                        if let target = transferTarget, let a = Double(transferAmount), a > 0 {
                            envelope.allocatedAmount -= a
                            target.allocatedAmount += a
                            try? context.save()
                        }
                        transferAmount = ""
                        showingTransfer = false
                    } label: { Text("Transfer Funds") }
                        .buttonStyle(.ftPrimary)
                        .disabled(transferTarget == nil || transferAmount.isEmpty)
                        .opacity(transferTarget == nil || transferAmount.isEmpty ? 0.55 : 1)
                        .padding(.horizontal, FTSpacing.screen)
                        .padding(.bottom, FTSpacing.sm)
                }
                .padding(.horizontal, FTSpacing.screen).padding(.top, FTSpacing.xxl)
            }
            .navigationTitle("Transfer Funds").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingTransfer = false }
                }
            }
            .dismissKeyboardOnTap()
        }
    }
}

// MARK: - Budget Templates View (Feature 10)

struct BudgetTemplatesView: View {
    let existingBudgets: [Budget]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var storedTemplates: [BudgetTemplate]

    @State private var selectedTemplate: BudgetTemplate? = nil
    @State private var showingApply = false

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        Text("Start with a pre-built seasonal template optimized for UAE spending patterns, or save your own.")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            .padding(.horizontal, FTSpacing.xs)

                        let builtIn = storedTemplates.filter { $0.isBuiltIn }
                        let custom = storedTemplates.filter { !$0.isBuiltIn }

                        if !builtIn.isEmpty {
                            sectionHeader("Seasonal Templates")
                            ForEach(builtIn) { template in
                                templateCard(template)
                            }
                        }

                        if !custom.isEmpty {
                            sectionHeader("My Templates")
                                .padding(.top, FTSpacing.sm)
                            ForEach(custom) { template in
                                templateCard(template)
                            }
                        }

                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Seasonal Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
            }
            .sheet(item: $selectedTemplate) { template in
                ApplyTemplateView(template: template, existingBudgets: existingBudgets)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func templateCard(_ template: BudgetTemplate) -> some View {
        Button { selectedTemplate = template } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: template.icon, tint: template.color, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text(template.templateDescription)
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet").font(.system(size: 11))
                        Text("\(template.items.count) categories")
                    }
                    .font(.ftCaption).foregroundStyle(FTColor.accent)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(FTColor.textMuted)
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Apply Template View

struct ApplyTemplateView: View {
    let template: BudgetTemplate
    let existingBudgets: [Budget]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var amounts: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Header
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: template.icon, tint: template.color, size: 50)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                                Text(template.templateDescription)
                                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Review and adjust the suggested amounts, then tap Apply to create these budgets.")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)

                        VStack(spacing: 0) {
                            ForEach(template.items) { item in
                                HStack(spacing: FTSpacing.md) {
                                    FTIconTile(symbol: item.category.icon,
                                               tint: Color.fromString(item.category.color), size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.category.rawValue)
                                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        if let notes = item.notes {
                                            Text(notes).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                    TextField(
                                        String(format: "%.0f", item.suggestedAmount),
                                        text: binding(for: item)
                                    )
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 100)
                                }
                                .padding(.vertical, 13)
                                if item.id != template.items.last?.id {
                                    Divider().opacity(0.4)
                                }
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen).padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively)

                Button { applyTemplate() } label: {
                    Label("Apply Template", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.ftPrimary)
                .padding(.horizontal, FTSpacing.screen).padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Apply Template").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .dismissKeyboardOnTap()
            .onAppear {
                // Pre-fill amounts from template suggestions
                for item in template.items {
                    amounts[item.id] = String(format: "%.0f", item.suggestedAmount)
                }
            }
        }
    }

    private func binding(for item: TemplateItem) -> Binding<String> {
        Binding(
            get: { amounts[item.id] ?? String(format: "%.0f", item.suggestedAmount) },
            set: { amounts[item.id] = $0 }
        )
    }

    private func applyTemplate() {
        let budgetedCats = Set(existingBudgets.filter { $0.isActive }.map { $0.category })
        for item in template.items {
            guard !budgetedCats.contains(item.category) else { continue }
            let amount = Double(amounts[item.id] ?? "") ?? item.suggestedAmount
            guard amount > 0 else { continue }
            let budget = Budget(
                name: item.category.rawValue,
                category: item.category,
                amount: amount,
                currency: appState.baseCurrency,
                period: .monthly,
                alertThreshold: 0.8,
                color: item.category.color
            )
            context.insert(budget)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Budget Recommendations View (Feature 9)

struct BudgetRecommendationsView: View {
    @Binding var recommendations: [BudgetRecommendation]
    let budgets: [Budget]
    let onCreateBudget: (TransactionCategory, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    var activeRecs: [BudgetRecommendation] { recommendations.filter { !$0.isDismissed } }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                if activeRecs.isEmpty {
                    EmptyStateView(
                        icon: "sparkles",
                        title: "All Caught Up",
                        message: "No new recommendations. Keep tracking your spending and we'll surface insights as patterns emerge."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: FTSpacing.md) {
                            Text("Based on your spending over the last 3 months, here are personalized budget recommendations.")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                .padding(.horizontal, FTSpacing.xs)

                            ForEach(activeRecs) { rec in
                                recommendationCard(rec)
                            }

                            Color.clear.frame(height: 40)
                        }
                        .padding(.horizontal, FTSpacing.screen)
                        .padding(.top, FTSpacing.sm)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("AI Recommendations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
            }
        }
    }

    private func recommendationCard(_ rec: BudgetRecommendation) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                Image(systemName: rec.type.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.fromString(rec.type.colorName))
                    .frame(width: 44, height: 44)
                    .background(Color.fromString(rec.type.colorName).opacity(0.12),
                                in: .rect(cornerRadius: FTRadius.sm))

                VStack(alignment: .leading, spacing: 3) {
                    Text(rec.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if let cat = rec.category {
                        BadgeView(text: cat.rawValue, color: Color.fromString(cat.color))
                    }
                }
                Spacer()
                Button {
                    withAnimation {
                        if let idx = recommendations.firstIndex(where: { $0.id == rec.id }) {
                            recommendations[idx].isDismissed = true
                        }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(FTColor.textMuted)
                }
            }

            Text(rec.description)
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if rec.type == .createBudget || rec.type == .increaseBudget || rec.type == .decreaseBudget,
               let amount = rec.suggestedAmount, let cat = rec.category {
                HStack(spacing: FTSpacing.sm) {
                    Text("Suggested: \(amount.formatted(as: budgets.first?.currency ?? "AED"))")
                        .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Button {
                        onCreateBudget(cat, amount)
                        withAnimation {
                            if let idx = recommendations.firstIndex(where: { $0.id == rec.id }) {
                                recommendations[idx].isDismissed = true
                            }
                        }
                        dismiss()
                    } label: {
                        Text(rec.type == .createBudget ? "Create Budget" : "Apply")
                            .font(.ftCallout)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(FTColor.accent, in: .capsule)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}
