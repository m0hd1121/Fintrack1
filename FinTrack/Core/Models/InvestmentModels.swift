import Foundation
import SwiftUI

// MARK: - Purchase Lot (cost basis tracking for FIFO / LIFO / Average)

struct PurchaseLot: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var quantity: Double
    var costPerUnit: Double
    var purchaseDate: Date
    var notes: String?

    var totalCost: Double { quantity * costPerUnit }
}

// MARK: - Sale Record (realized P&L)

struct SaleRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var quantity: Double
    var salePricePerUnit: Double
    var saleDate: Date
    var costBasis: Double
    var method: CostBasisMethod
    var notes: String?

    var proceeds: Double { quantity * salePricePerUnit }
    var realizedPnL: Double { proceeds - costBasis }
    var isGain: Bool { realizedPnL >= 0 }
    var isLongTerm: Bool {
        let months = Calendar.current.dateComponents([.month], from: saleDate, to: Date()).month ?? 0
        return months >= 12
    }
}

// MARK: - Cost Basis Method

enum CostBasisMethod: String, Codable, CaseIterable {
    case fifo        = "FIFO"
    case lifo        = "LIFO"
    case averageCost = "Average Cost"

    var fullName: String {
        switch self {
        case .fifo:        return "First In, First Out"
        case .lifo:        return "Last In, First Out"
        case .averageCost: return "Weighted Average Cost"
        }
    }

    var icon: String {
        switch self {
        case .fifo:        return "arrow.right.circle"
        case .lifo:        return "arrow.left.circle"
        case .averageCost: return "equal.circle"
        }
    }
}

// MARK: - Weight Unit

enum WeightUnit: String, Codable, CaseIterable {
    case grams     = "g"
    case kilograms = "kg"
    case tola      = "Tola"
    case ounces    = "oz"

    var fullName: String {
        switch self {
        case .grams:     return "Grams"
        case .kilograms: return "Kilograms"
        case .tola:      return "Tola"
        case .ounces:    return "Troy Ounces"
        }
    }

    /// Convert a value stored in grams into this unit.
    func fromGrams(_ grams: Double) -> Double {
        switch self {
        case .grams:     return grams
        case .kilograms: return grams / 1_000.0
        case .tola:      return grams / 11.6638
        case .ounces:    return grams / 31.1035
        }
    }

    /// Convert a value expressed in this unit into grams.
    func toGrams(_ value: Double) -> Double {
        switch self {
        case .grams:     return value
        case .kilograms: return value * 1_000.0
        case .tola:      return value * 11.6638
        case .ounces:    return value * 31.1035
        }
    }
}

// MARK: - Contribution Frequency

enum ContributionFrequency: String, Codable, CaseIterable {
    case monthly   = "Monthly"
    case quarterly = "Quarterly"
    case annually  = "Annually"

    var periodsPerYear: Double {
        switch self {
        case .monthly:   return 12.0
        case .quarterly: return 4.0
        case .annually:  return 1.0
        }
    }

    var icon: String {
        switch self {
        case .monthly:   return "calendar.circle"
        case .quarterly: return "calendar.badge.plus"
        case .annually:  return "calendar.badge.checkmark"
        }
    }
}

// MARK: - Benchmark Type

enum BenchmarkType: String, Codable, CaseIterable {
    case sp500     = "S&P 500"
    case msciWorld = "MSCI World"
    case dfm       = "DFM Index"

    var icon: String {
        switch self {
        case .sp500:     return "flag.fill"
        case .msciWorld: return "globe"
        case .dfm:       return "building.2"
        }
    }

    var color: Color {
        switch self {
        case .sp500:     return FTColor.income
        case .msciWorld: return FTColor.catBlue
        case .dfm:       return FTColor.gold
        }
    }

    // Approximate historical annual total returns (dividends reinvested)
    var historicalAnnualReturns: [Int: Double] {
        switch self {
        case .sp500:
            return [2019: 31.5, 2020: 18.4, 2021: 28.7, 2022: -18.1, 2023: 26.3, 2024: 23.3]
        case .msciWorld:
            return [2019: 28.4, 2020: 16.5, 2021: 21.8, 2022: -17.7, 2023: 24.4, 2024: 18.6]
        case .dfm:
            return [2019:  9.3, 2020: -10.0, 2021: 28.2, 2022:  6.1, 2023: 12.4, 2024:  8.5]
        }
    }

    /// Compounded total return over the last N calendar years.
    func totalReturn(years: Int) -> Double {
        let current = Calendar.current.component(.year, from: Date())
        var compound = 1.0
        for yr in (current - min(years, 6))..<current {
            compound *= 1 + (historicalAnnualReturns[yr] ?? 8.0) / 100
        }
        return (compound - 1) * 100
    }

    /// CAGR over N years.
    func cagr(years: Int) -> Double {
        guard years > 0 else { return 0 }
        let total = totalReturn(years: years) / 100
        return (pow(1 + total, 1.0 / Double(years)) - 1) * 100
    }
}

// MARK: - Projection Point

struct ProjectionPoint: Identifiable {
    let id = UUID()
    let year: Int
    let nominalValue: Double
    let realValue: Double
    let totalContributions: Double
    let growthComponent: Double
}

// MARK: - Monte Carlo Result

struct MonteCarloResult {
    let iterations: Int
    let successProbability: Double
    let percentile10: Double
    let percentile25: Double
    let median: Double
    let percentile75: Double
    let percentile90: Double
    let finalValues: [Double]
    let yearlyMedians: [Double]
    let targetAmount: Double
}

// MARK: - Allocation Slice

struct AllocationSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
    var percentage: Double = 0
}

// MARK: - Capital Gains Summary

struct CapitalGainsSummary {
    var totalRealizedGain: Double = 0
    var totalRealizedLoss: Double = 0
    var netRealized: Double { totalRealizedGain - totalRealizedLoss }
    var totalUnrealized: Double = 0
    var shortTermGain: Double = 0
    var longTermGain: Double = 0
}
