import Foundation
// Models (Loan, CreditCard) imported via same module

// MARK: - DebtItem

struct DebtItem {
    var id: UUID
    var name: String
    var outstandingBalance: Double
    var interestRate: Double   // annual percentage, e.g. 5.0 for 5%
    var minimumPayment: Double
    var currency: String
    var nextPaymentDate: Date?
    var lenderName: String
    var isLoan: Bool           // true = Loan, false = CreditCard
}

// MARK: - RepaymentMonth

struct RepaymentMonth: Identifiable {
    var id = UUID()
    var month: Int
    var debtName: String
    var payment: Double
    var interestPaid: Double
    var principalPaid: Double
    var remainingBalance: Double
}

// MARK: - DebtPayoffPlan

struct DebtPayoffPlan {
    struct DebtOrderEntry: Identifiable {
        var id = UUID()
        var name: String
        var payoffOrder: Int
        var payoffDate: Date
        var totalInterestPaid: Double
        var monthsToPayoff: Int
        var minimumPayment: Double
        var snowballExtraAt: Double  // extra monthly $ applied to this debt at payoff time
    }

    var entries: [DebtOrderEntry]
    var totalMonthsToPayoff: Int
    var totalInterestPaid: Double
    var payoffDate: Date
    var monthlySchedule: [RepaymentMonth]
}

// MARK: - InterestSavingsResult

struct InterestSavingsResult {
    var standardTotalInterest: Double
    var acceleratedTotalInterest: Double
    var interestSaved: Double
    var standardMonths: Int
    var acceleratedMonths: Int
    var monthsReduced: Int
    var standardPayoffDate: Date
    var acceleratedPayoffDate: Date
    var monthlySavingsBreakdown: [(month: Int, standardBalance: Double, acceleratedBalance: Double)]
}

// MARK: - CreditUtilizationSummary

struct CreditUtilizationSummary {

    struct CardUtilization: Identifiable {
        var id: UUID
        var cardName: String
        var bankName: String
        var outstandingBalance: Double
        var creditLimit: Double
        var utilizationRate: Double
        var availableCredit: Double
        var color: String
        var currency: String
        var utilizationStatus: UtilizationStatus
    }

    enum UtilizationStatus: String {
        case excellent = "Excellent"  // < 10%
        case good      = "Good"       // 10–29%
        case fair      = "Fair"       // 30–49%
        case poor      = "Poor"       // 50–74%
        case critical  = "Critical"   // 75%+

        var threshold: Double {
            switch self {
            case .excellent: return 0.10
            case .good:      return 0.30
            case .fair:      return 0.50
            case .poor:      return 0.75
            case .critical:  return 1.01
            }
        }

        static func from(rate: Double) -> UtilizationStatus {
            switch rate {
            case ..<0.10: return .excellent
            case ..<0.30: return .good
            case ..<0.50: return .fair
            case ..<0.75: return .poor
            default:      return .critical
            }
        }

        var colorName: String {
            switch self {
            case .excellent: return "green"
            case .good:      return "teal"
            case .fair:      return "yellow"
            case .poor:      return "orange"
            case .critical:  return "red"
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "checkmark.circle.fill"
            case .good:      return "checkmark.circle"
            case .fair:      return "exclamationmark.circle"
            case .poor:      return "exclamationmark.triangle.fill"
            case .critical:  return "xmark.circle.fill"
            }
        }
    }

    var cards: [CardUtilization]
    var totalOutstanding: Double
    var totalLimit: Double
    var aggregateUtilization: Double
    var aggregateStatus: UtilizationStatus
    var availableCredit: Double
    var recommendations: [String]
}

// MARK: - DebtService

final class DebtService {

    static let shared = DebtService()
    private init() {}
    private let calendar = Calendar.current

    // MARK: - Conversion helpers

    /// Converts active Loan and CreditCard records into a unified DebtItem array.
    func debtItems(loans: [Loan], creditCards: [CreditCard]) -> [DebtItem] {
        let loanItems: [DebtItem] = loans
            .filter { $0.isActive }
            .map { loan in
                DebtItem(
                    id: loan.id,
                    name: loan.name,
                    outstandingBalance: loan.outstandingBalance,
                    interestRate: loan.interestRate,
                    minimumPayment: loan.emiAmount,
                    currency: loan.currency,
                    nextPaymentDate: loan.nextPaymentDate,
                    lenderName: loan.lenderName,
                    isLoan: true
                )
            }

        let cardItems: [DebtItem] = creditCards
            .filter { $0.isActive }
            .map { card in
                DebtItem(
                    id: card.id,
                    name: card.name,
                    outstandingBalance: card.outstandingBalance,
                    interestRate: card.interestRate,
                    minimumPayment: max(card.minimumPayment, 25),
                    currency: card.currency,
                    nextPaymentDate: card.dueDate,
                    lenderName: card.bankName,
                    isLoan: false
                )
            }

        return loanItems + cardItems
    }

