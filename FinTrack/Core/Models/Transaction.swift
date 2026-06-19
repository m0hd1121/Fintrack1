import Foundation
import SwiftData

// MARK: - Transaction Subtype

enum TransactionSubtype: String, Codable, CaseIterable {
    case refund             = "Refund"
    case reversal           = "Reversal"
    case cashback           = "Cashback"
    case rewardPoints       = "Reward Points"
    case promotionalCredit  = "Promotional Credit"
    case bankFee            = "Bank Fee"
    case atmFee             = "ATM Fee"
    case fxFee              = "FX Fee"
    case interestEarned     = "Interest Earned"
    case interestCharged    = "Interest Charged"

    var icon: String {
        switch self {
        case .refund:            return "arrow.counterclockwise.circle.fill"
        case .reversal:          return "xmark.circle.fill"
        case .cashback:          return "arrow.down.left.circle.fill"
        case .rewardPoints:      return "rosette"
        case .promotionalCredit: return "tag.fill"
        case .bankFee:           return "building.columns"
        case .atmFee:            return "banknote"
        case .fxFee:             return "globe"
        case .interestEarned:    return "chart.line.uptrend.xyaxis"
        case .interestCharged:   return "chart.line.downtrend.xyaxis"
        }
    }

    var colorName: String {
        switch self {
        case .refund, .reversal:                           return "teal"
        case .cashback, .rewardPoints, .promotionalCredit,
             .interestEarned:                              return "green"
        case .bankFee, .atmFee, .fxFee, .interestCharged: return "red"
        }
    }

    /// Subtypes that reduce a spending category rather than being counted as net income.
    var isSpendingReduction: Bool {
        switch self {
        case .refund, .reversal, .cashback, .rewardPoints, .promotionalCredit: return true
        default: return false
        }
    }

    /// Subtypes valid for income transactions.
    static var incomeSubtypes: [TransactionSubtype] {
        [.refund, .reversal, .cashback, .rewardPoints, .promotionalCredit, .interestEarned]
    }

    /// Subtypes valid for expense transactions.
    static var expenseSubtypes: [TransactionSubtype] {
        [.bankFee, .atmFee, .fxFee, .interestCharged]
    }
}

// MARK: - Split Item

struct SplitItem: Codable, Identifiable, Equatable {
    var id: UUID
    var category: TransactionCategory
    var amount: Double
    var notes: String?

    init(id: UUID = UUID(), category: TransactionCategory, amount: Double, notes: String? = nil) {
        self.id = id
        self.category = category
        self.amount = amount
        self.notes = notes
    }
}

// MARK: - Transaction

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

    // Pending / Scheduled state
    var isPending: Bool
    var isScheduled: Bool
    var scheduledDate: Date?

    // Transaction subtype (refund, cashback, fee, interest, etc.)
    var subtype: TransactionSubtype?

    // Split transaction breakdown — non-empty when the amount is divided across categories
    var splitItems: [SplitItem]

    // Income source tagging (e.g. employer name, client name)
    var incomeSource: String?

    // GPS location
    var latitude: Double?
    var longitude: Double?

    // Relationships
    var account: Account?
    var toAccount: Account?
    var linkedLoan: Loan?

    // Document attachments (cascade-deleted with the transaction)
    @Relationship(deleteRule: .cascade) var documents: [DocumentAttachment]

    // Cheque-specific fields
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
        isDuplicate: Bool = false,
        isPending: Bool = false,
        isScheduled: Bool = false,
        scheduledDate: Date? = nil,
        subtype: TransactionSubtype? = nil,
        splitItems: [SplitItem] = [],
        incomeSource: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
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
        self.isPending = isPending
        self.isScheduled = isScheduled
        self.scheduledDate = scheduledDate
        self.subtype = subtype
        self.splitItems = splitItems
        self.incomeSource = incomeSource
        self.latitude = latitude
        self.longitude = longitude
        self.documents = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Spending helpers (used by Budget & Reports)

extension Transaction {
    /// Returns (category, amountInBaseCurrency) pairs for spending aggregation.
    /// For split transactions, returns one pair per split item converted to base currency.
    /// For regular expense transactions, returns a single pair.
    var spendingPairs: [(TransactionCategory, Double)] {
        guard type == .expense, !isPending, !isScheduled else { return [] }
        if !splitItems.isEmpty, amount > 0 {
            let rate = amountInBaseCurrency / amount
            return splitItems.map { ($0.category, $0.amount * rate) }
        }
        return [(category, amountInBaseCurrency)]
    }

    var isSplit: Bool { !splitItems.isEmpty }

    var hasLocation: Bool { latitude != nil && longitude != nil }

    var displaySubtitle: String {
        if let sub = subtype { return sub.rawValue }
        if isSplit { return "Split · \(splitItems.count) categories" }
        return category.rawValue
    }
}

// MARK: - TransactionType

enum TransactionType: String, Codable, CaseIterable {
    case income   = "Income"
    case expense  = "Expense"
    case transfer = "Transfer"

