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
    @Query private var goldHoldings: [GoldHolding]
    @Query private var dividends: [Dividend]
    @Query private var loans: [Loan]
    @Query private var realEstateProperties: [RealEstateProperty]
    @Query private var vehicles: [Vehicle]
    @Query private var personalAssets: [PersonalAsset]
    @Query private var digitalAssets: [DigitalAsset]
    @Query private var creditCards: [CreditCard]
    @Query private var moneyLent: [MoneyLent]
    @Query private var moneyBorrowed: [MoneyBorrowed]
    @Query private var savingsGoals: [SavingsGoal]

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
                            case .investments:
                                InvestmentReport(
                                    investments: investments,
                                    cryptos: cryptoHoldings,
                                    golds: goldHoldings,
                                    dividends: dividends,
                                    currency: baseCurrency
                                )
                            case .debt:
                                DebtReport(
                                    loans: loans,
                                    creditCards: creditCards,
                                    moneyLent: Array(moneyLent),
                                    moneyBorrowed: Array(moneyBorrowed),
                                    currency: baseCurrency
                                )
                            case .netWorth:
                                NetWorthReport(
                                    accounts: accounts,
                                    investments: investments,
                                    cryptos: cryptoHoldings,
                                    golds: goldHoldings,
                                    realEstate: realEstateProperties,
                                    vehicles: vehicles,
                                    personalAssets: personalAssets,
                                    digitalAssets: digitalAssets,
                                    loans: loans,
                                    creditCards: creditCards,
                                    currency: baseCurrency
                                )
                            case .trends:
                                TrendsReport(transactions: transactions, currency: baseCurrency)
                            case .savingsGoals:
                                SavingsGoalsReport(goals: savingsGoals, transactions: transactions, currency: baseCurrency)
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
    case cashFlow    = "Cash Flow"
    case spending    = "Spending"
    case income      = "Income"
    case investments = "Investments"
    case debt        = "Debt"
    case netWorth    = "Net Worth"
    case trends      = "Trends"
    case savingsGoals = "Goals"
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

    private var incomeByCategory: [(category: TransactionCategory, amount: Double, count: Int)] {
        let income = transactions.filter { $0.type == .income && !$0.isPending && !$0.isScheduled }
        return Dictionary(grouping: income) { $0.category }
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }, count: $0.value.count) }
            .sorted { $0.amount > $1.amount }
    }

    private var monthlyTrend: [(month: String, amount: Double)] {
        var result: [(String, Double)] = []
        for i in (0..<6).reversed() {
            let date = Calendar.current.date(byAdding: .month, value: -i, to: Date()) ?? Date()
            let amount = transactions
                .filter { $0.type == .income && !$0.isPending && !$0.isScheduled && $0.date.isSameMonth(as: date) }
                .reduce(0) { $0 + $1.amountInBaseCurrency }
            result.append((date.shortMonthName, amount))
        }
        return result
    }

    private var incomeBySource: [(source: String, amount: Double)] {
        let income = transactions.filter { $0.type == .income && !$0.isPending && !$0.isScheduled }
        let grouped = Dictionary(grouping: income) { tx -> String in
            tx.incomeSource ?? tx.category.rawValue
        }
        return grouped.map { (source: $0.key, amount: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }) }
            .sorted { $0.amount > $1.amount }
            .prefix(8).map { $0 }
    }

    var body: some View {
        let incomeByCategory = self.incomeByCategory
        let total = incomeByCategory.reduce(0) { $0 + $1.amount }
        let trend = self.monthlyTrend
        let bySource = self.incomeBySource
        let avgMonthly = trend.isEmpty ? 0 : trend.reduce(0) { $0 + $1.amount } / Double(trend.count)

        return VStack(spacing: 16) {
            HStack(spacing: 12) {
                ReportSummaryCard(title: "Total Income", amount: total, currency: currency, color: .green, icon: "arrow.down.circle.fill")
                ReportSummaryCard(title: "Avg Monthly", amount: avgMonthly, currency: currency, color: FTColor.accent, icon: "calendar.circle.fill")
            }

            if !trend.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("6-Month Income Trend").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Chart {
                        ForEach(trend, id: \.month) { data in
                            BarMark(x: .value("Month", data.month), y: .value("Income", data.amount))
                                .foregroundStyle(AnyShapeStyle(FTColor.accentGradient))
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 160)
                    .ftChartAxes()
                }
                .padding()
                .ftGlass(FTRadius.md)
            }

            if !incomeByCategory.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Income by Category")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        .padding()

                    Chart {
                        ForEach(Array(incomeByCategory.prefix(8).enumerated()), id: \.element.category) { idx, item in
                            BarMark(
                                x: .value("Amount", item.amount),
                                y: .value("Category", item.category.rawValue)
                            )
                            .foregroundStyle(ftChartPalette[idx % ftChartPalette.count])
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: max(160, CGFloat(min(incomeByCategory.count, 8)) * 36))
                    .ftChartAxes()
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .ftGlass(FTRadius.md)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Category Breakdown")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        .padding()
                    ForEach(Array(incomeByCategory.prefix(10).enumerated()), id: \.element.category) { idx, item in
                        HStack(spacing: 12) {
                            let tint = ftChartPalette[idx % ftChartPalette.count]
                            ZStack {
                                Circle().fill(tint.opacity(0.15)).frame(width: 40, height: 40)
                                Image(systemName: item.category.icon).foregroundStyle(tint).font(.ftBody)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category.rawValue).font(.subheadline).fontWeight(.medium)
                                Text("\(item.count) transaction\(item.count == 1 ? "" : "s")")
                                    .font(.caption).foregroundStyle(FTColor.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.amount.formatted(as: currency)).font(.subheadline).fontWeight(.semibold)
                                Text(total > 0 ? (item.amount / total * 100).asPercentage() : "0%")
                                    .font(.caption).foregroundStyle(FTColor.textSecondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        if idx < incomeByCategory.prefix(10).count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .ftGlass(FTRadius.md)

                if !bySource.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Income by Source")
                            .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                            .padding()
                        ForEach(Array(bySource.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 12) {
                                let tint = ftChartPalette[idx % ftChartPalette.count]
                                Circle().fill(tint).frame(width: 10, height: 10)
                                    .padding(.leading, 8)
                                Text(item.source).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                Spacer()
                                Text(item.amount.formatted(as: currency))
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                                    .padding(.trailing, 8)
                            }
                            .padding(.vertical, 10)
                            if idx < bySource.count - 1 { Divider().padding(.leading, 28) }
                        }
                        .padding(.bottom, 4)
                    }
                    .ftGlass(FTRadius.md)
                }
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
    let golds: [GoldHolding]
    let realEstate: [RealEstateProperty]
    let vehicles: [Vehicle]
    let personalAssets: [PersonalAsset]
    let digitalAssets: [DigitalAsset]
    let loans: [Loan]
    let creditCards: [CreditCard]
    let currency: String
    @Environment(CurrencyService.self) private var currencyService

    private var svc: NetWorthService { .shared }

    private var cashTotal: Double { accounts.filter { !$0.isArchived && !$0.isHidden }.reduce(0) { $0 + currencyService.convert($1.balance, from: $1.currency, to: currency) } }
    private var investTotal: Double { investments.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: currency) } }
    private var cryptoTotal: Double { cryptos.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: currency) } }
    private var goldTotal: Double { golds.filter { !$0.isArchived }.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: currency) } }
    private var reTotal: Double { svc.realEstateTotal(realEstate: realEstate, currencyService: currencyService, base: currency) }
    private var vehTotal: Double { svc.vehicleTotal(vehicles: vehicles, currencyService: currencyService, base: currency) }
    private var paTotal: Double { svc.personalAssetTotal(assets: personalAssets, currencyService: currencyService, base: currency) }
    private var daTotal: Double { svc.digitalAssetTotal(assets: digitalAssets, currencyService: currencyService, base: currency) }
    private var loanDebt: Double { loans.filter { $0.isActive }.reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: currency) } }
    private var ccDebt: Double { creditCards.filter { $0.isActive }.reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: currency) } }

    var body: some View {
        let totalAssets = cashTotal + investTotal + cryptoTotal + goldTotal + reTotal + vehTotal + paTotal + daTotal
        let totalLiabilities = loanDebt + ccDebt
        let netWorth = totalAssets - totalLiabilities
        return VStack(spacing: FTSpacing.lg) {
            // Net Worth hero
            VStack(spacing: FTSpacing.sm) {
                Text("Net Worth").font(.ftCaption).foregroundStyle(.white.opacity(0.7))
                Text(netWorth.formatted(as: currency)).font(.ftAmount)
                    .foregroundStyle(netWorth >= 0 ? Color.white : FTColor.expense)
                HStack(spacing: FTSpacing.lg) {
                    VStack(spacing: 2) {
                        Text("Assets").font(.ftLabel).foregroundStyle(.white.opacity(0.7))
                        Text(totalAssets.asCompact(currency: currency)).font(.ftCallout).foregroundStyle(.white)
                    }
                    Text("|").foregroundStyle(.white.opacity(0.3))
                    VStack(spacing: 2) {
                        Text("Liabilities").font(.ftLabel).foregroundStyle(.white.opacity(0.7))
                        Text(totalLiabilities.asCompact(currency: currency)).font(.ftCallout).foregroundStyle(FTColor.expense)
                    }
                }
            }
            .frame(maxWidth: .infinity).padding(FTSpacing.xl)
            .background(FTColor.portfolioGradient).clipShape(RoundedRectangle(cornerRadius: FTRadius.lg))

            // Asset breakdown
            VStack(alignment: .leading, spacing: 0) {
                Text("Assets").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
                let assetRows: [(label: String, amount: Double, icon: String, color: Color)] = [
                    ("Cash & Accounts", cashTotal, "banknote.fill", FTColor.accent),
                    ("Investments", investTotal, "chart.line.uptrend.xyaxis", FTColor.catBlue),
                    ("Crypto", cryptoTotal, "bitcoinsign.circle.fill", FTColor.catPurple),
                    ("Gold & Metals", goldTotal, "star.circle.fill", FTColor.gold),
                    ("Real Estate", reTotal, "house.fill", FTColor.catCoral),
                    ("Vehicles", vehTotal, "car.fill", .blue),
                    ("Personal Assets", paTotal, "sparkles", .orange),
                    ("Digital Assets", daTotal, "globe", .teal)
                ].filter { $0.amount > 0 }
                ForEach(Array(assetRows.enumerated()), id: \.offset) { idx, row in
                    NetWorthRow(label: row.label, amount: row.amount, currency: currency, color: row.color, icon: row.icon)
                    if idx < assetRows.count - 1 { Divider().padding(.leading, 56) }
                }
            }
            .ftGlass(FTRadius.lg)

            // Liabilities breakdown
            VStack(alignment: .leading, spacing: 0) {
                Text("Liabilities").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
                NetWorthRow(label: "Bank Loans", amount: loanDebt, currency: currency, color: FTColor.expense, icon: "doc.text.fill", isLiability: true)
                if ccDebt > 0 {
                    Divider().padding(.leading, 56)
                    NetWorthRow(label: "Credit Cards", amount: ccDebt, currency: currency, color: FTColor.catCoral, icon: "creditcard.fill", isLiability: true)
                }
            }
            .ftGlass(FTRadius.lg)
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

// MARK: - Debt Report

struct DebtReport: View {
    let loans: [Loan]
    let creditCards: [CreditCard]
    let moneyLent: [MoneyLent]
    let moneyBorrowed: [MoneyBorrowed]
    let currency: String
    @Environment(CurrencyService.self) private var currencyService

    private var activeLoans: [Loan] { loans.filter { $0.isActive } }
    private var activeCards: [CreditCard] { creditCards.filter { $0.isActive } }

    private var totalLoanDebt: Double {
        activeLoans.reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: currency) }
    }
    private var totalCardDebt: Double {
        activeCards.reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: currency) }
    }
    private var totalPersonalDebt: Double {
        moneyBorrowed.filter { !$0.isFullyRepaid }.reduce(0) {
            $0 + currencyService.convert($1.remainingBalance, from: $1.currency, to: currency)
        }
    }
    private var totalDebt: Double { totalLoanDebt + totalCardDebt + totalPersonalDebt }
    private var totalLent: Double {
        moneyLent.filter { !$0.isFullyRepaid }.reduce(0) {
            $0 + currencyService.convert($1.remainingBalance, from: $1.currency, to: currency)
        }
    }
    private var totalMonthlyPayments: Double {
        activeLoans.reduce(0) { $0 + currencyService.convert($1.emiAmount, from: $1.currency, to: currency) }
        + activeCards.reduce(0) { $0 + currencyService.convert($1.minimumPayment, from: $1.currency, to: currency) }
    }

    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            // Summary hero
            VStack(spacing: FTSpacing.md) {
                HStack {
                    ReportSummaryCard(title: "Total Debt", amount: totalDebt, currency: currency,
                                      color: FTColor.expense, icon: "creditcard.fill")
                    ReportSummaryCard(title: "Outstanding Lent", amount: totalLent, currency: currency,
                                      color: FTColor.income, icon: "hand.raised.fill")
                }
                HStack {
                    ReportSummaryCard(title: "Monthly Payments", amount: totalMonthlyPayments,
                                      currency: currency, color: FTColor.catPurple, icon: "calendar")
                    ReportSummaryCard(title: "Net Position", amount: totalLent - totalDebt,
                                      currency: currency,
                                      color: totalLent >= totalDebt ? FTColor.income : FTColor.expense,
                                      icon: "scalemass")
                }
            }

            // Breakdown by type
            if totalDebt > 0 {
                VStack(alignment: .leading, spacing: FTSpacing.md) {
                    Text("Debt Breakdown")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

                    VStack(spacing: 0) {
                        if totalLoanDebt > 0 {
                            debtBreakdownRow(label: "Bank Loans", amount: totalLoanDebt,
                                             total: totalDebt, color: FTColor.catPurple,
                                             icon: "building.columns")
                            Divider().padding(.leading, 56)
                        }
                        if totalCardDebt > 0 {
                            debtBreakdownRow(label: "Credit Cards", amount: totalCardDebt,
                                             total: totalDebt, color: FTColor.expense,
                                             icon: "creditcard")
                            Divider().padding(.leading, 56)
                        }
                        if totalPersonalDebt > 0 {
                            debtBreakdownRow(label: "Personal Borrowed", amount: totalPersonalDebt,
                                             total: totalDebt, color: FTColor.catCoral,
                                             icon: "person.fill")
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.lg)
                }
            }

            // Active loans detail
            if !activeLoans.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.md) {
                    Text("Loan Details")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

                    VStack(spacing: 0) {
                        ForEach(Array(activeLoans.enumerated()), id: \.element.id) { idx, loan in
                            HStack(spacing: FTSpacing.md) {
                                FTIconTile(symbol: loan.loanType.icon, tint: FTColor.catPurple, size: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(loan.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text("\(loan.interestRate.asPercentage()) APR · \(loan.remainingInstallments) payments left")
                                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                }
                                Spacer()
                                Text(currencyService.convert(loan.outstandingBalance, from: loan.currency, to: currency).formatted(as: currency))
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                            }
                            .padding(.vertical, FTSpacing.md)
                            if idx < activeLoans.count - 1 { Divider().padding(.leading, 56) }
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.lg)
                }
            }

            // Credit cards utilization
            if !activeCards.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.md) {
                    Text("Credit Card Utilization")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

                    VStack(spacing: 0) {
                        ForEach(Array(activeCards.enumerated()), id: \.element.id) { idx, card in
                            VStack(spacing: FTSpacing.sm) {
                                HStack {
                                    FTIconTile(symbol: "creditcard.fill",
                                               tint: Color.fromString(card.color), size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        Text(card.bankName).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                    }
                                    Spacer()
                                    Text(card.utilizationRate.asPercentage())
                                        .font(.ftBodySemibold)
                                        .foregroundStyle(card.utilizationRate > 0.5 ? FTColor.expense :
                                                         card.utilizationRate > 0.3 ? .orange : FTColor.income)
                                }
                                FTProgressBar(
                                    value: card.utilizationRate,
                                    color: card.utilizationRate > 0.5 ? FTColor.expense :
                                           card.utilizationRate > 0.3 ? .orange : FTColor.income
                                )
                            }
                            .padding(.vertical, FTSpacing.md)
                            if idx < activeCards.count - 1 { Divider().padding(.leading, 56) }
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.lg)
                }
            }

            // Money lent summary
            if !moneyLent.filter({ !$0.isFullyRepaid }).isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.md) {
                    Text("Money You've Lent")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

                    VStack(spacing: 0) {
                        let active = moneyLent.filter { !$0.isFullyRepaid }
                        ForEach(Array(active.enumerated()), id: \.element.id) { idx, lent in
                            HStack(spacing: FTSpacing.md) {
                                FTIconTile(symbol: "hand.raised.fill",
                                           tint: Color.fromString(lent.color), size: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(lent.borrowerName)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text(lent.computedStatus.rawValue)
                                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                }
                                Spacer()
                                Text(currencyService.convert(lent.remainingBalance, from: lent.currency, to: currency).formatted(as: currency))
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                            }
                            .padding(.vertical, FTSpacing.md)
                            if idx < active.count - 1 { Divider().padding(.leading, 56) }
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.lg)
                }
            }

            if totalDebt == 0 && totalLent == 0 {
                VStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "checkmark.seal.fill", tint: FTColor.income, size: 60)
                    Text("Debt-Free!").font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                    Text("No active debts. Keep it up!")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding(.top, FTSpacing.md)
    }

    private func debtBreakdownRow(label: String, amount: Double, total: Double,
                                   color: Color, icon: String) -> some View {
        VStack(spacing: FTSpacing.sm) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: icon, tint: color, size: 36)
                Text(label).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(amount.formatted(as: currency))
                        .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                    Text((total > 0 ? amount / total : 0).asPercentage())
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
            FTProgressBar(value: total > 0 ? amount / total : 0, color: color)
        }
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - Investment Report

