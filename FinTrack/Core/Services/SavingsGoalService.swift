import Foundation
import SwiftData
import SwiftUI

// MARK: - Savings Goal Service

final class SavingsGoalService {
    static let shared = SavingsGoalService()
    private init() {}

    // MARK: - Monthly Income Estimation

    func estimatedMonthlyIncome(transactions: [Transaction]) -> Double {
        let now = Date()
        let last3Months = (0..<3).compactMap { offset -> Double? in
            guard let monthStart = Calendar.current.date(byAdding: .month, value: -offset, to: now.startOfMonth) else { return nil }
            return transactions
                .filter { $0.type == .income && !$0.isPending && !$0.isScheduled && $0.date.isSameMonth(as: monthStart) }
                .reduce(0) { $0 + $1.amountInBaseCurrency }
        }
        guard !last3Months.isEmpty else { return 0 }
        return last3Months.reduce(0, +) / Double(last3Months.count)
    }

    // MARK: - Monthly Expense Estimation

    func estimatedMonthlyExpenses(transactions: [Transaction]) -> Double {
        let now = Date()
        let last3Months = (0..<3).compactMap { offset -> Double? in
            guard let monthStart = Calendar.current.date(byAdding: .month, value: -offset, to: now.startOfMonth) else { return nil }
            return transactions
                .filter { !$0.isPending && !$0.isScheduled && $0.date.isSameMonth(as: monthStart) }
                .flatMap { $0.spendingPairs }
                .reduce(0) { $0 + $1.1 }
        }
        guard !last3Months.isEmpty else { return 0 }
        return last3Months.reduce(0, +) / Double(last3Months.count)
    }

    // MARK: - Emergency Fund Recommendation

    func emergencyFundRecommendation(
        transactions: [Transaction],
        months: Int = 3,
        currency: String
    ) -> (amount: Double, rationale: String) {
        let monthly = estimatedMonthlyExpenses(transactions: transactions)
        if monthly > 0 {
            let amount = monthly * Double(months)
            let rationale = "Based on your average monthly expenses of \(monthly.asCompact(currency: currency)), a \(months)-month emergency fund would be \(amount.asCompact(currency: currency))."
            return (amount, rationale)
        }
        let defaultAmount = months == 3 ? 15_000.0 : 30_000.0
        let rationale = "Recommended \(months)-month emergency fund based on UAE average living costs."
        return (defaultAmount, rationale)
    }

    // MARK: - Required Monthly Contribution

    func requiredMonthlyContribution(for goal: SavingsGoal) -> Double {
        guard let months = goal.monthsRemaining, months > 0 else { return goal.remaining }
        return goal.remaining / Double(months)
    }

    // MARK: - Available Monthly Savings

    func availableMonthlySavings(
        transactions: [Transaction],
        goals: [SavingsGoal]
    ) -> Double {
        let income = estimatedMonthlyIncome(transactions: transactions)
        let expenses = estimatedMonthlyExpenses(transactions: transactions)
        return max(0, income - expenses)
    }

    // MARK: - Conflict Analysis

    struct GoalConflict: Identifiable {
        let id = UUID()
        let goals: [SavingsGoal]
        let totalRequiredMonthly: Double
        let availableMonthly: Double
        let shortfall: Double
        let suggestions: [String]

        var hasConflict: Bool { shortfall > 0 }
    }

    func analyzeConflicts(
        goals: [SavingsGoal],
        transactions: [Transaction],
        currencyService: CurrencyService,
        base: String
    ) -> GoalConflict {
        let active = goals.filter { !$0.isCompleted && !$0.isArchived && $0.targetDate != nil }
        let totalRequired = active.reduce(0) { total, goal in
            let req = requiredMonthlyContribution(for: goal)
            return total + currencyService.convert(req, from: goal.currency, to: base)
        }
        let available = availableMonthlySavings(transactions: transactions, goals: goals)
        let shortfall = max(0, totalRequired - available)

        var suggestions: [String] = []
        if shortfall > 0 {
            // Prioritize by conflict priority, then by nearest target date
            let sorted = active.sorted {
                if $0.conflictPriority != $1.conflictPriority { return $0.conflictPriority > $1.conflictPriority }
                guard let d0 = $0.targetDate, let d1 = $1.targetDate else { return $0.targetDate != nil }
                return d0 < d1
            }
            if let first = sorted.first {
                suggestions.append("Prioritize '\(first.name)' — it has the nearest deadline.")
            }
            suggestions.append("Extend one or more goal deadlines to reduce monthly pressure by \(shortfall.asCompact(currency: base))/mo.")
            if shortfall > available * 0.3 {
                suggestions.append("Consider reviewing expenses to free up additional monthly savings.")
            }
        }

        return GoalConflict(
            goals: active,
            totalRequiredMonthly: totalRequired,
            availableMonthly: available,
            shortfall: shortfall,
            suggestions: suggestions
        )
    }

