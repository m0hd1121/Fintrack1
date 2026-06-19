import Foundation
import UserNotifications

// MARK: - IncomeStabilityFactor

struct IncomeStabilityFactor {
    let name: String
    let score: Double       // 0...100
    let weight: Double      // 0...1 (all weights sum to 1)
    let detail: String
    let icon: String
}

// MARK: - IncomeStabilityScore

struct IncomeStabilityScore {
    let score: Double           // 0...100 (weighted sum)
    let grade: Grade
    let factors: [IncomeStabilityFactor]
    let insights: [String]
    let recommendation: String
    let computedAt: Date

    enum Grade: String {
        case excellent = "A"    // 80+
        case good      = "B"    // 65–79
        case fair      = "C"    // 50–64
        case poor      = "D"    // 35–49
        case critical  = "F"    // <35

        static func from(score: Double) -> Grade {
            switch score {
            case 80...:  return .excellent
            case 65..<80: return .good
            case 50..<65: return .fair
            case 35..<50: return .poor
            default:      return .critical
            }
        }

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good:      return "mint"
            case .fair:      return "yellow"
            case .poor:      return "orange"
            case .critical:  return "red"
            }
        }

        var description: String {
            switch self {
            case .excellent: return "Excellent — Your income is highly stable and diversified."
            case .good:      return "Good — Your income is generally reliable with minor risks."
            case .fair:      return "Fair — Some instability detected; diversification recommended."
            case .poor:      return "Poor — Income is irregular or highly concentrated in one source."
            case .critical:  return "Critical — Significant income instability requires immediate attention."
            }
        }
    }
}

// MARK: - IncomeStreamSummary

struct IncomeStreamSummary {
    let sourceType: String    // "Salary", "Freelance", "Rental", "Dividends", "Business", "Other"
    let monthlyAverage: Double
    let yearToDate: Double
    let percentage: Double    // % of total income
    let trend: Trend

    enum Trend { case up, down, stable }
}

// MARK: - PassiveIncomeMetrics

struct PassiveIncomeMetrics {
    let rentalMonthly: Double
    let dividendMonthly: Double
    let royaltiesMonthly: Double
    let businessDistributionsMonthly: Double
    let totalMonthly: Double
    let totalAnnual: Double
    let breakdown: [(source: String, amount: Double, percentage: Double)]
}

// MARK: - IncomeService

final class IncomeService {

    static let shared = IncomeService()
    private init() {}

    // MARK: - Private Helpers

    private let calendar = Calendar.current
    private let notificationCenter = UNUserNotificationCenter.current()

    /// Returns the start of a month offset by `offset` months from today.
    private func startOfMonth(offsetBy offset: Int) -> Date {
        let now = Date()
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else { return now }
        return calendar.date(byAdding: .month, value: offset, to: monthStart) ?? monthStart
    }

    /// Formats a month label from a Date as "MMM yyyy".
    private func monthLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    /// Returns "MMM yyyy" key for an arbitrary date.
    private func monthKey(for date: Date) -> String {
        monthLabel(from: date)
    }

    /// Standard deviation of an array of Doubles. Returns 0 for empty or single-element arrays.
    private func standardDeviation(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }

    // MARK: - Salary Methods

    /// Records a salary payment against an active SalaryRecord.
    /// Computes status by comparing received date/amount to expected values.
    @discardableResult
    func recordSalaryPayment(
        record: SalaryRecord,
        amount: Double,
        date: Date,
        notes: String?
    ) -> SalaryPayment {
        let expectedDate   = record.nextExpectedDate
        let expectedAmount = record.expectedAmount

        let isLate     = date > expectedDate
        let isPartial  = amount < expectedAmount * 0.95

        let status: SalaryPaymentStatus
        if isLate && isPartial {
            status = .partialLate
        } else if isLate {
            status = .late
        } else if isPartial {
            status = .partial
        } else {
            status = .received
        }

        let variance = amount - expectedAmount

        let payment = SalaryPayment(
            expectedDate:   expectedDate,
            expectedAmount: expectedAmount,
            receivedDate:   date,
            receivedAmount: amount,
            status:         status,
            isLate:         isLate,
            variance:       variance,
            notes:          notes
        )

        record.payments.append(payment)
        record.updatedAt = Date()
        return payment
    }

