import SwiftUI
import SwiftData
import Charts

// MARK: - IncomeManagementView

struct IncomeManagementView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<SalaryRecord> { $0.isActive }) private var salaryRecords: [SalaryRecord]
    @Query(filter: #Predicate<FreelanceProject> { !$0.isArchived }) private var projects: [FreelanceProject]
    @Query(filter: #Predicate<RentalProperty> { $0.isActive }) private var properties: [RentalProperty]
    @Query private var dividends: [Dividend]
    @Query private var transactions: [Transaction]

    @State private var selectedTab = 0
    @State private var stabilityScore: IncomeStabilityScore? = nil
    @State private var streamSummaries: [IncomeStreamSummary] = []
    @State private var passiveMetrics: PassiveIncomeMetrics? = nil
    @State private var showingAddSalary = false
    @State private var showingAddProject = false
    @State private var showingAddProperty = false
    @State private var showingAddDividend = false
    @State private var selectedSalaryRecord: SalaryRecord? = nil

    private var baseCurrency: String { appState.baseCurrency }
    private let tabs = ["Overview", "Salary", "Freelance", "Rental", "Dividends", "Passive", "Stability"]

    // MARK: - Derived Metrics

    private var incomeTransactions: [Transaction] {
        transactions.filter { $0.type == .income && !$0.isPending && !$0.isScheduled }
    }

    private var lastMonthIncome: Double {
        let now = Date()
        let startOfMonth = now.startOfMonth
        return incomeTransactions
            .filter { $0.date >= startOfMonth && $0.date < now }
            .reduce(0) { $0 + currencyService.convert($1.amountInBaseCurrency, from: $1.currency, to: baseCurrency) }
    }

    private var previousMonthIncome: Double {
        let now = Date()
        guard let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: now.startOfMonth) else { return 0 }
        let endOfPrev = now.startOfMonth
        return incomeTransactions
            .filter { $0.date >= prevMonth && $0.date < endOfPrev }
            .reduce(0) { $0 + currencyService.convert($1.amountInBaseCurrency, from: $1.currency, to: baseCurrency) }
    }

    private var monthOverMonthChange: Double {
        guard previousMonthIncome > 0 else { return 0 }
        return ((lastMonthIncome - previousMonthIncome) / previousMonthIncome) * 100
    }

    private var recentIncomeTransactions: [Transaction] {
        incomeTransactions
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
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
                        Group {
                            switch selectedTab {
                            case 0: overviewTab
                            case 1: SalaryTrackerView()
                            case 2: FreelanceView()
                            case 3: RentalView()
                            case 4: dividendsTab
                            case 5: passiveTab
                            case 6: stabilityTab
                            default: overviewTab
                            }
                        }
                        .padding(.bottom, FTSpacing.xxl + FTSpacing.lg)
                    }
                }
            }
            .navigationTitle("Income")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .sheet(isPresented: $showingAddSalary) {
                AddSalaryRecordView()
            }
            .sheet(isPresented: $showingAddProject) {
                AddFreelanceProjectView()
            }
            .sheet(isPresented: $showingAddProperty) {
                AddRentalPropertyView()
            }
            .sheet(isPresented: $showingAddDividend) {
                AddDividendView()
            }
            .sheet(item: $selectedSalaryRecord) { record in
                SalaryDetailSheet(record: record)
            }
        }
        .onAppear {
            recomputeAll()
        }
        .task(id: selectedTab) {
            if selectedTab == 5 && passiveMetrics == nil {
                passiveMetrics = IncomeService.shared.computePassiveIncomeMetrics(
                    transactions: transactions,
                    dividends: dividends,
                    rentalProperties: properties,
                    baseCurrency: baseCurrency
                )
            }
            if selectedTab == 6 && stabilityScore == nil {
                stabilityScore = IncomeService.shared.computeStabilityScore(
                    transactions: transactions,
                    salaryRecords: salaryRecords,
                    freelanceProjects: projects,
                    rentalProperties: properties,
                    dividends: dividends,
                    baseCurrency: baseCurrency
                )
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedTab = i
                        }
                    } label: {
                        Text(tabs[i])
                            .font(.ftCallout)
                            .foregroundStyle(selectedTab == i ? .white : FTColor.textPrimary)
                            .padding(.horizontal, FTSpacing.md)
                            .padding(.vertical, FTSpacing.sm + 2)
                            .background {
                                if selectedTab == i {
                                    Capsule().fill(FTColor.accentGradient)
                                } else {
                                    Capsule().fill(.regularMaterial)
                                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.sm)
        }
    }

    // MARK: - Context-sensitive Add Button

    @ViewBuilder
    private var addButton: some View {
        if selectedTab <= 4 {
            Button {
                switch selectedTab {
                case 1: showingAddSalary = true
                case 2: showingAddProject = true
                case 3: showingAddProperty = true
                case 4: showingAddDividend = true
                default: showingAddSalary = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FTColor.accent)
            }
        }
    }

    // MARK: - Recompute All

    private func recomputeAll() {
        streamSummaries = IncomeService.shared.computeStreamSummaries(
            transactions: transactions,
            baseCurrency: baseCurrency
        )
        passiveMetrics = IncomeService.shared.computePassiveIncomeMetrics(
            transactions: transactions,
            dividends: dividends,
            rentalProperties: properties,
            baseCurrency: baseCurrency
        )
        stabilityScore = IncomeService.shared.computeStabilityScore(
            transactions: transactions,
            salaryRecords: salaryRecords,
            freelanceProjects: projects,
            rentalProperties: properties,
            dividends: dividends,
            baseCurrency: baseCurrency
        )
    }

    // MARK: - Tab 0: Overview

    private var overviewTab: some View {
        VStack(spacing: FTSpacing.lg) {

            // Hero income card
            IncomeHeroCard(
                totalMonthlyIncome: lastMonthIncome,
                monthOverMonthChange: monthOverMonthChange,
                baseCurrency: baseCurrency
            )
            .padding(.horizontal, FTSpacing.screen)

            // Income Streams Grid
            if !streamSummaries.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    IncomeSectionHeader(title: "Income Streams", symbol: "chart.bar.fill", tint: FTColor.accent)
                        .padding(.horizontal, FTSpacing.screen)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FTSpacing.md) {
                            ForEach(streamSummaries, id: \.sourceType) { summary in
                                IncomeStreamCard(summary: summary, baseCurrency: baseCurrency)
                            }
                        }
                        .padding(.horizontal, FTSpacing.screen)
                        .padding(.vertical, FTSpacing.xs)
                    }
                }
            }

            // Quick Stats
            HStack(spacing: FTSpacing.md) {
                IncomeQuickStat(
                    value: "\(salaryRecords.count)",
                    label: "Salary\nRecords",
                    symbol: "banknote.fill",
                    tint: FTColor.income
                )
                IncomeQuickStat(
                    value: "\(projects.count)",
                    label: "Active\nProjects",
                    symbol: "laptopcomputer",
                    tint: FTColor.accent
                )
                IncomeQuickStat(
                    value: "\(properties.count)",
                    label: "Properties",
                    symbol: "house.fill",
                    tint: FTColor.gold
                )
            }
            .padding(.horizontal, FTSpacing.screen)

            // Recent Income
            if !recentIncomeTransactions.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    IncomeSectionHeader(title: "Recent Income", symbol: "clock.fill", tint: FTColor.textSecondary)
                        .padding(.horizontal, FTSpacing.screen)

                    VStack(spacing: 1) {
                        ForEach(recentIncomeTransactions, id: \.id) { tx in
                            IncomeTransactionRow(transaction: tx, baseCurrency: baseCurrency)
                                .padding(.horizontal, FTSpacing.screen)
                                .padding(.vertical, FTSpacing.sm)

                            if tx.id != recentIncomeTransactions.last?.id {
                                Divider()
                                    .padding(.leading, FTSpacing.screen + 42 + FTSpacing.md)
                            }
                        }
                    }
                    .ftGlass(FTRadius.lg)
                    .padding(.horizontal, FTSpacing.screen)
                }
            }

            // Quick navigation chips
            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                IncomeSectionHeader(title: "Quick Access", symbol: "square.grid.2x2", tint: FTColor.textSecondary)
                    .padding(.horizontal, FTSpacing.screen)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.sm) {
                        QuickNavChip(symbol: "banknote.fill", title: "Salary", tint: FTColor.income) {
                            withAnimation(.snappy(duration: 0.22)) { selectedTab = 1 }
                        }
                        QuickNavChip(symbol: "laptopcomputer", title: "Freelance", tint: FTColor.accent) {
                            withAnimation(.snappy(duration: 0.22)) { selectedTab = 2 }
                        }
                        QuickNavChip(symbol: "house.fill", title: "Rental", tint: FTColor.gold) {
                            withAnimation(.snappy(duration: 0.22)) { selectedTab = 3 }
                        }
                        QuickNavChip(symbol: "dollarsign.circle.fill", title: "Dividends", tint: FTColor.catPurple) {
                            withAnimation(.snappy(duration: 0.22)) { selectedTab = 4 }
                        }
                        QuickNavChip(symbol: "leaf.fill", title: "Passive", tint: FTColor.catBlue) {
                            withAnimation(.snappy(duration: 0.22)) { selectedTab = 5 }
                        }
                        QuickNavChip(symbol: "shield.lefthalf.filled", title: "Stability", tint: FTColor.expense) {
                            withAnimation(.snappy(duration: 0.22)) { selectedTab = 6 }
                        }
                    }
                    .padding(.horizontal, FTSpacing.screen)
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - Tab 4: Dividends

    private var dividendsTab: some View {
        VStack(spacing: FTSpacing.lg) {

            // Summary card
            let totalGross = dividends.reduce(0) { $0 + currencyService.convert($1.grossAmount, from: $1.currency, to: baseCurrency) }
            let totalWithheld = dividends.reduce(0) { $0 + currencyService.convert($1.taxWithholding, from: $1.currency, to: baseCurrency) }
            let totalNet = dividends.reduce(0) { $0 + currencyService.convert($1.netAmount, from: $1.currency, to: baseCurrency) }

            VStack(spacing: FTSpacing.lg) {
                HStack(spacing: FTSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FTRadius.sm)
                            .fill(FTColor.gold.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(FTColor.gold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dividends YTD")
                            .font(.ftHeadline)
                            .foregroundStyle(FTColor.textPrimary)
                        Text("Year-to-date summary")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.md) {
                    DividendMetricCell(label: "Gross", value: totalGross.formatted(as: baseCurrency), tint: FTColor.income)
                    DividendMetricCell(label: "Tax Withheld", value: totalWithheld.formatted(as: baseCurrency), tint: FTColor.expense)
                    DividendMetricCell(label: "Net", value: totalNet.formatted(as: baseCurrency), tint: FTColor.accent)
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)

            // Dividend list
            if dividends.isEmpty {
                IncomeEmptyState(
                    symbol: "dollarsign.circle",
                    title: "No Dividends Yet",
                    message: "Record your investment dividends to track income from your portfolio.",
                    action: { showingAddDividend = true },
                    actionLabel: "Add Dividend"
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    IncomeSectionHeader(title: "All Dividends", symbol: "list.bullet", tint: FTColor.textSecondary)
                        .padding(.horizontal, FTSpacing.screen)

                    let sorted = dividends.sorted { $0.date > $1.date }
                    VStack(spacing: 1) {
                        ForEach(sorted, id: \.id) { dividend in
                            DividendRow(dividend: dividend, baseCurrency: baseCurrency)
                                .padding(.horizontal, FTSpacing.screen)
                                .padding(.vertical, FTSpacing.sm)

                            if dividend.id != sorted.last?.id {
                                Divider()
                                    .padding(.leading, FTSpacing.screen + 42 + FTSpacing.md)
                            }
                        }
                    }
                    .ftGlass(FTRadius.lg)
                    .padding(.horizontal, FTSpacing.screen)
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - Tab 5: Passive Dashboard

    private var passiveTab: some View {
        VStack(spacing: FTSpacing.lg) {
            if let metrics = passiveMetrics {
                // Hero card
                PassiveIncomeHeroCard(metrics: metrics, baseCurrency: baseCurrency)
                    .padding(.horizontal, FTSpacing.screen)

                // Donut chart
                if !metrics.breakdown.isEmpty {
                    PassiveDonutChart(breakdown: metrics.breakdown, baseCurrency: baseCurrency)
                        .padding(.horizontal, FTSpacing.screen)
                }

                // Monthly trend chart
                PassiveMonthlyTrendChart(
                    transactions: incomeTransactions,
                    baseCurrency: baseCurrency
                )
                .padding(.horizontal, FTSpacing.screen)

                // Source breakdown list
                if !metrics.breakdown.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        IncomeSectionHeader(title: "Source Breakdown", symbol: "chart.pie.fill", tint: FTColor.textSecondary)
                            .padding(.horizontal, FTSpacing.screen)

                        VStack(spacing: 1) {
                            ForEach(metrics.breakdown, id: \.source) { item in
                                PassiveSourceRow(item: item, baseCurrency: baseCurrency)
                                    .padding(.horizontal, FTSpacing.screen)
                                    .padding(.vertical, FTSpacing.sm)

                                if item.source != metrics.breakdown.last?.source {
                                    Divider()
                                        .padding(.leading, FTSpacing.screen + 42 + FTSpacing.md)
                                }
                            }
                        }
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                }

            } else {
                ProgressView("Computing passive metrics...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FTSpacing.xxl)
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - Tab 6: Stability Score

    private var stabilityTab: some View {
        VStack(spacing: FTSpacing.lg) {
            if let score = stabilityScore {

                // Score arc
                VStack(spacing: FTSpacing.lg) {
                    StabilityScoreArc(score: score.score, grade: score.grade)
                        .frame(height: 220)

                    VStack(spacing: FTSpacing.xs) {
                        Text("Grade \(score.grade.rawValue)")
                            .font(.ftTitle)
                            .foregroundStyle(Color.fromString(score.grade.color))
                        Text(score.grade.description)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(FTSpacing.lg)
                .ftGlass(FTRadius.lg)
                .padding(.horizontal, FTSpacing.screen)

                // Factors
                if !score.factors.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        IncomeSectionHeader(title: "Score Factors", symbol: "list.number", tint: FTColor.textSecondary)
                            .padding(.horizontal, FTSpacing.screen)

                        VStack(spacing: FTSpacing.md) {
                            ForEach(score.factors, id: \.name) { factor in
                                StabilityFactorRow(factor: factor)
                            }
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                }

                // Insights
                if !score.insights.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        IncomeSectionHeader(title: "Insights", symbol: "lightbulb.fill", tint: FTColor.gold)
                            .padding(.horizontal, FTSpacing.screen)

                        VStack(alignment: .leading, spacing: FTSpacing.md) {
                            ForEach(score.insights, id: \.self) { insight in
                                HStack(alignment: .top, spacing: FTSpacing.sm) {
                                    Circle()
                                        .fill(FTColor.accent)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(insight)
                                        .font(.ftBody)
                                        .foregroundStyle(FTColor.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                }

                // Recommendation
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    IncomeSectionHeader(title: "Recommendation", symbol: "star.fill", tint: FTColor.accent)
                        .padding(.horizontal, FTSpacing.screen)

                    HStack(alignment: .top, spacing: FTSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(FTColor.accent.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "lightbulb.max.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(FTColor.accent)
                        }
                        Text(score.recommendation)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(FTSpacing.lg)
                    .background(FTColor.accent.opacity(0.08), in: .rect(cornerRadius: FTRadius.lg))
                    .ftGlass(FTRadius.lg)
                    .padding(.horizontal, FTSpacing.screen)
                }

                // Recalculate button
                Button {
                    stabilityScore = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        stabilityScore = IncomeService.shared.computeStabilityScore(
                            transactions: transactions,
                            salaryRecords: salaryRecords,
                            freelanceProjects: projects,
                            rentalProperties: properties,
                            dividends: dividends,
                            baseCurrency: baseCurrency
                        )
                    }
                } label: {
                    Label("Recalculate Score", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.ftPrimary)
                .padding(.horizontal, FTSpacing.screen)

            } else {
                VStack(spacing: FTSpacing.lg) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(FTColor.accent)
                    Text("Computing your stability score…")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
        .padding(.top, FTSpacing.md)
    }
}

// MARK: - Income Hero Card

private struct IncomeHeroCard: View {
    let totalMonthlyIncome: Double
    let monthOverMonthChange: Double
    let baseCurrency: String

    private var incomeGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x1DB96B), Color(hex: 0x0D7A47)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TOTAL MONTHLY INCOME")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            Text(totalMonthlyIncome.formatted(as: baseCurrency))
                .font(.ftDisplay)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            HStack(spacing: FTSpacing.md) {
                // Month-over-month badge
                HStack(spacing: 4) {
                    Image(systemName: monthOverMonthChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(format: "%.1f%%", abs(monthOverMonthChange)))
                        .font(.ftCaption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, FTSpacing.sm + 2)
                .padding(.vertical, 5)
                .background(.white.opacity(monthOverMonthChange >= 0 ? 0.22 : 0.15), in: .capsule)

                Text(monthOverMonthChange >= 0 ? "vs last month" : "vs last month")
                    .font(.ftCaption)
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                    Text(Date().monthName)
                        .font(.ftCaption)
                }
                .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(FTSpacing.xl)
        .background(incomeGradient, in: .rect(cornerRadius: FTRadius.xl))
        .shadow(color: Color(hex: 0x0D7A47).opacity(0.35), radius: 20, y: 8)
    }
}

// MARK: - IncomeStreamCard

struct IncomeStreamCard: View {
    let summary: IncomeStreamSummary
    let baseCurrency: String

    private var icon: String {
        switch summary.sourceType.lowercased() {
        case "salary", "employment": return "banknote.fill"
        case "freelance", "consulting": return "laptopcomputer"
        case "rental", "rent": return "house.fill"
        case "dividends", "dividend": return "dollarsign.circle.fill"
        case "business": return "briefcase.fill"
        case "interest": return "percent"
        case "royalties": return "music.note"
        default: return "arrow.down.circle.fill"
        }
    }

    private var tint: Color {
        switch summary.sourceType.lowercased() {
        case "salary", "employment": return FTColor.income
        case "freelance", "consulting": return FTColor.accent
        case "rental", "rent": return FTColor.gold
        case "dividends", "dividend": return FTColor.catPurple
        case "business": return FTColor.catBlue
        case "interest": return FTColor.catTeal
        default: return FTColor.textSecondary
        }
    }

    private var trendIcon: String {
        switch summary.trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch summary.trend {
        case .up: return FTColor.income
        case .down: return FTColor.expense
        case .stable: return FTColor.textMuted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                FTIconTile(symbol: icon, tint: tint, size: 36)
                Spacer()
                Image(systemName: trendIcon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(trendColor)
            }

            Text(summary.sourceType)
                .font(.ftCallout)
                .foregroundStyle(FTColor.textPrimary)
                .lineLimit(1)

            Text(summary.monthlyAverage.formatted(as: baseCurrency))
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("Monthly avg")
                .font(.ftLabel)
                .tracking(0.5)
                .foregroundStyle(FTColor.textMuted)
        }
        .padding(FTSpacing.md)
        .frame(width: 150)
        .ftGlassInteractive(FTRadius.md)
    }
}

// MARK: - Income Quick Stat

private struct IncomeQuickStat: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: FTSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: FTRadius.sm))

            Text(value)
                .font(.ftTitle)
                .foregroundStyle(FTColor.textPrimary)

            Text(label)
                .font(.ftLabel)
                .tracking(0.3)
                .foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - Income Transaction Row

private struct IncomeTransactionRow: View {
    let transaction: Transaction
    let baseCurrency: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(
                symbol: transaction.category.icon,
                tint: Color.fromString(transaction.category.color),
                size: 42
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.title)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: FTSpacing.xs) {
                    Text(transaction.category.rawValue)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                    if let source = transaction.incomeSource, !source.isEmpty {
                        Text("·")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                        Text(source)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("+" + transaction.amountInBaseCurrency.formatted(as: baseCurrency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.income)
                Text(transaction.date.relativeFormatted)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }
        }
    }
}

// MARK: - Quick Nav Chip

private struct QuickNavChip: View {
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.textPrimary)
            }
            .padding(.horizontal, FTSpacing.md)
            .padding(.vertical, FTSpacing.sm + 1)
            .background(.regularMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dividend Row

private struct DividendRow: View {
    let dividend: Dividend
    let baseCurrency: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "dollarsign.circle.fill", tint: FTColor.gold, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(dividend.securityName ?? "Unknown Security")
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .lineLimit(1)
                Text(dividend.date.formatted)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(dividend.grossAmount.formatted(as: dividend.currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)

                HStack(spacing: FTSpacing.xs) {
                    if dividend.taxWithholding > 0 {
                        Text("Tax: \(dividend.taxWithholding.formatted(as: dividend.currency))")
                            .font(.ftLabel)
                            .tracking(0.3)
                            .foregroundStyle(FTColor.expense)
                    }
                    Text("Net: \(dividend.netAmount.formatted(as: dividend.currency))")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.income)
                }
            }
        }
    }
}

// MARK: - Dividend Metric Cell

private struct DividendMetricCell: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            Text(label)
                .font(.ftLabel)
                .tracking(0.5)
                .foregroundStyle(FTColor.textSecondary)
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpacing.sm)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: FTRadius.sm))
    }
}

// MARK: - PassiveIncomeHeroCard

struct PassiveIncomeHeroCard: View {
    let metrics: PassiveIncomeMetrics
    let baseCurrency: String

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FTRadius.sm)
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("PASSIVE INCOME")
                        .font(.ftLabel)
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Earn while you sleep")
                        .font(.ftCaption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }

            Text(metrics.totalMonthly.formatted(as: baseCurrency))
                .font(.ftAmount)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            HStack(spacing: 0) {
                Text("/ month  ·  ")
                    .font(.ftCaption)
                    .foregroundStyle(.white.opacity(0.75))
                Text(metrics.totalAnnual.asCompact(currency: baseCurrency))
                    .font(.ftCaption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(" annually")
                    .font(.ftCaption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(FTSpacing.xl)
        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
        .shadow(color: Color(hex: 0x0A6E7E).opacity(0.35), radius: 20, y: 8)
    }
}

// MARK: - Passive Donut Chart

private struct PassiveDonutChart: View {
    let breakdown: [(source: String, amount: Double, percentage: Double)]
    let baseCurrency: String

    private let chartColors: [Color] = [
        FTColor.accent, FTColor.gold, FTColor.catPurple, FTColor.catBlue, FTColor.catCoral, FTColor.income
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            IncomeSectionHeader(title: "By Source", symbol: "chart.pie.fill", tint: FTColor.textSecondary)

            HStack(spacing: FTSpacing.xl) {
                Chart(breakdown, id: \.source) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(
                        chartColors[
                            min(breakdown.firstIndex(where: { $0.source == item.source }) ?? 0,
                                chartColors.count - 1)
                        ]
                    )
                    .cornerRadius(4)
                }
                .frame(width: 130, height: 130)

                // Legend
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    ForEach(breakdown.prefix(5), id: \.source) { item in
                        let idx = min(breakdown.firstIndex(where: { $0.source == item.source }) ?? 0, chartColors.count - 1)
                        HStack(spacing: FTSpacing.sm) {
                            Circle()
                                .fill(chartColors[idx])
                                .frame(width: 8, height: 8)
                            Text(item.source)
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.0f%%", item.percentage))
                                .font(.ftLabel)
                                .tracking(0.3)
                                .foregroundStyle(FTColor.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - Passive Monthly Trend Chart

private struct PassiveMonthlyTrendChart: View {
    let transactions: [Transaction]
    let baseCurrency: String

    private struct MonthData: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
        let date: Date
    }

    private var last6Months: [MonthData] {
        let cal = Calendar.current
        let now = Date()
        return (0...5).reversed().compactMap { offset -> MonthData? in
            guard let monthDate = cal.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let start = monthDate.startOfMonth
            guard let end = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
            let passiveCategories: Set<TransactionCategory> = [.dividends, .rental, .investmentIncome, .interestIncome]
            let total = transactions
                .filter { $0.date >= start && $0.date < end && passiveCategories.contains($0.category) }
                .reduce(0) { $0 + $1.amountInBaseCurrency }
            return MonthData(label: monthDate.shortMonthName, amount: total, date: start)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            IncomeSectionHeader(title: "6-Month Trend", symbol: "chart.bar.fill", tint: FTColor.textSecondary)

            Chart(last6Months) { month in
                BarMark(
                    x: .value("Month", month.label),
                    y: .value("Amount", month.amount)
                )
                .foregroundStyle(FTColor.accentGradient)
                .cornerRadius(6)
            }
            .frame(height: 140)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .foregroundStyle(FTColor.textMuted)
                        .font(.ftLabel)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
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

// MARK: - Passive Source Row

private struct PassiveSourceRow: View {
    let item: (source: String, amount: Double, percentage: Double)
    let baseCurrency: String

    private var icon: String {
        switch item.source.lowercased() {
        case "rental", "rent": return "house.fill"
        case "dividends", "dividend": return "dollarsign.circle.fill"
        case "interest": return "percent"
        case "royalties": return "music.note"
        case "business distributions", "business": return "briefcase.fill"
        default: return "arrow.down.circle.fill"
        }
    }

    private var tint: Color {
        switch item.source.lowercased() {
        case "rental", "rent": return FTColor.gold
        case "dividends", "dividend": return FTColor.catPurple
        case "interest": return FTColor.catTeal
        case "royalties": return FTColor.catCoral
        case "business distributions", "business": return FTColor.catBlue
        default: return FTColor.accent
        }
    }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: icon, tint: tint, size: 42)

            Text(item.source)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(item.amount.formatted(as: baseCurrency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text(String(format: "%.1f%%", item.percentage))
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }
        }
    }
}

// MARK: - StabilityScoreArc

// MARK: - SalaryDetailSheet

struct SalaryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let record: SalaryRecord

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        FTCard {
                            VStack(spacing: FTSpacing.md) {
                                FTIconTile(symbol: "dollarsign.circle.fill", tint: Color.fromString(record.colorName))
                                Text(record.employerName).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                                Text(record.jobTitle).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FTSpacing.sm)
                        }
                        FTCard {
                            VStack(spacing: FTSpacing.sm) {
                                HStack {
                                    Text("Expected").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(record.expectedAmount.formatted(as: record.currency)).font(.ftBodySemibold).foregroundStyle(FTColor.income)
                                }
                                HStack {
                                    Text("Frequency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(record.paymentFrequency.rawValue).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                }
                                HStack {
                                    Text("Payment Day").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text("Day \(record.expectedPaymentDay)").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                }
                                HStack {
                                    Text("On-time Rate").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(record.onTimeRate.asPercentage(decimals: 0)).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                }
                            }
                        }
                        if let notes = record.notes, !notes.isEmpty {
                            FTCard {
                                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                    Text("NOTES").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                                    Text(notes).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }
            }
            .navigationTitle("Salary Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
            }
        }
    }
}

struct StabilityScoreArc: View {
    let score: Double   // 0-100
    let grade: IncomeStabilityScore.Grade

    private var arcColor: Color {
        switch grade.rawValue {
        case "A", "B": return FTColor.income
        case "C": return .yellow
        case "D": return .orange
        default: return FTColor.expense
        }
    }

    private var trimEnd: CGFloat {
        CGFloat(max(0, min(score, 100))) / 100 * 0.75
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0.125, to: 0.875)
                .stroke(FTColor.textPrimary.opacity(0.1), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(180))

            // Fill
            Circle()
                .trim(from: 0.125, to: 0.125 + trimEnd)
                .stroke(
                    LinearGradient(
                        colors: [arcColor.opacity(0.7), arcColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(180))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: trimEnd)

            // Center content
            VStack(spacing: FTSpacing.xs) {
                Text(String(format: "%.0f", score))
                    .font(.ftDisplay)
                    .foregroundStyle(FTColor.textPrimary)
                Text(grade.rawValue)
                    .font(.ftTitle)
                    .foregroundStyle(arcColor)
            }
        }
        .padding(FTSpacing.xl)
    }
}

// MARK: - Stability Factor Row

private struct StabilityFactorRow: View {
    let factor: IncomeStabilityFactor

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: factor.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                        .frame(width: 24)
                    Text(factor.name)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                }
                Spacer()
                Text("\(Int(factor.score))/100")
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.textSecondary)
            }

            FTProgressBar(
                value: factor.score / 100,
                color: factor.score >= 75 ? FTColor.income : factor.score >= 50 ? FTColor.gold : FTColor.expense
            )

            Text(factor.detail)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Section Header

private struct IncomeSectionHeader: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
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
}

// MARK: - Empty State

private struct IncomeEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    let action: () -> Void
    let actionLabel: String

    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FTColor.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(FTColor.accent)
            }

            VStack(spacing: FTSpacing.xs) {
                Text(title)
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text(message)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(actionLabel, action: action)
                .buttonStyle(.ftPrimary)
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.xxl)
        .padding(.horizontal, FTSpacing.xl)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        FTBackdrop()
        IncomeManagementView()
    }
    .environment(AppState())
    .environment(CurrencyService.shared)
    .modelContainer(
        for: [
            SalaryRecord.self,
            FreelanceProject.self,
            RentalProperty.self,
            Dividend.self,
            Transaction.self,
        ],
        inMemory: true
    )
}
