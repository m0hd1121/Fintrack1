import Foundation

// MARK: - Result Types

struct VATSummary {
    var taxYear: Int
    var totalVATPaid: Double
    var totalVATCollected: Double
    var totalVATExempt: Double
    var totalReclaimable: Double
    var netVATPosition: Double           // collected − paid (positive = owe to FTA)
    var quarterlyBreakdown: [QuarterlyVAT]
}

struct QuarterlyVAT: Identifiable {
    var id: Int { quarter }
    var quarter: Int
    var vatPaid: Double
    var vatCollected: Double
    var netPosition: Double
    var label: String { "Q\(quarter)" }
    var isSurplus: Bool { netPosition > 0 }
}

struct IncomeTaxEstimate {
    var annualIncome: Double
    var personalAllowance: Double
    var taxableIncome: Double
    var estimatedTax: Double
    var effectiveRate: Double
    var marginalRate: Double
    var monthlyProvision: Double
    var bracketBreakdown: [TaxBracketResult]
    var countryName: String
    var isSubjectToTax: Bool
    var currencyCode: String
}

struct TaxBracketResult: Identifiable {
    var id: String { label }
    var label: String
    var rate: Double
    var taxableAmount: Double
    var taxAmount: Double
}

struct DeductiblesSummary {
    var taxYear: Int
    var totalDeductible: Double
    var totalVATReclaimable: Double
    var transactionCount: Int
    var byCategory: [(category: String, amount: Double)]
}

struct FTAQuarterReport {
    var year: Int
    var quarter: Int
    var outputVAT: Double
    var inputVAT: Double
    var netVAT: Double
    var isPayable: Bool
    var label: String { "Q\(quarter) \(year)" }
    var ftaNote: String { isPayable ? "Payable to FTA" : "Refund from FTA" }
}

// MARK: - TaxService

final class TaxService {
    static let shared = TaxService()
    private init() {}

    // MARK: VAT Summary

    func vatSummary(records: [TaxRecord], taxYear: Int) -> VATSummary {
        let yr = records.filter { $0.taxYear == taxYear }
        let paid        = yr.filter { $0.vatType == .paid }.reduce(0) { $0 + $1.vatAmount }
        let collected   = yr.filter { $0.vatType == .collected }.reduce(0) { $0 + $1.vatAmount }
        let exempt      = yr.filter { $0.vatType == .exempt }.reduce(0) { $0 + $1.amount }
        let reclaimable = yr.filter { $0.vatType == .reclaimable }.reduce(0) { $0 + $1.vatAmount }

        let quarters = (1...4).map { q -> QuarterlyVAT in
            let lo = (q - 1) * 3 + 1
            let hi = lo + 2
            let qr = yr.filter {
                let m = Calendar.current.component(.month, from: $0.date)
                return m >= lo && m <= hi
            }
            let qp = qr.filter { $0.vatType == .paid }.reduce(0) { $0 + $1.vatAmount }
            let qc = qr.filter { $0.vatType == .collected }.reduce(0) { $0 + $1.vatAmount }
            return QuarterlyVAT(quarter: q, vatPaid: qp, vatCollected: qc, netPosition: qc - qp)
        }

        return VATSummary(
            taxYear: taxYear,
            totalVATPaid: paid,
            totalVATCollected: collected,
            totalVATExempt: exempt,
            totalReclaimable: reclaimable,
            netVATPosition: collected - paid,
            quarterlyBreakdown: quarters
        )
    }

    // MARK: FTA Quarter Report

    func ftaReport(records: [TaxRecord], year: Int, quarter: Int) -> FTAQuarterReport {
        let lo = (quarter - 1) * 3 + 1
        let hi = lo + 2
        let qr = records.filter {
            $0.taxYear == year &&
            Calendar.current.component(.month, from: $0.date) >= lo &&
            Calendar.current.component(.month, from: $0.date) <= hi
        }
        let output = qr.filter { $0.vatType == .collected }.reduce(0) { $0 + $1.vatAmount }
        let input  = qr.filter { $0.vatType == .paid || $0.vatType == .reclaimable }.reduce(0) { $0 + $1.vatAmount }
        let net    = output - input
        return FTAQuarterReport(year: year, quarter: quarter, outputVAT: output, inputVAT: input, netVAT: net, isPayable: net > 0)
    }

    // MARK: Income Tax Estimation

