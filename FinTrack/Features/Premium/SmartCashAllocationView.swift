import SwiftUI
import SwiftData

struct SmartCashAllocationView: View {
    @Environment(AppState.self) private var appState
    @Query private var accounts: [Account]
    @Query private var goals: [SavingsGoal]
    @Query(filter: #Predicate<Loan> { $0.outstandingBalance > 0 }) private var loans: [Loan]
    @Query private var investments: [Investment]

    private var currency: String { appState.baseCurrency }

    private var totalCash: Double { accounts.reduce(0) { $0 + $1.balance } }

    private var monthlyExpensesEstimate: Double {
        // Assume 6-month emergency fund target based on account activity
        totalCash * 0.1 // placeholder: 10% of cash as rough monthly estimate
    }

    private var emergencyFund: Double { monthlyExpensesEstimate * 6 }
    private var idleCash: Double { max(0, totalCash - emergencyFund) }

    private var allocations: [CashAllocation] { generateAllocations() }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                cashOverviewCard
                allocationCard
                waterfallSection
                investmentTipsCard
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Smart Cash Allocation")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Cards

    private var cashOverviewCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Cash").font(.ftLabel).foregroundStyle(FTColor.textSecondary).tracking(1.2)
                    Text(totalCash.formatted(as: currency)).font(.ftDisplay).foregroundStyle(FTColor.textPrimary)
                }
                Spacer()
                FTIconTile(symbol: "brain.head.profile", tint: FTColor.accent, size: 48)
            }

            HStack(spacing: 0) {
                cashStat("Emergency Fund", emergencyFund.asCompact(currency: currency), FTColor.catTeal)
                Spacer()
                cashStat("Idle Cash", idleCash.asCompact(currency: currency),
                         idleCash > 0 ? FTColor.gold : FTColor.textMuted)
                Spacer()
                cashStat("In Investments", investments.reduce(0) { $0 + $1.currentValue }.asCompact(currency: currency), FTColor.income)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var allocationCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundStyle(FTColor.gold)
                Text("AI Recommendations").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            }

            if allocations.isEmpty {
                Text("Great work! Your cash is well-allocated. Keep building your investment portfolio.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
            } else {
                ForEach(allocations) { allocation in
                    AllocationRow(allocation: allocation, currency: currency)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var waterfallSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Cash Waterfall Strategy").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            let steps: [(Int, String, String, Color)] = [
                (1, "Emergency Fund", "3–6 months of expenses in high-yield savings", FTColor.catTeal),
                (2, "High-Interest Debt", "Pay off debt >5% interest rate first", FTColor.expense),
                (3, "Savings Goals", "Fund active goals (home, education, events)", FTColor.catPurple),
                (4, "Invest", "Low-cost index funds, UAE REITs, bonds", FTColor.income),
                (5, "Speculative", "Crypto, individual stocks (<5% of portfolio)", FTColor.catCoral),
            ]

            ForEach(steps, id: \.0) { step, title, desc, color in
                HStack(alignment: .top, spacing: FTSpacing.md) {
                    ZStack {
                        Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                        Text("\(step)").font(.system(size: 12, weight: .bold)).foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text(desc).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var investmentTipsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("UAE Investment Options").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            let options: [(String, String, String)] = [
                ("bank.fill", "High-Yield Savings", "Emirates NBD, FAB, ADCB — up to 4% p.a."),
                ("chart.bar.fill", "UAE Bonds/Sukuk", "Government & corporate sukuk via banks"),
                ("building.fill", "UAE REITs", "Emaar Malls REIT, Emirates REIT on DFM"),
                ("globe", "Global ETFs", "Access via Sarwa, Baraka, StashAway UAE"),
                ("bitcoinsign.circle.fill", "Digital Gold", "Dubai Gold & Commodities Exchange"),
            ]

            ForEach(options, id: \.1) { icon, title, desc in
                HStack(alignment: .top, spacing: FTSpacing.md) {
                    Image(systemName: icon).foregroundStyle(FTColor.accent).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text(desc).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: – Helpers

    private func cashStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
        }
    }

    private func generateAllocations() -> [CashAllocation] {
        var recs: [CashAllocation] = []

        if totalCash < emergencyFund {
            let needed = emergencyFund - totalCash
            recs.append(CashAllocation(
                icon: "shield.fill", color: FTColor.catTeal, priority: 1,
                title: "Build Emergency Fund",
                amount: needed, currency: currency,
                rationale: "You need \(needed.formatted(as: currency)) more for 6 months of expenses. Keep in a high-yield savings account."
            ))
        }

        let highRateLoans = loans.filter { $0.interestRate > 5 }
        if !highRateLoans.isEmpty && idleCash > 0 {
            let totalDebt = highRateLoans.reduce(0) { $0 + $1.outstandingBalance }
            let payoff = min(idleCash * 0.5, totalDebt)
            recs.append(CashAllocation(
                icon: "arrow.down.circle.fill", color: FTColor.expense, priority: 2,
                title: "Accelerate Debt Payoff",
                amount: payoff, currency: currency,
                rationale: "High-interest loans cost you guaranteed returns. Paying \(payoff.formatted(as: currency)) saves interest instantly."
            ))
        }

        let underfundedGoals = goals.filter { $0.progress < 0.5 }
        if !underfundedGoals.isEmpty && idleCash > 5000 {
            let goalAmount = min(idleCash * 0.3, underfundedGoals.reduce(0) { $0 + ($1.targetAmount - $1.currentAmount) })
            recs.append(CashAllocation(
                icon: "star.fill", color: FTColor.catPurple, priority: 3,
                title: "Fund Your Goals",
                amount: goalAmount, currency: currency,
                rationale: "Move \(goalAmount.formatted(as: currency)) into your savings goals to accelerate progress."
            ))
        }

        if idleCash > 10000 && investments.isEmpty {
            recs.append(CashAllocation(
                icon: "chart.line.uptrend.xyaxis", color: FTColor.income, priority: 4,
                title: "Start Investing",
                amount: idleCash * 0.6, currency: currency,
                rationale: "Idle cash loses value to inflation. Consider diversified ETFs or UAE government sukuk for long-term growth."
            ))
        }

        return recs.sorted { $0.priority < $1.priority }
    }
}

struct CashAllocation: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let priority: Int
    let title: String
    let amount: Double
    let currency: String
    let rationale: String
}

struct AllocationRow: View {
    let allocation: CashAllocation
    let currency: String

    var body: some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            FTIconTile(symbol: allocation.icon, tint: allocation.color, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(allocation.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Text(allocation.amount.formatted(as: allocation.currency))
                        .font(.ftBodySemibold).foregroundStyle(allocation.color)
                }
                Text(allocation.rationale).font(.ftCaption).foregroundStyle(FTColor.textSecondary).lineSpacing(3)
            }
        }
        .padding(FTSpacing.sm)
    }
}
