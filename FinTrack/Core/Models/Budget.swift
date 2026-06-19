import Foundation
import SwiftData

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

    var spent: Double = 0

    var remaining: Double { amount - spent }
    var progress: Double { min(spent / max(amount, 1), 1.0) }
    var isOverBudget: Bool { spent > amount }
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
        color: String = "blue"
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
    }
}

enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
}

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
