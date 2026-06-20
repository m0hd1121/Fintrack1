import SwiftUI
import SwiftData
import Charts

struct ESGAnalysisView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]

    @State private var result: ESGResult?
    @State private var showingBreakdown = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    if let r = result {
                        heroScoreCard(r)
                        carbonCard(r)
                        categoryBreakdownSection(r)
                        insightsSection(r)
                        esgExplainerCard
                    } else {
                        ProgressView().padding(.top, 100)
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 32)
            }
            .navigationTitle("ESG Analysis")
            .background { FTBackdrop() }
            .onAppear { compute() }
        }
    }

    // MARK: - Hero Score Card

    private func heroScoreCard(_ r: ESGResult) -> some View {
        VStack(spacing: FTSpacing.xl) {
            HStack(spacing: FTSpacing.xl) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(FTColor.textMuted.opacity(0.15), lineWidth: 10)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: CGFloat(r.overallScore) / 100)
                        .stroke(esgScoreColor(r.overallScore), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(r.overallScore)")
                            .font(.ftHeadline)
                            .foregroundStyle(esgScoreColor(r.overallScore))
                        Image(systemName: "leaf.fill")
                            .font(.ftCaption)
                            .foregroundStyle(esgScoreColor(r.overallScore))
                    }
                }

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text(esgGrade(r.overallScore))
                        .font(.ftTitle)
                        .foregroundStyle(esgScoreColor(r.overallScore))
                    Text("ESG Score")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)

                    HStack(spacing: FTSpacing.lg) {
                        esgMiniStat(label: "Green", value: r.greenSpending.asCompact(currency: appState.baseCurrency), color: FTColor.income, icon: "leaf.fill")
                        esgMiniStat(label: "High Impact", value: r.highImpactSpending.asCompact(currency: appState.baseCurrency), color: FTColor.expense, icon: "exclamationmark.circle.fill")
                    }
                }
                Spacer()
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func esgMiniStat(label: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9)).foregroundStyle(color)
                Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Text(value).font(.ftCallout).foregroundStyle(color)
        }
    }

    // MARK: - Carbon Card

    private func carbonCard(_ r: ESGResult) -> some View {
        HStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FTColor.expense.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "smoke.fill")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.expense)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("ESTIMATED CARBON FOOTPRINT")
                    .font(.ftLabel)
                    .tracking(1.4)
                    .foregroundStyle(FTColor.textMuted)
                Text(String(format: "%.1f kg CO₂e", r.carbonEstimateKg))
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("from tracked spending this period (estimate)")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }
            Spacer()
        }
        .padding()
        .background(FTColor.expense.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: FTRadius.lg).stroke(FTColor.expense.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Category Breakdown

    private func categoryBreakdownSection(_ r: ESGResult) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Button {
                withAnimation(.spring) { showingBreakdown.toggle() }
            } label: {
                HStack {
                    Text("CATEGORY BREAKDOWN")
                        .font(.ftLabel)
                        .tracking(1.6)
                        .foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                        .rotationEffect(.degrees(showingBreakdown ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            // Always-visible rating summary
            ratingsSummaryChart(r)

            if showingBreakdown {
                categoryList(r)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func ratingsSummaryChart(_ r: ESGResult) -> some View {
        let ratings: [ESGRating] = [.veryGreen, .green, .neutral, .yellow, .red]
        let counts = ratings.map { rating in
            r.categoryBreakdown.values.filter { $0.0 == rating }.count
        }
        let total = Double(counts.reduce(0, +))
        guard total > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            HStack(spacing: 2) {
                ForEach(Array(zip(ratings, counts)), id: \.0.rawValue) { rating, count in
                    if count > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(rating.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 8)
                            .frame(maxWidth: CGFloat(count) / total * 300)
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        )
    }

    private func categoryList(_ r: ESGResult) -> some View {
        let sorted = r.categoryBreakdown
            .sorted { $0.value.1 > $1.value.1 }

        return VStack(spacing: FTSpacing.sm) {
            ForEach(sorted, id: \.key.rawValue) { cat, tuple in
                let (rating, amount) = tuple
                HStack {
                    Image(systemName: rating.icon)
                        .foregroundStyle(rating.color)
                        .font(.ftCallout)
                        .frame(width: 24)
                    Image(systemName: cat.icon)
                        .foregroundStyle(Color.fromString(cat.color))
                        .font(.ftCaption)
                    Text(cat.rawValue)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(amount.formatted(as: appState.baseCurrency))
                            .font(.ftCallout)
                            .foregroundStyle(FTColor.textPrimary)
                        Text(rating.rawValue)
                            .font(.ftCaption)
                            .foregroundStyle(rating.color)
                    }
                }
                .padding(.vertical, 4)
                Divider().opacity(0.2)
            }
        }
    }

    // MARK: - Insights

    private func insightsSection(_ r: ESGResult) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("ESG INSIGHTS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                ForEach(Array(r.insights.enumerated()), id: \.offset) { _, insight in
                    HStack(alignment: .top, spacing: FTSpacing.md) {
                        Image(systemName: "leaf.circle.fill")
                            .foregroundStyle(FTColor.income)
                            .font(.ftCallout)
                        Text(insight)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(FTColor.income.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                }

                if let top = r.topGreenCategory {
                    HStack(alignment: .top, spacing: FTSpacing.md) {
                        Image(systemName: "star.fill").foregroundStyle(FTColor.gold).font(.ftCallout)
                        Text("Your greenest category is \(top.rawValue). Keep it up!")
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    }
                    .padding()
                    .background(FTColor.gold.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                }
            }
        }
    }

    // MARK: - ESG Explainer

    private var esgExplainerCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("ABOUT ESG RATINGS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                ForEach([ESGRating.veryGreen, .green, .neutral, .yellow, .red], id: \.rawValue) { r in
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: r.icon).foregroundStyle(r.color).font(.ftCallout).frame(width: 22)
                        Text(r.rawValue).font(.ftBodySemibold).foregroundStyle(r.color).frame(width: 80, alignment: .leading)
                        Text(esgExplain(r)).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
            }
            .padding()
            .background(FTColor.textMuted.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))

            Text("Carbon estimates use published industry CO₂e factors per dirham spent. They are approximations and not certified environmental data.")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
        }
    }

    // MARK: - Helpers

    private func esgScoreColor(_ score: Int) -> Color {
        score >= 70 ? FTColor.income : score >= 50 ? FTColor.gold : FTColor.expense
    }

    private func esgGrade(_ score: Int) -> String {
        score >= 80 ? "Eco Leader" : score >= 60 ? "Eco Aware" : score >= 40 ? "Developing" : "Needs Work"
    }

    private func esgExplain(_ r: ESGRating) -> String {
        switch r {
        case .veryGreen: return "Education, charity, childcare — high positive social impact"
        case .green:     return "Healthcare, investments, pets — positive social/environmental"
        case .neutral:   return "Food, utilities, rent — necessary, mixed impact"
        case .yellow:    return "Shopping, transportation — moderate environmental impact"
        case .red:       return "Fuel, air travel — high carbon/environmental impact"
        }
    }

    private func compute() {
        result = AIAnalyticsService.shared.analyzeESG(transactions: transactions, currency: appState.baseCurrency)
    }
}