    /// Checks all active salary records for missing payments and fires alerts.
    /// Sends a notification if the expected payment day has passed by 3+ days
    /// and no payment has been received for the current month.
    func checkSalaryAlerts(records: [SalaryRecord]) {
        let now      = Date()
        let todayKey = monthKey(for: now)

        for record in records where record.isActive {
            let expectedDay = record.expectedPaymentDay
            guard let expectedThisMonth = calendar.date(
                bySetting: .day,
                value: expectedDay,
                of: now
            ) else { continue }

            // Check we are at least 3 days past the expected date
            let daysPast = calendar.dateComponents([.day], from: expectedThisMonth, to: now).day ?? 0
            guard daysPast >= 3 else { continue }

            // Check whether a payment has already been received this calendar month
            let alreadyReceived = record.payments.contains { payment in
                guard let receivedDate = payment.receivedDate else { return false }
                return monthKey(for: receivedDate) == todayKey
            }
            guard !alreadyReceived else { continue }

            // Avoid duplicate alerts sent today
            if let lastAlertDate = record.lastSalaryAlertDate,
               calendar.isDateInToday(lastAlertDate) {
                continue
            }

            sendSalaryMissingAlert(record: record)
            record.lastSalaryAlertDate = now
        }
    }

    /// Schedules a UNCalendarNotificationTrigger reminder one day before the salary
    /// expected payment day each month.
    func scheduleSalaryReminder(record: SalaryRecord) {
        let content        = UNMutableNotificationContent()
        content.title      = "Salary Due Tomorrow"
        content.body       = "Your salary from \(record.employerName) (\(String(format: "%.2f", record.expectedAmount)) \(record.currency)) is expected tomorrow."
        content.sound      = .default

        // Trigger on day (expectedPaymentDay - 1) of each month at 09:00
        var components        = DateComponents()
        let reminderDay       = max(1, record.expectedPaymentDay - 1)
        components.day        = reminderDay
        components.hour       = 9
        components.minute     = 0

        let trigger  = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let id       = "salary_\(record.id.uuidString)"
        let request  = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    /// Cancels a pending salary reminder for the given record UUID.
    func cancelSalaryReminder(recordId: UUID) {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ["salary_\(recordId.uuidString)"]
        )
    }

    // MARK: - Salary Private Alert Sender

