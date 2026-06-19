import Foundation
import SwiftData
import SwiftUI

// MARK: - Budget Period

enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly     = "Weekly"
    case monthly    = "Monthly"
    case quarterly  = "Quarterly"
    case yearly     = "Yearly"

    var daysInPeriod: Int {
        switch self {
        case .weekly:    return 7
        case .monthly:   return 30
        case .quarterly: return 90
        case .yearly:    return 365
        }
    }
}

// MARK: - Template Season

enum TemplateSeason: String, Codable, CaseIterable {
    case ramadan = "Ramadan"
    case eid     = "Eid"
    case summer  = "Summer Holidays"
    case custom  = "Custom"

    var icon: String {
        switch self {
        case .ramadan: return "moon.stars.fill"
        case .eid:     return "star.and.crescent.fill"
        case .summer:  return "sun.max.fill"
        case .custom:  return "doc.badge.plus"
        }
    }
}

// MARK: - Template Item

struct TemplateItem: Codable, Identifiable {
    var id: UUID = UUID()
    var category: TransactionCategory
    var suggestedAmount: Double
    var notes: String?

    init(category: TransactionCategory, suggestedAmount: Double, notes: String? = nil) {
        self.category = category
        self.suggestedAmount = suggestedAmount
        self.notes = notes
    }
}

// MARK: - Budget Recommendation (persisted dismissal)

struct BudgetRecommendationRecord: Codable {
    var dismissedIDs: [String] = []
}

// MARK: - Budget (enhanced)

@Model
final class Budget {
    var id: UUID
    var name: String
    var category: TransactionCategory
    var customCategory: String?
    var amount: Double
    var currency: String
    var period: BudgetPeriod
    var startDate: Date
    var endDate: Date?
    var alertThreshold: Double
    var isActive: Bool
    var color: String
    var createdAt: Date

    // Unused stored field kept for schema compatibility
    var spent: Double = 0

    // Feature 5: Rollover
    var isRollover: Bool
    var rolloverAmount: Double

    // Feature 6: Shared / household
    var isShared: Bool
    var sharedMembers: [String]

    // Feature 8: Alert deduplication — which thresholds were already fired this period
    var notifiedThresholds: [Double]
    var notifiedMonth: Int  // calendar month (1-12) when thresholds were last fired

    // Computed
    var remaining: Double { (amount + rolloverAmount) - spent }
    var progress: Double { let cap = amount + rolloverAmount; return cap > 0 ? min(spent / cap, 1.0) : 0 }
    var isOverBudget: Bool { spent > (amount + rolloverAmount) }
    var isNearLimit: Bool { progress >= alertThreshold && !isOverBudget }

    init(
        id: UUID = UUID(),
        name: String,
        category: TransactionCategory,
        customCategory: String? = nil,
        amount: Double,
        currency: String = "AED",
        period: BudgetPeriod = .monthly,
        startDate: Date = Date().startOfMonth,
        endDate: Date? = nil,
        alertThreshold: Double = 0.8,
        isActive: Bool = true,
        color: String = "blue",
        isRollover: Bool = false,
        rolloverAmount: Double = 0,
        isShared: Bool = false,
        sharedMembers: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.customCategory = customCategory
        self.amount = amount
        self.currency = currency
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.alertThreshold = alertThreshold
        self.isActive = isActive
        self.color = color
        self.createdAt = Date()
        self.isRollover = isRollover
        self.rolloverAmount = rolloverAmount
        self.isShared = isShared
        self.sharedMembers = sharedMembers
        self.notifiedThresholds = []
        self.notifiedMonth = 0
    }
}

// MARK: - Savings Goal

@Model
final class SavingsGoal {
    var id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var currency: String
    var targetDate: Date?
    var icon: String
    var color: String
    var notes: String?
    var isCompleted: Bool
    var createdAt: Date

    var progress: Double { min(currentAmount / max(targetAmount, 1), 1.0) }
    var remaining: Double { max(targetAmount - currentAmount, 0) }

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        currency: String = "AED",
        targetDate: Date? = nil,
        icon: String = "star",
        color: String = "blue",
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.currency = currency
        self.targetDate = targetDate
        self.icon = icon
        self.color = color
        self.notes = notes
        self.isCompleted = false
        self.createdAt = Date()
    }
}

// MARK: - Budget Envelope (Feature 4)

@Model
final class BudgetEnvelope {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var allocatedAmount: Double      // Amount funded into this envelope this period
    var category: TransactionCategory  // Spending is tracked against this category
    var currency: String
    var sortOrder: Int
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "envelope.fill",
        colorHex: String = "#0E9C8A",
        allocatedAmount: Double,
        category: TransactionCategory,
        currency: String = "AED",
        sortOrder: Int = 0,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.allocatedAmount = allocatedAmount
        self.category = category
        self.currency = currency
        self.sortOrder = sortOrder
        self.notes = notes
        self.createdAt = Date()
    }

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Budget Template (Feature 10)

@Model
final class BudgetTemplate {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var templateDescription: String
    var seasonRaw: String
    var isBuiltIn: Bool
    var items: [TemplateItem]
    var createdAt: Date

    var season: TemplateSeason {
        get { TemplateSeason(rawValue: seasonRaw) ?? .custom }
        set { seasonRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String = "#0E9C8A",
        description: String,
        season: TemplateSeason = .custom,
        isBuiltIn: Bool = false,
        items: [TemplateItem] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.templateDescription = description
        self.seasonRaw = season.rawValue
        self.isBuiltIn = isBuiltIn
        self.items = items
        self.createdAt = Date()
    }
}
