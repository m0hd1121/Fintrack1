import SwiftUI
import SwiftData
import Charts

// MARK: - Chart palette (Phase 5)

private let ftChartPalette: [Color] = [
    FTColor.accent, FTColor.catTeal, FTColor.catBlue, FTColor.gold,
    FTColor.catCoral, FTColor.catPurple, FTColor.income, FTColor.expense
]

private extension View {
    /// Standard FT minimal chart axes used across reports.
    func ftChartAxes() -> some View {
        self
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textMuted)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(FTColor.textMuted.opacity(0.2))
                    AxisValueLabel().foregroundStyle(FTColor.textMuted)
                }
            }
            .chartPlotStyle { $0.background(Color.clear) }
    }
}

struct ReportsView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var investments: [Investment]
    @Query private var cryptoHoldings: [CryptoHolding]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]

    @State private var selectedPeriod: ReportPeriod = .month
    @State private var selectedReport: ReportType = .cashFlow
    // #16 – custom date range
    @State private var showingCustomRange = false
    @State private var customStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()

    private var baseCurrency: String { appState.baseCurrency }

    private var periodIndex: Binding<Int> {
        Binding(
            get: { ReportPeriod.allCases.firstIndex(of: selectedPeriod) ?? 0 },
            set: { newValue in
                let p = ReportPeriod.allCases[newValue]
                selectedPeriod = p
                if p == .custom { showingCustomRange = true }
            }
        )
    }

    private var filteredTransactions: [Transaction] {
        // #16
        if selectedPeriod == .custom {
            return transactions.filter { $0.date >= customStart && $0.date <= customEnd }
        }
        let cutoff: Date
        switch selectedPeriod {
        case .week:    cutoff = Date().startOfWeek
        case .month:   cutoff = Date().startOfMonth
        case .quarter: cutoff = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .year:    cutoff = Date().startOfYear
        case .custom:  cutoff = customStart
        }
        return transactions.filter { $0.date >= cutoff }
    }

    var body: some View {
            ZStack {
                FTBackdrop()

                VStack(spacing: FTSpacing.md) {
                    // Period selector
                    FTSegmentedControl(options: ReportPeriod.allCases.map(\.rawValue), selection: periodIndex)
                        .padding(.horizontal, FTSpacing.screen)
                        .padding(.top, FTSpacing.sm)

                    // #16 – custom date range picker
                    if selectedPeriod == .custom {
                        HStack(spacing: FTSpacing.lg) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("From").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                DatePicker("", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("To").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                DatePicker("", selection: $customEnd, in: customStart..., displayedComponents: .date)
                                    .labelsHidden()
                            }
                            Spacer()
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)
                    }

                    // Report type selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FTSpacing.sm) {
                            ForEach(ReportType.allCases, id: \.self) { type in
                                FilterChip(title: type.rawValue, isSelected: selectedReport == type) {
                                    selectedReport = type
                                }
                            }
                        }
                        .padding(.horizontal, FTSpacing.screen)
                    }

                    ScrollView {
                        VStack(spacing: FTSpacing.lg) {
                            switch selectedReport {
                            case .cashFlow:
                                CashFlowReport(transactions: filteredTransactions, currency: baseCurrency)
                            case .spending:
                                SpendingReport(transactions: filteredTransactions, currency: baseCurrency)
                            case .income:
                                IncomeReport(transactions: filteredTransactions, currency: baseCurrency)
                            case .netWorth:
                                NetWorthReport(
                                    accounts: accounts,
                                    investments: investments,
                                    cryptos: cryptoHoldings,
                                    loans: loans,
                                    creditCards: creditCards,
                                    currency: baseCurrency
                                )
                            case .trends:
                                TrendsReport(transactions: transactions, currency: baseCurrency)
                            }
                        }
                        .padding(.horizontal, FTSpacing.screen)
                        .padding(.top, FTSpacing.xs)
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
    }
}

enum ReportPeriod: String, CaseIterable {
    case week    = "Week"
    case month   = "Month"
    case quarter = "Quarter"
    case year    = "Year"
    case custom  = "Custom"   // #16
}

enum ReportType: String, CaseIterable {
    case cashFlow = "Cash Flow"
    case spending = "Spending"
    case income = "Income"
    case netWorth = "Net Worth"
    case trends = "Trends"
}

