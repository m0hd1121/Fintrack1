import SwiftUI
import SwiftData
import Charts
import UIKit

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
    @State private var showingExportMenu = false

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

    private var previousFilteredTransactions: [Transaction] {
        switch selectedPeriod {
        case .week:
            let end = Date().startOfWeek
            let start = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: end) ?? end
            return transactions.filter { $0.date >= start && $0.date < end }
        case .month:
            let end = Date().startOfMonth
            let start = Calendar.current.date(byAdding: .month, value: -1, to: end) ?? end
            return transactions.filter { $0.date >= start && $0.date < end }
        case .quarter:
            let end = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            let start = Calendar.current.date(byAdding: .month, value: -3, to: end) ?? end
            return transactions.filter { $0.date >= start && $0.date < end }
        case .year:
            let end = Date().startOfYear
            let start = Calendar.current.date(byAdding: .year, value: -1, to: end) ?? end
            return transactions.filter { $0.date >= start && $0.date < end }
        case .custom:
            let duration = customEnd.timeIntervalSince(customStart)
            let prevEnd = customStart
            let prevStart = prevEnd.addingTimeInterval(-duration)
            return transactions.filter { $0.date >= prevStart && $0.date < prevEnd }
        }
    }

    private var periodLabel: String {
        switch selectedPeriod {
        case .week:    return "This Week"
        case .month:   return "This Month"
        case .quarter: return "Last 3 Months"
        case .year:    return "This Year"
        case .custom:
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            return "\(fmt.string(from: customStart)) – \(fmt.string(from: customEnd))"
        }
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
                                CashFlowReport(
                                    transactions: filteredTransactions,
                                    previousTransactions: previousFilteredTransactions,
                                    currency: baseCurrency
                                )
                            case .spending:
                                SpendingReport(
                                    transactions: filteredTransactions,
                                    previousTransactions: previousFilteredTransactions,
                                    currency: baseCurrency
                                )
                            case .income:
                                IncomeReport(
                                    transactions: filteredTransactions,
                                    previousTransactions: previousFilteredTransactions,
                                    currency: baseCurrency
                                )
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
                            case .taxSummary:
                                TaxSummaryReport(transactions: filteredTransactions, currency: baseCurrency)
                            case .vatReport:
                                VATReport(transactions: filteredTransactions, currency: baseCurrency)
                            case .annualSummary:
                                AnnualSummaryReport(transactions: transactions, currency: baseCurrency)
                            case .merchantSpend:
                                MerchantSpendReport(
                                    transactions: filteredTransactions,
                                    previousTransactions: previousFilteredTransactions,
                                    currency: baseCurrency
                                )
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingExportMenu = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .confirmationDialog("Export \(selectedReport.rawValue) Report", isPresented: $showingExportMenu, titleVisibility: .visible) {
                Button("Export as PDF") { exportReport(asPDF: true) }
                Button("Export as CSV") { exportReport(asPDF: false) }
                Button("Cancel", role: .cancel) {}
            }
    }

    // MARK: – Export

    @MainActor
    private func exportReport(asPDF: Bool) {
        let svc = ReportExportService.shared
        let safeLabel = periodLabel.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: " ", with: "_")
        let url: URL?

        if asPDF {
            url = svc.generatePDF(title: selectedReport.rawValue + " Report",
                                  periodLabel: periodLabel,
                                  sections: buildPDFSections())
        } else {
            url = buildCSV(label: safeLabel)
        }
        guard let url else { return }
        svc.share(url: url)
    }

    private func buildPDFSections() -> [PDFSection] {
        let txs = filteredTransactions
        let cur = baseCurrency
        switch selectedReport {
        case .spending:
            let expenses = txs.filter { $0.type == .expense }
            let cats = Dictionary(grouping: expenses) { $0.category }
                .map { (label: $0.key.rawValue, amount: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }, count: $0.value.count) }
                .sorted { $0.amount > $1.amount }
            let total = cats.reduce(0) { $0 + $1.amount }
            return [
                PDFSection(title: "Summary", rows: [
                    PDFRow("Total Spending", total.formatted(as: cur), highlight: true, color: UIColor(FTColor.expense)),
                    PDFRow("Transactions", "\(expenses.count)")
                ]),
                PDFSection(title: "By Category", rows: cats.map { PDFRow($0.label, $0.amount.formatted(as: cur)) })
            ]
        case .cashFlow:
            let income = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency }
            let expenses = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
            let net = income - expenses
            return [PDFSection(title: "Cash Flow Summary", rows: [
                PDFRow("Total Income", income.formatted(as: cur), color: UIColor(FTColor.income)),
                PDFRow("Total Expenses", expenses.formatted(as: cur), color: UIColor(FTColor.expense)),
                PDFRow("Net Cash Flow", net.formatted(as: cur), highlight: true,
                       color: net >= 0 ? UIColor(FTColor.income) : UIColor(FTColor.expense))
            ])]
        case .income:
            let incTxs = txs.filter { $0.type == .income }
            let cats = Dictionary(grouping: incTxs) { $0.category }
                .map { (label: $0.key.rawValue, amount: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }) }
                .sorted { $0.amount > $1.amount }
            let total = cats.reduce(0) { $0 + $1.amount }
            let expTotal = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
            return [
                PDFSection(title: "Income Statement", rows: [
                    PDFRow("Total Revenue", total.formatted(as: cur), color: UIColor(FTColor.income)),
                    PDFRow("Total Expenses", expTotal.formatted(as: cur), color: UIColor(FTColor.expense)),
                    PDFRow("Net Income", (total - expTotal).formatted(as: cur), highlight: true,
                           color: total >= expTotal ? UIColor(FTColor.income) : UIColor(FTColor.expense))
                ]),
                PDFSection(title: "Revenue by Category",
                           rows: cats.map { PDFRow($0.label, $0.amount.formatted(as: cur)) })
            ]
        case .taxSummary:
            let ded = txs.filter { $0.isTaxDeductible && $0.type == .expense }
            let cats = Dictionary(grouping: ded) { $0.category.rawValue }
                .map { (label: $0.key, amount: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }) }
                .sorted { $0.amount > $1.amount }
            let total = cats.reduce(0) { $0 + $1.amount }
            return [
                PDFSection(title: "Tax Deduction Summary", rows: [
                    PDFRow("Total Deductible Expenses", total.formatted(as: cur), highlight: true),
                    PDFRow("Transactions", "\(ded.count)"),
                    PDFRow("Est. Corporate Tax Saving (9%)", (total * 0.09).formatted(as: cur))
                ]),
                PDFSection(title: "By Category", rows: cats.map { PDFRow($0.label, $0.amount.formatted(as: cur)) })
            ]
        case .vatReport:
            let vatRate = 0.05
            let vatPaid = txs.filter { $0.isVATReclaimable && $0.type == .expense }
                .reduce(0) { $0 + $1.amountInBaseCurrency * vatRate }
            let vatCollected = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency * vatRate }
            let net = vatCollected - vatPaid
            return [PDFSection(title: "UAE VAT Summary (5%)", rows: [
                PDFRow("VAT Rate", "5%"),
                PDFRow("Input VAT (Reclaimable)", vatPaid.formatted(as: cur), color: UIColor(FTColor.expense)),
                PDFRow("Output VAT (Collected)", vatCollected.formatted(as: cur), color: UIColor(FTColor.income)),
                PDFRow("Net VAT Position", net.formatted(as: cur), highlight: true,
                       color: net >= 0 ? UIColor(FTColor.income) : UIColor(FTColor.expense))
            ])]
        case .annualSummary:
            let year = Calendar.current.component(.year, from: Date())
            let yearTxs = transactions.filter { Calendar.current.component(.year, from: $0.date) == year }
            let income = yearTxs.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency }
            let expenses = yearTxs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
            let net = income - expenses
            let rate = income > 0 ? (net / income * 100) : 0
            return [PDFSection(title: "\(year) Annual Summary", rows: [
                PDFRow("Total Income", income.formatted(as: cur), color: UIColor(FTColor.income)),
                PDFRow("Total Expenses", expenses.formatted(as: cur), color: UIColor(FTColor.expense)),
                PDFRow("Net Savings", net.formatted(as: cur), highlight: true,
                       color: net >= 0 ? UIColor(FTColor.income) : UIColor(FTColor.expense)),
                PDFRow("Savings Rate", "\(String(format: "%.1f", rate))%")
            ])]
        case .merchantSpend:
            let merchants = Dictionary(grouping: txs.filter { $0.type == .expense && $0.merchant != nil }) { $0.merchant! }
                .map { (name: $0.key, amount: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }, count: $0.value.count) }
                .sorted { $0.amount > $1.amount }
            return [
                PDFSection(title: "Merchant Spend Summary", rows: [
                    PDFRow("Unique Merchants", "\(merchants.count)"),
                    PDFRow("Total Spend", merchants.reduce(0) { $0 + $1.amount }.formatted(as: cur))
                ]),
                PDFSection(title: "Top Merchants", rows: Array(merchants.prefix(20).map {
                    PDFRow($0.name, $0.amount.formatted(as: cur))
                }))
            ]
        default:
            return [PDFSection(title: "Report", rows: [
                PDFRow("Period", periodLabel),
                PDFRow("Transactions", "\(txs.count)")
            ])]
        }
    }

    private func buildCSV(label: String) -> URL? {
        let svc = ReportExportService.shared
        let cur = baseCurrency
        let txs = filteredTransactions
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]

        switch selectedReport {
        case .spending:
            let expenses = txs.filter { $0.type == .expense }
            let cats = Dictionary(grouping: expenses) { $0.category }
                .map { (cat: $0.key.rawValue, amount: $0.value.reduce(0.0) { $0 + $1.amountInBaseCurrency }, count: $0.value.count) }
                .sorted { $0.amount > $1.amount }
            let total = cats.reduce(0.0) { $0 + $1.amount }
            var lines = ["Category,Amount (\(cur)),Transactions,Percentage"]
            for c in cats {
                let pct = total > 0 ? c.amount / total * 100 : 0
                lines.append("\(c.cat.csvEscaped),\(String(format: "%.2f", c.amount)),\(c.count),\(String(format: "%.1f", pct))%")
            }
            lines.append("\nTOTAL,\(String(format: "%.2f", total)),\(expenses.count),100%")
            return svc.writeCSV(lines.joined(separator: "\n"), filename: "spending_\(label)")

        case .taxSummary:
            let ded = txs.filter { $0.isTaxDeductible && $0.type == .expense }
            let cats = Dictionary(grouping: ded) { $0.category.rawValue }
                .map { (cat: $0.key, amount: $0.value.reduce(0.0) { $0 + $1.amountInBaseCurrency }, count: $0.value.count) }
                .sorted { $0.amount > $1.amount }
            let total = cats.reduce(0.0) { $0 + $1.amount }
            var lines = ["TAX SUMMARY - \(periodLabel)", "",
                         "Total Deductible,\(String(format: "%.2f", total))",
                         "Est. Tax Saving (9%),\(String(format: "%.2f", total * 0.09))", "",
                         "Category,Amount (\(cur)),Transactions"]
            for c in cats { lines.append("\(c.cat.csvEscaped),\(String(format: "%.2f", c.amount)),\(c.count)") }
            lines.append("")
            lines.append("Date,Merchant,Category,Amount (\(cur)),Notes")
            for tx in ded.sorted(by: { $0.date > $1.date }) {
                lines.append("\(fmt.string(from: tx.date)),\(tx.merchant?.csvEscaped ?? ""),\(tx.category.rawValue.csvEscaped),\(String(format: "%.2f", tx.amountInBaseCurrency)),\(tx.notes?.csvEscaped ?? "")")
            }
            return svc.writeCSV(lines.joined(separator: "\n"), filename: "tax_summary_\(label)")

        case .vatReport:
            let vatRate = 0.05
            let reclaimable = txs.filter { $0.isVATReclaimable && $0.type == .expense }
            let vatPaid = reclaimable.reduce(0.0) { $0 + $1.amountInBaseCurrency * vatRate }
            let incTxs = txs.filter { $0.type == .income }
            let vatCollected = incTxs.reduce(0.0) { $0 + $1.amountInBaseCurrency * vatRate }
            let net = vatCollected - vatPaid
            var lines = ["UAE VAT REPORT - \(periodLabel)", "",
                         "VAT Rate,5%",
                         "Input VAT (Paid),\(String(format: "%.2f", vatPaid))",
                         "Output VAT (Collected),\(String(format: "%.2f", vatCollected))",
                         "Net VAT Position,\(String(format: "%.2f", net))", "",
                         "Date,Merchant,Category,Amount (\(cur)),VAT Amount (\(cur)),Type"]
            for tx in reclaimable.sorted(by: { $0.date > $1.date }) {
                let vat = tx.amountInBaseCurrency * vatRate
                lines.append("\(fmt.string(from: tx.date)),\(tx.merchant?.csvEscaped ?? ""),\(tx.category.rawValue.csvEscaped),\(String(format: "%.2f", tx.amountInBaseCurrency)),\(String(format: "%.2f", vat)),Input")
            }
            for tx in incTxs.sorted(by: { $0.date > $1.date }) {
                let vat = tx.amountInBaseCurrency * vatRate
                lines.append("\(fmt.string(from: tx.date)),,\(tx.category.rawValue.csvEscaped),\(String(format: "%.2f", tx.amountInBaseCurrency)),\(String(format: "%.2f", vat)),Output")
            }
            return svc.writeCSV(lines.joined(separator: "\n"), filename: "vat_report_\(label)")

        case .merchantSpend:
            let expTxs = txs.filter { $0.type == .expense && $0.merchant != nil }
            let merchants = Dictionary(grouping: expTxs) { $0.merchant! }
                .map { m, mTxs -> (name: String, total: Double, count: Int, avg: Double, topCat: String) in
                    let total = mTxs.reduce(0.0) { $0 + $1.amountInBaseCurrency }
                    let topCat = (Dictionary(grouping: mTxs) { $0.category.rawValue }.max(by: { $0.value.count < $1.value.count })?.key) ?? ""
                    return (m, total, mTxs.count, total / Double(mTxs.count), topCat)
                }.sorted { $0.total > $1.total }
            var lines = ["Merchant,Total (\(cur)),Visits,Avg Per Visit (\(cur)),Top Category"]
            for m in merchants {
                lines.append("\(m.name.csvEscaped),\(String(format: "%.2f", m.total)),\(m.count),\(String(format: "%.2f", m.avg)),\(m.topCat.csvEscaped)")
            }
            return svc.writeCSV(lines.joined(separator: "\n"), filename: "merchant_spend_\(label)")

        case .annualSummary:
            let year = Calendar.current.component(.year, from: Date())
            let yearTxs = transactions.filter { Calendar.current.component(.year, from: $0.date) == year }
            var lines = ["\(year) ANNUAL SUMMARY", ""]
            lines.append("Month,Income (\(cur)),Expenses (\(cur)),Net (\(cur))")
            for m in 0..<12 {
                guard let monthDate = Calendar.current.date(from: DateComponents(year: year, month: m + 1)) else { continue }
                let mTxs = yearTxs.filter { $0.date.isSameMonth(as: monthDate) }
                let income = mTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amountInBaseCurrency }
                let expense = mTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amountInBaseCurrency }
                lines.append("\(monthDate.monthName),\(String(format: "%.2f", income)),\(String(format: "%.2f", expense)),\(String(format: "%.2f", income - expense))")
            }
            return svc.writeCSV(lines.joined(separator: "\n"), filename: "annual_summary_\(year)")

        default:
            var lines = ["Date,Title,Category,Amount (\(cur)),Type,Merchant,Notes"]
            for tx in txs.sorted(by: { $0.date > $1.date }) {
                lines.append("\(fmt.string(from: tx.date)),\(tx.title.csvEscaped),\(tx.category.rawValue.csvEscaped),\(String(format: "%.2f", tx.amountInBaseCurrency)),\(tx.type.rawValue),\(tx.merchant?.csvEscaped ?? ""),\(tx.notes?.csvEscaped ?? "")")
            }
            return svc.writeCSV(lines.joined(separator: "\n"), filename: "\(selectedReport.rawValue.lowercased())_\(label)")
        }
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
    case cashFlow      = "Cash Flow"
    case spending      = "Spending"
    case income        = "Income"
    case investments   = "Investments"
    case debt          = "Debt"
    case netWorth      = "Net Worth"
    case trends        = "Trends"
    case savingsGoals  = "Goals"
    case taxSummary    = "Tax"
    case vatReport     = "VAT"
    case annualSummary = "Annual"
    case merchantSpend = "Merchants"
}

