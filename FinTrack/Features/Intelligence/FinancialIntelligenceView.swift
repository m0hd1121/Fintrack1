import SwiftUI
import SwiftData

// MARK: - FinancialIntelligenceView
// The Financial Intelligence hub: health score, insights, and predictions —
// all computed on-device by the deterministic engine. No network, no API,
// no cost.

struct FinancialIntelligenceView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var budgets: [Budget]
    @Query private var goals: [SavingsGoal]
    @Query private var loans: [Loan]
    @Query private var bills: [Bill]

    @State private var score: FinancialHealthScore? = nil
    @State private var insightList: [IntelligenceInsight] = []
    @State private var predictionList: [IntelligencePrediction] = []

    private var baseCurrency: String { appState.baseCurrency }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                if let score {
                    healthScoreCard(score)
                } else {
                    EmptyStateView(
                        icon: "heart.text.square",
                        title: "Not Enough Data Yet",
                        message: "Add an account or a couple of transactions to get your financial health score.")
                }

                if !predictionList.isEmpty {
                    VStack(spacing: FTSpacing.md) {
                        Text("PREDICTIONS")
                            .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.sm) {
                            ForEach(predictionList) { prediction in
                                VStack(alignment: .leading, spacing: 6) {
                                    Image(systemName: prediction.icon)
                                        .font(.ftCallout).foregroundStyle(FTColor.accent)
                                    Text(prediction.value)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                    Text(prediction.label)
                                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                        .lineLimit(2)
                                    Text("Confidence \(prediction.confidence)%")
                                        .font(.ftLabel).tracking(0.4).foregroundStyle(FTColor.textMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(FTSpacing.md)
                                .ftGlass(FTRadius.md)
                            }
                        }
                    }
                }

                VStack(spacing: FTSpacing.md) {
                    Text("INSIGHTS")
                        .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if insightList.isEmpty {
                        EmptyStateView(
                            icon: "sparkles",
                            title: "Not Enough Data Yet",
                            message: "Insights appear once a couple of months of transactions are recorded.")
                    } else {
                        ForEach(insightList.prefix(12)) { insight in
                            HStack(alignment: .top, spacing: FTSpacing.md) {
                                FTIconTile(symbol: insight.icon,
                                           tint: Color.fromString(insight.colorName), size: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(insight.title)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text(insight.message)
                                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(FTSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .ftGlass(FTRadius.md)
                        }
                    }
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .refreshable { recompute() }
        .navigationTitle("Financial Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .onAppear(perform: recompute)
    }

    private func recompute() {
        let engine = FinancialIntelligenceService.shared
        score = engine.healthScore(transactions: Array(transactions), accounts: Array(accounts),
                                   budgets: Array(budgets), goals: Array(goals), loans: Array(loans))
        insightList = engine.insights(transactions: Array(transactions), budgets: Array(budgets),
                                      baseCurrency: baseCurrency)
        predictionList = engine.predictions(transactions: Array(transactions), accounts: Array(accounts),
                                            bills: Array(bills), baseCurrency: baseCurrency)
    }

    // MARK: - Health score card

    private func healthScoreCard(_ score: FinancialHealthScore) -> some View {
        VStack(spacing: FTSpacing.lg) {
            HStack(alignment: .center, spacing: FTSpacing.xl) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(score.overall) / 100)
                        .stroke(scoreColor(score.overall), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(score.overall)")
                            .font(.ftAmount).foregroundStyle(.white)
                        Text(score.grade)
                            .font(.ftCaption).foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("FINANCIAL HEALTH")
                        .font(.ftLabel).tracking(1.6).foregroundStyle(.white.opacity(0.8))
                    ForEach(score.components.prefix(3)) { component in
                        HStack(spacing: FTSpacing.xs) {
                            Text(component.name)
                                .font(.ftCaption).foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("\(Int(component.score))")
                                .font(.ftCaption).bold()
                                .foregroundStyle(scoreColor(Int(component.score)))
                        }
                    }
                }
            }

            VStack(spacing: FTSpacing.sm) {
                ForEach(score.components) { component in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(component.name).font(.ftCaption).foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Text("\(Int(component.score))/100")
                                .font(.ftCaption).foregroundStyle(.white.opacity(0.7))
                        }
                        FTProgressBar(value: component.score / 100,
                                      color: scoreColor(Int(component.score)), height: 5)
                        Text(component.explanation)
                            .font(.ftLabel).tracking(0.2)
                            .foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(FTSpacing.xl)
        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
    }

    private func scoreColor(_ value: Int) -> Color {
        switch value {
        case 70...: return FTColor.income
        case 45..<70: return FTColor.gold
        default: return FTColor.expense
        }
    }
}
