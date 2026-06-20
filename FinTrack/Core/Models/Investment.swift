import Foundation
import SwiftData

// MARK: - Investment (Stocks, ETFs, Mutual Funds, Bonds, REITs, Commodities)

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
    // ETF / Mutual Fund specific
    var expenseRatio: Double        // Annual expense ratio %
    var dividendYield: Double       // Annual dividend yield %
    // Purchase lots for FIFO/LIFO/Average cost basis
    @Attribute(.externalStorage) var lotsData: Data
    // Sale records for realized P&L tracking
    @Attribute(.externalStorage) var salesData: Data
    var realizedPnL: Double         // Running total of realized gains/losses
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed

    var totalCost: Double { quantity * averageCost }
    var currentValue: Double { quantity * currentPrice }
    var profitLoss: Double { currentValue - totalCost }
    var profitLossPercent: Double { totalCost > 0 ? (profitLoss / totalCost) * 100 : 0 }
    var isProfit: Bool { profitLoss >= 0 }
    var totalReturn: Double { profitLoss + realizedPnL }

    // MARK: - Purchase Lots (Codable array via externalStorage)

    var lots: [PurchaseLot] {
        get { (try? JSONDecoder().decode([PurchaseLot].self, from: lotsData)) ?? [] }
        set { lotsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // MARK: - Sale Records

    var sales: [SaleRecord] {
        get { (try? JSONDecoder().decode([SaleRecord].self, from: salesData)) ?? [] }
        set { salesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // MARK: - Init

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
        purchaseDate: Date = Date(),
        expenseRatio: Double = 0,
        dividendYield: Double = 0,
        realizedPnL: Double = 0
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
        self.expenseRatio = expenseRatio
        self.dividendYield = dividendYield
        self.lotsData = Data()
        self.salesData = Data()
        self.realizedPnL = realizedPnL
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - InvestmentType

enum InvestmentType: String, Codable, CaseIterable {
    case stock      = "Stock"
    case etf        = "ETF"
    case mutualFund = "Mutual Fund"
    case bond       = "Bond"
    case reit       = "REIT"
    case commodity  = "Commodity"
    case other      = "Other"

    var icon: String {
        switch self {
        case .stock:      return "chart.line.uptrend.xyaxis"
        case .etf:        return "chart.bar"
        case .mutualFund: return "chart.pie"
        case .bond:       return "doc.text"
        case .reit:       return "building.2"
        case .commodity:  return "cube.box"
        case .other:      return "ellipsis.circle"
        }
    }

    var color: String {
        switch self {
        case .stock:      return "blue"
        case .etf:        return "teal"
        case .mutualFund: return "purple"
        case .bond:       return "green"
        case .reit:       return "brown"
        case .commodity:  return "orange"
        case .other:      return "gray"
        }
    }
}

// MARK: - CryptoHolding

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
    @Attribute(.externalStorage) var lotsData: Data
    @Attribute(.externalStorage) var salesData: Data
    var realizedPnL: Double
    var createdAt: Date
    var updatedAt: Date

    var totalCost: Double { quantity * averageCost }
    var currentValue: Double { quantity * currentPrice }
    var profitLoss: Double { currentValue - totalCost }
    var profitLossPercent: Double { totalCost > 0 ? (profitLoss / totalCost) * 100 : 0 }
    var isProfit: Bool { profitLoss >= 0 }

    var lots: [PurchaseLot] {
        get { (try? JSONDecoder().decode([PurchaseLot].self, from: lotsData)) ?? [] }
        set { lotsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var sales: [SaleRecord] {
        get { (try? JSONDecoder().decode([SaleRecord].self, from: salesData)) ?? [] }
        set { salesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

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
        purchaseDate: Date = Date(),
        realizedPnL: Double = 0
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
        self.lotsData = Data()
        self.salesData = Data()
        self.realizedPnL = realizedPnL
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Dividend

@Model
final class Dividend {
    var id: UUID
    var investmentId: UUID
    var amount: Double
    var currency: String
    var date: Date
    var paymentDate: Date?          // actual payment date
    var notes: String?
    var securityName: String?
    var exDividendDate: Date?
    var taxWithholding: Double

    var grossAmount: Double { amount }
    var netAmount: Double { amount - taxWithholding }
    var withholdingRate: Double { amount > 0 ? (taxWithholding / amount) * 100 : 0 }

    init(
        id: UUID = UUID(),
        investmentId: UUID,
        amount: Double,
        currency: String = "USD",
        date: Date = Date(),
        paymentDate: Date? = nil,
        notes: String? = nil,
        securityName: String? = nil,
        exDividendDate: Date? = nil,
        taxWithholding: Double = 0
    ) {
        self.id = id
        self.investmentId = investmentId
        self.amount = amount
        self.currency = currency
        self.date = date
        self.paymentDate = paymentDate
        self.notes = notes
        self.securityName = securityName
        self.exDividendDate = exDividendDate
        self.taxWithholding = taxWithholding
    }
}
