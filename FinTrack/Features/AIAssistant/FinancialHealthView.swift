import SwiftUI
import SwiftData

struct FinancialHealthView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var budgets: [Budget]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var loans: [Loan]
    @Query private var investments: [Investment]

    @State private var result: HealthScoreResult?
    @State private var selectedComponent: HealthScoreResult.HealthComponent?
    @State private var animateScore = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    heroScoreCard
                    if let r = result {
                        componentsSection(r)
                        if !r.improvements.isEmpty { improvementsSection(r) }
                        gradeExplainerSection(r)
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 32)
            }
            .navigationTitle("Financial Health")
            .background { FTBackdrop() }
            .onAppear { compute() }
        }
    }

    // MARK: - Hero Score Card

    private var heroScoreCard: some View {
        VStack(spacing: FTSpacing.xl) {
            ZStack {
                Circle()
                    .stroke(FTColor.textMuted.opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: animateScore ? CGFloat(result?.score ?? 0) / 100 : 0)
                    .stroke(
                        (result?.gradeColor ?? FTColor.accent),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.2), value: animateScore)

                VStack(spacing: 4) {
                    Text(animateScore ? "\(result?.score ?? 0)" : "0")
                        .font(.ftDisplay)
                        .foregroundStyle(result?.gradeColor ?? FTColor.accent)
                        .contentTransition(.numericText())
                    Text(result?.grade ?? "—")
                        .font(.ftHeadline)
                        .foregroundStyle(FTColor.textSecondary)
                    Text("out of 100")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }
            }
            .padding(.top, FTSpacing.xl)

            Text(scoreLabel(result?.score ?? 0))
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.xxl)
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Components

    private func componentsSection(_ r: HealthScoreResult) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("SCORE BREAKDOWN")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                ForEach(r.components) { component in
                    Button {
                        withAnimation(.spring) {
                            selectedComponent = selectedComponent?.id == component.id ? nil : component
                        }
                    } label: {
                        componentRow(component)
                    }
                    .buttonStyle(.plain)

                    if selectedComponent?.id == component.id {
                        componentDetail(component)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private func componentRow(_ component: HealthScoreResult.HealthComponent) -> some View {
        VStack(spacing: FTSpacing.sm) {
            HStack {
                FTIconTile(symbol: component.icon, tint: component.color, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.name)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text(component.detail)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Text("\(component.score)")
                    .font(.ftHeadline)
                    .foregroundStyle(component.color)
                Image(systemName: "chevron.down")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                    .rotationEffect(.degrees(selectedComponent?.id == component.id ? 180 : 0))
                    .animation(.spring, value: selectedComponent?.id)
            }
            FTProgressBar(value: Double(component.score) / 100.0, color: component.color)
                .frame(height: 6)
        }
        .padding()
        .ftGlass(FTRadius.md)
    }

    private func componentDetail(_ component: HealthScoreResult.HealthComponent) -> some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(component.color)
            Text(componentAdvice(component))
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(component.color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    // MARK: - Improvements

    private func improvementsSection(_ r: HealthScoreResult) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("IMPROVEMENT TIPS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                ForEach(Array(r.improvements.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: FTSpacing.md) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(FTColor.gold)
                            .font(.ftCallout)
                            .frame(width: 20)
                        Text(tip)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding()
                    .background(FTColor.gold.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                }
            }
        }
    }

    // MARK: - Grade Explainer

    private func gradeExplainerSection(_ r: HealthScoreResult) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("GRADE SCALE")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: 2) {
                ForEach(gradeScale, id: \.grade) { item in
                    HStack {
                        Text(item.grade)
                            .font(.ftBodySemibold)
                            .foregroundStyle(item.grade == r.grade ? item.color : FTColor.textMuted)
                            .frame(width: 36, alignment: .leading)
                        Text(item.range)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text(item.label)
                            .font(.ftCaption)
                            .foregroundStyle(item.grade == r.grade ? item.color : FTColor.textMuted)
                    }
                    .padding(.horizontal, FTSpacing.md)
                    .padding(.vertical, 6)
                    .background(item.grade == r.grade ? item.color.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                }
            }
            .padding(.vertical, FTSpacing.sm)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Helpers

    private func compute() {
        result = AIAnalyticsService.shared.computeHealthScore(
            transactions: transactions, accounts: accounts, budgets: budgets,
            savingsGoals: savingsGoals, loans: loans, investments: investments,
            currency: appState.baseCurrency
        )
        withAnimation(.spring(duration: 1.0).delay(0.2)) { animateScore = true }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 90...: return "Excellent financial health. You're on track for long-term prosperity."
        case 75..<90: return "Very good. A few tweaks will get you to the top tier."
        case 60..<75: return "Good foundation. Focus on savings rate and emergency fund."
        case 40..<60: return "Room for improvement. Address debt and savings first."
        default: return "Needs attention. Start with an emergency fund and budget plan."
        }
    }

    private func componentAdvice(_ c: HealthScoreResult.HealthComponent) -> String {
        switch c.name {
        case "Savings Rate": return "Aim for 20%+ savings rate. Automate transfers on payday to make saving effortless."
        case "Emergency Fund": return "Keep 3-6 months of expenses in liquid accounts. This protects you from unexpected costs."
        case "Debt Load": return "Keep total debt below 1x annual income. Prioritize high-interest debt first using avalanche method."
        default: return "Diversify across at least 3-5 asset classes: stocks, ETFs, bonds, real estate, and commodities."
        }
    }

    private let gradeScale: [(grade: String, range: String, label: String, color: Color)] = [
        ("A+", "90-100", "Excellent",     FTColor.income),
        ("A",  "80-89",  "Very Good",     FTColor.income),
        ("B+", "70-79",  "Good",          FTColor.accentBright),
        ("B",  "60-69",  "Above Average", FTColor.accentBright),
        ("C+", "50-59",  "Average",       FTColor.gold),
        ("C",  "40-49",  "Below Average", FTColor.gold),
        ("D",  "30-39",  "Poor",          FTColor.expense),
        ("F",  "0-29",   "Critical",      FTColor.expense),
    ]
}
