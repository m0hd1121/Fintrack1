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
