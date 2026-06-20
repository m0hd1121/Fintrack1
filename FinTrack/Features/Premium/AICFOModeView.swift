import SwiftUI
import SwiftData

struct AICFOModeView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var budgets: [Budget]
    @Query(filter: #Predicate<SavingsGoal> { !$0.isCompleted }) private var goals: [SavingsGoal]
    @Query private var loans: [Loan]
    @Query private var investments: [Investment]

    @State private var selectedPeriod = 0
    private let periods = ["This Week", "This Month", "Last 3 Months"]

    private var currency: String { appState.baseCurrency }

    private var periodTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date()
        let cutoff: Date
        switch selectedPeriod {
        case 0: cutoff = cal.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case 1: cutoff = now.startOfMonth
        default: cutoff = cal.date(byAdding: .month, value: -3, to: now) ?? now
        }
        return transactions.filter { $0.date >= cutoff }
    }

    private var totalIncome: Double {
        periodTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    private var totalExpenses: Double {
        periodTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    private var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return max(0, (totalIncome - totalExpenses) / totalIncome)
    }

    private var netWorth: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }

    private var recommendations: [CFORecommendation] { generateRecommendations() }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                headerCard
                FTSegmentedControl(options: periods, selection: .init(
                    get: { selectedPeriod }, set: { selectedPeriod = $0 }
                ))
                scoreCard
                metricsGrid
                if !recommendations.isEmpty { recommendationsSection }
                cashflowCard
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("AI CFO Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Cards

    private var headerCard: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle()
                    .fill(FTColor.accentGradient)
                    .frame(width: 52, height: 52)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Your AI Chief Financial Officer")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Personalized financial analysis & strategy")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var scoreCard: some View {
        let score = financialHealthScore
        return VStack(spacing: FTSpacing.md) {
            HStack {
                Text("Financial Health Score").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Text("\(score)/100")
                    .font(.ftTitle)
                    .foregroundStyle(scoreColor(score))
            }
            FTProgressBar(value: Double(score) / 100, color: scoreColor(score), height: 12)
            Text(scoreLabel(score))
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.md) {
            metricCard("Income", totalIncome.asCompact(currency: currency), "arrow.down.circle.fill", FTColor.income)
            metricCard("Expenses", totalExpenses.asCompact(currency: currency), "arrow.up.circle.fill", FTColor.expense)
            metricCard("Savings Rate", savingsRate.asPercentage(), "chart.line.uptrend.xyaxis", FTColor.accent)
            metricCard("Net Worth", netWorth.asCompact(currency: currency), "building.columns.fill", FTColor.gold)
        }
    }

    private func metricCard(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: FTSpacing.sm) {
            HStack {
                Image(systemName: icon).foregroundStyle(color).font(.title3)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text(title).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("CFO Recommendations").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            ForEach(recommendations) { rec in
                CFORecommendationCard(rec: rec)
            }
        }
    }

    private var cashflowCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Cashflow Summary").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            let net = totalIncome - totalExpenses
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Cashflow")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                    Text(net.formatted(as: currency))
                        .font(.ftTitle)
                        .foregroundStyle(net >= 0 ? FTColor.income : FTColor.expense)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Burn Rate").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    if totalIncome > 0 {
                        Text((totalExpenses / totalIncome).asPercentage())
                            .font(.ftBodySemibold)
                            .foregroundStyle(totalExpenses > totalIncome ? FTColor.expense : FTColor.textPrimary)
                    }
                }
            }

            if totalExpenses > totalIncome {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(FTColor.expense)
                    Text("Spending exceeds income this period. Review subscriptions and discretionary expenses.")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                .padding(FTSpacing.sm)
                .background(FTColor.expense.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
            }

            topCategories
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var topCategories: some View {
        let cats = Dictionary(grouping: periodTransactions.filter { $0.type == .expense }, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amountInBaseCurrency } }
            .sorted { $0.value > $1.value }
            .prefix(4)

        return VStack(spacing: FTSpacing.sm) {
            ForEach(Array(cats), id: \.key) { cat, amount in
                HStack {
                    Text(cat.rawValue).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(amount.formatted(as: currency)).font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                }
            }
        }
    }

    // MARK: – Score & Recommendations

    private var financialHealthScore: Int {
        var score = 50
        if savingsRate >= 0.20 { score += 20 } else if savingsRate >= 0.10 { score += 10 }
        if netWorth > 0 { score += 10 }
        let debtRatio = loans.reduce(0.0) { $0 + $1.outstandingBalance } / max(1, netWorth)
        if debtRatio < 0.3 { score += 10 } else if debtRatio > 1.0 { score -= 10 }
        if !goals.isEmpty && goals.first(where: { $0.progress > 0.5 }) != nil { score += 10 }
        return min(100, max(0, score))
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 80...: return "Excellent financial health. Keep optimizing your investment returns."
        case 60..<80: return "Good financial position. Focus on increasing savings rate and reducing debt."
        case 40..<60: return "Fair health. Prioritize building an emergency fund and cutting discretionary spend."
        default: return "Needs attention. Focus on reducing expenses and avoiding new debt."
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 70 ? FTColor.income : score >= 50 ? FTColor.gold : FTColor.expense
    }

    private func generateRecommendations() -> [CFORecommendation] {
        var recs: [CFORecommendation] = []

        if savingsRate < 0.10 {
            recs.append(CFORecommendation(
                icon: "exclamationmark.circle.fill", color: FTColor.expense, priority: .high,
                title: "Boost Savings Rate",
                detail: "Savings rate is \(savingsRate.asPercentage()). Target 20% by cutting top expense categories."
            ))
        }

        let totalLoanBalance = loans.reduce(0.0) { $0 + $1.outstandingBalance }
        if totalLoanBalance > 0 {
            let highestRate = loans.max(by: { $0.interestRate < $1.interestRate })
            if let loan = highestRate, loan.interestRate > 5 {
                recs.append(CFORecommendation(
                    icon: "arrow.down.circle.fill", color: FTColor.gold, priority: .medium,
                    title: "Debt Avalanche Strategy",
                    detail: "Focus extra payments on '\(loan.lenderName)' at \(String(format: "%.1f", loan.interestRate))% — highest rate loan."
                ))
            }
        }

        if investments.isEmpty {
            recs.append(CFORecommendation(
                icon: "chart.line.uptrend.xyaxis", color: FTColor.accent, priority: .medium,
                title: "Start Investing",
                detail: "No investments found. Consider low-cost index funds or UAE-based ETFs for long-term growth."
            ))
        }

        if goals.isEmpty {
            recs.append(CFORecommendation(
                icon: "star.fill", color: FTColor.catPurple, priority: .low,
                title: "Set Financial Goals",
                detail: "Define savings goals for emergency fund, retirement, or major purchases to stay motivated."
            ))
        }

        return recs.sorted { $0.priority.order < $1.priority.order }
    }
}

// MARK: – Supporting Types

struct CFORecommendation: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let priority: Priority
    let title: String
    let detail: String

    enum Priority { case high, medium, low
        var order: Int { switch self { case .high: return 0; case .medium: return 1; case .low: return 2 } }
        var label: String { switch self { case .high: return "HIGH"; case .medium: return "MED"; case .low: return "LOW" } }
        var color: Color { switch self { case .high: return FTColor.expense; case .medium: return FTColor.gold; case .low: return FTColor.accent } }
    }
}

struct CFORecommendationCard: View {
    let rec: CFORecommendation

    var body: some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(rec.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: rec.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(rec.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rec.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    BadgeView(text: rec.priority.label, color: rec.priority.color)
                }
                Text(rec.detail).font(.ftCaption).foregroundStyle(FTColor.textSecondary).lineSpacing(3)
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.sm)
    }
}
