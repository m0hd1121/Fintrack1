import Foundation
import UserNotifications
import SwiftData

// MARK: - Budget Forecast (Feature 7)

struct BudgetForecast {
    let budgetID: UUID
    let budgetName: String
    let category: TransactionCategory
    let spent: Double
    let budgetAmount: Double
    let projectedEndOfMonth: Double
    let confidence: Double  // 0…1

    var isProjectedOverBudget: Bool { projectedEndOfMonth > budgetAmount }
    var projectedOverage: Double { max(projectedEndOfMonth - budgetAmount, 0) }

    var paceLabel: String {
        let ratio = projectedEndOfMonth / max(budgetAmount, 1)
        if ratio < 0.85 { return "Under budget pace" }
        if ratio < 1.0  { return "On track" }
        return "Exceeding budget"
    }
}

// MARK: - Budget Recommendation (Feature 9)

struct BudgetRecommendation: Identifiable {
    var id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let suggestedAmount: Double?
    let category: TransactionCategory?
    var isDismissed: Bool = false

    enum RecommendationType {
        case createBudget
        case increaseBudget
        case decreaseBudget
        case anomaly
        case savings

        var icon: String {
            switch self {
            case .createBudget:   return "plus.circle.fill"
            case .increaseBudget: return "arrow.up.circle.fill"
            case .decreaseBudget: return "arrow.down.circle.fill"
            case .anomaly:        return "exclamationmark.triangle.fill"
            case .savings:        return "lightbulb.fill"
            }
        }

        var colorName: String {
            switch self {
            case .createBudget:   return "teal"
            case .increaseBudget: return "orange"
            case .decreaseBudget: return "green"
            case .anomaly:        return "red"
            case .savings:        return "blue"
            }
        }
    }
}

// MARK: - Budget Service

final class BudgetService {
    static let shared = BudgetService()
    private init() {}

    // MARK: Feature 7 — End-of-Month Forecast

    func forecastEndOfMonth(
        for budget: Budget,
        spent: Double,
        transactions: [Transaction]
    ) -> BudgetForecast {
        let cal = Calendar.current
        let now = Date()
        let dayOfMonth = cal.component(.day, from: now)
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let daysRemaining = max(daysInMonth - dayOfMonth, 0)

        // Current daily run-rate
        let dailyRate = dayOfMonth > 0 ? spent / Double(dayOfMonth) : 0
        let projectedFromPace = spent + dailyRate * Double(daysRemaining)

        // Historical average (last 3 months, same category)
        let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now) ?? now
        var monthlyTotals: [Date: Double] = [:]
        for tx in transactions
        where tx.date >= threeMonthsAgo && !tx.date.isSameMonth(as: now) {
            for (cat, amount) in tx.spendingPairs where cat == budget.category {
                let monthStart = tx.date.startOfMonth
                monthlyTotals[monthStart, default: 0] += amount
            }
        }

        let historicalValues = Array(monthlyTotals.values)
        let confidence: Double
        var finalProjection: Double

        if historicalValues.count >= 2 {
            let histAvg = historicalValues.reduce(0, +) / Double(historicalValues.count)
            // Weight: lean toward current pace more as the month progresses
            let weight = min(Double(dayOfMonth) / 20.0, 1.0)
            finalProjection = projectedFromPace * weight + histAvg * (1 - weight)
            confidence = min(0.85, Double(historicalValues.count) * 0.2 + 0.25)
        } else {
            finalProjection = projectedFromPace
            confidence = min(Double(dayOfMonth) / 30.0, 0.5)
        }

        // Include rollover in effective budget
        let effectiveBudget = budget.amount + budget.rolloverAmount

