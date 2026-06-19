import Foundation
import SwiftData

@Model
final class GoldHolding {
    var id: UUID
    var name: String
    var metal: PreciousMetal
    var form: GoldForm
    var weightGrams: Double             // Weight in grams
    var purchasePricePerGram: Double    // Price paid per gram
    var currentPricePerGram: Double     // Live/manually updated price per gram
    var currency: String
    var storageLocation: String?        // "Home", "Bank Safe", "Vault", etc.
    var purchaseDate: Date
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var totalCost: Double { weightGrams * purchasePricePerGram }
    var currentValue: Double { weightGrams * currentPricePerGram }
    var profitLoss: Double { currentValue - totalCost }
    var profitLossPercent: Double { totalCost > 0 ? (profitLoss / totalCost) * 100 : 0 }
    var isProfit: Bool { profitLoss >= 0 }

    init(
        id: UUID = UUID(),
        name: String,
        metal: PreciousMetal = .gold,
        form: GoldForm = .bar,
        weightGrams: Double,
        purchasePricePerGram: Double,
        currentPricePerGram: Double,
        currency: String = "AED",
        storageLocation: String? = nil,
        purchaseDate: Date = Date(),
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.metal = metal
        self.form = form
        self.weightGrams = weightGrams
        self.purchasePricePerGram = purchasePricePerGram
        self.currentPricePerGram = currentPricePerGram
        self.currency = currency
        self.storageLocation = storageLocation
        self.purchaseDate = purchaseDate
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum PreciousMetal: String, Codable, CaseIterable {
    case gold      = "Gold"
    case silver    = "Silver"
    case platinum  = "Platinum"
    case palladium = "Palladium"

    var symbol: String {
        switch self {
        case .gold:      return "Au"
        case .silver:    return "Ag"
        case .platinum:  return "Pt"
        case .palladium: return "Pd"
        }
    }

    var icon: String {
        switch self {
        case .gold:      return "star.circle.fill"
        case .silver:    return "circle.fill"
        case .platinum:  return "diamond.fill"
        case .palladium: return "hexagon.fill"
        }
    }

    var color: String {
        switch self {
        case .gold:      return "yellow"
        case .silver:    return "gray"
        case .platinum:  return "cyan"
        case .palladium: return "purple"
        }
    }

    /// Approximate reference price per gram in USD (user should update manually)
    var referencePriceUSD: Double {
        switch self {
        case .gold:      return 95.0
        case .silver:    return 1.10
        case .platinum:  return 32.0
        case .palladium: return 38.0
        }
    }
}

enum GoldForm: String, Codable, CaseIterable {
    case bar      = "Bar"
    case coin     = "Coin"
    case jewelry  = "Jewelry"
    case etf      = "ETF"
    case other    = "Other"

    var icon: String {
        switch self {
        case .bar:     return "rectangle.fill"
        case .coin:    return "circle.fill"
        case .jewelry: return "sparkles"
        case .etf:     return "chart.bar.fill"
        case .other:   return "ellipsis.circle"
        }
    }
}