    /// Sum of all active outstanding balances (raw values; caller handles currency conversion).
    func totalOutstandingDebt(loans: [Loan], creditCards: [CreditCard]) -> Double {
        let loanTotal = loans
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.outstandingBalance }
        let cardTotal = creditCards
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.outstandingBalance }
        return loanTotal + cardTotal
    }

    /// Sum of minimum monthly payments across all active debts.
    func totalMinimumPayments(loans: [Loan], creditCards: [CreditCard]) -> Double {
        let loanMin = loans
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.emiAmount }
        let cardMin = creditCards
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.minimumPayment }
        return loanMin + cardMin
    }

    // MARK: - Snowball Plan

    /// Debt Snowball: pays off smallest balance first.
    /// Extra monthly payment + freed-up minimums are redirected to the next smallest debt.
    func snowballPlan(items: [DebtItem], extraMonthlyPayment: Double) -> DebtPayoffPlan {
        let sorted = items.sorted { $0.outstandingBalance < $1.outstandingBalance }
        return buildPayoffPlan(orderedItems: sorted, extraMonthlyPayment: extraMonthlyPayment)
    }

    // MARK: - Avalanche Plan

    /// Debt Avalanche: pays off highest-interest debt first.
    /// Extra monthly payment + freed-up minimums are redirected to the next highest-rate debt.
    func avalanchePlan(items: [DebtItem], extraMonthlyPayment: Double) -> DebtPayoffPlan {
        let sorted = items.sorted { $0.interestRate > $1.interestRate }
        return buildPayoffPlan(orderedItems: sorted, extraMonthlyPayment: extraMonthlyPayment)
    }

    // MARK: - Interest Savings

    /// Compares standard amortization (min payment) with accelerated (min + extra).
    func calculateInterestSavings(item: DebtItem, extraMonthlyPayment: Double) -> InterestSavingsResult {
        let (stdInterest, stdMonths) = simulateSingleDebt(
            balance: item.outstandingBalance,
            annualRate: item.interestRate,
            monthlyPayment: item.minimumPayment
        )
        let (accInterest, accMonths) = simulateSingleDebt(
            balance: item.outstandingBalance,
            annualRate: item.interestRate,
            monthlyPayment: item.minimumPayment + extraMonthlyPayment
        )

        // Build breakdown for the first 60 months (or until both are paid off)
        let breakdownLimit = min(max(stdMonths, accMonths), 60)
        var stdBalance  = item.outstandingBalance
        var accBalance  = item.outstandingBalance
        let monthlyRate = item.interestRate / 100.0 / 12.0
        var breakdown: [(month: Int, standardBalance: Double, acceleratedBalance: Double)] = []

        for month in 1...max(breakdownLimit, 1) {
            // Standard
            if stdBalance > 0 {
                let interest = stdBalance * monthlyRate
                let principal = min(max(item.minimumPayment - interest, 0), stdBalance)
                stdBalance = max(stdBalance - principal, 0)
            }
            // Accelerated
            if accBalance > 0 {
                let interest = accBalance * monthlyRate
                let payment = item.minimumPayment + extraMonthlyPayment
                let principal = min(max(payment - interest, 0), accBalance)
                accBalance = max(accBalance - principal, 0)
            }
            breakdown.append((month: month, standardBalance: stdBalance, acceleratedBalance: accBalance))
            if stdBalance <= 0 && accBalance <= 0 { break }
        }

        let now = Date()
        let stdPayoffDate  = calendar.date(byAdding: .month, value: stdMonths,  to: now) ?? now
        let accPayoffDate  = calendar.date(byAdding: .month, value: accMonths,  to: now) ?? now

        return InterestSavingsResult(
            standardTotalInterest:    stdInterest,
            acceleratedTotalInterest: accInterest,
            interestSaved:            max(stdInterest - accInterest, 0),
            standardMonths:           stdMonths,
            acceleratedMonths:        accMonths,
            monthsReduced:            max(stdMonths - accMonths, 0),
            standardPayoffDate:       stdPayoffDate,
            acceleratedPayoffDate:    accPayoffDate,
            monthlySavingsBreakdown:  breakdown
        )
    }

    // MARK: - Credit Utilization Summary

    /// Builds a full utilization summary with per-card details and actionable recommendations.
    func utilizationSummary(creditCards: [CreditCard]) -> CreditUtilizationSummary {
        let activeCards = creditCards.filter { $0.isActive }

        let cardUtilizations: [CreditUtilizationSummary.CardUtilization] = activeCards.map { card in
            let rate   = card.outstandingBalance / max(card.creditLimit, 1)
            let status = CreditUtilizationSummary.UtilizationStatus.from(rate: rate)
            return CreditUtilizationSummary.CardUtilization(
                id: card.id,
                cardName: card.name,
                bankName: card.bankName,
                outstandingBalance: card.outstandingBalance,
                creditLimit: card.creditLimit,
                utilizationRate: rate,
                availableCredit: card.availableCredit,
                color: card.color,
                currency: card.currency,
                utilizationStatus: status
            )
        }

        let totalOutstanding = activeCards.reduce(0) { $0 + $1.outstandingBalance }
        let totalLimit       = activeCards.reduce(0) { $0 + $1.creditLimit }
        let aggregateRate    = totalOutstanding / max(totalLimit, 1)
        let aggregateStatus  = CreditUtilizationSummary.UtilizationStatus.from(rate: aggregateRate)
        let availableCredit  = max(totalLimit - totalOutstanding, 0)

        // Build recommendations (max 4)
        var recommendations: [String] = []

        if aggregateRate < 0.10 {
            recommendations.append("Excellent utilization! Maintaining below 10% maximizes your credit score.")
        } else if aggregateRate > 0.30 {
            recommendations.append("Consider paying down high-balance cards to improve your credit score.")
        }

        for card in cardUtilizations {
            guard recommendations.count < 4 else { break }
            if card.utilizationRate > 0.75 {
                recommendations.append("Critical: \(card.cardName) is over 75% utilization. Prioritize paying this down immediately.")
            } else if card.utilizationRate > 0.50 {
                recommendations.append("Reduce \(card.cardName) balance below 50% utilization for better credit health.")
            }
        }

        return CreditUtilizationSummary(
            cards:                cardUtilizations,
            totalOutstanding:     totalOutstanding,
            totalLimit:           totalLimit,
            aggregateUtilization: aggregateRate,
            aggregateStatus:      aggregateStatus,
            availableCredit:      availableCredit,
            recommendations:      Array(recommendations.prefix(4))
        )
    }

    // MARK: - Private simulation helpers

    /// Core snowball/avalanche engine.
    /// `orderedItems` must already be sorted in the desired payoff priority order.
    private func buildPayoffPlan(
        orderedItems: [DebtItem],
        extraMonthlyPayment: Double
    ) -> DebtPayoffPlan {
        guard !orderedItems.isEmpty else {
            return DebtPayoffPlan(
                entries: [],
                totalMonthsToPayoff: 0,
                totalInterestPaid: 0,
                payoffDate: Date(),
                monthlySchedule: []
            )
        }

        // Working state per debt
        struct DebtState {
            let item: DebtItem
            var balance: Double
            var interestAccumulated: Double
            var payoffMonth: Int?
            var minimumPayment: Double  // may increase as other debts are freed
        }

        var states: [DebtState] = orderedItems.map {
            DebtState(
                item: $0,
                balance: $0.outstandingBalance,
                interestAccumulated: 0,
                payoffMonth: nil,
                minimumPayment: $0.minimumPayment
            )
        }

        var monthlySchedule: [RepaymentMonth] = []
        let maxMonths = 600
        var totalMonths = 0
        var runningDate = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())
        ) ?? Date()

        // Track freed-up minimum payments from paid-off debts to roll into snowball
        var freedMinimums: Double = 0

        for month in 1...maxMonths {
            // Check if all debts are paid off
            if states.allSatisfy({ $0.balance <= 0.005 }) { break }

            totalMonths = month

            // Extra available this month = user extra + freed minimums from previous payoffs
            var snowballPool = extraMonthlyPayment + freedMinimums

            for idx in states.indices {
                guard states[idx].balance > 0.005 else { continue }

                let monthlyRate   = states[idx].item.interestRate / 100.0 / 12.0
                let interestCharge = states[idx].balance * monthlyRate
                states[idx].interestAccumulated += interestCharge

                // Apply minimum payment (or full balance if smaller)
                let minPmt = min(states[idx].minimumPayment, states[idx].balance + interestCharge)
                let principalFromMin = max(minPmt - interestCharge, 0)
                states[idx].balance = max(states[idx].balance - principalFromMin, 0)

                if month <= 36 {
                    monthlySchedule.append(RepaymentMonth(
                        month: month,
                        debtName: states[idx].item.name,
                        payment: minPmt,
                        interestPaid: interestCharge,
                        principalPaid: principalFromMin,
                        remainingBalance: states[idx].balance
                    ))
                }
            }

            // Apply snowball extra to the first unpaid debt (priority order)
            if snowballPool > 0 {
                for idx in states.indices {
                    guard states[idx].balance > 0.005 else { continue }
                    let applied = min(snowballPool, states[idx].balance)
                    states[idx].balance -= applied

                    if month <= 36 {
                        // Append extra snowball payment as a separate entry
                        monthlySchedule.append(RepaymentMonth(
                            month: month,
                            debtName: states[idx].item.name + " (extra)",
                            payment: applied,
                            interestPaid: 0,
                            principalPaid: applied,
                            remainingBalance: states[idx].balance
                        ))
                    }
                    break  // Snowball applies to one debt at a time
                }
            }

            // Mark payoffs and accumulate freed minimums
            for idx in states.indices {
                if states[idx].balance <= 0.005 && states[idx].payoffMonth == nil {
                    states[idx].balance = 0
                    states[idx].payoffMonth = month
                    freedMinimums += states[idx].item.minimumPayment
                }
            }

            runningDate = calendar.date(byAdding: .month, value: 1, to: runningDate) ?? runningDate
        }

        let payoffDate     = runningDate
        let totalInterest  = states.reduce(0) { $0 + $1.interestAccumulated }

        let entries: [DebtPayoffPlan.DebtOrderEntry] = states.enumerated().map { (order, state) in
            let pMonth = state.payoffMonth ?? totalMonths
            let pDate  = calendar.date(
                byAdding: .month,
                value: pMonth,
                to: calendar.date(
                    from: calendar.dateComponents([.year, .month], from: Date())
                ) ?? Date()
            ) ?? payoffDate

            // Extra applied at payoff = user extra + all freed minimums from earlier-paid debts
            let freedBeforeThis = states
                .prefix(order)
                .filter { $0.payoffMonth != nil }
                .reduce(0) { $0 + $1.item.minimumPayment }
            let extraAtPayoff = extraMonthlyPayment + freedBeforeThis

            return DebtPayoffPlan.DebtOrderEntry(
                name: state.item.name,
                payoffOrder: order + 1,
                payoffDate: pDate,
                totalInterestPaid: state.interestAccumulated,
                monthsToPayoff: pMonth,
                minimumPayment: state.item.minimumPayment,
                snowballExtraAt: extraAtPayoff
            )
        }

        return DebtPayoffPlan(
            entries: entries,
            totalMonthsToPayoff: totalMonths,
            totalInterestPaid: totalInterest,
            payoffDate: payoffDate,
            monthlySchedule: monthlySchedule
        )
    }

    /// Simulates a single debt to payoff, returning (totalInterestPaid, months).
    /// Handles zero-interest and cases where payment is too small (caps at maxMonths).
    private func simulateSingleDebt(
        balance startBalance: Double,
        annualRate: Double,
        monthlyPayment: Double
    ) -> (totalInterest: Double, months: Int) {
        guard startBalance > 0.005 else { return (0, 0) }

        let monthlyRate = annualRate / 100.0 / 12.0
        var balance     = startBalance
        var totalInterest: Double = 0
        let maxMonths   = 600

        for month in 1...maxMonths {
            let interest  = balance * monthlyRate
            totalInterest += interest
            let payment   = min(monthlyPayment, balance + interest)
            let principal = max(payment - interest, 0)
            balance = max(balance - principal, 0)

            if balance <= 0.005 {
                return (totalInterest, month)
            }

            // Safety: if payment doesn't cover interest (debt never pays off), bail
            if monthlyPayment <= interest && monthlyRate > 0 {
                return (totalInterest, maxMonths)
            }
        }

        return (totalInterest, maxMonths)
    }
}
