import SwiftUI
import SwiftData
import Charts

struct DigitalTwinView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var loans: [Loan]

    @State private var scenario = DigitalTwinScenario(
        name: "Base Scenario",
        description: "Your current trajectory",
        monthlySalaryChange: 0,
        monthlyExpenseChange: 0,
        additionalSavingsRate: 0,
        investmentReturnRate: 7,
        projectionYears: 5
    )

    @State private var projection: DigitalTwinProjection?
    @State private var baselineProjection: DigitalTwinProjection?
    @State private var showingParameters = true

    private var currency: String { appState.baseCurrency }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    parametersSection
                    if let proj = projection, let base = baselineProjection {
                        resultsSummaryCard(proj, baseline: base)
                        netWorthChart(proj, baseline: base)
                        milestonesCard(proj)
                        scenarioComparisonCard(proj, baseline: base)
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 32)
            }
            .navigationTitle("Financial Twin")
            .background { FTBackdrop() }
            .onAppear { compute() }
        }
    }

    // MARK: - Parameters Section

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Button {
                withAnimation(.spring) { showingParameters.toggle() }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(FTColor.accent)
                    Text("SCENARIO PARAMETERS")
                        .font(.ftLabel)
                        .tracking(1.6)
                        .foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                        .rotationEffect(.degrees(showingParameters ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if showingParameters {
                VStack(spacing: FTSpacing.lg) {
                    sliderRow(
                        label: "Salary Change",
                        value: $scenario.monthlySalaryChange,
                        range: -5000...15000,
                        step: 500,
                        format: { v in (v >= 0 ? "+" : "") + v.formatted(as: currency) + "/mo" },
                        color: scenario.monthlySalaryChange >= 0 ? FTColor.income : FTColor.expense
                    )
                    sliderRow(
                        label: "Expense Change",
                        value: $scenario.monthlyExpenseChange,
                        range: -5000...5000,
                        step: 200,
                        format: { v in (v >= 0 ? "+" : "") + v.formatted(as: currency) + "/mo" },
                        color: scenario.monthlyExpenseChange <= 0 ? FTColor.income : FTColor.expense
                    )
                    sliderRow(
                        label: "Extra Savings Rate",
                        value: $scenario.additionalSavingsRate,
                        range: 0...0.30,
                        step: 0.01,
                        format: { v in v.asPercentage() + " extra" },
                        color: FTColor.accent
                    )
                    sliderRow(
                        label: "Investment Return",
                        value: $scenario.investmentReturnRate,
                        range: 0...20,
                        step: 0.5,
                        format: { v in v.asPercentage() + "/yr" },
                        color: FTColor.catBlue
                    )
                    yearPicker
                    presetScenarios
                }
                .padding()
                .ftGlass(FTRadius.lg)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String,
        color: Color
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.ftBodySemibold)
                    .foregroundStyle(color)
            }
            Slider(value: value, in: range, step: step)
                .tint(color)
                .onChange(of: value.wrappedValue) { _, _ in compute() }
        }
    }

    private var yearPicker: some View {
        HStack {
            Text("Projection Period")
                .font(.ftBody)
                .foregroundStyle(FTColor.textPrimary)
            Spacer()
            Picker("Years", selection: $scenario.projectionYears) {
                ForEach([1, 3, 5, 10, 20], id: \.self) { y in
                    Text("\(y)yr").tag(y)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            .onChange(of: scenario.projectionYears) { _, _ in compute() }
        }
    }

    private var presetScenarios: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("QUICK PRESETS")
                .font(.ftLabel)
                .tracking(1.4)
                .foregroundStyle(FTColor.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    presetButton("Raise +20%", { applyPreset(salaryChange: monthlyIncome * 0.20, expenseChange: 0, savings: 0.05) })
                    presetButton("Cut Costs -15%", { applyPreset(salaryChange: 0, expenseChange: -monthlyExpenses * 0.15, savings: 0) })
                    presetButton("Aggressive Save", { applyPreset(salaryChange: 0, expenseChange: -monthlyExpenses * 0.10, savings: 0.10) })
                    presetButton("Reset", { resetScenario() })
                }
            }
        }
    }

    private func presetButton(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.ftCallout)
                .foregroundStyle(FTColor.accent)
                .padding(.horizontal, FTSpacing.md)
                .padding(.vertical, FTSpacing.sm)
                .ftGlass(FTRadius.pill)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results Summary Card

    private func resultsSummaryCard(_ proj: DigitalTwinProjection, baseline: DigitalTwinProjection) -> some View {
        let gain = proj.netWorthAtEnd - baseline.netWorthAtEnd
        return VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROJECTED NET WORTH")
                        .font(.ftLabel)
                        .tracking(1.6)
                        .foregroundStyle(FTColor.textMuted)
                    Text(proj.netWorthAtEnd.formatted(as: currency))
                        .font(.ftAmount)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("in \(proj.years) year\(proj.years == 1 ? "" : "s")")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("vs. baseline")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                    Text((gain >= 0 ? "+" : "") + gain.formatted(as: currency))
                        .font(.ftHeadline)
                        .foregroundStyle(gain >= 0 ? FTColor.income : FTColor.expense)
                }
            }
            Divider().opacity(0.3)
            HStack(spacing: 0) {
                kpiBox(value: proj.totalSavings.asCompact(currency: currency), label: "Total Saved", color: FTColor.income)
                Divider().frame(height: 36)
                kpiBox(value: proj.totalInvestmentGrowth.asCompact(currency: currency), label: "Growth", color: FTColor.catBlue)
                Divider().frame(height: 36)
                kpiBox(value: proj.debtFreeMonth.map { monthLabel($0) } ?? "N/A", label: "Debt Free", color: FTColor.gold)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func kpiBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.ftCallout).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.sm)
    }

    // MARK: - Net Worth Chart

    private func netWorthChart(_ proj: DigitalTwinProjection, baseline: DigitalTwinProjection) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("NET WORTH PROJECTION")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            Chart {
                // Scenario line
                ForEach(proj.monthlySnapshots.filter { $0.month % 3 == 0 || $0.month == 1 }) { snap in
                    LineMark(
                        x: .value("Month", snap.month),
                        y: .value("Net Worth", snap.netWorth)
                    )
                    .foregroundStyle(FTColor.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                }

                // Baseline line
                ForEach(baseline.monthlySnapshots.filter { $0.month % 3 == 0 || $0.month == 1 }) { snap in
                    LineMark(
                        x: .value("Month", snap.month),
                        y: .value("Net Worth", snap.netWorth)
                    )
                    .foregroundStyle(FTColor.textMuted.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: max(12, proj.years * 12 / 5))) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(FTColor.textMuted.opacity(0.2))
                    AxisValueLabel {
                        if let m = value.as(Int.self) {
                            Text("Yr \(m / 12)").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(FTColor.textMuted.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.asCompact(currency: currency)).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
            }
            .frame(height: 200)

            HStack(spacing: FTSpacing.xl) {
                legendItem(color: FTColor.accent, label: "Your Scenario")
                legendItem(color: FTColor.textMuted.opacity(0.5), dashed: true, label: "Baseline")
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func legendItem(color: Color, dashed: Bool = false, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 20, height: 2)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
    }

    // MARK: - Milestones

    private func milestonesCard(_ proj: DigitalTwinProjection) -> some View {
        let milestones = computeMilestones(proj)
        guard !milestones.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("KEY MILESTONES")
                    .font(.ftLabel)
                    .tracking(1.6)
                    .foregroundStyle(FTColor.textMuted)

                VStack(spacing: FTSpacing.sm) {
                    ForEach(milestones, id: \.label) { milestone in
                        HStack(spacing: FTSpacing.md) {
                            Image(systemName: milestone.icon)
                                .foregroundStyle(milestone.color)
                                .font(.ftHeadline)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(milestone.label)
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.textPrimary)
                                Text(milestone.detail)
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textSecondary)
                            }
                            Spacer()
                            Text(milestone.time)
                                .font(.ftCallout)
                                .foregroundStyle(milestone.color)
                        }
                        .padding()
                        .background(milestone.color.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                    }
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)
        )
    }

    // MARK: - Scenario Comparison

    private func scenarioComparisonCard(_ proj: DigitalTwinProjection, baseline: DigitalTwinProjection) -> some View {
        let fields: [(String, String, String)] = [
            ("Net Worth", baseline.netWorthAtEnd.formatted(as: currency), proj.netWorthAtEnd.formatted(as: currency)),
            ("Total Saved", baseline.totalSavings.formatted(as: currency), proj.totalSavings.formatted(as: currency)),
            ("Investment Growth", baseline.totalInvestmentGrowth.formatted(as: currency), proj.totalInvestmentGrowth.formatted(as: currency)),
        ]
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("SCENARIO COMPARISON")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: 0) {
                HStack {
                    Text("Metric").font(.ftLabel).tracking(1.2).foregroundStyle(FTColor.textMuted).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Baseline").font(.ftLabel).tracking(1.2).foregroundStyle(FTColor.textMuted).frame(maxWidth: .infinity, alignment: .center)
                    Text("Scenario").font(.ftLabel).tracking(1.2).foregroundStyle(FTColor.accent).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal)
                .padding(.vertical, FTSpacing.sm)
                Divider()
                ForEach(fields, id: \.0) { label, base, scenario in
                    HStack {
                        Text(label).font(.ftBody).foregroundStyle(FTColor.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                        Text(base).font(.ftCallout).foregroundStyle(FTColor.textMuted).frame(maxWidth: .infinity, alignment: .center)
                        Text(scenario).font(.ftCallout).foregroundStyle(FTColor.accent).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, FTSpacing.sm)
                    Divider().opacity(0.3)
                }
            }
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Helpers

    private var monthlyIncome: Double {
        let (income, _) = AIAnalyticsService.shared.monthlyAverages(transactions: transactions)
        return income
    }

    private var monthlyExpenses: Double {
        let (_, expenses) = AIAnalyticsService.shared.monthlyAverages(transactions: transactions)
        return expenses
    }

    private var currentNetWorth: Double {
        accounts.filter { !$0.isArchived && !$0.isHidden }.reduce(0.0) {
            $0 + ($1.type.isLiability ? -$1.balance : $1.balance)
        }
    }

    private var totalDebt: Double {
        loans.filter { $0.isActive }.reduce(0.0) { $0 + $1.outstandingBalance }
    }

    private func compute() {
        let (inc, exp) = AIAnalyticsService.shared.monthlyAverages(transactions: transactions)
        let nw = currentNetWorth
        let debt = totalDebt

        projection = AIAnalyticsService.shared.runDigitalTwin(
            scenario: scenario, currentNetWorth: nw, monthlyIncome: inc, monthlyExpenses: exp, totalDebt: debt
        )
        let baselineScenario = DigitalTwinScenario(
            name: "Baseline", description: "", monthlySalaryChange: 0, monthlyExpenseChange: 0,
            additionalSavingsRate: 0, investmentReturnRate: 7, projectionYears: scenario.projectionYears
        )
        baselineProjection = AIAnalyticsService.shared.runDigitalTwin(
            scenario: baselineScenario, currentNetWorth: nw, monthlyIncome: inc, monthlyExpenses: exp, totalDebt: debt
        )
    }

    private func applyPreset(salaryChange: Double, expenseChange: Double, savings: Double) {
        scenario.monthlySalaryChange = salaryChange
        scenario.monthlyExpenseChange = expenseChange
        scenario.additionalSavingsRate = savings
        compute()
    }

    private func resetScenario() {
        scenario.monthlySalaryChange = 0
        scenario.monthlyExpenseChange = 0
        scenario.additionalSavingsRate = 0
        scenario.investmentReturnRate = 7
        compute()
    }

    private func monthLabel(_ month: Int) -> String {
        let yr = month / 12
        let m = month % 12
        if yr > 0 && m > 0 { return "\(yr)yr \(m)mo" }
        if yr > 0 { return "\(yr) yr" }
        return "\(m) mo"
    }

    private func computeMilestones(_ proj: DigitalTwinProjection) -> [(label: String, detail: String, time: String, icon: String, color: Color)] {
        var milestones: [(label: String, detail: String, time: String, icon: String, color: Color)] = []

        let targets: [(Double, String, String, String, Color)] = [
            (100_000, "100K Milestone", "Net worth reaches 100,000", "star.fill", FTColor.gold),
            (500_000, "500K Milestone", "Half million net worth", "star.circle.fill", FTColor.catPurple),
            (1_000_000, "Millionaire", "Net worth reaches 1M", "crown.fill", FTColor.income),
        ]

        for (target, label, detail, icon, color) in targets {
            if let snap = proj.monthlySnapshots.first(where: { $0.netWorth >= target }) {
                milestones.append((label: label, detail: detail, time: monthLabel(snap.month), icon: icon, color: color))
            }
        }

        if let dfm = proj.debtFreeMonth {
            milestones.append((label: "Debt-Free", detail: "All tracked loans paid off", time: monthLabel(dfm), icon: "checkmark.circle.fill", color: FTColor.income))
        }

        return milestones.sorted { a, b in
            let aM = proj.monthlySnapshots.first(where: { $0.netWorth >= 0 })?.month ?? 999
            let bM = proj.monthlySnapshots.first(where: { $0.netWorth >= 0 })?.month ?? 999
            return aM < bM
        }
    }
}
