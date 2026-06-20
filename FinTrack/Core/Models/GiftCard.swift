import Foundation
import SwiftData

@Model
final class GiftCard {
    var id: UUID
    var merchant: String
    var balance: Double
    var initialBalance: Double
    var currency: String
    var cardNumber: String?             // Last 4 digits or full card number
    var pinCode: String?
    var expiryDate: Date?
    var purchaseDate: Date
    var notes: String?
    var color: String
    var isUsedUp: Bool
    var createdAt: Date
    var updatedAt: Date

    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }

    var isExpiringSoon: Bool {
        guard let expiry = expiryDate, !isExpired else { return false }
        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return daysLeft <= 30
    }

    var usagePercent: Double {
        initialBalance > 0 ? (1 - balance / initialBalance) : 0
    }

    init(
        id: UUID = UUID(),
        merchant: String,
        balance: Double,
        currency: String = "AED",
        cardNumber: String? = nil,
        pinCode: String? = nil,
        expiryDate: Date? = nil,
        purchaseDate: Date = Date(),
        notes: String? = nil,
        color: String = "teal",
        isUsedUp: Bool = false
    ) {
        self.id = id
        self.merchant = merchant
        self.balance = balance
        self.initialBalance = balance
        self.currency = currency
        self.cardNumber = cardNumber
        self.pinCode = pinCode
        self.expiryDate = expiryDate
        self.purchaseDate = purchaseDate
        self.notes = notes
        self.color = color
        self.isUsedUp = isUsedUp
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
