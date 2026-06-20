import SwiftUI
import SwiftData
import Charts

struct PredictiveBalanceView: View {
    @Environment(AppState.self) private var appState
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]

    @State private var forecast: BalanceForecast?
    @State private var showRecurring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    if let f = forecast {
                        currentBalanceCard(f)
                        forecastChart(f)
                        keyInsightsCard(f)
                        recurringItemsSection(f)
                        confidenceNote
                    } else {
                        ProgressView()
                            .padding(.top, 100)
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 32)
            }
            .navigationTitle("30-Day Forecast")
            .background { FTBackdrop() }
            .onAppear { compute() }
        }
    }

    // MARK: - Current Balance Card

    private func currentBalanceCard(_ f: BalanceForecast) -> some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT BALANCE")
                        .font(.ftLabel)
                        .tracking(1.6)
                        .foregroundStyle(FTColor.textMuted)
                    Text(f.currentBalance.formatted(as: appState.baseCurrency))
                        .font(.ftAmount)
                        .foregroundStyle(FTColor.textPrimary)
                }
                Spacer()
                FTIconTile(symbol: "chart.line.uptrend.xyaxis", tint: FTColor.accent, size: 42)
            }

            Divider().opacity(0.3)

            HStack {
                forecastKPI(
                    label: "Expected In",
                    value: f.expectedIncome.formatted(as: appState.baseCurrency),
                    color: FTColor.income,
                    icon: "arrow.down.circle.fill"
                )
                Divider().frame(height: 40)
                forecastKPI(
                    label: "Expected Out",
                    value: f.expectedExpenses.formatted(as: appState.baseCurrency),
                    color: FTColor.expense,
                    icon: "arrow.up.circle.fill"
                )
                Divider().frame(height: 40)
                let net = f.expectedIncome - f.expectedExpenses
                forecastKPI(
                    label: "Net Change",
                    value: (net >= 0 ? "+" : "") + net.formatted(as: appState.baseCurrency),
                    color: net >= 0 ? FTColor.income : FTColor.expense,
                    icon: "plusminus.circle.fill"
                )
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func forecastKPI(label: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.ftCallout)
                .foregroundStyle(color)
            Text(value)
                .font(.ftCallout)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chart

    private func forecastChart(_ f: BalanceForecast) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("BALANCE PROJECTION")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            Chart {
                // Confidence shading
                ForEach(f.days.prefix(15)) { day in
                    AreaMark(
                        x: .value("Date", day.date),
                        yStart: .value("Low", min(day.projectedBalance, f.currentBalance) - 100),
                        yEnd: .value("High", day.projectedBalance)
                    )
                    .foregroundStyle(FTColor.accent.opacity(0.06))
                }

                // Forecast line
                ForEach(f.days) { day in
                    LineMark(
                        x: .value("Date", day.date),
                        y: .value("Balance", day.projectedBalance)
                    )
                    .foregroundStyle(day.isConfident ? FTColor.accent : FTColor.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: day.isConfident ? [] : [5, 4]))
                    .interpolationMethod(.catmullRom)
                }

                // Current balance reference line
                RuleMark(y: .value("Current", f.currentBalance))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(FTColor.textMuted.opacity(0.5))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Current")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }

                // Lowest point annotation
                if let lowestDay = f.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: f.lowestDate) }) {
                    PointMark(
                        x: .value("Date", lowestDay.date),
                        y: .value("Balance", lowestDay.projectedBalance)
                    )
                    .foregroundStyle(FTColor.expense)
                    .symbolSize(80)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(FTColor.textMuted.opacity(0.2))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(FTColor.textMuted)
                        .font(.ftCaption)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(FTColor.textMuted.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.asCompact(currency: appState.baseCurrency))
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding(.top, FTSpacing.sm)

            HStack(spacing: FTSpacing.lg) {
                legendItem(color: FTColor.accent, dash: false, label: "Confident (0-15 days)")
                legendItem(color: FTColor.textSecondary, dash: true, label: "Estimated (15-30 days)")
            }
            .padding(.top, 4)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func legendItem(color: Color, dash: Bool, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 20, height: 2)
                .overlay(
                    dash ? RoundedRectangle(cornerRadius: 2).fill(Color.clear).overlay(
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle().fill(Color.white).frame(width: 3, height: 2)
                            }
                        }
                    ) : nil
                )
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
        }
    }

    // MARK: - Key Insights

    private func keyInsightsCard(_ f: BalanceForecast) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("KEY INSIGHTS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                insightRow(
                    icon: "arrow.down.circle.fill",
                    label: "Lowest Projected Balance",
                    value: f.lowestPoint.formatted(as: appState.baseCurrency),
                    valueColor: f.lowestPoint < 0 ? FTColor.expense : FTColor.textPrimary,
                    detail: "on \(f.lowestDate.formatted)"
                )
                insightRow(
                    icon: "gauge.with.dots.needle.67percent",
                    label: "Forecast Confidence",
                    value: "\(Int(f.confidence * 100))%",
                    valueColor: FTColor.accent,
                    detail: "based on 3-month history"
                )
                insightRow(
                    icon: "calendar.badge.clock",
                    label: "Recurring Items Detected",
                    value: "\(f.recurringItems.count)",
                    valueColor: FTColor.catBlue,
                    detail: "bills and income included"
                )
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func insightRow(icon: String, label: String, value: String, valueColor: Color, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(valueColor)
                .font(.ftCallout)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                Text(detail)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - Recurring Items

    private func recurringItemsSection(_ f: BalanceForecast) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Button {
                withAnimation(.spring) { showRecurring.toggle() }
            } label: {
                HStack {
                    Text("UPCOMING RECURRING")
                        .font(.ftLabel)
                        .tracking(1.6)
                        .foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                        .rotationEffect(.degrees(showRecurring ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if showRecurring {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(f.recurringItems) { item in
                        HStack {
                            Image(systemName: item.isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .foregroundStyle(item.isIncome ? FTColor.income : FTColor.expense)
                                .font(.ftCallout)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                                Text(item.dueDate.formatted)
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textMuted)
                            }
                            Spacer()
                            Text((item.isIncome ? "+" : "-") + item.amount.formatted(as: appState.baseCurrency))
                                .font(.ftBodySemibold)
                                .foregroundStyle(item.isIncome ? FTColor.income : FTColor.expense)
                        }
                        .padding(.vertical, FTSpacing.sm)
                        Divider().opacity(0.3)
                    }
                }
                .padding()
                .ftGlass(FTRadius.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Confidence Note

    private var confidenceNote: some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(FTColor.textMuted)
                .font(.ftCallout)
            Text("Forecast uses your 90-day spending average plus known recurring bills. Actual results may vary based on irregular expenses.")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(FTColor.textMuted.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    // MARK: - Compute

    private func compute() {
        forecast = AIAnalyticsService.shared.predictBalance(
            accounts: accounts,
            transactions: transactions,
            bills: bills
        )
    }
}
