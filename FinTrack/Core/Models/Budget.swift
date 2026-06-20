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

// MARK: - Savings Goal Type

enum SavingsGoalType: String, Codable, CaseIterable {
    case custom        = "Custom"
    case emergencyFund = "Emergency Fund"
    case downPayment   = "Down Payment"
    case education     = "Education Fund"
    case hajj          = "Hajj / Umrah"
    case vehicle       = "Vehicle"
    case vacation      = "Vacation"
    case wedding       = "Wedding"

    var icon: String {
        switch self {
        case .custom:        return "star.fill"
        case .emergencyFund: return "shield.fill"
        case .downPayment:   return "house.fill"
        case .education:     return "graduationcap.fill"
        case .hajj:          return "moon.stars.fill"
        case .vehicle:       return "car.fill"
        case .vacation:      return "airplane"
        case .wedding:       return "heart.fill"
        }
    }

    var color: String {
        switch self {
        case .custom:        return "blue"
        case .emergencyFund: return "orange"
        case .downPayment:   return "teal"
        case .education:     return "purple"
        case .hajj:          return "green"
        case .vehicle:       return "indigo"
        case .vacation:      return "cyan"
        case .wedding:       return "pink"
        }
    }

    var shortDescription: String {
        switch self {
        case .custom:        return "Any savings goal"
        case .emergencyFund: return "3–6 months of expenses"
        case .downPayment:   return "Home purchase fund"
        case .education:     return "University tuition fund"
        case .hajj:          return "Hajj or Umrah trip"
        case .vehicle:       return "Car or vehicle purchase"
        case .vacation:      return "Dream vacation or travel"
        case .wedding:       return "Wedding & celebrations"
        }
    }
}

// MARK: - Goal Contribution Frequency

enum GoalContributionFrequency: String, Codable, CaseIterable {
    case weekly   = "Weekly"
    case biWeekly = "Bi-Weekly"
    case monthly  = "Monthly"

    var periodsPerMonth: Double {
        switch self {
        case .weekly:   return 4.33
        case .biWeekly: return 2.17
        case .monthly:  return 1.0
        }
    }

    var icon: String {
        switch self {
        case .weekly:   return "calendar.circle"
        case .biWeekly: return "calendar.badge.plus"
        case .monthly:  return "calendar"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly, .biWeekly: return .weekOfYear
        case .monthly:           return .month
        }
    }

    func nextContributionDate(from date: Date, dayOfMonth: Int) -> Date {
        let cal = Calendar.current
        switch self {
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biWeekly:
            return cal.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: date)
            comps.month! += 1
            comps.day = min(dayOfMonth, 28)
            return cal.date(from: comps) ?? date
        }
    }
}

// MARK: - Savings Goal

@Model
final class SavingsGoal {
    // MARK: Core fields (original)
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

    // MARK: Enhanced fields (v12)
    var goalTypeRaw: String                   // SavingsGoalType.rawValue
    var linkedAccountId: UUID?                // Optional funding account
    var autoContributionEnabled: Bool
    var autoContributionAmount: Double
    var autoContributionFrequencyRaw: String  // GoalContributionFrequency.rawValue
    var autoContributionDay: Int              // Day of month (1-28) for monthly
    var roundUpEnabled: Bool
    var salaryPercentage: Double              // % of salary; 0 = disabled
    var conflictPriority: Int                 // 1 = highest, 0 = unset
    var isArchived: Bool
    var updatedAt: Date
    var notifiedMilestones: [Double]          // Milestones already notified, e.g. [0.5, 0.75]

    // Template-specific optional fields
    var propertyTargetPrice: Double           // Down payment: full property value
    var downPaymentPercent: Double            // Down payment: desired % (default 20%)
    var educationInstitution: String?         // Education: university/institution name
    var hajjTravelYear: Int                   // Hajj: target travel year (0 = not set)
    var emergencyMonthsTarget: Int            // Emergency fund: 3 or 6 months

    // MARK: Computed Properties

    var goalType: SavingsGoalType {
        get { SavingsGoalType(rawValue: goalTypeRaw) ?? .custom }
        set { goalTypeRaw = newValue.rawValue }
    }

    var autoContributionFrequency: GoalContributionFrequency {
        get { GoalContributionFrequency(rawValue: autoContributionFrequencyRaw) ?? .monthly }
        set { autoContributionFrequencyRaw = newValue.rawValue }
    }

    var progress: Double { min(currentAmount / max(targetAmount, 1), 1.0) }
    var remaining: Double { max(targetAmount - currentAmount, 0) }
    var isFullyFunded: Bool { currentAmount >= targetAmount }

    var daysRemaining: Int? {
        guard let date = targetDate, date > Date() else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day
    }

    var monthsRemaining: Int? {
        guard let date = targetDate, date > Date() else { return nil }
        return max(0, Calendar.current.dateComponents([.month], from: Date(), to: date).month ?? 0)
    }

    var requiredMonthlyContribution: Double {
        guard let m = monthsRemaining, m > 0 else { return remaining }
        return remaining / Double(m)
    }

    var projectedCompletionDate: Date? {
        guard autoContributionEnabled else { return nil }
        let monthlyEquivalent = autoContributionAmount * autoContributionFrequency.periodsPerMonth
        guard monthlyEquivalent > 0 && remaining > 0 else { return nil }
        let monthsNeeded = Int(ceil(remaining / monthlyEquivalent))
        return Calendar.current.date(byAdding: .month, value: monthsNeeded, to: Date())
    }

    var effectiveIcon: String { icon.isEmpty ? goalType.icon : icon }
    var effectiveColor: String { color.isEmpty ? goalType.color : color }

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        currency: String = "AED",
        targetDate: Date? = nil,
        icon: String = "",
        color: String = "",
        notes: String? = nil,
        goalType: SavingsGoalType = .custom,
        linkedAccountId: UUID? = nil,
        autoContributionEnabled: Bool = false,
        autoContributionAmount: Double = 0,
        autoContributionFrequency: GoalContributionFrequency = .monthly,
        autoContributionDay: Int = 1,
        roundUpEnabled: Bool = false,
        salaryPercentage: Double = 0,
        conflictPriority: Int = 0,
        isArchived: Bool = false,
        propertyTargetPrice: Double = 0,
        downPaymentPercent: Double = 20,
        educationInstitution: String? = nil,
        hajjTravelYear: Int = 0,
        emergencyMonthsTarget: Int = 3
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
        self.goalTypeRaw = goalType.rawValue
        self.linkedAccountId = linkedAccountId
        self.autoContributionEnabled = autoContributionEnabled
        self.autoContributionAmount = autoContributionAmount
        self.autoContributionFrequencyRaw = autoContributionFrequency.rawValue
        self.autoContributionDay = autoContributionDay
        self.roundUpEnabled = roundUpEnabled
        self.salaryPercentage = salaryPercentage
        self.conflictPriority = conflictPriority
        self.isArchived = isArchived
        self.updatedAt = Date()
        self.notifiedMilestones = []
        self.propertyTargetPrice = propertyTargetPrice
        self.downPaymentPercent = downPaymentPercent
        self.educationInstitution = educationInstitution
        self.hajjTravelYear = hajjTravelYear
        self.emergencyMonthsTarget = emergencyMonthsTarget
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
