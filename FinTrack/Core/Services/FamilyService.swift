import Foundation

// MARK: - Result Types

struct HouseholdBudgetSummary {
    var totalMonthlyIncome: Double
    var totalMonthlyExpenses: Double
    var totalMonthlyBills: Double
    var netCashFlow: Double
    var savingsRate: Double
    var currency: String
    var topExpenseCategories: [(category: String, amount: Double, percentage: Double)]
}

struct GoalMilestone: Identifiable {
    var id: String { label }
    var percentage: Double
    var amount: Double
    var isReached: Bool
    var label: String
}

// MARK: - FamilyService

final class FamilyService {
    static let shared = FamilyService()
    private init() {}

    // MARK: Household Budget

    func householdBudgetSummary(
        transactions: [Transaction],
        bills: [Bill],
        currency: String
    ) -> HouseholdBudgetSummary {
        let now = Date()
        let monthTxs = transactions.filter { $0.date.isSameMonth(as: now) && !$0.isPending }

        let income   = monthTxs.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency }
        let expenses = monthTxs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }
        let billsTotal = bills.filter { $0.isActive }.reduce(0) { $0 + $1.monthlyEquivalent }
        let savingsRate = income > 0 ? max(0, (income - expenses) / income) : 0

        let top = Dictionary(grouping: monthTxs.filter { $0.type == .expense }) { $0.category.rawValue }
            .mapValues { $0.reduce(0) { $0 + $1.amountInBaseCurrency } }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (category: $0.key, amount: $0.value, percentage: expenses > 0 ? $0.value / expenses : 0) }

        return HouseholdBudgetSummary(
            totalMonthlyIncome: income,
            totalMonthlyExpenses: expenses,
            totalMonthlyBills: billsTotal,
            netCashFlow: income - expenses,
            savingsRate: savingsRate,
            currency: currency,
            topExpenseCategories: top
        )
    }

    // MARK: Permission Check

    func canAccess(
        member: FamilyMemberData,
        resourceType: String,
        resourceId: String? = nil,
        requiredLevel: FamilyPermissionLevel = .viewOnly
    ) -> Bool {
        let level = member.permissionFor(resourceType: resourceType, resourceId: resourceId)
        switch requiredLevel {
        case .viewOnly: return true
        case .edit:     return level.canEdit
        case .admin:    return level.isAdmin
        }
    }

    // MARK: Default Permissions by Role

    func defaultPermissions(for role: FamilyMemberRole) -> [FamilyPermissionRecord] {
        switch role {
        case .partner, .parent:
            return [FamilyPermissionRecord(resourceType: "all", level: .admin)]
        case .child:
            return [
                FamilyPermissionRecord(resourceType: "goals", level: .viewOnly),
                FamilyPermissionRecord(resourceType: "budget", level: .viewOnly),
            ]
        case .other:
            return [FamilyPermissionRecord(resourceType: "all", level: .viewOnly)]
        }
    }

    // MARK: Shared Goal Milestones

    func milestones(for goal: SharedFamilyGoal) -> [GoalMilestone] {
        [0.25, 0.5, 0.75, 1.0].map { fraction in
            GoalMilestone(
                percentage: fraction,
                amount: goal.targetAmount * fraction,
                isReached: goal.progress >= fraction,
                label: "\(Int(fraction * 100))%"
            )
        }
    }

    // MARK: Allowance Insights

    func allowanceInsights(child: ChildProfile, currency: String) -> [String] {
        var insights: [String] = []

        if child.isAllowanceDue {
            insights.append("Allowance payment is due for \(child.name).")
        }

        if child.savingsGoalAmount > 0 {
            let pct = Int(child.savingsProgress * 100)
            insights.append("\(child.name) is \(pct)% of the way to their savings goal.")
            if child.savingsProgress >= 1 {
                insights.append("\(child.name) has reached their savings goal!")
            }
        }

        if child.totalPaid > 0 {
            let monthly = child.monthlyAllowance
            if monthly > 0 {
                insights.append(
                    "At \(monthly.formatted(as: currency))/\(child.allowanceFrequency.rawValue.lowercased()), " +
                    "\(child.name) receives \(child.monthlyAllowance.formatted(as: currency)) monthly."
                )
            }
        }

        return insights
    }

    // MARK: Build Family Overview

    func buildMemberSummaries(
        members: [FamilyMemberData],
        transactions: [Transaction],
        currency: String
    ) -> [(member: FamilyMemberData, monthlyIncome: Double, monthlyExpenses: Double)] {
        // In a single-user offline app, all transactions belong to the current user.
        // We distribute totals across the "current user" member.
        let now = Date()
        let monthTxs = transactions.filter { $0.date.isSameMonth(as: now) && !$0.isPending }
        let income   = monthTxs.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInBaseCurrency }
        let expenses = monthTxs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency }

        return members.map { member in
            if member.isCurrentUser {
                return (member: member, monthlyIncome: income, monthlyExpenses: expenses)
            }
            return (member: member, monthlyIncome: 0, monthlyExpenses: 0)
        }
    }
}
