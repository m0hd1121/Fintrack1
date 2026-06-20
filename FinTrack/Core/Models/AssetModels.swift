import Foundation
import SwiftData
import SwiftUI

// MARK: - RealEstateProperty

@Model
final class RealEstateProperty {
    var id: UUID
    var name: String
    var propertyTypeRaw: String
    var address: String?
    var purchasePrice: Double
    var purchaseDate: Date
    var currentValue: Double         // Manually updated market estimate
    var mortgageBalance: Double      // Manual or linked to Loan
    var ownershipPercentage: Double  // 0–100
    var currency: String
    var area: Double?                // Square meters or feet
    var areaUnit: String?            // "sqm" or "sqft"
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var propertyType: RealEstateType {
        get { RealEstateType(rawValue: propertyTypeRaw) ?? .apartment }
        set { propertyTypeRaw = newValue.rawValue }
    }

    // MARK: Computed

    /// Net equity the user owns
    var equity: Double { (currentValue * ownershipPercentage / 100) - mortgageBalance }
    /// Total appreciation from purchase price
    var appreciation: Double { currentValue - purchasePrice }
    var appreciationPercent: Double { purchasePrice > 0 ? (appreciation / purchasePrice) * 100 : 0 }
    /// Value attributed to user's ownership share
    var ownedValue: Double { currentValue * ownershipPercentage / 100 }

