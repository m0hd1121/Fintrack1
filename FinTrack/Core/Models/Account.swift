import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID
    var name: String
    var type: AccountType
    var currency: String
    var balance: Double
    var initialBalance: Double          // #7 – never recalculate below this
    var bankName: String
    var customBankName: String?         // #2 – for "Other" bank
    var accountNumber: String?
    var color: String
    var icon: String
    var isDefault: Bool
    var isArchived: Bool
    var isHidden: Bool                  // Excluded from dashboard & net worth (still editable)
    var isBusiness: Bool                // Business account flag
    var isLinked: Bool                  // Bank linking status (manual/linked)
    var walletProvider: String?         // For .digitalWallet type
    var retirementType: String?         // "Pension" | "Gratuity" | "401k" | "RRSP" | "Other"
    var sharedMembers: [String]         // Email list for shared/family accounts
    var createdAt: Date
    var updatedAt: Date
    var notes: String?
    var minimumBalanceEnabled: Bool     // #22
    var minimumBalance: Double          // #22

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    /// Effective bank label shown to users
    var effectiveBankName: String {
        switch type {
        case .cash: return ""
        case .crypto: return ""
        case .digitalWallet:
            return walletProvider ?? ""
        default:
            if bankName == "Other", let custom = customBankName, !custom.isEmpty { return custom }
            return bankName
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        currency: String = "AED",
        balance: Double = 0,
        bankName: String = "",
        customBankName: String? = nil,
        accountNumber: String? = nil,
        color: String = "blue",
        icon: String = "building.columns",
        isDefault: Bool = false,
        isArchived: Bool = false,
        isHidden: Bool = false,
        isBusiness: Bool = false,
        isLinked: Bool = false,
        walletProvider: String? = nil,
        retirementType: String? = nil,
        sharedMembers: [String] = [],
        notes: String? = nil,
        minimumBalanceEnabled: Bool = false,
        minimumBalance: Double = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.currency = currency
        self.balance = balance
        self.initialBalance = balance
        self.bankName = bankName
        self.customBankName = customBankName
        self.accountNumber = accountNumber
        self.color = color
        self.icon = icon
        self.isDefault = isDefault
        self.isArchived = isArchived
        self.isHidden = isHidden
        self.isBusiness = isBusiness
        self.isLinked = isLinked
        self.walletProvider = walletProvider
        self.retirementType = retirementType
        self.sharedMembers = sharedMembers
        self.notes = notes
        self.minimumBalanceEnabled = minimumBalanceEnabled
        self.minimumBalance = minimumBalance
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum AccountType: String, Codable, CaseIterable {
    case current        = "Current"
    case savings        = "Savings"
    case cash           = "Cash"
    case foreignCurrency = "Foreign Currency"
    case digitalWallet  = "Digital Wallet"
    case investment     = "Investment"
    case crypto         = "Crypto"
    case creditCard     = "Credit Card"
    case retirement     = "Retirement"

    var icon: String {
        switch self {
        case .current:        return "building.columns"
        case .savings:        return "banknote.fill"
        case .cash:           return "banknote"
        case .foreignCurrency: return "globe"
        case .digitalWallet:  return "wallet.pass.fill"
        case .investment:     return "chart.line.uptrend.xyaxis"
        case .crypto:         return "bitcoinsign.circle"
        case .creditCard:     return "creditcard.fill"
        case .retirement:     return "umbrella.fill"
        }
    }

    var isLiability: Bool { self == .creditCard }

    var needsBankName: Bool {
        switch self {
        case .cash, .digitalWallet: return false
        default: return true
        }
    }
}

// MARK: - Digital Wallet Providers
enum WalletProvider: String, CaseIterable {
    case applePay   = "Apple Pay"
    case googlePay  = "Google Pay"
    case samsungPay = "Samsung Pay"
    case payoneer   = "Payoneer"
    case wise       = "Wise"
    case paypal     = "PayPal"
    case stcPay     = "STC Pay"
    case other      = "Other"

    var icon: String {
        switch self {
        case .applePay:   return "apple.logo"
        case .googlePay:  return "g.circle.fill"
        case .samsungPay: return "s.circle.fill"
        case .payoneer:   return "p.circle.fill"
        case .wise:       return "w.circle.fill"
        case .paypal:     return "p.square.fill"
        case .stcPay:     return "phone.fill"
        case .other:      return "wallet.pass"
        }
    }
}