// MARK: - Cash Flow Report

struct CashFlowReport: View {
    let transactions: [Transaction]
    let currency: String

    /// Single pass over all transactions for both totals.
    private var totals: (income: Double, expenses: Double) {
        var income = 0.0, expenses = 0.0
        for tx in transactions {
            if tx.type == .income { income += tx.amountInBaseCurrency }
            else if tx.type == .expense { expenses += tx.amountInBaseCurrency }
        }
        return (income, expenses)
    }

    private var dailyData: [(day: String, income: Double, expense: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let grouped = Dictionary(grouping: transactions) { tx -> String in
            formatter.string(from: tx.date)
        }
        return grouped.map { key, txs in
            let income = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency }
            let expense = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
            return (key, income, expense)
        }.sorted { $0.day < $1.day }.prefix(14).map { $0 }
    }

    var body: some View {
        let (totalIncome, totalExpenses) = totals
        let netCashFlow = totalIncome - totalExpenses
        let dailyData = self.dailyData
        return VStack(spacing: 16) {
            // Summary cards
            HStack(spacing: 12) {
                ReportSummaryCard(title: "Income", amount: totalIncome, currency: currency, color: .green, icon: "arrow.down.circle.fill")
                ReportSummaryCard(title: "Expenses", amount: totalExpenses, currency: currency, color: FTColor.expense, icon: "arrow.up.circle.fill")
            }

            ReportSummaryCard(
                title: "Net Cash Flow",
                amount: netCashFlow,
                currency: currency,
                color: netCashFlow >= 0 ? .blue : FTColor.expense,
                icon: "arrow.left.arrow.right.circle.fill"
            )
            .frame(maxWidth: .infinity)

            // Chart
            if !dailyData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Cash Flow").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

                    Chart {
                        ForEach(dailyData, id: \.day) { data in
                            BarMark(x: .value("Day", data.day), y: .value("Income", data.income))
                                .foregroundStyle(FTColor.income)
                            BarMark(x: .value("Day", data.day), y: .value("Expense", -data.expense))
                                .foregroundStyle(FTColor.expense)
                        }
                        RuleMark(y: .value("Zero", 0))
                            .foregroundStyle(FTColor.textMuted.opacity(0.4))
                    }
                    .frame(height: 200)
                    .ftChartAxes()

                    HStack {
                        Circle().fill(FTColor.income).frame(width: 10, height: 10)
                        Text("Income").font(.caption).foregroundStyle(FTColor.textMuted)
                        Circle().fill(FTColor.expense).frame(width: 10, height: 10)
                        Text("Expenses").font(.caption).foregroundStyle(FTColor.textMuted)
                    }
                }
                .padding()
                .ftGlass(FTRadius.md)
            }
        }
    }
}

// MARK: - Spending Report

struct SpendingReport: View {
    let transactions: [Transaction]
    let currency: String

    private var expensesByCategory: [(category: TransactionCategory, amount: Double, count: Int)] {
        let expenses = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses) { $0.category }
        return grouped.map { cat, txs in
            (category: cat, amount: txs.reduce(0) { $0 + $1.amountInBaseCurrency }, count: txs.count)
        }.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        let expensesByCategory = self.expensesByCategory
        let total = expensesByCategory.reduce(0) { $0 + $1.amount }
        return VStack(spacing: 16) {
            if expensesByCategory.isEmpty {
                EmptyStateView(icon: "chart.pie", title: "No Expenses", message: "No expenses recorded for this period.")
            } else {
                // Pie chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spending Distribution").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

                    Chart {
                        ForEach(Array(expensesByCategory.prefix(8).enumerated()), id: \.element.category) { idx, item in
                            SectorMark(
                                angle: .value("Amount", item.amount),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(ftChartPalette[idx % ftChartPalette.count])
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: 220)
                }
                .padding()
                .ftGlass(FTRadius.md)

                // Category breakdown
                VStack(alignment: .leading, spacing: 0) {
                    Text("Category Breakdown")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                    ForEach(Array(expensesByCategory.prefix(10).enumerated()), id: \.element.category) { idx, item in
                        let tint = ftChartPalette[idx % ftChartPalette.count]
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(tint.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: item.category.icon)
                                    .foregroundStyle(tint)
                                    .font(.ftBody)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category.rawValue).font(.subheadline).fontWeight(.medium)
                                Text("\(item.count) transactions").font(.caption).foregroundStyle(FTColor.textSecondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.amount.formatted(as: currency)).font(.subheadline).fontWeight(.semibold)
                                Text((item.amount / max(total, 1) * 100).asPercentage()).font(.caption).foregroundStyle(FTColor.textSecondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 60)
                    }
                }
                .ftGlass(FTRadius.md)
            }
        }
    }
}

