import Foundation
import SwiftData

enum RemittanceProvider: String, Codable, CaseIterable {
    case wise       = "Wise"
    case westernUnion = "Western Union"
    case moneygram  = "MoneyGram"
    case alAnsari   = "Al Ansari"
    case luluExchange = "Lulu Exchange"
    case emNBD      = "Emirates NBD"
    case payit      = "PayIt"
    case fib        = "First Abu Dhabi Bank"
    case custom     = "Other"

    var icon: String {
        switch self {
        case .wise:         return "arrow.left.arrow.right"
        case .westernUnion: return "building.columns"
        case .moneygram:    return "m.circle"
        case .alAnsari, .luluExchange: return "storefront"
        case .emNBD, .fib:  return "building.2"
        case .payit:        return "iphone"
        case .custom:       return "arrow.up.right.circle"
        }
    }
}

@Model
final class RemittanceRecord {
    var id: UUID
    var date: Date
    var providerRaw: String
    var customProviderName: String?
    var senderCurrency: String
    var receiverCurrency: String
    var sentAmount: Double
    var receivedAmount: Double
    var exchangeRate: Double
    var fee: Double
    var recipientName: String
    var recipientCountry: String
    var referenceNumber: String?
    var notes: String?
    var isPending: Bool

    var provider: RemittanceProvider {
        get { RemittanceProvider(rawValue: providerRaw) ?? .custom }
        set { providerRaw = newValue.rawValue }
    }

    var providerDisplayName: String {
        provider == .custom ? (customProviderName ?? "Other") : provider.rawValue
    }

    var totalCost: Double { sentAmount + fee }
    var effectiveRate: Double { sentAmount > 0 ? receivedAmount / sentAmount : 0 }
    var feePercent: Double { sentAmount > 0 ? fee / sentAmount * 100 : 0 }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        provider: RemittanceProvider = .wise,
        customProviderName: String? = nil,
        senderCurrency: String = "AED",
        receiverCurrency: String = "INR",
        sentAmount: Double = 0,
        receivedAmount: Double = 0,
        exchangeRate: Double = 0,
        fee: Double = 0,
        recipientName: String = "",
        recipientCountry: String = "",
        referenceNumber: String? = nil,
        notes: String? = nil,
        isPending: Bool = false
    ) {
        self.id = id
        self.date = date
        self.providerRaw = provider.rawValue
        self.customProviderName = customProviderName
        self.senderCurrency = senderCurrency
        self.receiverCurrency = receiverCurrency
        self.sentAmount = sentAmount
        self.receivedAmount = receivedAmount
        self.exchangeRate = exchangeRate
        self.fee = fee
        self.recipientName = recipientName
        self.recipientCountry = recipientCountry
        self.referenceNumber = referenceNumber
        self.notes = notes
        self.isPending = isPending
    }
}
