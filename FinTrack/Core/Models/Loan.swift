import Foundation
import SwiftData

@Model
final class Loan {
    var id: UUID
    var name: String
    var loanType: LoanType
    var principalAmount: Double
    var outstandingBalance: Double
    var interestRate: Double
    var emiAmount: Double
    var startDate: Date
    var endDate: Date
    var nextPaymentDate: Date
    var currency: String
    var lenderName: String
    var notes: String?
    var isActive: Bool
    var createdAt: Date
    var paidInstallments: Int           // #4 – already-paid installments
    var reminderDaysBefore: Int         // #21 – configurable reminder

    // For personal loans (borrowed from / lent to people)
    var lenderPersonName: String?
    var lenderContactInfo: String?

    var totalInstallments: Int {
        guard emiAmount > 0 else { return 0 }
        let months = Calendar.current.dateComponents([.month], from: startDate, to: endDate).month ?? 0
        return months
    }

    var remainingInstallments: Int { max(totalInstallments - paidInstallments, 0) }

    var totalInterest: Double {
        let months = Calendar.current.dateComponents([.month], from: startDate, to: endDate).month ?? 0
        return (emiAmount * Double(months)) - principalAmount
    }

    var amortizationSchedule: [AmortizationEntry] {
        // Works for both interest-bearing and 0% loans
        guard emiAmount > 0, outstandingBalance > 0 else { return [] }
        var schedule: [AmortizationEntry] = []
        var balance = outstandingBalance
        let monthlyRate = interestRate / 100.0 / 12.0   // 0 when interestRate == 0
        var date = nextPaymentDate

        while balance > 0.01 {
            let interestPayment = balance * monthlyRate
            let principalPayment = min(emiAmount - interestPayment, balance)
            guard principalPayment > 0 else { break }   // prevents infinite loop if EMI < interest
            balance -= principalPayment
            schedule.append(AmortizationEntry(
                date: date,
                payment: min(emiAmount, principalPayment + interestPayment + balance < 0.01 ? principalPayment + interestPayment : emiAmount),
                principal: principalPayment,
                interest: interestPayment,
                balance: max(balance, 0)
            ))
            date = Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
            if schedule.count > 600 { break }
        }
        return schedule
    }

    init(
        id: UUID = UUID(),
        name: String,
        loanType: LoanType,
        principalAmount: Double,
        outstandingBalance: Double? = nil,
        interestRate: Double,
        emiAmount: Double,
        startDate: Date = Date(),
        endDate: Date,
        nextPaymentDate: Date,
        currency: String = "AED",
        lenderName: String = "",
        lenderPersonName: String? = nil,
        lenderContactInfo: String? = nil,
        notes: String? = nil,
        paidInstallments: Int = 0,
        reminderDaysBefore: Int = 3
    ) {
        self.id = id
        self.name = name
        self.loanType = loanType
        self.principalAmount = principalAmount
        self.outstandingBalance = outstandingBalance ?? principalAmount
        self.interestRate = interestRate
        self.emiAmount = emiAmount
        self.startDate = startDate
        self.endDate = endDate
        self.nextPaymentDate = nextPaymentDate
        self.currency = currency
        self.lenderName = lenderName
        self.lenderPersonName = lenderPersonName
        self.lenderContactInfo = lenderContactInfo
        self.notes = notes
        self.isActive = true
        self.paidInstallments = paidInstallments
        self.reminderDaysBefore = reminderDaysBefore
        self.createdAt = Date()
    }
}

extension Loan {
    /// Applies one repayment to this loan: splits it into interest (on the
    /// current outstanding balance) and principal using the same amortization
    /// model as `amortizationSchedule`, so `outstandingBalance` tracks the real
    /// remaining debt rather than the raw payment total, then advances the
    /// instalment count and next due date, or closes the loan when it's paid off.
    ///
    /// The single definition of that rule, shared by `AccountDetailView`'s
    /// manual "record payment" and the review queue's loan-repayment approval
    /// (`EmailSyncService.approveToLedger`) so the two can't drift apart.
    ///
    /// `amountInLoanCurrency` must already be in `currency` — a payment made in
    /// another currency is converted by the caller, so `outstandingBalance`
    /// stays in the loan's own currency like every other loan field.
    func recordPayment(amountInLoanCurrency: Double) {
        let monthlyRate = interestRate / 100.0 / 12.0
        let interestPortion = outstandingBalance * monthlyRate
        let principalPortion = min(max(amountInLoanCurrency - interestPortion, 0), outstandingBalance)

        outstandingBalance = max(0, outstandingBalance - principalPortion)
        paidInstallments += 1
        let fullyPaid = outstandingBalance <= 0.01
            || (totalInstallments > 0 && paidInstallments >= totalInstallments)
        if fullyPaid {
            isActive = false
        } else {
            nextPaymentDate = Calendar.current.date(byAdding: .month, value: 1, to: nextPaymentDate) ?? nextPaymentDate
        }
    }
}

enum LoanType: String, Codable, CaseIterable {
    case personal = "Personal Loan"
    case car = "Car Loan"
    case mortgage = "Mortgage"
    case personalBorrowed = "Personal Borrowed"

    var icon: String {
        switch self {
        case .personal:         return "person.fill"
        case .car:              return "car.fill"
        case .mortgage:         return "house.fill"
        case .personalBorrowed: return "arrow.down.circle.fill"
        }
    }
}

struct AmortizationEntry: Identifiable {
    let id = UUID()
    let date: Date
    let payment: Double
    let principal: Double
    let interest: Double
    let balance: Double
}