struct InvestmentReport: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState

    let investments: [Investment]
    let cryptos: [CryptoHolding]
    let golds: [GoldHolding]
    let dividends: [Dividend]
    let currency: String

    private var svc: InvestmentService { .shared }
    private var baseCurrency: String { appState.baseCurrency }

    private var totalValue: Double {
        svc.totalValue(investments: investments, cryptos: cryptos, golds: golds,
                       currencyService: currencyService, baseCurrency: baseCurrency)
    }
    private var totalCost: Double {
        svc.totalCost(investments: investments, cryptos: cryptos, golds: golds,
                      currencyService: currencyService, baseCurrency: baseCurrency)
    }
    private var unrealizedPnL: Double { totalValue - totalCost }
    private var realizedPnL: Double {
        svc.totalRealizedPnL(investments: investments, cryptos: cryptos,
                             currencyService: currencyService, baseCurrency: baseCurrency)
    }
    private var annualDividends: Double {
        svc.annualDividendIncome(dividends: dividends, currencyService: currencyService,
                                 baseCurrency: baseCurrency)
    }
    private var gainsSummary: CapitalGainsSummary {
        svc.capitalGainsSummary(investments: investments, cryptos: cryptos,
                                currencyService: currencyService, baseCurrency: baseCurrency)
    }
    private var allocationSlices: [AllocationSlice] {
        svc.allocationSlices(investments: investments, cryptos: cryptos, golds: golds,
                             accounts: [], currencyService: currencyService,
                             baseCurrency: baseCurrency)
    }
    private var portfolioReturn: Double {
        svc.portfolioReturn(investments: investments, cryptos: cryptos, golds: golds,
                            currencyService: currencyService, baseCurrency: baseCurrency)
    }

    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            // Summary cards
            portfolioSummarySection
            // Allocation donut
            if !allocationSlices.isEmpty { allocationSection }
            // Capital gains
            capitalGainsSection
            // Dividends
            if annualDividends > 0 { dividendSection }
        }
    }

    private var portfolioSummarySection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Portfolio Summary")
                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            VStack(spacing: 0) {
                summaryRow(label: "Total Value", value: totalValue, highlight: false)
                Divider().padding(.leading, 16)
                summaryRow(label: "Total Cost", value: totalCost, highlight: false)
                Divider().padding(.leading, 16)
                summaryRow(label: "Unrealized P&L", value: unrealizedPnL, highlight: true)
                Divider().padding(.leading, 16)
                summaryRow(label: "Realized P&L", value: realizedPnL, highlight: true)
                Divider().padding(.leading, 16)
                HStack {
                    Text("Total Return").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(portfolioReturn.asPercentage(decimals: 2))
                        .font(.ftBodySemibold)
                        .foregroundStyle(portfolioReturn >= 0 ? FTColor.income : FTColor.expense)
                }
                .padding(.horizontal, FTSpacing.lg)
                .padding(.vertical, FTSpacing.md)
            }
            .ftGlass(FTRadius.lg)
        }
    }

    private func summaryRow(label: String, value: Double, highlight: Bool) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value.formatted(as: baseCurrency))
                .font(.ftBodySemibold)
                .foregroundStyle(highlight ? (value >= 0 ? FTColor.income : FTColor.expense) : FTColor.textPrimary)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }

    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Asset Allocation")
                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Chart(allocationSlices) { slice in
                SectorMark(
                    angle: .value("Value", slice.value),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .foregroundStyle(slice.color)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .padding(.vertical, FTSpacing.sm)

            VStack(spacing: 0) {
                ForEach(Array(allocationSlices.enumerated()), id: \.element.id) { idx, slice in
                    HStack(spacing: FTSpacing.md) {
                        Circle().fill(slice.color).frame(width: 10, height: 10)
                        Text(slice.label).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Spacer()
                        Text(slice.value.asCompact(currency: baseCurrency))
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text(slice.percentage.asPercentage())
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .padding(.vertical, FTSpacing.md)
                    if idx < allocationSlices.count - 1 {
                        Divider().padding(.leading, 42)
                    }
                }
            }
            .ftGlass(FTRadius.lg)
        }
    }

    private var capitalGainsSection: some View {
        let s = gainsSummary
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Capital Gains").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            VStack(spacing: 0) {
                gainRow(label: "Realized Gain", value: s.totalRealizedGain, color: FTColor.income)
                Divider().padding(.leading, 16)
                gainRow(label: "Realized Loss", value: -s.totalRealizedLoss, color: FTColor.expense)
                Divider().padding(.leading, 16)
                gainRow(label: "Net Realized", value: s.netRealized, color: s.netRealized >= 0 ? FTColor.income : FTColor.expense)
                Divider().padding(.leading, 16)
                gainRow(label: "Short-term Gain", value: s.shortTermGain, color: FTColor.catCoral)
                Divider().padding(.leading, 16)
                gainRow(label: "Long-term Gain", value: s.longTermGain, color: FTColor.income)
                Divider().padding(.leading, 16)
                gainRow(label: "Unrealized", value: s.totalUnrealized, color: s.totalUnrealized >= 0 ? FTColor.income : FTColor.expense)
            }
            .ftGlass(FTRadius.lg)
        }
    }

    private func gainRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value.formatted(as: baseCurrency))
                .font(.ftBodySemibold).foregroundStyle(color)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }

    private var dividendSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Dividend Income").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            HStack {
                FTIconTile(symbol: "dollarsign.circle.fill", tint: FTColor.income, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text("YTD Dividends")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Text(annualDividends.formatted(as: baseCurrency))
                        .font(.ftTitle).foregroundStyle(FTColor.income)
                }
                Spacer()
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }
}

