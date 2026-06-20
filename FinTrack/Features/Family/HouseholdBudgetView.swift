import SwiftUI
import SwiftData
import Charts

struct HouseholdBudgetView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]
    @Query private var familyGroups: [FamilyGroup]

    private var group: FamilyGroup? { familyGroups.first(where: { $0.isActive }) }

    private var summary: HouseholdBudgetSummary {
        FamilyService.shared.householdBudgetSummary(
            transactions: transactions, bills: bills, currency: appState.baseCurrency
        )
    }

    private var currentMonthTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date()
        return transactions.filter {
            cal.isDate($0.date, equalTo: now, toGranularity: .month)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                cashFlowOverview
                memberContributions
                expenseBreakdownCard
                billsCard
                monthlyTrendChart
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Household Budget")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
    }

    // MARK: - Cash Flow Overview

    private var cashFlowOverview: some View {
        VStack(spacing: FTSpacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOUSEHOLD CASH FLOW").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(summary.netCashFlow >= 0 ? "+" : "" + summary.netCashFlow.formatted(as: appState.baseCurrency))
                        .font(.ftAmount)
                        .foregroundStyle(summary.netCashFlow >= 0 ? FTColor.income : FTColor.expense)
                    Text("Combined · \(Date().monthName)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(summary.netCashFlow >= 0 ? FTColor.income.opacity(0.1) : FTColor.expense.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: summary.netCashFlow >= 0 ? "house.fill" : "house.fill")
                        .font(.ftTitle)
                        .foregroundStyle(summary.netCashFlow >= 0 ? FTColor.income : FTColor.expense)
                }
            }

            HStack(spacing: FTSpacing.sm) {
                metricTile(label: "Income", value: summary.totalMonthlyIncome, color: FTColor.income, icon: "arrow.down.circle.fill")
                metricTile(label: "Expenses", value: summary.totalMonthlyExpenses, color: FTColor.expense, icon: "arrow.up.circle.fill")
                metricTile(label: "Bills", value: summary.totalMonthlyBills, color: FTColor.catBlue, icon: "calendar.circle.fill")
            }

            VStack(spacing: FTSpacing.sm) {
                HStack {
                    Text("Household Savings Rate")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(summary.savingsRate.asPercentage())
                        .font(.ftBodySemibold)
                        .foregroundStyle(summary.savingsRate >= 0.2 ? FTColor.income : FTColor.gold)
                }
                FTProgressBar(
                    value: summary.savingsRate,
                    color: summary.savingsRate >= 0.2 ? FTColor.income : FTColor.gold,
                    height: 8
                )
                if summary.savingsRate < 0.2 {
                    Text("Aim for 20% savings rate for a healthy household budget")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func metricTile(label: String, value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.ftCaption).foregroundStyle(color)
            Text(value.asCompact(currency: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.md)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    // MARK: - Member Contributions

    @ViewBuilder
    private var memberContributions: some View {
        if let g = group, !g.members.isEmpty {
            let summaries = FamilyService.shared.buildMemberSummaries(
                members: g.members, transactions: transactions, currency: appState.baseCurrency
            )
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("MEMBER CONTRIBUTIONS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                VStack(spacing: FTSpacing.sm) {
                    ForEach(summaries, id: \.member.id) { ms in
                        memberContributionRow(ms.member, income: ms.monthlyIncome, expenses: ms.monthlyExpenses)
                    }
                }
            }
        }
    }

    private func memberContributionRow(_ member: FamilyMemberData, income: Double, expenses: Double) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(member.initials)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: member.avatarColorHex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(member.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(member.role.rawValue).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if income > 0 {
                    Text("+" + income.asCompact(currency: appState.baseCurrency))
                        .font(.ftCallout).foregroundStyle(FTColor.income)
                }
                if expenses > 0 {
                    Text("-" + expenses.asCompact(currency: appState.baseCurrency))
                        .font(.ftCaption).foregroundStyle(FTColor.expense)
                }
                if income == 0 && expenses == 0 {
                    Text("No activity").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.md)
    }

    // MARK: - Expense Breakdown

    private var expenseBreakdownCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TOP SPENDING CATEGORIES").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if summary.topExpenseCategories.isEmpty {
                Text("No expenses recorded this month.")
                    .font(.ftBody).foregroundStyle(FTColor.textMuted)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(summary.topExpenseCategories, id: \.category) { item in
                        VStack(spacing: 6) {
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
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Bills Card

    @ViewBuilder
    private var billsCard: some View {
        let upcomingBills = bills.filter { $0.isActive }.prefix(5)
        if !upcomingBills.isEmpty {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                HStack {
                    Text("UPCOMING BILLS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Text(summary.totalMonthlyBills.formatted(as: appState.baseCurrency))
                        .font(.ftCallout).foregroundStyle(FTColor.catBlue)
                }
                VStack(spacing: FTSpacing.sm) {
                    ForEach(Array(upcomingBills), id: \.id) { bill in
                        billRow(bill)
                    }
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    private func billRow(_ bill: Bill) -> some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(FTColor.catBlue.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: bill.icon).font(.ftCaption).foregroundStyle(FTColor.catBlue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(bill.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Text(bill.nextDueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            Text(bill.amount.formatted(as: appState.baseCurrency))
                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
        }
    }

    // MARK: - Monthly Trend Chart

    private var monthlyTrendChart: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("MONTHLY TREND (6 MONTHS)").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            let data = last6MonthsData()
            if data.isEmpty {
                Text("Not enough data to display trend.")
                    .font(.ftBody).foregroundStyle(FTColor.textMuted).padding()
            } else {
                Chart {
                    ForEach(data, id: \.month) { item in
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Income", item.income)
                        )
                        .foregroundStyle(FTColor.income.opacity(0.8))

                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Expenses", item.expenses)
                        )
                        .foregroundStyle(FTColor.expense.opacity(0.8))
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 180)

                HStack(spacing: FTSpacing.xl) {
                    legendItem(color: FTColor.income, label: "Income")
                    legendItem(color: FTColor.expense, label: "Expenses")
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
    }

    private struct MonthData {
        let month: String
        let income: Double
        let expenses: Double
    }

    private func last6MonthsData() -> [MonthData] {
        let cal = Calendar.current
        let now = Date()
        return (0..<6).reversed().compactMap { offset -> MonthData? in
            guard let date = cal.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let monthTxs = transactions.filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }
            let income = monthTxs.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency }
            let expenses = monthTxs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
            let fmt = DateFormatter(); fmt.dateFormat = "MMM"
            return MonthData(month: fmt.string(from: date), income: income, expenses: expenses)
        }
    }
}
