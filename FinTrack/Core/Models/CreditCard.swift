import Foundation
import SwiftData

@Model
final class CreditCard {
    var id: UUID
    var name: String
    var bankName: String
    var last4Digits: String
    var creditLimit: Double
    var outstandingBalance: Double
    var minimumPayment: Double
    var dueDate: Date
    var statementDate: Int
    var interestRate: Double
    var currency: String
    var color: String
    var icon: String
    var isActive: Bool
    var createdAt: Date
    var notes: String?

    var availableCredit: Double { max(creditLimit - outstandingBalance, 0) }
    var utilizationRate: Double { outstandingBalance / max(creditLimit, 1) }
    var isOverLimit: Bool { outstandingBalance > creditLimit }
    var isPaymentDueSoon: Bool {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return days <= 7 && days >= 0
    }

    init(
        id: UUID = UUID(),
        name: String,
        bankName: String,
        last4Digits: String = "",
        creditLimit: Double,
        outstandingBalance: Double = 0,
        minimumPayment: Double = 0,
        dueDate: Date,
        statementDate: Int = 1,
        interestRate: Double = 0,
        currency: String = "AED",
        color: String = "purple",
        icon: String = "creditcard",
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bankName = bankName
        self.last4Digits = last4Digits
        self.creditLimit = creditLimit
        self.outstandingBalance = outstandingBalance
        self.minimumPayment = minimumPayment
        self.dueDate = dueDate
        self.statementDate = statementDate
        self.interestRate = interestRate
        self.currency = currency
        self.color = color
        self.icon = icon
        self.notes = notes
        self.isActive = true
        self.createdAt = Date()
    }
}