// MARK: - Savings Goals Report

struct SavingsGoalsReport: View {
    let goals: [SavingsGoal]
    let transactions: [Transaction]
    let currency: String

    private var activeGoals: [SavingsGoal] { goals.filter { !$0.isArchived && !$0.isCompleted } }
    private var completedGoals: [SavingsGoal] { goals.filter { $0.isCompleted } }
    private var archivedGoals: [SavingsGoal] { goals.filter { $0.isArchived && !$0.isCompleted } }

    private var totalSaved: Double { activeGoals.reduce(0) { $0 + $1.currentAmount } }
    private var totalTarget: Double { activeGoals.reduce(0) { $0 + $1.targetAmount } }
    private var overallProgress: Double { totalTarget > 0 ? min(totalSaved / totalTarget, 1.0) : 0 }
    private var svc = SavingsGoalService.shared

    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            summaryCard
            if !activeGoals.isEmpty { activeGoalsSection }
            if !completedGoals.isEmpty { completedSection }
            if !archivedGoals.isEmpty { archivedSection }
            if goals.isEmpty { emptyState }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("SAVINGS SUMMARY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: FTSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Goals").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text("\(activeGoals.count)").font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Saved").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text(totalSaved.asCompact(currency: currency)).font(.ftTitle).foregroundStyle(FTColor.income)
                    }
                }
                FTProgressBar(value: overallProgress, color: FTColor.income)
                HStack {
                    Text("\(Int(overallProgress * 100))% of \(totalTarget.asCompact(currency: currency)) total target")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text("\(completedGoals.count) completed")
                        .font(.ftCaption).foregroundStyle(FTColor.income)
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("ACTIVE GOALS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: FTSpacing.sm) {
                ForEach(activeGoals.sorted { $0.progress > $1.progress }) { goal in
                    goalReportRow(goal)
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("COMPLETED").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: FTSpacing.sm) {
                ForEach(completedGoals) { goal in goalReportRow(goal) }
            }
        }
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("ARCHIVED").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: FTSpacing.sm) {
                ForEach(archivedGoals) { goal in goalReportRow(goal) }
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "star.fill",
            title: "No Savings Goals",
            message: "Create savings goals to see your progress here."
        )
        .ftGlass(FTRadius.lg)
    }

    private func goalReportRow(_ goal: SavingsGoal) -> some View {
        let tint = Color.fromString(goal.effectiveColor)
        let status = svc.goalStatus(for: goal)
        return VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: goal.effectiveIcon, tint: tint, size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text(goal.goalType.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(goal.currentAmount.asCompact(currency: goal.currency))
                        .font(.ftBodySemibold).foregroundStyle(tint)
                    Text("/ \(goal.targetAmount.asCompact(currency: goal.currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
            FTProgressBar(value: goal.progress, color: tint)
            HStack {
                BadgeView(text: svc.statusLabel(for: status), color: svc.statusColor(for: status))
                Spacer()
                if let months = goal.monthsRemaining {
                    Text("\(months) months left").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                if goal.autoContributionEnabled {
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 12)).foregroundStyle(FTColor.accent)
                }
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}