    init(
        id: UUID = UUID(),
        name: String,
        propertyType: RealEstateType = .apartment,
        address: String? = nil,
        purchasePrice: Double,
        purchaseDate: Date = Date(),
        currentValue: Double,
        mortgageBalance: Double = 0,
        ownershipPercentage: Double = 100,
        currency: String = "AED",
        area: Double? = nil,
        areaUnit: String? = nil,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.propertyTypeRaw = propertyType.rawValue
        self.address = address
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.currentValue = currentValue
        self.mortgageBalance = mortgageBalance
        self.ownershipPercentage = ownershipPercentage
        self.currency = currency
        self.area = area
        self.areaUnit = areaUnit
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum RealEstateType: String, Codable, CaseIterable {
    case apartment  = "Apartment"
    case villa      = "Villa"
    case townhouse  = "Townhouse"
    case land       = "Land"
    case commercial = "Commercial"
    case warehouse  = "Warehouse"
    case other      = "Other"

    var icon: String {
        switch self {
        case .apartment:  return "building.fill"
        case .villa:      return "house.fill"
        case .townhouse:  return "house.lodge.fill"
        case .land:       return "map.fill"
        case .commercial: return "building.2.fill"
        case .warehouse:  return "shippingbox.fill"
        case .other:      return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .apartment:  return "blue"
        case .villa:      return "green"
        case .townhouse:  return "teal"
        case .land:       return "brown"
        case .commercial: return "orange"
        case .warehouse:  return "purple"
        case .other:      return "gray"
        }
    }
}

// MARK: - Vehicle

@Model
final class Vehicle {
    var id: UUID
    var make: String
    var model: String
    var year: Int
    var purchasePrice: Double
    var purchaseDate: Date
    var currency: String
    var registrationNumber: String?
    var registrationExpiry: Date?
    var insuranceProvider: String?
    var insuranceExpiry: Date?
    var depreciationRate: Double      // Annual % e.g. 15.0 = 15%
    var depreciationMethodRaw: String
    var manualCurrentValue: Double?   // User override; nil = use depreciation formula
    var color: String?
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var depreciationMethod: VehicleDepreciationMethod {
        get { VehicleDepreciationMethod(rawValue: depreciationMethodRaw) ?? .decliningBalance }
        set { depreciationMethodRaw = newValue.rawValue }
    }

    // MARK: Computed

    private var yearsOwned: Double {
        max(0, Date().timeIntervalSince(purchaseDate) / (365.25 * 24 * 3600))
    }

    var estimatedValue: Double {
        let rate = depreciationRate / 100.0
        switch depreciationMethod {
        case .straightLine:
            // Straight-line: depreciates evenly to zero over 1/rate years
            let usefulLife = rate > 0 ? 1.0 / rate : 10
            let annualDep  = purchasePrice / usefulLife
            return max(0, purchasePrice - annualDep * yearsOwned)
        case .decliningBalance:
            // Declining balance: value *= (1 - rate)^years
            return purchasePrice * pow(max(0, 1 - rate), yearsOwned)
        }
    }

    var currentValue: Double { manualCurrentValue ?? estimatedValue }
    var depreciation: Double { purchasePrice - currentValue }
    var depreciationPercent: Double { purchasePrice > 0 ? (depreciation / purchasePrice) * 100 : 0 }

    var isRegistrationExpiringSoon: Bool {
        guard let exp = registrationExpiry else { return false }
        return exp.timeIntervalSinceNow < 30 * 24 * 3600 && exp > Date()
    }

    var isInsuranceExpiringSoon: Bool {
        guard let exp = insuranceExpiry else { return false }
        return exp.timeIntervalSinceNow < 30 * 24 * 3600 && exp > Date()
    }

    init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int,
        purchasePrice: Double,
        purchaseDate: Date = Date(),
        currency: String = "AED",
        registrationNumber: String? = nil,
        registrationExpiry: Date? = nil,
        insuranceProvider: String? = nil,
        insuranceExpiry: Date? = nil,
        depreciationRate: Double = 15.0,
        depreciationMethod: VehicleDepreciationMethod = .decliningBalance,
        manualCurrentValue: Double? = nil,
        color: String? = nil,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.currency = currency
        self.registrationNumber = registrationNumber
        self.registrationExpiry = registrationExpiry
        self.insuranceProvider = insuranceProvider
        self.insuranceExpiry = insuranceExpiry
        self.depreciationRate = depreciationRate
        self.depreciationMethodRaw = depreciationMethod.rawValue
        self.manualCurrentValue = manualCurrentValue
        self.color = color
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum VehicleDepreciationMethod: String, Codable, CaseIterable {
    case straightLine     = "Straight-Line"
    case decliningBalance = "Declining Balance"

    var description: String {
        switch self {
        case .straightLine:     return "Even depreciation each year"
        case .decliningBalance: return "Faster initial depreciation"
        }
    }
}

// MARK: - PersonalAsset (High-Value Items)

@Model
final class PersonalAsset {
    var id: UUID
    var name: String
    var categoryRaw: String
    var purchasePrice: Double
    var purchaseDate: Date
    var insuranceValue: Double
    var estimatedMarketValue: Double  // Manually updated
    var currency: String
    var serialNumber: String?
    var brand: String?
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var category: PersonalAssetCategory {
        get { PersonalAssetCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var appreciation: Double { estimatedMarketValue - purchasePrice }
    var appreciationPercent: Double { purchasePrice > 0 ? (appreciation / purchasePrice) * 100 : 0 }
    var isAppreciated: Bool { appreciation >= 0 }

    init(
        id: UUID = UUID(),
        name: String,
        category: PersonalAssetCategory = .other,
        purchasePrice: Double,
        purchaseDate: Date = Date(),
        insuranceValue: Double = 0,
        estimatedMarketValue: Double,
        currency: String = "AED",
        serialNumber: String? = nil,
        brand: String? = nil,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.insuranceValue = insuranceValue
        self.estimatedMarketValue = estimatedMarketValue
        self.currency = currency
        self.serialNumber = serialNumber
        self.brand = brand
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum PersonalAssetCategory: String, Codable, CaseIterable {
    case jewelry     = "Jewelry"
    case watch       = "Watch"
    case electronics = "Electronics"
    case art         = "Art"
    case collectible = "Collectible"
    case furniture   = "Furniture"
    case other       = "Other"

    var icon: String {
        switch self {
        case .jewelry:     return "sparkles"
        case .watch:       return "applewatch"
        case .electronics: return "laptopcomputer"
        case .art:         return "paintpalette.fill"
        case .collectible: return "trophy.fill"
        case .furniture:   return "sofa.fill"
        case .other:       return "cube.fill"
        }
    }

    var color: String {
        switch self {
        case .jewelry:     return "yellow"
        case .watch:       return "gray"
        case .electronics: return "blue"
        case .art:         return "purple"
        case .collectible: return "orange"
        case .furniture:   return "brown"
        case .other:       return "teal"
        }
    }
}

// MARK: - DigitalAsset

@Model
final class DigitalAsset {
    var id: UUID
    var name: String
    var typeRaw: String
    var acquisitionValue: Double
    var acquisitionDate: Date
    var currentValue: Double
    var currency: String
    var platform: String?       // e.g. "GoDaddy", "OpenSea", "USPTO"
    var identifier: String?     // Domain name, token ID, patent number, etc.
    var expiryDate: Date?       // Domain expiry, license expiry
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var assetType: DigitalAssetType {
        get { DigitalAssetType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var gainLoss: Double { currentValue - acquisitionValue }
    var gainLossPercent: Double { acquisitionValue > 0 ? (gainLoss / acquisitionValue) * 100 : 0 }

    var isExpiringWithin30Days: Bool {
        guard let exp = expiryDate else { return false }
        return exp.timeIntervalSinceNow < 30 * 24 * 3600 && exp > Date()
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: DigitalAssetType = .other,
        acquisitionValue: Double,
        acquisitionDate: Date = Date(),
        currentValue: Double,
        currency: String = "USD",
        platform: String? = nil,
        identifier: String? = nil,
        expiryDate: Date? = nil,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.acquisitionValue = acquisitionValue
        self.acquisitionDate = acquisitionDate
        self.currentValue = currentValue
        self.currency = currency
        self.platform = platform
        self.identifier = identifier
        self.expiryDate = expiryDate
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum DigitalAssetType: String, Codable, CaseIterable {
    case domain    = "Domain"
    case nft       = "NFT"
    case ip        = "Intellectual Property"
    case license   = "License"
    case business  = "Digital Business"
    case software  = "Software / SaaS"
    case other     = "Other"

    var icon: String {
        switch self {
        case .domain:    return "globe"
        case .nft:       return "photo.artframe"
        case .ip:        return "lightbulb.fill"
        case .license:   return "key.fill"
        case .business:  return "storefront.fill"
        case .software:  return "app.fill"
        case .other:     return "doc.fill"
        }
    }

    var color: String {
        switch self {
        case .domain:    return "blue"
        case .nft:       return "purple"
        case .ip:        return "yellow"
        case .license:   return "teal"
        case .business:  return "orange"
        case .software:  return "green"
        case .other:     return "gray"
        }
    }
}

// MARK: - NetWorthSnapshot (for historical chart)

@Model
final class NetWorthSnapshot {
    var id: UUID
    var date: Date
    var totalAssets: Double
    var totalLiabilities: Double
    var netWorth: Double
    var currency: String
    @Attribute(.externalStorage) var breakdownData: Data  // JSON [String: Double]

    var breakdown: [String: Double] {
        get { (try? JSONDecoder().decode([String: Double].self, from: breakdownData)) ?? [:] }
        set { breakdownData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        totalAssets: Double,
        totalLiabilities: Double,
        currency: String = "AED",
        breakdown: [String: Double] = [:]
    ) {
        self.id = id
        self.date = date
        self.totalAssets = totalAssets
        self.totalLiabilities = totalLiabilities
        self.netWorth = totalAssets - totalLiabilities
        self.currency = currency
        self.breakdownData = (try? JSONEncoder().encode(breakdown)) ?? Data()
    }
}

// MARK: - NetWorthMilestone

@Model
final class NetWorthMilestone {
    var id: UUID
    var amount: Double
    var currency: String
    var achievedAt: Date
    var isAcknowledged: Bool

    init(
        id: UUID = UUID(),
        amount: Double,
        currency: String = "AED",
        achievedAt: Date = Date(),
        isAcknowledged: Bool = false
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.achievedAt = achievedAt
        self.isAcknowledged = isAcknowledged
    }
}