    private func sendSalaryMissingAlert(record: SalaryRecord) {
        let content   = UNMutableNotificationContent()
        content.title = "Salary Not Received"
        content.body  = "Your salary from \(record.employerName) (\(String(format: "%.2f", record.expectedAmount)) \(record.currency)) was expected on the \(record.expectedPaymentDay)th and has not been received yet."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id      = "salary_missing_\(record.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    // MARK: - Freelance Methods

    /// Records a payment against a specific invoice in a freelance project.
    func recordInvoicePayment(
        project: inout FreelanceProject,
        invoiceId: UUID,
        amount: Double,
        date: Date
    ) {
        guard let idx = project.invoices.firstIndex(where: { $0.id == invoiceId }) else { return }
        project.invoices[idx].paidDate      = date
        project.invoices[idx].paidAmount    = amount
        project.invoices[idx].statusRaw     = InvoiceStatus.paid.rawValue
        project.updatedAt = Date()
    }

    /// Returns all unpaid invoices across all projects whose due date has passed.
    func checkOverdueInvoices(
        projects: [FreelanceProject]
    ) -> [(project: FreelanceProject, invoice: FreelanceInvoice)] {
        let now = Date()
        var result: [(project: FreelanceProject, invoice: FreelanceInvoice)] = []
        for project in projects {
            for invoice in project.invoices where !invoice.isPaid && invoice.dueDate < now {
                result.append((project, invoice))
            }
        }
        return result
    }

    /// Fires an immediate notification for an overdue freelance invoice.
    func sendOverdueInvoiceAlert(project: FreelanceProject, invoice: FreelanceInvoice) {
        let content   = UNMutableNotificationContent()
        content.title = "Invoice Overdue — \(project.clientName)"
        content.body  = "Invoice #\(invoice.invoiceNumber) for \(String(format: "%.2f", invoice.amount)) \(invoice.currency) is overdue."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id      = "invoice_overdue_\(invoice.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    // MARK: - Rental Methods

    /// Records a rent payment for a property.
    /// Finds the most recent unpaid payment record, or creates a new one if none exists.
    func recordRentPayment(
        property: RentalProperty,
        amount: Double,
        date: Date,
        notes: String?
    ) {
        let unpaid = property.paymentHistory
            .filter { !$0.isPaid }
            .sorted { $0.expectedDate < $1.expectedDate }

        if let idx = property.paymentHistory.firstIndex(where: { !$0.isPaid && $0.expectedDate <= date }) {
            property.paymentHistory[idx].receivedDate   = date
            property.paymentHistory[idx].receivedAmount = amount
            property.paymentHistory[idx].isPaid         = true
            property.paymentHistory[idx].isLate         = date > property.paymentHistory[idx].expectedDate
            property.paymentHistory[idx].notes          = notes
        } else if unpaid.isEmpty {
            // No unpaid record found — create a new one for the current month
            let expectedDate = calendar.date(
                bySetting: .day,
                value: property.rentDueDay,
                of: date
            ) ?? date

            var newRecord                = RentPaymentRecord(
                expectedDate:   expectedDate,
                expectedAmount: property.currentMonthlyRent
            )
            newRecord.receivedDate   = date
            newRecord.receivedAmount = amount
            newRecord.isPaid         = true
            newRecord.isLate         = date > expectedDate
            newRecord.notes          = notes
            property.paymentHistory.append(newRecord)
        } else {
            // Use the earliest unpaid record
            if let first = unpaid.first,
               let idx = property.paymentHistory.firstIndex(where: { $0.id == first.id }) {
                property.paymentHistory[idx].receivedDate   = date
                property.paymentHistory[idx].receivedAmount = amount
                property.paymentHistory[idx].isPaid         = true
                property.paymentHistory[idx].isLate         = date > property.paymentHistory[idx].expectedDate
                property.paymentHistory[idx].notes          = notes
            }
        }

        property.updatedAt = Date()
    }

    /// Marks a property as occupied, appends the occupancy period, and generates
    /// monthly RentPaymentRecord entries from leaseStartDate to leaseEndDate.
    func addOccupancyPeriod(property: inout RentalProperty, period: OccupancyPeriod) {
        property.isOccupied = true
        property.occupancyPeriods.append(period)

        // Generate monthly rent payment stubs for the full lease term
        let endDate      = period.leaseEndDate
        var currentStart = period.leaseStartDate

        while currentStart <= endDate {
            let expectedDate = calendar.date(
                bySetting: .day,
                value: property.rentDueDay,
                of: currentStart
            ) ?? currentStart

            let record = RentPaymentRecord(
                expectedDate:   expectedDate,
                expectedAmount: period.monthlyRent
            )

            // Avoid duplicate stubs for the same expected date
            let alreadyExists = property.paymentHistory.contains {
                calendar.isDate($0.expectedDate, inSameDayAs: expectedDate)
            }

            if !alreadyExists {
                property.paymentHistory.append(record)
            }

            guard let next = calendar.date(byAdding: .month, value: 1, to: currentStart) else { break }
            currentStart = next
        }

        property.updatedAt = Date()
    }

    /// Marks the property as unoccupied and closes the most recent occupancy period.
    func endOccupancy(property: inout RentalProperty) {
        property.isOccupied = false
        if let lastIdx = property.occupancyPeriods.indices.last {
            property.occupancyPeriods[lastIdx].leaseEndDate = Date()
        }
        property.updatedAt = Date()
    }

    /// Checks all active rental properties for overdue rent payments and fires alerts.
    func checkLateRentAlerts(properties: [RentalProperty]) {
        let now = Date()

        for property in properties where property.isOccupied {
            let overdueRecords = property.paymentHistory.filter {
                !$0.isPaid && $0.expectedDate < now
            }
            guard !overdueRecords.isEmpty else { continue }

            // Avoid duplicate alerts sent today
            if let lastAlertDate = property.lastRentAlertDate,
               calendar.isDateInToday(lastAlertDate) {
                continue
            }

            let overdueCount  = overdueRecords.count
            let totalOverdue  = overdueRecords.compactMap { $0.expectedAmount }.reduce(0, +)
            sendLateRentAlert(property: property, overdueCount: overdueCount, totalOverdue: totalOverdue)
            property.lastRentAlertDate = now
        }
    }

    // MARK: - Rental Private Alert Sender

    private func sendLateRentAlert(property: RentalProperty, overdueCount: Int, totalOverdue: Double) {
        let content   = UNMutableNotificationContent()
        content.title = "Rent Overdue — \(property.propertyName)"
        let plural    = overdueCount == 1 ? "payment" : "payments"
        content.body  = "\(property.propertyName) has \(overdueCount) overdue rent \(plural) totalling \(String(format: "%.2f", totalOverdue)) \(property.currency)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id      = "rent_late_\(property.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    // MARK: - AI Income Stability Score

    /// Computes a weighted Income Stability Score (0–100) across 6 factors using
    /// transaction history, salary records, freelance projects, rental properties,
    /// and dividend records.
    func computeStabilityScore(
        transactions:      [Transaction],
        salaryRecords:     [SalaryRecord],
        freelanceProjects: [FreelanceProject],
        rentalProperties:  [RentalProperty],
        dividends:         [Dividend],
        baseCurrency:      String
    ) -> IncomeStabilityScore {

        // Filter income transactions for the last 6 months
        let sixMonthsAgo    = startOfMonth(offsetBy: -6)
        let incomeTransactions = transactions.filter {
            $0.type == .income && $0.date >= sixMonthsAgo && !$0.isPending
        }

        // Build monthly totals map for last 6 months
        var monthlyTotals: [String: Double] = [:]
        for offset in -5...0 {
            let monthStart = startOfMonth(offsetBy: offset)
            monthlyTotals[monthKey(for: monthStart)] = 0
        }
        for tx in incomeTransactions {
            let key = monthKey(for: tx.date)
            monthlyTotals[key, default: 0] += tx.amountInBaseCurrency
        }

        let sortedKeys    = monthlyTotals.keys.sorted()
        let monthlyValues = sortedKeys.map { monthlyTotals[$0] ?? 0 }

        // ── Factor 1: Payment Regularity (weight: 0.25) ──────────────────────
        let monthsWithIncome = monthlyValues.filter { $0 > 0 }.count
        let monthlyCoverage  = Double(monthsWithIncome) / 6.0 * 100.0

        // Average on-time rate from salary records
        let onTimeRates: [Double] = salaryRecords.filter { $0.isActive }.compactMap { record in
            let total   = record.payments.count
            guard total > 0 else { return nil }
            let onTime  = record.payments.filter { !$0.isLate }.count
            return Double(onTime) / Double(total) * 100.0
        }
        let avgOnTimeRate = onTimeRates.isEmpty ? 80.0 : onTimeRates.reduce(0, +) / Double(onTimeRates.count)

        let regularityScore = (monthlyCoverage * 0.60 + avgOnTimeRate * 0.40)
        let factor1 = IncomeStabilityFactor(
            name:   "Payment Regularity",
            score:  regularityScore,
            weight: 0.25,
            detail: "\(monthsWithIncome) of 6 months had income; \(String(format: "%.0f", avgOnTimeRate))% on-time salary payments.",
            icon:   "calendar.badge.checkmark"
        )

        // ── Factor 2: Amount Variance (weight: 0.20) ──────────────────────────
        let mean6 = monthlyValues.reduce(0, +) / Double(max(1, monthlyValues.count))
        let cv    = mean6 > 0 ? (standardDeviation(of: monthlyValues) / mean6) : 1.0
        let varianceScore = max(0, 100.0 - (cv * 150.0))
        let factor2 = IncomeStabilityFactor(
            name:   "Amount Variance",
            score:  varianceScore,
            weight: 0.20,
            detail: "Coefficient of variation: \(String(format: "%.1f", cv * 100))%. Lower variation means more predictable income.",
            icon:   "waveform.path.ecg"
        )

        // ── Factor 3: Source Diversity (weight: 0.20) ─────────────────────────
        var activeSources = Set<String>()
        let hasSalary     = incomeTransactions.contains { $0.category == .salary || $0.category == .bonus }
        let hasFreelance  = incomeTransactions.contains { $0.category == .freelance }
        let hasRental     = incomeTransactions.contains { $0.category == .rental }
        let hasDividends  = incomeTransactions.contains { $0.category == .dividends || $0.category == .investmentIncome }
        let hasBusiness   = incomeTransactions.contains { $0.category == .business }
        let hasOther      = incomeTransactions.contains {
            ![TransactionCategory.salary, .bonus, .freelance, .rental, .dividends,
              .investmentIncome, .business].contains($0.category)
        }

        if hasSalary    { activeSources.insert("Salary") }
        if hasFreelance { activeSources.insert("Freelance") }
        if hasRental    { activeSources.insert("Rental") }
        if hasDividends { activeSources.insert("Dividends") }
        if hasBusiness  { activeSources.insert("Business") }
        if hasOther     { activeSources.insert("Other") }

        let sourceCount      = activeSources.count
        let diversityScore   = min(100.0, (Double(sourceCount) / 4.0) * 100.0)
        let factor3 = IncomeStabilityFactor(
            name:   "Source Diversity",
            score:  diversityScore,
            weight: 0.20,
            detail: "\(sourceCount) distinct income source\(sourceCount == 1 ? "" : "s") active in the last 6 months. 4+ sources = 100.",
            icon:   "chart.pie.fill"
        )

        // ── Factor 4: Concentration Risk (weight: 0.15) ───────────────────────
        let totalIncome6m = incomeTransactions.reduce(0) { $0 + $1.amountInBaseCurrency }

        // Group by broad category
        var categoryTotals: [String: Double] = [:]
        for tx in incomeTransactions {
            let key: String
            switch tx.category {
            case .salary, .bonus:              key = "Salary"
            case .freelance:                   key = "Freelance"
            case .rental:                      key = "Rental"
            case .dividends, .investmentIncome: key = "Dividends"
            case .business:                    key = "Business"
            default:                           key = "Other"
            }
            categoryTotals[key, default: 0] += tx.amountInBaseCurrency
        }

        let topSourcePct: Double = {
            guard totalIncome6m > 0 else { return 100.0 }
            let maxAmount = categoryTotals.values.max() ?? totalIncome6m
            return (maxAmount / totalIncome6m) * 100.0
        }()

        // Score = 100 when top source ≤ 50%, linearly decreasing to 50 at 100%
        let concentrationScore: Double
        if topSourcePct <= 50 {
            concentrationScore = 100.0
        } else {
            concentrationScore = max(0, 100.0 - (topSourcePct - 50.0))
        }
        let factor4 = IncomeStabilityFactor(
            name:   "Concentration Risk",
            score:  concentrationScore,
            weight: 0.15,
            detail: "Largest income source represents \(String(format: "%.0f", topSourcePct))% of total income. Lower concentration = lower risk.",
            icon:   "exclamationmark.triangle.fill"
        )

        // ── Factor 5: Historical Volatility (weight: 0.10) ────────────────────
        let avgDeviation: Double = {
            guard mean6 > 0 else { return 100.0 }
            let deviations = monthlyValues.map { abs($0 - mean6) }
            return deviations.reduce(0, +) / Double(max(1, deviations.count))
        }()
        let volatilityScore = mean6 > 0
            ? max(0.0, 100.0 - (avgDeviation / mean6 * 100.0))
            : 0.0
        let factor5 = IncomeStabilityFactor(
            name:   "Historical Volatility",
            score:  volatilityScore,
            weight: 0.10,
            detail: "Average monthly deviation from 6-month mean: \(String(format: "%.1f", (mean6 > 0 ? avgDeviation / mean6 * 100 : 100)))%.",
            icon:   "chart.xyaxis.line"
        )

        // ── Factor 6: Income Trend (weight: 0.10) ─────────────────────────────
        let first3 = Array(monthlyValues.prefix(3))
        let last3  = Array(monthlyValues.suffix(3))
        let first3Avg = first3.reduce(0, +) / Double(max(1, first3.count))
        let last3Avg  = last3.reduce(0, +) / Double(max(1, last3.count))

        let trendScore: Double
        if first3Avg <= 0 {
            trendScore = last3Avg > 0 ? 100.0 : 50.0
        } else if last3Avg >= first3Avg {
            trendScore = 100.0
        } else {
            // Penalize proportionally: if income dropped to 0, score = 0
            trendScore = max(0, (last3Avg / first3Avg) * 100.0)
        }
        let factor6 = IncomeStabilityFactor(
            name:   "Income Trend",
            score:  trendScore,
            weight: 0.10,
            detail: "Last 3-month avg: \(String(format: "%.2f", last3Avg)) vs. first 3-month avg: \(String(format: "%.2f", first3Avg)).",
            icon:   "arrow.up.right.circle.fill"
        )

        // ── Final Weighted Score ──────────────────────────────────────────────
        let factors = [factor1, factor2, factor3, factor4, factor5, factor6]
        let finalScore = factors.reduce(0.0) { $0 + $1.score * $1.weight }
        let grade      = IncomeStabilityScore.Grade.from(score: finalScore)

        // ── Insights ──────────────────────────────────────────────────────────
        var insights: [String] = []

        if monthsWithIncome < 5 {
            insights.append("Income was missing or zero in \(6 - monthsWithIncome) of the last 6 months, reducing payment regularity.")
        } else {
            insights.append("Income was recorded in \(monthsWithIncome) of the last 6 months — strong payment regularity.")
        }

        if cv > 0.4 {
            insights.append("High month-to-month income variance (CV \(String(format: "%.0f", cv * 100))%) makes cash-flow planning difficult.")
        } else {
            insights.append("Monthly income amounts are relatively consistent, supporting predictable budgeting.")
        }

        if sourceCount >= 3 {
            insights.append("Good income diversification with \(sourceCount) active streams reduces dependency on any single source.")
        } else {
            insights.append("Only \(sourceCount) income source\(sourceCount == 1 ? "" : "s") active — consider building additional streams.")
        }

        if topSourcePct > 80 {
            insights.append("Over \(String(format: "%.0f", topSourcePct))% of income comes from a single source — high concentration risk.")
        }

        // ── Recommendation ────────────────────────────────────────────────────
        let recommendation: String
        switch grade {
        case .excellent:
            recommendation = "Your income is in excellent shape. Continue maintaining multiple income streams and monitor for any emerging variance."
        case .good:
            recommendation = "Your income stability is good. Consider adding one more passive income stream (rental or dividend) to push towards an excellent rating."
        case .fair:
            recommendation = "Focus on building income regularity: pursue recurring retainer contracts, dividend-paying investments, or a rental property to reduce month-to-month gaps."
        case .poor:
            recommendation = "Prioritise stabilising your primary income source and actively build at least one reliable passive stream — rental income or index fund dividends are low-maintenance options."
        case .critical:
            recommendation = "Immediate action needed: secure a stable income source, reduce reliance on sporadic payments, and establish an emergency fund of at least 3–6 months of expenses."
        }

        return IncomeStabilityScore(
            score:          finalScore,
            grade:          grade,
            factors:        factors,
            insights:       insights,
            recommendation: recommendation,
            computedAt:     Date()
        )
    }

    // MARK: - Analytics

    /// Groups income transactions from the last 6 months by source type and
    /// returns a summary per stream including monthly average, YTD, percentage, and trend.
    func computeStreamSummaries(
        transactions: [Transaction],
        baseCurrency: String
    ) -> [IncomeStreamSummary] {

        let now          = Date()
        let sixMonthsAgo = startOfMonth(offsetBy: -6)
        let yearStart    = calendar.date(
            from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1)
        ) ?? now

        let income6m = transactions.filter {
            $0.type == .income && $0.date >= sixMonthsAgo && !$0.isPending
        }
        let incomeYTD = transactions.filter {
            $0.type == .income && $0.date >= yearStart && !$0.isPending
        }

        let total6m = income6m.reduce(0.0) { $0 + $1.amountInBaseCurrency }

        // Mapping function: category → stream label
        func streamLabel(for category: TransactionCategory) -> String {
            switch category {
            case .salary, .bonus:               return "Salary"
            case .freelance:                    return "Freelance"
            case .rental:                       return "Rental"
            case .dividends, .investmentIncome: return "Dividends"
            case .business:                     return "Business"
            default:                            return "Other"
            }
        }

        // Aggregate by stream for 6-month window
        var streamTotals6m: [String: Double] = [:]
        for tx in income6m {
            let label = streamLabel(for: tx.category)
            streamTotals6m[label, default: 0] += tx.amountInBaseCurrency
        }

        // Aggregate YTD
        var streamTotalsYTD: [String: Double] = [:]
        for tx in incomeYTD {
            let label = streamLabel(for: tx.category)
            streamTotalsYTD[label, default: 0] += tx.amountInBaseCurrency
        }

        // For trend: split 6 months into first 3 and last 3
        let midPoint = startOfMonth(offsetBy: -3)
        var streamFirst3: [String: Double] = [:]
        var streamLast3:  [String: Double] = [:]
        for tx in income6m {
            let label = streamLabel(for: tx.category)
            if tx.date < midPoint {
                streamFirst3[label, default: 0] += tx.amountInBaseCurrency
            } else {
                streamLast3[label, default: 0] += tx.amountInBaseCurrency
            }
        }

        let allLabels = Set(streamTotals6m.keys)
        var summaries: [IncomeStreamSummary] = []

        for label in allLabels.sorted() {
            let total6  = streamTotals6m[label] ?? 0
            let ytd     = streamTotalsYTD[label] ?? 0
            let monthly = total6 / 6.0
            let pct     = total6m > 0 ? (total6 / total6m) * 100.0 : 0

            let f3 = streamFirst3[label] ?? 0
            let l3 = streamLast3[label] ?? 0
            let trend: IncomeStreamSummary.Trend
            if abs(l3 - f3) < (f3 * 0.05) {
                trend = .stable
            } else if l3 > f3 {
                trend = .up
            } else {
                trend = .down
            }

            summaries.append(IncomeStreamSummary(
                sourceType:    label,
                monthlyAverage: monthly,
                yearToDate:    ytd,
                percentage:    pct,
                trend:         trend
            ))
        }

        return summaries.sorted { $0.monthlyAverage > $1.monthlyAverage }
    }

    /// Computes passive income metrics from rental transactions, dividend records,
    /// royalty transactions, and business distribution transactions.
    func computePassiveIncomeMetrics(
        transactions:    [Transaction],
        dividends:       [Dividend],
        rentalProperties: [RentalProperty],
        baseCurrency:    String
    ) -> PassiveIncomeMetrics {

        let sixMonthsAgo = startOfMonth(offsetBy: -6)

        // ── Rental ────────────────────────────────────────────────────────────
        // Use rental income transactions from last 6 months
        let rentalTransactions = transactions.filter {
            $0.type == .income && $0.category == .rental &&
            $0.date >= sixMonthsAgo && !$0.isPending
        }
        let rentalFromTx = rentalTransactions.reduce(0.0) { $0 + $1.amountInBaseCurrency }

        // Also aggregate from rental property payment history
        var rentalFromProperties = 0.0
        for property in rentalProperties {
            let paid = property.paymentHistory.filter {
                $0.isPaid &&
                ($0.receivedDate ?? Date.distantPast) >= sixMonthsAgo
            }
            rentalFromProperties += paid.compactMap { $0.receivedAmount }.reduce(0, +)
        }
        // Use whichever is larger (avoid double-counting by taking max as a conservative estimate)
        let rentalTotal   = max(rentalFromTx, rentalFromProperties)
        let rentalMonthly = rentalTotal / 6.0

        // ── Dividends ─────────────────────────────────────────────────────────
        let dividendsSince = dividends.filter { $0.date >= sixMonthsAgo }
        let dividendTotal  = dividendsSince.reduce(0.0) { $0 + $1.netAmount }
        let dividendMonthly = dividendTotal / 6.0

        // ── Royalties ─────────────────────────────────────────────────────────
        let royaltyTransactions = transactions.filter { tx in
            tx.type == .income && tx.category == .other &&
            tx.date >= sixMonthsAgo && !tx.isPending &&
            (tx.incomeSource?.lowercased().contains("royalt") ?? false)
        }
        let royaltyTotal   = royaltyTransactions.reduce(0.0) { $0 + $1.amountInBaseCurrency }
        let royaltiesMonthly = royaltyTotal / 6.0

        // ── Business Distributions ────────────────────────────────────────────
        let businessDistTransactions = transactions.filter {
            $0.type == .income && $0.category == .business &&
            $0.date >= sixMonthsAgo && !$0.isPending
        }
        let businessDistTotal   = businessDistTransactions.reduce(0.0) { $0 + $1.amountInBaseCurrency }
        let businessDistMonthly = businessDistTotal / 6.0

        // ── Aggregates ────────────────────────────────────────────────────────
        let totalMonthly = rentalMonthly + dividendMonthly + royaltiesMonthly + businessDistMonthly
        let totalAnnual  = totalMonthly * 12.0

        // ── Breakdown ─────────────────────────────────────────────────────────
        var breakdown: [(source: String, amount: Double, percentage: Double)] = []
        let sources: [(String, Double)] = [
            ("Rental",               rentalMonthly),
            ("Dividends",            dividendMonthly),
            ("Royalties",            royaltiesMonthly),
            ("Business Distributions", businessDistMonthly)
        ]
        for (source, amount) in sources where amount > 0 {
            let pct = totalMonthly > 0 ? (amount / totalMonthly) * 100.0 : 0
            breakdown.append((source: source, amount: amount, percentage: pct))
        }
        breakdown.sort { $0.amount > $1.amount }

        return PassiveIncomeMetrics(
            rentalMonthly:                  rentalMonthly,
            dividendMonthly:                dividendMonthly,
            royaltiesMonthly:               royaltiesMonthly,
            businessDistributionsMonthly:   businessDistMonthly,
            totalMonthly:                   totalMonthly,
            totalAnnual:                    totalAnnual,
            breakdown:                      breakdown
        )
    }

    /// Returns the last N months of total income, keyed as "MMM yyyy" month labels.
    func monthlyIncomeTotals(
        transactions: [Transaction],
        months: Int
    ) -> [(month: String, amount: Double)] {
        let start = startOfMonth(offsetBy: -months)
        let incomeTransactions = transactions.filter {
            $0.type == .income && $0.date >= start && !$0.isPending
        }

        // Pre-populate all months with zero
        var totals: [String: Double] = [:]
        for offset in (-months + 1)...0 {
            let monthStart = startOfMonth(offsetBy: offset)
            totals[monthKey(for: monthStart)] = 0
        }

        for tx in incomeTransactions {
            let key = monthKey(for: tx.date)
            totals[key, default: 0] += tx.amountInBaseCurrency
        }

        // Sort chronologically
        let dateFormatter    = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"

        return totals.keys
            .sorted {
                let d1 = dateFormatter.date(from: $0) ?? Date.distantPast
                let d2 = dateFormatter.date(from: $1) ?? Date.distantPast
                return d1 < d2
            }
            .map { (month: $0, amount: totals[$0] ?? 0) }
    }
}
