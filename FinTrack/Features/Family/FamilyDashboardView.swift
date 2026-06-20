import SwiftUI
import SwiftData
import Charts

struct FamilyDashboardView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]
    @Query private var accounts: [Account]
    @Query private var sharedGoals: [SharedFamilyGoal]

    let group: FamilyGroup

    private var summary: HouseholdBudgetSummary {
        FamilyService.shared.householdBudgetSummary(
            transactions: transactions, bills: bills, currency: appState.baseCurrency
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                cashFlowCard
                memberCards
                sharedGoalsPreview
                spendingBreakdown
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Family Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
    }

    // MARK: - Cash Flow Card

    private var cashFlowCard: some View {
        VStack(spacing: FTSpacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOUSEHOLD CASH FLOW").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(summary.netCashFlow >= 0 ? "+" : "" + summary.netCashFlow.formatted(as: appState.baseCurrency))
                        .font(.ftAmount)
                        .foregroundStyle(summary.netCashFlow >= 0 ? FTColor.income : FTColor.expense)
                    Text("This month · \(Date().monthName)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(summary.netCashFlow >= 0 ? FTColor.income.opacity(0.1) : FTColor.expense.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: summary.netCashFlow >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.ftTitle)
                        .foregroundStyle(summary.netCashFlow >= 0 ? FTColor.income : FTColor.expense)
                }
            }

            HStack(spacing: FTSpacing.md) {
                cashFlowStat(label: "Income", value: summary.totalMonthlyIncome, color: FTColor.income, icon: "arrow.down.circle.fill")
                Divider().frame(height: 40)
                cashFlowStat(label: "Expenses", value: summary.totalMonthlyExpenses, color: FTColor.expense, icon: "arrow.up.circle.fill")
                Divider().frame(height: 40)
                cashFlowStat(label: "Bills", value: summary.totalMonthlyBills, color: FTColor.catBlue, icon: "calendar.circle.fill")
            }

            HStack {
                Text("Savings Rate")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text(summary.savingsRate.asPercentage())
                    .font(.ftBodySemibold)
                    .foregroundStyle(summary.savingsRate >= 0.2 ? FTColor.income : FTColor.gold)
            }
            FTProgressBar(value: summary.savingsRate, color: summary.savingsRate >= 0.2 ? FTColor.income : FTColor.gold, height: 6)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func cashFlowStat(label: String, value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.ftCaption).foregroundStyle(color)
            Text(value.asCompact(currency: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Member Cards

    private var memberCards: some View {
        let memberSummaries = FamilyService.shared.buildMemberSummaries(
            members: group.members, transactions: transactions, currency: appState.baseCurrency
        )
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("FAMILY MEMBERS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ForEach(memberSummaries, id: \.member.id) { ms in
                    memberCard(ms.member, income: ms.monthlyIncome, expenses: ms.monthlyExpenses)
                }
            }
        }
    }

    private func memberCard(_ member: FamilyMemberData, income: Double, expenses: Double) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(member.initials)
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color(hex: member.avatarColorHex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if member.isCurrentUser {
                        Text("You").font(.ftCaption).foregroundStyle(FTColor.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(FTColor.accent.opacity(0.1)).clipShape(Capsule())
                    }
                }
                Text(member.role.rawValue).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }

            Spacer()

            if income > 0 || expenses > 0 {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(income.asCompact(currency: appState.baseCurrency))
                        .font(.ftCallout).foregroundStyle(FTColor.income)
                    Text(expenses.asCompact(currency: appState.baseCurrency))
                        .font(.ftCaption).foregroundStyle(FTColor.expense)
                }
            } else {
                Text(member.defaultPermission.rawValue)
                    .font(.ftCaption)
                    .foregroundStyle(member.defaultPermission.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(member.defaultPermission.color.opacity(0.1)).clipShape(Capsule())
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Shared Goals Preview

    @ViewBuilder
    private var sharedGoalsPreview: some View {
        let active = sharedGoals.filter { !$0.isCompleted && !$0.isArchived }
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                HStack {
                    Text("SHARED GOALS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                    Spacer()
                    NavigationLink("See All") {
                        SharedFamilyGoalsView(group: group)
                    }
                    .font(.ftCallout).foregroundStyle(FTColor.accent)
                }

                ForEach(active.prefix(3)) { goal in
                    goalPreviewRow(goal)
                }
            }
        }
    }

    private func goalPreviewRow(_ goal: SharedFamilyGoal) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                ZStack {
                    Circle().fill(Color(hex: goal.colorHex).opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: goal.icon).font(.ftCaption).foregroundStyle(Color(hex: goal.colorHex))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text("\(goal.totalContributed.asCompact(currency: appState.baseCurrency)) of \(goal.targetAmount.asCompact(currency: appState.baseCurrency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Text(goal.progress.asPercentage()).font(.ftCallout).foregroundStyle(Color(hex: goal.colorHex))
            }
            FTProgressBar(value: goal.progress, color: Color(hex: goal.colorHex), height: 5)
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Spending Breakdown

    private var spendingBreakdown: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TOP SPENDING CATEGORIES").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ForEach(summary.topExpenseCategories, id: \.category) { item in
                    HStack {
                        Text(item.category).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text(item.amount.formatted(as: appState.baseCurrency))
                            .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                        Text(item.percentage.asPercentage())
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            .frame(width: 40, alignment: .trailing)
                    }
                    FTProgressBar(value: item.percentage, color: FTColor.expense, height: 4)
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }
}