// MARK: - Cash Flow Report

struct CashFlowReport: View {
    let transactions: [Transaction]
    var previousTransactions: [Transaction] = []
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

    private var previousNet: Double {
        previousTransactions.reduce(0) { result, tx in
            if tx.type == .income { return result + tx.amountInBaseCurrency }
            if tx.type == .expense { return result - tx.amountInBaseCurrency }
            return result
        }
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
        let prevNet = previousNet
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

            // Period comparison
            if !previousTransactions.isEmpty {
                let diff = netCashFlow - prevNet
                let pct = prevNet != 0 ? abs(diff / prevNet * 100) : 0
                HStack(spacing: FTSpacing.md) {
                    Image(systemName: diff >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .foregroundStyle(diff >= 0 ? FTColor.income : FTColor.expense)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("vs Previous Period").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text("\(diff >= 0 ? "+" : "")\(diff.formatted(as: currency))")
                            .font(.ftBodySemibold)
                            .foregroundStyle(diff >= 0 ? FTColor.income : FTColor.expense)
                    }
                    Spacer()
                    Text("\(diff >= 0 ? "+" : "-")\(pct.asPercentage())")
                        .font(.ftHeadline)
                        .foregroundStyle(diff >= 0 ? FTColor.income : FTColor.expense)
                }
                .padding(FTSpacing.md)
                .ftGlass(FTRadius.md)
            }

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
    var previousTransactions: [Transaction] = []
    let currency: String

    private var expensesByCategory: [(category: TransactionCategory, amount: Double, count: Int)] {
        let expenses = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses) { $0.category }
        return grouped.map { cat, txs in
            (category: cat, amount: txs.reduce(0) { $0 + $1.amountInBaseCurrency }, count: txs.count)
        }.sorted { $0.amount > $1.amount }
    }