        return BudgetForecast(
            budgetID: budget.id,
            budgetName: budget.name,
            category: budget.category,
            spent: spent,
            budgetAmount: effectiveBudget,
            projectedEndOfMonth: finalProjection,
            confidence: confidence
        )
    }

    // MARK: Feature 8 — Multi-Threshold Budget Alerts

    func checkAndSendAlerts(budget: Budget, spent: Double, currency: String) {
        let effectiveBudget = budget.amount + budget.rolloverAmount
        guard effectiveBudget > 0 else { return }
        let progress = spent / effectiveBudget

        let thresholds: [Double] = [0.75, 0.90, 1.0]
        let currentMonth = Calendar.current.component(.month, from: Date())

        // Reset notified thresholds when the calendar month changes
        if budget.notifiedMonth != currentMonth {
            budget.notifiedThresholds = []
            budget.notifiedMonth = currentMonth
        }

        for threshold in thresholds {
            guard progress >= threshold,
                  !budget.notifiedThresholds.contains(threshold) else { continue }

            let pct = Int(threshold * 100)
            let content = UNMutableNotificationContent()
            content.title = threshold >= 1.0
                ? "Budget Exceeded — \(budget.name)"
                : "Budget Alert — \(budget.name)"
            content.body = threshold >= 1.0
                ? "You've exceeded your \(budget.name) budget by \(max(spent - effectiveBudget, 0).formatted(as: currency))."
                : "You've used \(pct)% of your \(budget.name) budget (\(spent.formatted(as: currency)) of \(effectiveBudget.formatted(as: currency)))."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let rid = "budget_\(budget.id.uuidString)_\(pct)"
            UNUserNotificationCenter.current()
                .add(UNNotificationRequest(identifier: rid, content: content, trigger: trigger))

            budget.notifiedThresholds.append(threshold)
        }
    }

    // MARK: Feature 5 — Rollover Processing

    func processRollovers(budgets: [Budget], transactions: [Transaction]) {
        let cal = Calendar.current
        let now = Date()
        guard let lastMonthStart = cal.date(byAdding: .month, value: -1, to: now.startOfMonth) else { return }

        for budget in budgets where budget.isRollover && budget.isActive && budget.period == .monthly {
            // Sum last month's spending for this budget's category
            var lastMonthSpent: Double = 0
            for tx in transactions where tx.date.isSameMonth(as: lastMonthStart) {
                for (cat, amount) in tx.spendingPairs where cat == budget.category {
                    lastMonthSpent += amount
                }
            }
            let unused = max(budget.amount - lastMonthSpent, 0)
            budget.rolloverAmount = unused
        }
    }

    // MARK: Feature 9 — AI Spending Recommendations

    func generateRecommendations(
        transactions: [Transaction],
        budgets: [Budget]
    ) -> [BudgetRecommendation] {
        var recs: [BudgetRecommendation] = []
        let now = Date()
        let cal = Calendar.current
        guard let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now) else { return [] }

        // Historical spending averages (last 3 months, excluding current)
        var monthlyByCategory: [TransactionCategory: [Double]] = [:]
        let historical = transactions.filter {
            $0.date >= threeMonthsAgo && !$0.date.isSameMonth(as: now)
        }
        let groupedByMonth = Dictionary(grouping: historical) { tx in
            cal.startOfDay(for: tx.date.startOfMonth)
        }
        for (_, monthTxs) in groupedByMonth {
            var monthCatTotals: [TransactionCategory: Double] = [:]
            for tx in monthTxs {
                for (cat, amount) in tx.spendingPairs {
                    monthCatTotals[cat, default: 0] += amount
                }
            }
            for (cat, total) in monthCatTotals {
                monthlyByCategory[cat, default: []].append(total)
            }
        }
        let avgByCategory: [TransactionCategory: Double] = monthlyByCategory.mapValues {
            $0.reduce(0, +) / Double($0.count)
        }

        // Current month spending
        var currentByCategory: [TransactionCategory: Double] = [:]
        for tx in transactions where tx.date.isSameMonth(as: now) {
            for (cat, amount) in tx.spendingPairs {
                currentByCategory[cat, default: 0] += amount
            }
        }

        let budgetedCategories = Set(budgets.filter { $0.isActive }.map { $0.category })
        let sampleCurrency = budgets.first?.currency ?? "AED"

        // Suggest creating a budget for frequently-spent unbudgeted categories
        let candidatesForNewBudget: [TransactionCategory] = [
            .food, .shopping, .transportation, .utilities, .entertainment, .medical,
            .subscriptions, .personalCare, .travel
        ]
        for cat in candidatesForNewBudget {
            guard !budgetedCategories.contains(cat),
                  let avg = avgByCategory[cat], avg > 100 else { continue }
            recs.append(BudgetRecommendation(
                type: .createBudget,
                title: "Track \(cat.rawValue)",
                description: "You average \(avg.formatted(as: sampleCurrency)) on \(cat.rawValue) per month. A budget could help you stay on track.",
                suggestedAmount: (avg * 1.1).rounded(),
                category: cat
            ))
        }

        // Recommend increasing budgets consistently over-spent
        for budget in budgets where budget.isActive {
            guard let avg = avgByCategory[budget.category] else { continue }
            if avg > budget.amount * 1.15 {
                let overPct = Int((avg / budget.amount - 1) * 100)
                recs.append(BudgetRecommendation(
                    type: .increaseBudget,
                    title: "Adjust \(budget.name)",
                    description: "Your 3-month average for \(budget.category.rawValue) is \(avg.formatted(as: sampleCurrency)) — \(overPct)% over your \(budget.amount.formatted(as: sampleCurrency)) budget.",
                    suggestedAmount: (avg * 1.05).rounded(),
                    category: budget.category
                ))
            } else if avg < budget.amount * 0.6 && avg > 10 {
                // Budget consistently under-spent — suggest decreasing
                let underPct = Int((avg / budget.amount) * 100)
                recs.append(BudgetRecommendation(
                    type: .decreaseBudget,
                    title: "Optimize \(budget.name)",
                    description: "You only spend \(underPct)% of your \(budget.name) budget on average. Reducing it frees up budget for other categories.",
                    suggestedAmount: (avg * 1.1).rounded(),
                    category: budget.category
                ))
            }
        }

        // Anomaly detection: current-month spike vs. historical average
        for (cat, current) in currentByCategory {
            guard let avg = avgByCategory[cat], avg > 50, current > avg * 1.5 else { continue }
            let spikePct = Int((current / avg - 1) * 100)
            recs.append(BudgetRecommendation(
                type: .anomaly,
                title: "Unusual \(cat.rawValue) Spending",
                description: "Your \(cat.rawValue) spending this month (\(current.formatted(as: sampleCurrency))) is \(spikePct)% above your 3-month average.",
                suggestedAmount: nil,
                category: cat
            ))
        }

        // Savings opportunity: total historical < total budgeted
        let totalBudgeted = budgets.filter { $0.isActive }.reduce(0) { $0 + $1.amount }
        let totalHistAvg = avgByCategory.values.reduce(0, +)
        if totalBudgeted > 0, totalHistAvg < totalBudgeted * 0.75 {
            let savingsPotential = totalBudgeted - totalHistAvg
            recs.append(BudgetRecommendation(
                type: .savings,
                title: "Savings Opportunity",
                description: "Based on 3-month averages, you could redirect \(savingsPotential.formatted(as: sampleCurrency)) per month to savings or investments.",
                suggestedAmount: savingsPotential,
                category: nil
            ))
        }

        return Array(recs.prefix(10))
    }

    // MARK: Feature 10 — Built-in Seasonal Templates

    func builtInTemplates() -> [BudgetTemplate] {
        [ramadanTemplate(), eidTemplate(), summerTemplate()]
    }

    private func ramadanTemplate() -> BudgetTemplate {
        BudgetTemplate(
            name: "Ramadan Budget",
            icon: "moon.stars.fill",
            colorHex: "#7C5BD0",
            description: "Optimized for Ramadan: higher food & charity spending, lower entertainment.",
            season: .ramadan,
            isBuiltIn: true,
            items: [
                TemplateItem(category: .food,          suggestedAmount: 2500,  notes: "Iftar & Suhoor, dates, special groceries"),
                TemplateItem(category: .charity,       suggestedAmount: 3000,  notes: "Zakat, Sadaqah & Ramadan donations"),
                TemplateItem(category: .gifts,         suggestedAmount: 1000,  notes: "Ramadan gifts & hampers"),
                TemplateItem(category: .shopping,      suggestedAmount: 1500,  notes: "Eid preparation shopping"),
                TemplateItem(category: .entertainment, suggestedAmount: 500,   notes: "Reduced entertainment during fasting"),
                TemplateItem(category: .utilities,     suggestedAmount: 800,   notes: "Higher electricity (late nights)"),
                TemplateItem(category: .personalCare,  suggestedAmount: 600,   notes: "Grooming & wellness"),
                TemplateItem(category: .other,         suggestedAmount: 500,   notes: "Miscellaneous"),
            ]
        )
    }

    private func eidTemplate() -> BudgetTemplate {
        BudgetTemplate(
            name: "Eid Budget",
            icon: "star.and.crescent.fill",
            colorHex: "#C8902B",
            description: "Covers Eid Al-Fitr or Eid Al-Adha: gifts, outings, new clothes & family gatherings.",
            season: .eid,
            isBuiltIn: true,
            items: [
                TemplateItem(category: .gifts,         suggestedAmount: 3000,  notes: "Eid gifts & Eidiyas for children"),
                TemplateItem(category: .shopping,      suggestedAmount: 2500,  notes: "New Eid clothes & accessories"),
                TemplateItem(category: .food,          suggestedAmount: 2000,  notes: "Family feasts & restaurant outings"),
                TemplateItem(category: .travel,        suggestedAmount: 4000,  notes: "Eid holidays & staycations"),
                TemplateItem(category: .entertainment, suggestedAmount: 1500,  notes: "Theme parks, cinemas, outings"),
                TemplateItem(category: .charity,       suggestedAmount: 1500,  notes: "Zakat Al-Fitr & additional charity"),
                TemplateItem(category: .personalCare,  suggestedAmount: 800,   notes: "Eid grooming & beauty"),
                TemplateItem(category: .other,         suggestedAmount: 700,   notes: "Miscellaneous Eid expenses"),
            ]
        )
    }

    private func summerTemplate() -> BudgetTemplate {
        BudgetTemplate(
            name: "Summer Holidays",
            icon: "sun.max.fill",
            colorHex: "#E5736B",
            description: "For UAE residents traveling or staycationing during the hot summer months.",
            season: .summer,
            isBuiltIn: true,
            items: [
                TemplateItem(category: .travel,        suggestedAmount: 8000,  notes: "Flights, hotels & holiday packages"),
                TemplateItem(category: .food,          suggestedAmount: 2000,  notes: "Dining out & vacation meals"),
                TemplateItem(category: .entertainment, suggestedAmount: 2500,  notes: "Theme parks, water parks & activities"),
                TemplateItem(category: .shopping,      suggestedAmount: 3000,  notes: "Vacation shopping & souvenirs"),
                TemplateItem(category: .education,     suggestedAmount: 1500,  notes: "Summer courses & camps for kids"),
                TemplateItem(category: .utilities,     suggestedAmount: 1200,  notes: "Higher A/C bills during peak summer"),
                TemplateItem(category: .medical,       suggestedAmount: 500,   notes: "Travel insurance & health supplies"),
                TemplateItem(category: .personalCare,  suggestedAmount: 600,   notes: "Suncare, travel essentials"),
            ]
        )
    }
}