    func estimateIncomeTax(
        annualIncome: Double,
        configuration: TaxConfiguration?
    ) -> IncomeTaxEstimate {
        guard let cfg = configuration else {
            return IncomeTaxEstimate(
                annualIncome: annualIncome, personalAllowance: 0, taxableIncome: annualIncome,
                estimatedTax: 0, effectiveRate: 0, marginalRate: 0, monthlyProvision: 0,
                bracketBreakdown: [], countryName: "UAE", isSubjectToTax: false, currencyCode: "AED"
            )
        }

        guard cfg.isSubjectToIncomeTax, annualIncome > 0 else {
            return IncomeTaxEstimate(
                annualIncome: annualIncome, personalAllowance: cfg.personalAllowance,
                taxableIncome: max(0, annualIncome - cfg.personalAllowance),
                estimatedTax: 0, effectiveRate: 0, marginalRate: 0, monthlyProvision: 0,
                bracketBreakdown: [], countryName: cfg.countryName, isSubjectToTax: false,
                currencyCode: cfg.currency
            )
        }

        let taxable = max(0, annualIncome - cfg.personalAllowance)
        var totalTax = 0.0
        var results: [TaxBracketResult] = []
        var marginalRate = 0.0

        for b in cfg.brackets {
            let hi = b.maxIncome ?? Double.infinity
            if taxable > b.minIncome {
                let inBracket = min(taxable, hi) - b.minIncome
                if inBracket > 0 {
                    let tax = inBracket * b.rate
                    totalTax += tax
                    if b.rate > 0 {
                        results.append(TaxBracketResult(
                            label: b.label, rate: b.rate,
                            taxableAmount: inBracket, taxAmount: tax
                        ))
                    }
                    marginalRate = b.rate
                }
            }
        }

        return IncomeTaxEstimate(
            annualIncome: annualIncome,
            personalAllowance: cfg.personalAllowance,
            taxableIncome: taxable,
            estimatedTax: totalTax,
            effectiveRate: annualIncome > 0 ? totalTax / annualIncome : 0,
            marginalRate: marginalRate,
            monthlyProvision: totalTax / 12,
            bracketBreakdown: results,
            countryName: cfg.countryName,
            isSubjectToTax: true,
            currencyCode: cfg.currency
        )
    }

    // MARK: Deductibles from Transactions

    func deductiblesSummary(transactions: [Transaction], taxYear: Int) -> DeductiblesSummary {
        let cal = Calendar.current
        let eligible = transactions.filter {
            cal.component(.year, from: $0.date) == taxYear &&
            ($0.isTaxDeductible || $0.isVATReclaimable)
        }

        let deductible  = eligible.filter { $0.isTaxDeductible }.reduce(0) { $0 + $1.amountInBaseCurrency }
        let reclaimable = eligible.filter { $0.isVATReclaimable }.reduce(0) { $0 + $1.amountInBaseCurrency * 0.05 / 1.05 }

        let byCategory = Dictionary(grouping: eligible.filter { $0.isTaxDeductible }) { $0.category.rawValue }
            .mapValues { $0.reduce(0) { $0 + $1.amountInBaseCurrency } }
            .sorted { $0.value > $1.value }
            .map { (category: $0.key, amount: $0.value) }

        return DeductiblesSummary(
            taxYear: taxYear,
            totalDeductible: deductible,
            totalVATReclaimable: reclaimable,
            transactionCount: eligible.count,
            byCategory: byCategory
        )
    }

    // MARK: Synthetic VAT Records from Transactions

    func vatRecordsFromTransactions(transactions: [Transaction], taxYear: Int, vatRate: Double = 5.0) -> [TaxRecord] {
        let cal = Calendar.current
        return transactions
            .filter { cal.component(.year, from: $0.date) == taxYear && $0.isVATReclaimable }
            .map { tx in
                let vatAmt = tx.amountInBaseCurrency * vatRate / (100 + vatRate)
                return TaxRecord(
                    title: tx.title,
                    vendorOrCustomer: tx.merchant ?? tx.title,
                    amount: tx.amountInBaseCurrency - vatAmt,
                    vatAmount: vatAmt,
                    vatRate: vatRate,
                    vatType: .reclaimable,
                    date: tx.date,
                    currency: "AED",
                    taxYear: taxYear,
                    linkedTransactionId: tx.id
                )
            }
    }

    // MARK: Available Tax Years

    func availableTaxYears(records: [TaxRecord], transactions: [Transaction]) -> [Int] {
        var years = Set<Int>()
        records.forEach { years.insert($0.taxYear) }
        let cal = Calendar.current
        transactions.forEach { years.insert(cal.component(.year, from: $0.date)) }
        years.insert(cal.component(.year, from: Date()))
        return Array(years).sorted().reversed()
    }

    // MARK: Zakat Pre-fill from App Data

    func prefillZakat(
        record: ZakatRecord,
        transactions: [Transaction],
        accounts: [Account],
        investments: [Investment],
        goldHoldings: [GoldHolding],
        moneyLent: [MoneyLent],
        loans: [Loan],
        currency: String
    ) -> ZakatRecord {
        // Cash & Savings: sum of savings/cash accounts
        record.cashAndSavings = accounts
            .filter { !$0.isArchived && !$0.isHidden && ($0.type == .savings || $0.type == .cash) }
            .reduce(0) { $0 + $1.balance }

        // Investments market value
        record.investmentsValue = investments
            .reduce(0) { $0 + $1.currentValue }

        // Gold
        record.goldValueAED = goldHoldings
            .filter { !$0.isArchived && $0.metal == .gold }
            .reduce(0) { $0 + $1.currentValue }

        // Silver
        record.silverValueAED = goldHoldings
            .filter { !$0.isArchived && $0.metal == .silver }
            .reduce(0) { $0 + $1.currentValue }

        // Receivables: money lent not yet returned
        record.receivablesValue = moneyLent
            .filter { !$0.isFullyRepaid }
            .reduce(0) { $0 + $1.remainingBalance }

        // Debts: active loan outstanding balances
        record.immediateDebts = loans
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.outstandingBalance }

        record.updatedAt = Date()
        return record
    }
}