    private var previousTotal: Double {
        previousTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    private var previousByCategory: [TransactionCategory: Double] {
        Dictionary(grouping: previousTransactions.filter { $0.type == .expense }) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amountInBaseCurrency } }
    }

    var body: some View {
        let expensesByCategory = self.expensesByCategory
        let total = expensesByCategory.reduce(0) { $0 + $1.amount }
        let prevTotal = self.previousTotal
        let prevCats = self.previousByCategory
        return VStack(spacing: 16) {
            // Period comparison banner
            if !previousTransactions.isEmpty && (total > 0 || prevTotal > 0) {
                let diff = total - prevTotal
                let pct = prevTotal > 0 ? abs(diff / prevTotal * 100) : 0
                let isLess = diff < 0
                HStack(spacing: FTSpacing.md) {
                    Image(systemName: isLess ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(isLess ? FTColor.income : FTColor.expense)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("vs Previous Period").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text(isLess ? "Spent \(abs(diff).formatted(as: currency)) less" : "Spent \(abs(diff).formatted(as: currency)) more")
                            .font(.ftBodySemibold)
                            .foregroundStyle(isLess ? FTColor.income : FTColor.expense)
                    }
                    Spacer()
                    Text("\(isLess ? "-" : "+")\(pct.asPercentage())")
                        .font(.ftHeadline)
                        .foregroundStyle(isLess ? FTColor.income : FTColor.expense)
                }
                .padding(FTSpacing.md)
                .ftGlass(FTRadius.md)
            }

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
                        let prevAmt = prevCats[item.category] ?? 0
                        let trend: String = {
                            guard !previousTransactions.isEmpty else { return "" }
                            let delta = item.amount - prevAmt
                            if abs(delta) < 0.01 { return "→" }
                            return delta > 0 ? "↑" : "↓"
                        }()
                        let trendColor: Color = {
                            guard !trend.isEmpty else { return .clear }
                            return trend == "↑" ? FTColor.expense : (trend == "↓" ? FTColor.income : FTColor.textMuted)
                        }()
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
                                HStack(spacing: 4) {
                                    Text(item.category.rawValue).font(.subheadline).fontWeight(.medium)
                                    if !trend.isEmpty {
                                        Text(trend).font(.caption).foregroundStyle(trendColor)
                                    }
                                }
                                Text("\(item.count) transaction\(item.count == 1 ? "" : "s")").font(.caption).foregroundStyle(FTColor.textSecondary)
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
    var previousTransactions: [Transaction] = []
    let currency: String

    private var previousIncome: Double {
        previousTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency }
    }

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
        let totalExpenses = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
        let netIncome = total - totalExpenses
        let trend = self.monthlyTrend
        let bySource = self.incomeBySource
        let avgMonthly = trend.isEmpty ? 0 : trend.reduce(0) { $0 + $1.amount } / Double(trend.count)
        let prevInc = previousIncome

        return VStack(spacing: 16) {
            // P&L income statement summary
            VStack(spacing: 0) {
                HStack {
                    Text("INCOME STATEMENT").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, FTSpacing.lg).padding(.top, FTSpacing.md)
                incomeStatRow(label: "Revenue", value: total, color: FTColor.income)
                Divider().padding(.leading, FTSpacing.lg)
                incomeStatRow(label: "Expenses", value: totalExpenses, color: FTColor.expense)
                Divider().padding(.leading, FTSpacing.lg)
                incomeStatRow(label: "Net Income", value: netIncome, color: netIncome >= 0 ? FTColor.income : FTColor.expense, isTotal: true)
            }
            .ftGlass(FTRadius.md)

            // Previous period comparison
            if !previousTransactions.isEmpty && (total > 0 || prevInc > 0) {
                let diff = total - prevInc
                let pct = prevInc > 0 ? abs(diff / prevInc * 100) : 0
                HStack(spacing: FTSpacing.md) {
                    Image(systemName: diff >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(diff >= 0 ? FTColor.income : FTColor.expense)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("vs Previous Period").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text("\(diff >= 0 ? "+" : "")\(abs(diff).formatted(as: currency)) income")
                            .font(.ftBodySemibold)
                            .foregroundStyle(diff >= 0 ? FTColor.income : FTColor.expense)
                    }
                    Spacer()
                    Text("\(diff >= 0 ? "+" : "-")\(pct.asPercentage())")
                        .font(.ftHeadline)
                        .foregroundStyle(diff >= 0 ? FTColor.income : FTColor.expense)
                }
                .padding(FTSpacing.md)
                .ftGlass(FTRadius.md)
            }

            HStack(spacing: 12) {
                ReportSummaryCard(title: "Total Revenue", amount: total, currency: currency, color: .green, icon: "arrow.down.circle.fill")
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

    private func incomeStatRow(label: String, value: Double, color: Color, isTotal: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isTotal ? .ftBodySemibold : .ftBody)
                .foregroundStyle(isTotal ? FTColor.textPrimary : FTColor.textSecondary)
            Spacer()
            Text(value.formatted(as: currency))
                .font(isTotal ? .ftHeadline : .ftBodySemibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
        .background(isTotal ? color.opacity(0.07) : Color.clear)
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

// MARK: - Tax Summary Report

struct TaxSummaryReport: View {
    let transactions: [Transaction]
    let currency: String

    private var deductible: [Transaction] {
        transactions.filter { $0.isTaxDeductible && $0.type == .expense }
    }

    private var byCategory: [(category: String, amount: Double, count: Int)] {
        Dictionary(grouping: deductible) { $0.category.rawValue }
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }, count: $0.value.count) }
            .sorted { $0.amount > $1.amount }
    }

    private var totalDeductible: Double { byCategory.reduce(0) { $0 + $1.amount } }
    private var estimatedSaving: Double { totalDeductible * 0.09 }
    private var deductibleRatio: Double {
        let allExpenses = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
        return allExpenses > 0 ? totalDeductible / allExpenses : 0
    }

    @State private var showingAllTransactions = false

    var body: some View {
        let cats = byCategory
        return VStack(spacing: FTSpacing.lg) {
            // Hero
            VStack(spacing: FTSpacing.sm) {
                HStack {
                    FTIconTile(symbol: "doc.text.magnifyingglass", tint: FTColor.catBlue, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tax Deduction Summary").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        Text("UAE Corporate Tax · 9% rate").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                }
                HStack(spacing: FTSpacing.lg) {
                    VStack(spacing: 3) {
                        Text(totalDeductible.asCompact(currency: currency))
                            .font(.ftTitle).foregroundStyle(FTColor.catBlue)
                        Text("Total Deductible").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 3) {
                        Text(estimatedSaving.asCompact(currency: currency))
                            .font(.ftTitle).foregroundStyle(FTColor.income)
                        Text("Est. Tax Saving").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 3) {
                        Text("\(deductible.count)").font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                        Text("Transactions").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)

            // UAE Context note
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "info.circle.fill").foregroundStyle(FTColor.catBlue).font(.footnote)
                Text("UAE has no personal income tax. Corporate tax of 9% applies to business profits above AED 375,000 (from June 2023).")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            .padding(FTSpacing.md)
            .ftGlass(FTRadius.sm)

            if deductible.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Deductible Expenses",
                    message: "Mark expenses as tax-deductible when adding transactions to track them here."
                )
                .padding(.vertical, 40)
            } else {
                // Deductible ratio
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("DEDUCTIBLE RATIO").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                    VStack(spacing: FTSpacing.xs) {
                        HStack {
                            Text("Deductible Expenses").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            Spacer()
                            Text(deductibleRatio.asPercentage()).font(.ftBodySemibold).foregroundStyle(FTColor.catBlue)
                        }
                        FTProgressBar(value: deductibleRatio, color: FTColor.catBlue)
                        Text("of total period spending").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.md)
                }

                // Category breakdown
                VStack(alignment: .leading, spacing: 0) {
                    Text("BY CATEGORY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                        .padding(.bottom, FTSpacing.sm)
                    VStack(spacing: 0) {
                        ForEach(Array(cats.enumerated()), id: \.offset) { idx, cat in
                            let tint = ftChartPalette[idx % ftChartPalette.count]
                            HStack(spacing: FTSpacing.md) {
                                ZStack {
                                    Circle().fill(tint.opacity(0.15)).frame(width: 40, height: 40)
                                    Image(systemName: "doc.badge.checkmark").foregroundStyle(tint).font(.ftBody)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.category).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text("\(cat.count) transaction\(cat.count == 1 ? "" : "s")")
                                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(cat.amount.formatted(as: currency))
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text((totalDeductible > 0 ? cat.amount / totalDeductible * 100 : 0).asPercentage())
                                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                }
                            }
                            .padding(.horizontal, FTSpacing.lg)
                            .padding(.vertical, FTSpacing.md)
                            if idx < cats.count - 1 { Divider().padding(.leading, 68) }
                        }
                    }
                    .ftGlass(FTRadius.md)
                }

                // Transactions list
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Button {
                        withAnimation { showingAllTransactions.toggle() }
                    } label: {
                        HStack {
                            Text("DEDUCTIBLE TRANSACTIONS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Image(systemName: showingAllTransactions ? "chevron.up" : "chevron.down")
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                    }
                    .buttonStyle(.plain)

                    if showingAllTransactions {
                        VStack(spacing: 0) {
                            ForEach(Array(deductible.sorted(by: { $0.date > $1.date }).enumerated()), id: \.element.id) { idx, tx in
                                HStack(spacing: FTSpacing.md) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(tx.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        Text(tx.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(tx.amountInBaseCurrency.formatted(as: currency))
                                            .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                                        if let m = tx.merchant { Text(m).font(.ftCaption).foregroundStyle(FTColor.textMuted) }
                                    }
                                }
                                .padding(.horizontal, FTSpacing.lg)
                                .padding(.vertical, FTSpacing.md)
                                if idx < deductible.count - 1 { Divider().padding(.leading, FTSpacing.lg) }
                            }
                        }
                        .ftGlass(FTRadius.md)
                    }
                }
            }
        }
        .padding(.top, FTSpacing.sm)
    }
}

// MARK: - VAT Report

struct VATReport: View {
    let transactions: [Transaction]
    let currency: String

    private let vatRate = 0.05

    private var inputTxs: [Transaction] {
        transactions.filter { $0.isVATReclaimable && $0.type == .expense }
    }
    private var outputTxs: [Transaction] {
        transactions.filter { $0.type == .income }
    }

    private var vatPaid: Double { inputTxs.reduce(0) { $0 + $1.amountInBaseCurrency * vatRate } }
    private var vatCollected: Double { outputTxs.reduce(0) { $0 + $1.amountInBaseCurrency * vatRate } }
    private var netVAT: Double { vatCollected - vatPaid }

    private var inputByCategory: [(category: String, amount: Double, vat: Double)] {
        Dictionary(grouping: inputTxs) { $0.category.rawValue }
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }, vat: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency * vatRate }) }
            .sorted { $0.vat > $1.vat }
    }

    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            // Hero card
            VStack(spacing: FTSpacing.md) {
                HStack {
                    FTIconTile(symbol: "percent", tint: FTColor.catTeal, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UAE VAT Report").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        Text("Federal Tax Authority · 5% Standard Rate").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                }

                // Net position indicator
                let isRefund = netVAT < 0
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isRefund ? "VAT Refund Due" : "VAT Payable").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text(abs(netVAT).formatted(as: currency))
                            .font(.ftTitle)
                            .foregroundStyle(isRefund ? FTColor.income : FTColor.expense)
                    }
                    Spacer()
                    BadgeView(text: isRefund ? "Refund" : "Payable",
                             color: isRefund ? FTColor.income : FTColor.expense)
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)

            // FTA context note
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "info.circle.fill").foregroundStyle(FTColor.catTeal).font(.footnote)
                Text("VAT registration required when taxable supplies exceed AED 375,000/year. File quarterly on the FTA portal (tax.gov.ae).")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            .padding(FTSpacing.md)
            .ftGlass(FTRadius.sm)

            // Three-column summary
            HStack(spacing: FTSpacing.sm) {
                vatSummaryCard(title: "Input VAT", subtitle: "Reclaimable", amount: vatPaid, color: FTColor.expense, icon: "arrow.up.circle.fill")
                vatSummaryCard(title: "Output VAT", subtitle: "Collected", amount: vatCollected, color: FTColor.income, icon: "arrow.down.circle.fill")
                vatSummaryCard(title: "Net Position", subtitle: netVAT >= 0 ? "Payable" : "Refund", amount: abs(netVAT),
                              color: netVAT >= 0 ? FTColor.expense : FTColor.income, icon: "scalemass.fill")
            }

            // Input VAT by category
            if !inputTxs.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("INPUT VAT BY CATEGORY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                    VStack(spacing: 0) {
                        ForEach(Array(inputByCategory.enumerated()), id: \.offset) { idx, cat in
                            let tint = ftChartPalette[idx % ftChartPalette.count]
                            HStack(spacing: FTSpacing.md) {
                                Circle().fill(tint).frame(width: 10, height: 10).padding(.leading, FTSpacing.xs)
                                Text(cat.category).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(cat.vat.formatted(as: currency)).font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                                    Text("on \(cat.amount.asCompact(currency: currency))").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                }
                            }
                            .padding(.horizontal, FTSpacing.lg)
                            .padding(.vertical, FTSpacing.sm)
                            if idx < inputByCategory.count - 1 { Divider().padding(.leading, 36) }
                        }
                    }
                    .ftGlass(FTRadius.md)
                }

                // VAT return summary table (FTA-style)
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("VAT RETURN SUMMARY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                    VStack(spacing: 0) {
                        vatReturnRow(label: "Standard-rated supplies (5%)",
                                     amount: outputTxs.reduce(0) { $0 + $1.amountInBaseCurrency },
                                     vat: vatCollected)
                        Divider().padding(.leading, FTSpacing.lg)
                        vatReturnRow(label: "Standard-rated purchases (reclaimable)",
                                     amount: inputTxs.reduce(0) { $0 + $1.amountInBaseCurrency },
                                     vat: vatPaid)
                        Divider().padding(.leading, FTSpacing.lg)
                        HStack {
                            Text("Net VAT Due / (Refundable)")
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Spacer()
                            Text(netVAT.formatted(as: currency))
                                .font(.ftHeadline)
                                .foregroundStyle(netVAT >= 0 ? FTColor.expense : FTColor.income)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .padding(.vertical, FTSpacing.md)
                        .background(netVAT >= 0 ? FTColor.expense.opacity(0.07) : FTColor.income.opacity(0.07))
                    }
                    .ftGlass(FTRadius.md)
                }
            } else if outputTxs.isEmpty {
                EmptyStateView(
                    icon: "percent",
                    title: "No VAT Transactions",
                    message: "Mark expenses as VAT reclaimable when adding transactions to track input VAT here."
                )
                .padding(.vertical, 40)
            }
        }
        .padding(.top, FTSpacing.sm)
    }

    private func vatSummaryCard(title: String, subtitle: String, amount: Double, color: Color, icon: String) -> some View {
        VStack(spacing: FTSpacing.xs) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            Text(amount.asCompact(currency: currency)).font(.ftBodySemibold).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.ftCaption).foregroundStyle(FTColor.textPrimary)
            Text(subtitle).font(Font.system(size: 10)).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }

    private func vatReturnRow(label: String, amount: Double, vat: Double) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(vat.formatted(as: currency)).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("base: \(amount.asCompact(currency: currency))").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - Annual Financial Summary

