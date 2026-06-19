import Foundation
import SwiftData

@Model
final class Investment {
    var id: UUID
    var name: String
    var symbol: String
    var type: InvestmentType
    var quantity: Double
    var averageCost: Double
    var currentPrice: Double
    var currency: String
    var exchange: String?
    var notes: String?
    var purchaseDate: Date
    var createdAt: Date
    var updatedAt: Date

    var totalCost: Double { quantity * averageCost }
    var currentValue: Double { quantity * currentPrice }
    var profitLoss: Double { currentValue - totalCost }
    var profitLossPercent: Double { totalCost > 0 ? (profitLoss / totalCost) * 100 : 0 }
    var isProfit: Bool { profitLoss >= 0 }

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        type: InvestmentType,
        quantity: Double,
        averageCost: Double,
        currentPrice: Double = 0,
        currency: String = "USD",
        exchange: String? = nil,
        notes: String? = nil,
        purchaseDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.type = type
        self.quantity = quantity
        self.averageCost = averageCost
        self.currentPrice = currentPrice
        self.currency = currency
        self.exchange = exchange
        self.notes = notes
        self.purchaseDate = purchaseDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum InvestmentType: String, Codable, CaseIterable {
    case stock = "Stock"
    case etf = "ETF"
    case mutualFund = "Mutual Fund"
    case bond = "Bond"
    case reit = "REIT"
    case commodity = "Commodity"
    case other = "Other"

    var icon: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .etf: return "chart.bar"
        case .mutualFund: return "chart.pie"
        case .bond: return "doc.text"
        case .reit: return "building.2"
        case .commodity: return "cube.box"
        case .other: return "ellipsis.circle"
        }
    }
}

@Model
final class CryptoHolding {
    var id: UUID
    var name: String
    var symbol: String
    var quantity: Double
    var averageCost: Double
    var currentPrice: Double
    var currency: String
    var walletAddress: String?
    var exchange: String?
    var notes: String?
    var purchaseDate: Date
    var createdAt: Date
    var updatedAt: Date

    var totalCost: Double { quantity * averageCost }
    var currentValue: Double { quantity * currentPrice }
    var profitLoss: Double { currentValue - totalCost }
    var profitLossPercent: Double { totalCost > 0 ? (profitLoss / totalCost) * 100 : 0 }
    var isProfit: Bool { profitLoss >= 0 }

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        quantity: Double,
        averageCost: Double,
        currentPrice: Double = 0,
        currency: String = "USD",
        walletAddress: String? = nil,
        exchange: String? = nil,
        notes: String? = nil,
        purchaseDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.quantity = quantity
        self.averageCost = averageCost
        self.currentPrice = currentPrice
        self.currency = currency
        self.walletAddress = walletAddress
        self.exchange = exchange
        self.notes = notes
        self.purchaseDate = purchaseDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class Dividend {
    var id: UUID
    var investmentId: UUID
    var amount: Double
    var currency: String
    var date: Date
    var notes: String?

    init(
        id: UUID = UUID(),
        investmentId: UUID,
        amount: Double,
        currency: String = "USD",
        date: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.investmentId = investmentId
        self.amount = amount
        self.currency = currency
        self.date = date
        self.notes = notes
    }
}