// MARK: - Income Report

struct IncomeReport: View {
    let transactions: [Transaction]
    let currency: String

    private var incomeByCategory: [(category: TransactionCategory, amount: Double)] {
        let income = transactions.filter { $0.type == .income }
        return Dictionary(grouping: income) { $0.category }
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }) }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        let incomeByCategory = self.incomeByCategory
        let total = incomeByCategory.reduce(0) { $0 + $1.1 }
        return VStack(spacing: 16) {
            ReportSummaryCard(title: "Total Income", amount: total, currency: currency, color: .green, icon: "arrow.down.circle.fill")

            if !incomeByCategory.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Income by Source")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        .padding()

                    Chart {
                        ForEach(Array(incomeByCategory.enumerated()), id: \.element.category) { idx, item in
                            BarMark(
                                x: .value("Amount", item.amount),
                                y: .value("Category", item.category.rawValue)
                            )
                            .foregroundStyle(ftChartPalette[idx % ftChartPalette.count])
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: 200)
                    .ftChartAxes()
                    .padding()
                }
                .ftGlass(FTRadius.md)
            } else {
                EmptyStateView(icon: "arrow.down.circle", title: "No Income", message: "No income recorded for this period.")
            }
        }
    }
}

// MARK: - Net Worth Report

struct NetWorthReport: View {
    let accounts: [Account]
    let investments: [Investment]
    let cryptos: [CryptoHolding]
    let loans: [Loan]
    let creditCards: [CreditCard]
    let currency: String
    @Environment(CurrencyService.self) private var currencyService

