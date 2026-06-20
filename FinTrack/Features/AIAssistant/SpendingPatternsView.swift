import SwiftUI
import SwiftData
import Charts

struct SpendingPatternsView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]

    @State private var data: SpendingPatternData?
    @State private var selectedTab = 0

    private let tabs = ["Day of Week", "Hour of Day", "By Month"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    if let d = data {
                        summaryCard(d)
                        tabPicker
                        chartSection(d)
                        topMerchantsCard(d)
                        peakInsightsCard(d)
                    } else {
                        ProgressView().padding(.top, 100)
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 32)
            }
            .navigationTitle("Spending Patterns")
            .background { FTBackdrop() }
            .onAppear { compute() }
        }
    }

    // MARK: - Summary Card

    private func summaryCard(_ d: SpendingPatternData) -> some View {
        HStack(spacing: 0) {
            kpiBox(value: "\(d.totalTransactions)", label: "Transactions", color: FTColor.accent)
            Divider().frame(height: 40)
            kpiBox(value: dayName(d.peakDay), label: "Peak Day", color: FTColor.catBlue)
            Divider().frame(height: 40)
            kpiBox(value: hourLabel(d.peakHour), label: "Peak Time", color: FTColor.catPurple)
        }
        .ftGlass(FTRadius.lg)
    }

    private func kpiBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.ftHeadline)
                .foregroundStyle(color)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.lg)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        FTSegmentedControl(options: tabs, selection: $selectedTab)
    }

    // MARK: - Chart Section

    @ViewBuilder
    private func chartSection(_ d: SpendingPatternData) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text(tabs[selectedTab].uppercased())
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            switch selectedTab {
            case 0: dayOfWeekChart(d)
            case 1: hourOfDayChart(d)
            default: monthlyChart(d)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // Day of Week Chart
    private func dayOfWeekChart(_ d: SpendingPatternData) -> some View {
        let maxVal = (d.byDayOfWeek.values.max() ?? 1)
        return Chart {
            ForEach(1...7, id: \.self) { day in
                let amount = d.byDayOfWeek[day] ?? 0
                BarMark(
                    x: .value("Day", shortDayName(day)),
                    y: .value("Spend", amount)
                )
                .foregroundStyle(day == d.peakDay ? FTColor.accent : FTColor.accent.opacity(0.4))
                .cornerRadius(6)
                .annotation(position: .top) {
                    if amount == maxVal {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(FTColor.accent)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(FTColor.textMuted.opacity(0.2))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.asCompact(currency: appState.baseCurrency)).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    // Hour of Day Chart
    private func hourOfDayChart(_ d: SpendingPatternData) -> some View {
        Chart {
            ForEach(0...23, id: \.self) { hour in
                let amount = d.byHourOfDay[hour] ?? 0
                BarMark(
                    x: .value("Hour", hour),
                    y: .value("Spend", amount)
                )
                .foregroundStyle(hour == d.peakHour ? FTColor.catPurple : FTColor.catPurple.opacity(0.4))
                .cornerRadius(3)
            }
        }
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self) {
                        Text(hourLabel(h)).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(FTColor.textMuted.opacity(0.2))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(FTColor.textMuted.opacity(0.2))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.asCompact(currency: appState.baseCurrency)).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    // Monthly Chart
    private func monthlyChart(_ d: SpendingPatternData) -> some View {
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return Chart {
            ForEach(1...12, id: \.self) { month in
                let amount = d.byMonth[month] ?? 0
                BarMark(
                    x: .value("Month", months[month - 1]),
                    y: .value("Spend", amount)
                )
                .foregroundStyle(month == d.peakMonth ? FTColor.catTeal : FTColor.catTeal.opacity(0.4))
                .cornerRadius(6)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(FTColor.textMuted.opacity(0.2))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.asCompact(currency: appState.baseCurrency)).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    // MARK: - Top Merchants

    private func topMerchantsCard(_ d: SpendingPatternData) -> some View {
        let expenses = transactions.filter { $0.type == .expense && !$0.isPending }
        let merchantGroups = Dictionary(grouping: expenses.compactMap { $0.merchant?.isEmpty == false ? $0 : nil }) { $0.merchant! }
        let topMerchants = merchantGroups
            .map { (name: $0.key, total: $0.value.reduce(0.0) { $0 + $1.amountInBaseCurrency }, count: $0.value.count) }
            .sorted { $0.total > $1.total }
            .prefix(5)

        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TOP MERCHANTS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            if topMerchants.isEmpty {
                Text("No merchant data yet. Add a merchant to your transactions for insights.")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .padding()
            } else {
                let maxTotal = topMerchants.first?.total ?? 1
                VStack(spacing: FTSpacing.sm) {
                    ForEach(Array(topMerchants.enumerated()), id: \.offset) { i, merchant in
                        VStack(spacing: 6) {
                            HStack {
                                Text("\(i + 1)")
                                    .font(.ftLabel)
                                    .tracking(1.2)
                                    .foregroundStyle(FTColor.textMuted)
                                    .frame(width: 20)
                                Text(merchant.name)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(merchant.total.formatted(as: appState.baseCurrency))
                                        .font(.ftBodySemibold)
                                        .foregroundStyle(FTColor.textPrimary)
                                    Text("\(merchant.count) visits")
                                        .font(.ftCaption)
                                        .foregroundStyle(FTColor.textMuted)
                                }
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(FTColor.textMuted.opacity(0.15)).frame(height: 4)
                                    RoundedRectangle(cornerRadius: 3).fill(FTColor.accent).frame(width: geo.size.width * CGFloat(merchant.total / maxTotal), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Peak Insights

    private func peakInsightsCard(_ d: SpendingPatternData) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("PATTERN INSIGHTS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                insightRow(icon: "calendar", color: FTColor.accent,
                           text: "You spend the most on \(dayName(d.peakDay))s. Consider reviewing weekend spending if trying to cut costs.")
                insightRow(icon: "clock.fill", color: FTColor.catPurple,
                           text: "Your peak spending time is \(hourLabel(d.peakHour)). Avoid impulse purchases during this window.")
                if let cat = d.mostExpensiveCategory {
                    insightRow(icon: cat.icon, color: Color.fromString(cat.color),
                               text: "\(cat.rawValue) is your biggest spending category — consider setting a dedicated budget.")
                }
                if let merchant = d.mostFrequentMerchant {
                    insightRow(icon: "storefront.fill", color: FTColor.catTeal,
                               text: "\(merchant) is your most visited merchant. A loyalty program could offset costs.")
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func insightRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.ftCallout)
                .frame(width: 22)
            Text(text)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private func dayName(_ weekday: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names[max(0, min(weekday - 1, 6))]
    }

    private func shortDayName(_ weekday: Int) -> String { dayName(weekday) }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(h)\(period)"
    }

    private func compute() {
        data = AIAnalyticsService.shared.computeSpendingPatterns(transactions: transactions)
    }
}