    var icon: String {
        switch self {
        case .income:   return "arrow.down.circle.fill"
        case .expense:  return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }
}

// MARK: - TransactionCategory

enum TransactionCategory: String, Codable, CaseIterable {
    // Expense categories
    case food           = "Food & Dining"
    case shopping       = "Shopping"
    case transportation = "Transportation"
    case fuel           = "Fuel"
    case utilities      = "Utilities"
    case rent           = "Rent"
    case mortgage       = "Mortgage"
    case education      = "Education"
    case medical        = "Medical"
    case entertainment  = "Entertainment"
    case travel         = "Travel"
    case insurance      = "Insurance"
    case investments    = "Investments"
    case subscriptions  = "Subscriptions"
    case gifts          = "Gifts"
    case personalCare   = "Personal Care"
    case childcare      = "Childcare"
    case pets           = "Pets"
    case charity        = "Charity"
    case bankFees       = "Bank Fees"
    case interestExpense = "Interest Expense"
    // Income categories
    case salary          = "Salary"
    case bonus           = "Bonus"
    case freelance       = "Freelance"
    case business        = "Business"
    case investmentIncome = "Investment Income"
    case rental          = "Rental Income"
    case dividends       = "Dividends"
    case interestIncome  = "Interest Income"
    case cashbackIncome  = "Cashback & Rewards"
    // Personal lending
    case personalLent            = "Personal Lent"
    case personalLentRepayment   = "Personal Lent Repayment"
    // Shared
    case transfer       = "Transfer"
    case loanRepayment  = "Loan Repayment"
    case creditCard     = "Credit Card"
    case other          = "Other"

    var icon: String {
        switch self {
        case .food:              return "fork.knife"
        case .shopping:          return "bag"
        case .transportation:    return "car"
        case .fuel:              return "fuelpump"
        case .utilities:         return "bolt"
        case .rent:              return "house"
        case .mortgage:          return "building"
        case .education:         return "graduationcap"
        case .medical:           return "cross.circle"
        case .entertainment:     return "tv"
        case .travel:            return "airplane"
        case .insurance:         return "shield"
        case .investments:       return "chart.line.uptrend.xyaxis"
        case .subscriptions:     return "repeat"
        case .gifts:             return "gift"
        case .personalCare:      return "sparkles"
        case .childcare:         return "figure.and.child.holdinghands"
        case .pets:              return "pawprint"
        case .charity:           return "heart"
        case .bankFees:          return "building.columns"
        case .interestExpense:   return "chart.line.downtrend.xyaxis"
        case .salary:            return "banknote"
        case .bonus:             return "star"
        case .freelance:         return "laptopcomputer"
        case .business:          return "briefcase"
        case .investmentIncome:  return "chart.bar"
        case .rental:            return "house.fill"
        case .dividends:         return "dollarsign.circle"
        case .interestIncome:    return "percent"
        case .cashbackIncome:    return "arrow.down.left.circle.fill"
        case .transfer:          return "arrow.left.arrow.right"
        case .loanRepayment:     return "creditcard"
        case .personalLent:             return "hand.raised.fill"
        case .personalLentRepayment:    return "hand.thumbsup.fill"
        case .creditCard:        return "creditcard.fill"
        case .other:             return "ellipsis.circle"
        }
    }

    var color: String {
        switch self {
        case .food:              return "orange"
        case .shopping:          return "pink"
        case .transportation:    return "blue"
        case .fuel:              return "red"
        case .utilities:         return "yellow"
        case .rent, .mortgage:   return "brown"
        case .education:         return "indigo"
        case .medical:           return "red"
        case .entertainment:     return "purple"
        case .travel:            return "cyan"
        case .insurance:         return "gray"
        case .investments:       return "green"
        case .subscriptions:     return "teal"
        case .gifts:             return "pink"
        case .bankFees:          return "gray"
        case .interestExpense:   return "red"
        case .salary, .bonus:    return "green"
        case .freelance:         return "mint"
        case .business:          return "blue"
        case .investmentIncome, .dividends, .interestIncome: return "green"
        case .rental:            return "brown"
        case .cashbackIncome:    return "teal"
        case .personalLent:             return "orange"
        case .personalLentRepayment:    return "teal"
        default:                 return "gray"
        }
    }
}

// MARK: - PaymentMethod

enum PaymentMethod: String, Codable, CaseIterable {
    case cash         = "Cash"
    case debitCard    = "Debit Card"
    case creditCard   = "Credit Card"
    case bankTransfer = "Bank Transfer"
    case applePay     = "Apple Pay"
    case bnpl         = "Buy Now Pay Later"
    case crypto       = "Crypto"
    case cheque       = "Cheque"
    case other        = "Other"
}

// MARK: - RecurringRule

struct RecurringRule: Codable {
    var frequency: RecurringFrequency
    var interval: Int
    var endDate: Date?
    var maxOccurrences: Int?
    var nextDueDate: Date
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case daily     = "Daily"
    case weekly    = "Weekly"
    case biweekly  = "Bi-weekly"
    case monthly   = "Monthly"
    case quarterly = "Quarterly"
    case yearly    = "Yearly"
}