    // MARK: - Milestone Check

    static let milestoneThresholds: [Double] = [0.25, 0.5, 0.75, 1.0]

    func checkMilestones(
        goal: SavingsGoal,
        context: ModelContext
    ) -> [Double] {
        var newMilestones: [Double] = []
        for threshold in Self.milestoneThresholds {
            guard goal.progress >= threshold,
                  !goal.notifiedMilestones.contains(where: { abs($0 - threshold) < 0.001 })
            else { continue }
            goal.notifiedMilestones.append(threshold)
            goal.updatedAt = Date()
            newMilestones.append(threshold)
        }
        if !newMilestones.isEmpty {
            try? context.save()
        }
        return newMilestones
    }

    // MARK: - Auto-Contribution Processing

    /// Returns goals that have a due auto-contribution today.
    func goalsDueForContribution(goals: [SavingsGoal]) -> [SavingsGoal] {
        let today = Date()
        let cal = Calendar.current
        return goals.filter { goal in
            guard goal.autoContributionEnabled && !goal.isCompleted && !goal.isArchived else { return false }
            guard goal.autoContributionAmount > 0 else { return false }
            switch goal.autoContributionFrequency {
            case .monthly:
                return cal.component(.day, from: today) == goal.autoContributionDay
            case .weekly:
                return cal.component(.weekday, from: today) == 2 // Monday
            case .biWeekly:
                let weekOfYear = cal.component(.weekOfYear, from: today)
                return cal.component(.weekday, from: today) == 2 && weekOfYear % 2 == 0
            }
        }
    }

    // MARK: - Savings Insights

    enum GoalInsightSeverity {
        case info, warning, positive

        var color: Color {
            switch self {
            case .info:     return FTColor.accent
            case .warning:  return FTColor.gold
            case .positive: return FTColor.income
            }
        }
    }