struct AnnualSummaryReport: View {
    let transactions: [Transaction]
    let currency: String

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var availableYears: [Int] {
        let years = transactions.map { Calendar.current.component(.year, from: $0.date) }
        return Array(Set(years)).sorted().reversed().map { $0 }
    }

    private var yearTransactions: [Transaction] {
        transactions.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
    }

    private var previousYearTransactions: [Transaction] {
        transactions.filter { Calendar.current.component(.year, from: $0.date) == selectedYear - 1 }
    }

    private var totalIncome: Double { yearTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency } }
    private var totalExpenses: Double { yearTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency } }
    private var netSavings: Double { totalIncome - totalExpenses }
    private var savingsRate: Double { totalIncome > 0 ? netSavings / totalIncome * 100 : 0 }

    private var previousIncome: Double { previousYearTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency } }
    private var previousExpenses: Double { previousYearTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency } }

    private var monthlyData: [(month: String, income: Double, expenses: Double)] {
        (1...12).compactMap { m in
            guard let date = Calendar.current.date(from: DateComponents(year: selectedYear, month: m)) else { return nil }
            let mTxs = yearTransactions.filter { $0.date.isSameMonth(as: date) }
            return (
                month: date.shortMonthName,
                income: mTxs.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency },
                expenses: mTxs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
            )
        }
    }

    private var bestMonth: (month: String, net: Double)? {
        monthlyData.map { ($0.month, $0.income - $0.expenses) }.max(by: { $0.1 < $1.1 })
    }

    private var largestExpenseCategory: (category: String, amount: Double)? {
        Dictionary(grouping: yearTransactions.filter { $0.type == .expense }) { $0.category.rawValue }
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }) }
            .max(by: { $0.amount < $1.amount })
    }

    private var topMerchant: (name: String, total: Double, count: Int)? {
        let merch = yearTransactions.compactMap(\.merchant)
        guard !merch.isEmpty else { return nil }
        let groups = Dictionary(grouping: yearTransactions.filter { $0.type == .expense && $0.merchant != nil }) { $0.merchant! }
        return groups.map { (name: $0.key, total: $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }, count: $0.value.count) }
            .max(by: { $0.total < $1.total })
    }

    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            // Year selector
            if availableYears.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.sm) {
                        ForEach(availableYears, id: \.self) { yr in
                            FilterChip(title: "\(yr)", isSelected: yr == selectedYear) {
                                selectedYear = yr
                            }
                        }
                    }
                    .padding(.horizontal, FTSpacing.xs)
                }
            }

            // Year hero
            VStack(spacing: FTSpacing.md) {
                HStack {
                    Text("\(selectedYear) YEAR IN REVIEW").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    if totalIncome > 0 || totalExpenses > 0 {
                        BadgeView(text: savingsRate >= 20 ? "On Track" : savingsRate >= 10 ? "Fair" : "Below Target",
                                 color: savingsRate >= 20 ? FTColor.income : savingsRate >= 10 ? .orange : FTColor.expense)
                    }
                }
                HStack(spacing: FTSpacing.lg) {
                    annualMetric(label: "Income", value: totalIncome, color: FTColor.income)
                    Rectangle().fill(FTColor.textMuted.opacity(0.3)).frame(width: 1, height: 40)
                    annualMetric(label: "Expenses", value: totalExpenses, color: FTColor.expense)
                    Rectangle().fill(FTColor.textMuted.opacity(0.3)).frame(width: 1, height: 40)
                    annualMetric(label: "Saved", value: netSavings, color: netSavings >= 0 ? FTColor.accent : FTColor.expense)
                }
                .frame(maxWidth: .infinity)
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Savings Rate").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text(savingsRate.asPercentage()).font(.ftBodySemibold)
                            .foregroundStyle(savingsRate >= 20 ? FTColor.income : savingsRate >= 10 ? .orange : FTColor.expense)
                    }
                    Spacer()
                    // YoY change
                    if previousIncome > 0 {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("vs \(selectedYear - 1)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            let yoyChange = previousIncome > 0 ? (totalIncome - previousIncome) / previousIncome * 100 : 0
                            Text("\(yoyChange >= 0 ? "+" : "")\(yoyChange.asPercentage()) income")
                                .font(.ftBodySemibold)
                                .foregroundStyle(yoyChange >= 0 ? FTColor.income : FTColor.expense)
                        }
                    }
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)

            // 12-month chart
            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                Text("MONTHLY BREAKDOWN").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                let data = monthlyData
                if !data.allSatisfy({ $0.income == 0 && $0.expenses == 0 }) {
                    Chart {
                        ForEach(data, id: \.month) { d in
                            BarMark(x: .value("Month", d.month), y: .value("Income", d.income))
                                .foregroundStyle(FTColor.income.opacity(0.85))
                                .cornerRadius(3)
                            BarMark(x: .value("Month", d.month), y: .value("Expenses", -d.expenses))
                                .foregroundStyle(FTColor.expense.opacity(0.85))
                                .cornerRadius(3)
                        }
                        RuleMark(y: .value("Zero", 0)).foregroundStyle(FTColor.textMuted.opacity(0.4))
                    }
                    .frame(height: 200)
                    .ftChartAxes()
                    .padding()
                    .ftGlass(FTRadius.md)

                    HStack(spacing: FTSpacing.lg) {
                        HStack(spacing: 6) { Circle().fill(FTColor.income).frame(width: 8, height: 8); Text("Income").font(.ftCaption).foregroundStyle(FTColor.textMuted) }
                        HStack(spacing: 6) { Circle().fill(FTColor.expense).frame(width: 8, height: 8); Text("Expenses").font(.ftCaption).foregroundStyle(FTColor.textMuted) }
                    }
                } else {
                    Text("No transactions recorded for \(selectedYear).")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        .padding(FTSpacing.lg)
                        .frame(maxWidth: .infinity)
                        .ftGlass(FTRadius.md)
                }
            }

            // Key metrics
            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                Text("KEY METRICS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                VStack(spacing: 0) {
                    if let best = bestMonth {
                        keyMetricRow(icon: "star.fill", tint: FTColor.gold,
                                     label: "Best Month", value: "\(best.month) (\(best.net.asCompact(currency: currency)))")
                        Divider().padding(.leading, 56)
                    }
                    if let cat = largestExpenseCategory {
                        keyMetricRow(icon: "arrow.up.circle.fill", tint: FTColor.expense,
                                     label: "Largest Category", value: "\(cat.category) (\(cat.amount.asCompact(currency: currency)))")
                        Divider().padding(.leading, 56)
                    }
                    if let m = topMerchant {
                        keyMetricRow(icon: "storefront.fill", tint: FTColor.catCoral,
                                     label: "Top Merchant", value: "\(m.name) · \(m.count) visits")
                        Divider().padding(.leading, 56)
                    }
                    keyMetricRow(icon: "chart.line.uptrend.xyaxis", tint: FTColor.accent,
                                 label: "Savings Rate", value: savingsRate.asPercentage())
                    Divider().padding(.leading, 56)
                    keyMetricRow(icon: "calendar.circle.fill", tint: FTColor.catBlue,
                                 label: "Avg Monthly Income", value: (totalIncome / 12).asCompact(currency: currency))
                    Divider().padding(.leading, 56)
                    keyMetricRow(icon: "creditcard.fill", tint: FTColor.catPurple,
                                 label: "Avg Monthly Spend", value: (totalExpenses / 12).asCompact(currency: currency))
                }
                .ftGlass(FTRadius.lg)
            }

            // YoY Comparison
            if previousIncome > 0 || previousExpenses > 0 {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("YEAR-OVER-YEAR").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                    VStack(spacing: 0) {
                        yoyRow(label: "Total Income", current: totalIncome, previous: previousIncome)
                        Divider().padding(.leading, FTSpacing.lg)
                        yoyRow(label: "Total Expenses", current: totalExpenses, previous: previousExpenses, inverseGood: true)
                        Divider().padding(.leading, FTSpacing.lg)
                        yoyRow(label: "Net Savings", current: netSavings, previous: previousIncome - previousExpenses)
                    }
                    .ftGlass(FTRadius.lg)
                }
            }
        }
        .padding(.top, FTSpacing.sm)
    }

    private func annualMetric(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value.asCompact(currency: currency)).font(.ftBodySemibold).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func keyMetricRow(icon: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: icon, tint: tint, size: 36)
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }

    private func yoyRow(label: String, current: Double, previous: Double, inverseGood: Bool = false) -> some View {
        let change = previous > 0 ? (current - previous) / previous * 100 : 0
        let isPositive = inverseGood ? change < 0 : change > 0
        return HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(current.asCompact(currency: currency)).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                if previous > 0 {
                    Text("\(change >= 0 ? "+" : "")\(change.asPercentage()) YoY")
                        .font(.ftCaption).foregroundStyle(isPositive ? FTColor.income : FTColor.expense)
                }
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - Merchant Spend Report

struct MerchantSpendReport: View {
    let transactions: [Transaction]
    var previousTransactions: [Transaction] = []
    let currency: String

    enum SortOrder: String, CaseIterable {
        case total = "Total"
        case visits = "Visits"
        case average = "Avg/Visit"
    }

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .total

    private struct MerchantData: Identifiable {
        let id = UUID()
        let name: String
        let total: Double
        let count: Int
        let avg: Double
        let topCategory: String
        let prevTotal: Double
        var trend: Double { prevTotal > 0 ? (total - prevTotal) / prevTotal * 100 : 0 }
    }

    private var merchants: [MerchantData] {
        let expTxs = transactions.filter { $0.type == .expense && $0.merchant != nil }
        let prevExpTxs = previousTransactions.filter { $0.type == .expense && $0.merchant != nil }
        let prevMap = Dictionary(grouping: prevExpTxs) { $0.merchant! }.mapValues {
            $0.reduce(0) { $0 + $1.amountInBaseCurrency }
        }
        let grouped = Dictionary(grouping: expTxs) { $0.merchant! }
        return grouped.map { name, txs in
            let total = txs.reduce(0) { $0 + $1.amountInBaseCurrency }
            let topCat = (Dictionary(grouping: txs) { $0.category.rawValue }.max(by: { $0.value.count < $1.value.count })?.key) ?? ""
            return MerchantData(name: name, total: total, count: txs.count, avg: total / Double(txs.count),
                                topCategory: topCat, prevTotal: prevMap[name] ?? 0)
        }
    }

    private var filteredMerchants: [MerchantData] {
        let base = searchText.isEmpty ? merchants : merchants.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        switch sortOrder {
        case .total:   return base.sorted { $0.total > $1.total }
        case .visits:  return base.sorted { $0.count > $1.count }
        case .average: return base.sorted { $0.avg > $1.avg }
        }
    }

    private var grandTotal: Double { merchants.reduce(0) { $0 + $1.total } }
    private var unattributed: Double {
        transactions.filter { $0.type == .expense && $0.merchant == nil }.reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            // Summary
            HStack(spacing: FTSpacing.sm) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "storefront.fill").foregroundStyle(FTColor.accent).font(.caption)
                        Text("Merchants").font(.caption).foregroundStyle(FTColor.textSecondary)
                    }
                    Text("\(merchants.count)").font(.ftHeadline).lineLimit(1)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FTColor.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                ReportSummaryCard(title: "Total Spend", amount: grandTotal,
                                 currency: currency, color: FTColor.expense, icon: "creditcard.fill")
            }

            // Top 5 bar chart
            if !merchants.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("TOP MERCHANTS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                    let top5 = merchants.sorted { $0.total > $1.total }.prefix(5).map { $0 }
                    Chart {
                        ForEach(Array(top5.enumerated()), id: \.offset) { idx, m in
                            BarMark(
                                x: .value("Amount", m.total),
                                y: .value("Merchant", m.name)
                            )
                            .foregroundStyle(ftChartPalette[idx % ftChartPalette.count])
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: max(140, CGFloat(min(top5.count, 5)) * 38))
                    .ftChartAxes()
                    .padding()
                    .ftGlass(FTRadius.md)
                }
            }

            // Sort + search
            VStack(spacing: FTSpacing.sm) {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundStyle(FTColor.textMuted)
                    TextField("Search merchants", text: $searchText)
                        .font(.ftBody)
                }
                .padding(FTSpacing.md)
                .ftGlass(FTRadius.md)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.sm) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            FilterChip(title: "Sort: \(order.rawValue)", isSelected: sortOrder == order) {
                                sortOrder = order
                            }
                        }
                    }
                }
            }

            // Merchant list
            if filteredMerchants.isEmpty {
                EmptyStateView(
                    icon: "storefront",
                    title: searchText.isEmpty ? "No Merchant Data" : "No Results",
                    message: searchText.isEmpty
                        ? "Add a merchant name when creating transactions to see analytics here."
                        : "No merchants match '\(searchText)'."
                )
                .padding(.vertical, 32)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredMerchants.enumerated()), id: \.element.id) { idx, m in
                        VStack(spacing: FTSpacing.xs) {
                            HStack(spacing: FTSpacing.md) {
                                ZStack {
                                    Circle().fill(ftChartPalette[idx % ftChartPalette.count].opacity(0.15)).frame(width: 42, height: 42)
                                    Text(String(m.name.prefix(1)).uppercased())
                                        .font(.ftBodySemibold)
                                        .foregroundStyle(ftChartPalette[idx % ftChartPalette.count])
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(m.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    HStack(spacing: FTSpacing.xs) {
                                        Text(m.topCategory).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                        Text("·").foregroundStyle(FTColor.textMuted)
                                        Text("\(m.count) visit\(m.count == 1 ? "" : "s")").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(m.total.formatted(as: currency)).font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                                    HStack(spacing: FTSpacing.xs) {
                                        Text("avg \(m.avg.asCompact(currency: currency))").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                        if !previousTransactions.isEmpty && m.prevTotal > 0 {
                                            let trendUp = m.trend > 0
                                            Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(trendUp ? FTColor.expense : FTColor.income)
                                        }
                                    }
                                }
                            }
                            // Spend bar
                            if grandTotal > 0 {
                                FTProgressBar(value: m.total / grandTotal, color: ftChartPalette[idx % ftChartPalette.count])
                                    .padding(.leading, 58)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .padding(.vertical, FTSpacing.md)
                        if idx < filteredMerchants.count - 1 { Divider().padding(.leading, 68) }
                    }
                }
                .ftGlass(FTRadius.lg)

                // Unattributed
                if unattributed > 0 {
                    HStack(spacing: FTSpacing.md) {
                        FTIconTile(symbol: "questionmark.circle", tint: FTColor.textMuted, size: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Unattributed Spend").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Text("Transactions without a merchant name").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                        Text(unattributed.formatted(as: currency)).font(.ftBodySemibold).foregroundStyle(FTColor.textMuted)
                    }
                    .padding(FTSpacing.md)
                    .ftGlass(FTRadius.md)
                }
            }
        }
        .padding(.top, FTSpacing.sm)
    }
}