    private var cashAssets: Double {
        accounts.filter { !$0.isArchived }
            .reduce(0) { $0 + currencyService.convert($1.balance, from: $1.currency, to: currency) }
    }
    private var investmentAssets: Double {
        investments.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: currency) }
    }
    private var cryptoAssets: Double {
        cryptos.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: currency) }
    }
    private var loanDebt: Double {
        loans.filter { $0.isActive }.reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: currency) }
    }
    private var ccDebt: Double {
        creditCards.filter { $0.isActive }.reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: currency) }
    }
    var body: some View {
        let cashAssets = self.cashAssets
        let investmentAssets = self.investmentAssets
        let cryptoAssets = self.cryptoAssets
        let loanDebt = self.loanDebt
        let ccDebt = self.ccDebt
        let totalAssets = cashAssets + investmentAssets + cryptoAssets
        let totalLiabilities = loanDebt + ccDebt
        let netWorth = totalAssets - totalLiabilities
        return VStack(spacing: 16) {
            // Net Worth banner
            VStack(spacing: 8) {
                Text("Net Worth")
                    .font(.subheadline).foregroundStyle(FTColor.textSecondary)
                Text(netWorth.formatted(as: currency))
                    .font(.ftAmount)
                    .foregroundColor(netWorth >= 0 ? .white : FTColor.expense)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(FTColor.portfolioGradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Assets vs Liabilities
            HStack(spacing: 12) {
                ReportSummaryCard(title: "Total Assets", amount: totalAssets, currency: currency, color: .green, icon: "plus.circle.fill")
                ReportSummaryCard(title: "Total Debt", amount: totalLiabilities, currency: currency, color: FTColor.expense, icon: "minus.circle.fill")
            }

            // Breakdown
            VStack(alignment: .leading, spacing: 0) {
                Text("Asset Breakdown").font(.ftHeadline).foregroundStyle(FTColor.textPrimary).padding()

                NetWorthRow(label: "Cash & Bank Accounts", amount: cashAssets, currency: currency, color: .blue, icon: "building.columns.fill")
                Divider().padding(.leading, 56)
                NetWorthRow(label: "Investments (Stocks/ETFs)", amount: investmentAssets, currency: currency, color: .green, icon: "chart.line.uptrend.xyaxis")
                Divider().padding(.leading, 56)
                NetWorthRow(label: "Crypto Holdings", amount: cryptoAssets, currency: currency, color: .orange, icon: "bitcoinsign.circle.fill")

                Divider().padding(.vertical, 4)

                Text("Liabilities").font(.ftHeadline).foregroundStyle(FTColor.textPrimary).padding()

                NetWorthRow(label: "Bank Loans", amount: loanDebt, currency: currency, color: FTColor.expense, icon: "creditcard.fill", isLiability: true)
                Divider().padding(.leading, 56)
                NetWorthRow(label: "Credit Cards", amount: ccDebt, currency: currency, color: FTColor.catCoral, icon: "creditcard.fill", isLiability: true)
            }
            .ftGlass(FTRadius.md)
        }
    }
}

struct NetWorthRow: View {
    let label: String
    let amount: Double
    let currency: String
    let color: Color
    let icon: String
    var isLiability: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            Text(label)
                .font(.subheadline)
            Spacer()
            Text((isLiability ? "-" : "") + amount.formatted(as: currency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isLiability ? FTColor.expense : FTColor.textPrimary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Trends Report

struct TrendsReport: View {
    let transactions: [Transaction]
    let currency: String

    private var monthlyTrends: [(month: String, income: Double, expenses: Double)] {
        var result: [(String, Double, Double)] = []
        for i in (0..<6).reversed() {
            let date = Calendar.current.date(byAdding: .month, value: -i, to: Date()) ?? Date()
            var income = 0.0, expenses = 0.0
            for tx in transactions where tx.date.isSameMonth(as: date) {
                if tx.type == .income { income += tx.amountInBaseCurrency }
                else if tx.type == .expense { expenses += tx.amountInBaseCurrency }
            }
            result.append((date.shortMonthName, income, expenses))
        }
        return result
    }

    var body: some View {
        let monthlyTrends = self.monthlyTrends
        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("6-Month Trend").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

                Chart {
                    ForEach(monthlyTrends, id: \.month) { data in
                        LineMark(x: .value("Month", data.month), y: .value("Income", data.income))
                            .foregroundStyle(FTColor.income)
                            .symbol(Circle().strokeBorder(lineWidth: 2))
                        LineMark(x: .value("Month", data.month), y: .value("Expenses", data.expenses))
                            .foregroundStyle(FTColor.expense)
                            .symbol(Circle().strokeBorder(lineWidth: 2))
                    }
                }
                .frame(height: 220)
                .ftChartAxes()

                HStack {
                    Circle().fill(FTColor.income).frame(width: 10, height: 10)
                    Text("Income").font(.caption).foregroundStyle(FTColor.textMuted)
                    Spacer().frame(width: 16)
                    Circle().fill(FTColor.expense).frame(width: 10, height: 10)
                    Text("Expenses").font(.caption).foregroundStyle(FTColor.textMuted)
                }
            }
            .padding()
            .ftGlass(FTRadius.md)

            // Savings rate trend
            VStack(alignment: .leading, spacing: 8) {
                Text("Savings Rate Trend").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

                Chart {
                    ForEach(monthlyTrends, id: \.month) { data in
                        let rate = data.income > 0 ? ((data.income - data.expenses) / data.income) * 100 : 0
                        BarMark(x: .value("Month", data.month), y: .value("Savings %", rate))
                            .foregroundStyle(rate >= 0 ? AnyShapeStyle(FTColor.accentGradient) : AnyShapeStyle(FTColor.expense))
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Target", 20))
                        .foregroundStyle(FTColor.accent.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("20% target").font(.caption2).foregroundStyle(FTColor.accent)
                        }
                }
                .frame(height: 160)
                .ftChartAxes()
            }
            .padding()
            .ftGlass(FTRadius.md)
        }
    }
}

// MARK: - Supporting Views

struct ReportSummaryCard: View {
    let title: String
    let amount: Double
    let currency: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color).font(.caption)
                Text(title).font(.caption).foregroundStyle(FTColor.textSecondary)
            }
            Text(amount.formatted(as: currency))
                .font(.ftHeadline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
