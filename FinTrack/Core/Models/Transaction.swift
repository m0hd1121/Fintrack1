import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var amountInBaseCurrency: Double
    var type: TransactionType
    var category: TransactionCategory
    var customCategory: String?
    var date: Date
    var notes: String?
    @Attribute(.externalStorage) var receiptImageData: Data?
    var isRecurring: Bool
    var recurringRule: RecurringRule?
    var merchant: String?
    var paymentMethod: PaymentMethod
    var tags: [String]
    var isVerified: Bool
    var isDuplicate: Bool
    var createdAt: Date
    var updatedAt: Date

    var account: Account?
    var toAccount: Account?     // destination for transfer transactions
    var linkedLoan: Loan?       // set when category == .loanRepayment

    // Cheque-specific fields — only populated when paymentMethod == .cheque
    var chequeNumber: String?
    var chequeDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        currency: String = "AED",
        amountInBaseCurrency: Double? = nil,
        type: TransactionType,
        category: TransactionCategory = .other,
        customCategory: String? = nil,
        date: Date = Date(),
        notes: String? = nil,
        receiptImageData: Data? = nil,
        isRecurring: Bool = false,
        recurringRule: RecurringRule? = nil,
        merchant: String? = nil,
        paymentMethod: PaymentMethod = .cash,
        chequeNumber: String? = nil,
        chequeDate: Date? = nil,
        tags: [String] = [],
        isVerified: Bool = false,
        isDuplicate: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.amountInBaseCurrency = amountInBaseCurrency ?? amount
        self.type = type
        self.category = category
        self.customCategory = customCategory
        self.date = date
        self.notes = notes
        self.receiptImageData = receiptImageData
        self.isRecurring = isRecurring
        self.recurringRule = recurringRule
        self.merchant = merchant
        self.paymentMethod = paymentMethod
        self.chequeNumber = chequeNumber
        self.chequeDate = chequeDate
        self.tags = tags
        self.isVerified = isVerified
        self.isDuplicate = isDuplicate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum TransactionType: String, Codable, CaseIterable {
    case income = "Income"
    case expense = "Expense"
    case transfer = "Transfer"

    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }
}

enum TransactionCategory: String, Codable, CaseIterable {
    // Expense categories
    case food = "Food & Dining"
    case shopping = "Shopping"
    case transportation = "Transportation"
    case fuel = "Fuel"
    case utilities = "Utilities"
    case rent = "Rent"
    case mortgage = "Mortgage"
    case education = "Education"
    case medical = "Medical"
    case entertainment = "Entertainment"
    case travel = "Travel"
    case insurance = "Insurance"
    case investments = "Investments"
    case subscriptions = "Subscriptions"
    case gifts = "Gifts"
    case personalCare = "Personal Care"
    case childcare = "Childcare"
    case pets = "Pets"
    case charity = "Charity"
    // Income categories
    case salary = "Salary"
    case bonus = "Bonus"
    case freelance = "Freelance"
    case business = "Business"
    case investmentIncome = "Investment Income"
    case rental = "Rental Income"
    case dividends = "Dividends"
    case interestIncome = "Interest Income"
    // Personal lending
    case personalLent = "Personal Lent"               // expense: money lent to someone
    case personalLentRepayment = "Personal Lent Repayment" // income: money returned by them
    // Shared
    case transfer = "Transfer"
    case loanRepayment = "Loan Repayment"
    case creditCard = "Credit Card"
    case other = "Other"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .shopping: return "bag"
        case .transportation: return "car"
        case .fuel: return "fuelpump"
        case .utilities: return "bolt"
        case .rent: return "house"
        case .mortgage: return "building"
        case .education: return "graduationcap"
        case .medical: return "cross.circle"
        case .entertainment: return "tv"
        case .travel: return "airplane"
        case .insurance: return "shield"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .subscriptions: return "repeat"
        case .gifts: return "gift"
        case .personalCare: return "sparkles"
        case .childcare: return "figure.and.child.holdinghands"
        case .pets: return "pawprint"
        case .charity: return "heart"
        case .salary: return "banknote"
        case .bonus: return "star"
        case .freelance: return "laptopcomputer"
        case .business: return "briefcase"
        case .investmentIncome: return "chart.bar"
        case .rental: return "house.fill"
        case .dividends: return "dollarsign.circle"
        case .interestIncome: return "percent"
        case .transfer: return "arrow.left.arrow.right"
        case .loanRepayment: return "creditcard"
        case .personalLent:          return "hand.raised.fill"
        case .personalLentRepayment: return "hand.thumbsup.fill"
        case .creditCard: return "creditcard.fill"
        case .other: return "ellipsis.circle"
        }
    }

    var color: String {
        switch self {
        case .food: return "orange"
        case .shopping: return "pink"
        case .transportation: return "blue"
        case .fuel: return "red"
        case .utilities: return "yellow"
        case .rent, .mortgage: return "brown"
        case .education: return "indigo"
        case .medical: return "red"
        case .entertainment: return "purple"
        case .travel: return "cyan"
        case .insurance: return "gray"
        case .investments: return "green"
        case .subscriptions: return "teal"
        case .gifts: return "pink"
        case .salary, .bonus: return "green"
        case .freelance: return "mint"
        case .business: return "blue"
        case .investmentIncome, .dividends, .interestIncome: return "green"
        case .rental: return "brown"
        case .personalLent:          return "orange"
        case .personalLentRepayment: return "teal"
        default: return "gray"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable {
    case cash = "Cash"
    case debitCard = "Debit Card"
    case creditCard = "Credit Card"
    case bankTransfer = "Bank Transfer"
    case applePay = "Apple Pay"
    case bnpl = "Buy Now Pay Later"
    case crypto = "Crypto"
    case cheque = "Cheque"
    case other = "Other"
}

struct RecurringRule: Codable {
    var frequency: RecurringFrequency
    var interval: Int
    var endDate: Date?
    var maxOccurrences: Int?
    var nextDueDate: Date
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
}