    struct SavingsInsight: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let message: String
        let severity: GoalInsightSeverity
    }

    func generateInsights(
        goals: [SavingsGoal],
        transactions: [Transaction],
        currencyService: CurrencyService,
        base: String
    ) -> [SavingsInsight] {
        var insights: [SavingsInsight] = []
        let active = goals.filter { !$0.isCompleted && !$0.isArchived }
        let conflict = analyzeConflicts(goals: goals, transactions: transactions,
                                        currencyService: currencyService, base: base)

        if conflict.hasConflict {
            insights.append(SavingsInsight(
                icon: "exclamationmark.triangle.fill",
                title: "Goal Funding Conflict",
                message: "Your active goals require \(conflict.totalRequiredMonthly.asCompact(currency: base))/mo but your estimated savings capacity is \(conflict.availableMonthly.asCompact(currency: base))/mo.",
                severity: .warning
            ))
        }

        let hasEmergencyFund = active.contains { $0.goalType == .emergencyFund }
        if !hasEmergencyFund {
            let monthly = estimatedMonthlyExpenses(transactions: transactions)
            if monthly > 0 {
                insights.append(SavingsInsight(
                    icon: "shield.slash.fill",
                    title: "No Emergency Fund",
                    message: "You have no emergency fund goal. Financial experts recommend 3–6 months of expenses (\((monthly * 3).asCompact(currency: base))–\((monthly * 6).asCompact(currency: base))).",
                    severity: .warning
                ))
            }
        }

        for goal in active where goal.progress >= 0.9 && goal.progress < 1.0 {
            insights.append(SavingsInsight(
                icon: "target",
                title: "Almost There!",
                message: "'\(goal.name)' is \(Int(goal.progress * 100))% complete. Just \(goal.remaining.asCompact(currency: goal.currency)) to go!",
                severity: .info
            ))
        }

        let overdueGoals = active.filter { g in
            guard let date = g.targetDate else { return false }
            return date < Date() && !g.isCompleted
        }
        for goal in overdueGoals {
            insights.append(SavingsInsight(
                icon: "calendar.badge.exclamationmark",
                title: "Goal Overdue",
                message: "'\(goal.name)' passed its target date with \(Int(goal.progress * 100))% funded. Consider extending the deadline.",
                severity: .warning
            ))
        }

        let goalsWithoutAuto = active.filter { !$0.autoContributionEnabled }
        if !goalsWithoutAuto.isEmpty && active.count > 0 {
            insights.append(SavingsInsight(
                icon: "repeat.circle",
                title: "Enable Auto-Contributions",
                message: "\(goalsWithoutAuto.count) goal\(goalsWithoutAuto.count == 1 ? "" : "s") \(goalsWithoutAuto.count == 1 ? "has" : "have") no automatic contribution set. Automating contributions significantly improves success rates.",
                severity: .info
            ))
        }

        if active.contains(where: { $0.progress > 0.5 }) && !conflict.hasConflict {
            insights.append(SavingsInsight(
                icon: "star.fill",
                title: "Great Progress!",
                message: "You're on track with your savings goals. Keep up the momentum!",
                severity: .positive
            ))
        }

        return insights
    }

    // MARK: - Recommended Down Payment

    func downPaymentAmount(propertyPrice: Double, percentageOfPrice: Double) -> Double {
        return propertyPrice * (percentageOfPrice / 100)
    }

    // MARK: - UAE University Tuition Benchmarks

    static let uaeTuitionBenchmarks: [(university: String, annualAED: Double)] = [
        ("American University of Sharjah", 60_000),
        ("American University in Dubai", 75_000),
        ("University of Dubai", 45_000),
        ("Khalifa University", 42_000),
        ("New York University Abu Dhabi", 220_000),
        ("Sorbonne University Abu Dhabi", 75_000),
        ("Zayed University", 42_000),
        ("UAE University (UAEU)", 38_000),
        ("UK University (abroad)", 180_000),
        ("US University (abroad)", 260_000),
        ("Custom / Other", 0)
    ]

    // MARK: - Hajj/Umrah Package Estimates (UAE departure, AED)

    static let hajjPackageEstimates: [(tier: String, costAED: Double)] = [
        ("Economy Package", 18_000),
        ("Standard Package", 28_000),
        ("Comfort Package", 45_000),
        ("Premium Package", 70_000),
        ("Custom / Other", 0)
    ]

    static let umrahPackageEstimates: [(tier: String, costAED: Double)] = [
        ("Economy Umrah", 5_000),
        ("Standard Umrah", 9_000),
        ("Premium Umrah", 16_000),
        ("Custom / Other", 0)
    ]

    // MARK: - On-Track Status

    enum GoalStatus {
        case onTrack, slightlyBehind, atRisk, overdue, completed, noDate
    }

    func goalStatus(for goal: SavingsGoal) -> GoalStatus {
        if goal.isCompleted || goal.isFullyFunded { return .completed }
        guard let date = goal.targetDate else { return .noDate }
        if date < Date() { return .overdue }
        let monthsLeft = goal.monthsRemaining ?? 0
        let requiredProgress = monthsLeft > 0 ? 1.0 - Double(monthsLeft) / max(1, totalMonths(goal: goal)) : 0
        let actual = goal.progress
        let gap = requiredProgress - actual
        if gap <= 0 { return .onTrack }
        if gap < 0.1 { return .slightlyBehind }
        return .atRisk
    }

    private func totalMonths(goal: SavingsGoal) -> Double {
        guard let target = goal.targetDate else { return 12 }
        let months = Calendar.current.dateComponents([.month], from: goal.createdAt, to: target).month ?? 12
        return max(1, Double(months))
    }

    func statusColor(for status: GoalStatus) -> Color {
        switch status {
        case .onTrack:       return FTColor.income
        case .slightlyBehind: return FTColor.gold
        case .atRisk:        return FTColor.expense
        case .overdue:       return FTColor.expense
        case .completed:     return FTColor.income
        case .noDate:        return FTColor.textSecondary
        }
    }

    func statusLabel(for status: GoalStatus) -> String {
        switch status {
        case .onTrack:        return "On Track"
        case .slightlyBehind: return "Slightly Behind"
        case .atRisk:         return "At Risk"
        case .overdue:        return "Overdue"
        case .completed:      return "Completed"
        case .noDate:         return "No Deadline"
        }
    }
}

