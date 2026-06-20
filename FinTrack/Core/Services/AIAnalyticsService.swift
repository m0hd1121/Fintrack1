import Foundation
import SwiftUI

// MARK: - Financial Health Score

struct HealthScoreResult {
    let score: Int
    let grade: String
    let components: [HealthComponent]
    let improvements: [String]

    struct HealthComponent: Identifiable {
        let id = UUID()
        let name: String
        let score: Int
        let weight: Double
        let icon: String
        let detail: String
        var color: Color {
            score >= 80 ? FTColor.income : score >= 55 ? FTColor.gold : FTColor.expense
        }
    }

    var gradeColor: Color {
        switch grade {
        case "A+", "A":  return FTColor.income
        case "B+", "B":  return FTColor.accentBright
        case "C+", "C":  return FTColor.gold
        default:          return FTColor.expense
        }
    }
}

// MARK: - Spending Anomaly

struct SpendingAnomaly: Identifiable {
    let id = UUID()
    let type: AnomalyType
    let title: String
    let description: String
    let amount: Double
    let date: Date
    let category: TransactionCategory?
    let severity: AnomalySeverity
    let transaction: Transaction?

    enum AnomalyType { case unusualMerchant, spendingSpike, categoryIncrease, largeTransaction }

    enum AnomalySeverity {
        case low, medium, high
        var color: Color {
            switch self { case .low: return FTColor.income; case .medium: return FTColor.gold; case .high: return FTColor.expense }
        }
        var icon: String {
            switch self { case .low: return "info.circle.fill"; case .medium: return "exclamationmark.triangle.fill"; case .high: return "exclamationmark.circle.fill" }
        }
        var sortOrder: Int { switch self { case .high: return 3; case .medium: return 2; case .low: return 1 } }
    }
}

// MARK: - Predictive Balance

struct BalanceForecastDay: Identifiable {
    let id = UUID()
    let date: Date
    let projectedBalance: Double
    let isConfident: Bool
}

struct RecurringForecastItem: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
    let dueDate: Date
    let isIncome: Bool
    let category: TransactionCategory
}

struct BalanceForecast {
    let currentBalance: Double
    let days: [BalanceForecastDay]
    let expectedExpenses: Double
    let expectedIncome: Double
    let lowestPoint: Double
    let lowestDate: Date
    let confidence: Double
    let recurringItems: [RecurringForecastItem]
}

// MARK: - Spending Patterns

struct SpendingPatternData {
    let byDayOfWeek: [Int: Double]
    let byHourOfDay: [Int: Double]
    let byMonth: [Int: Double]
    let peakDay: Int
    let peakHour: Int
    let peakMonth: Int
    let mostExpensiveCategory: TransactionCategory?
    let mostFrequentMerchant: String?
    let totalTransactions: Int
}

// MARK: - Savings Opportunity

struct SavingsOpportunity: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let potentialMonthly: Double
    let category: TransactionCategory?
    let priority: Priority
    let icon: String

    enum Priority: Int, Comparable {
        case low = 1, medium = 2, high = 3
        static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }
        var color: Color {
            switch self { case .low: return FTColor.income; case .medium: return FTColor.gold; case .high: return FTColor.expense }
        }
        var label: String { switch self { case .low: return "Low"; case .medium: return "Medium"; case .high: return "High" } }
    }
}

// MARK: - Budgeting Coach

struct CoachingInsight: Identifiable {
    let id = UUID()
    let weekLabel: String
    let headline: String
    let body: String
    let tips: [String]
    let icon: String
    let accentColor: Color
}

// MARK: - Bill Negotiation

struct BillNegotiationTip: Identifiable {
    let id = UUID()
    let title: String
    let merchantName: String
    let amount: Double
    let category: TransactionCategory
    let potentialSaving: Double
    let script: String
    let tips: [String]
    let icon: String
}

// MARK: - ESG

enum ESGRating: String {
    case veryGreen = "Very Green"
    case green     = "Green"
    case neutral   = "Neutral"
    case yellow    = "Yellow"
    case red       = "Red"

    var color: Color {
        switch self {
        case .veryGreen: return Color(hex: "#1B8B4B")
        case .green:     return FTColor.income
        case .neutral:   return FTColor.textSecondary
        case .yellow:    return FTColor.gold
        case .red:       return FTColor.expense
        }
    }
    var icon: String {
        switch self {
        case .veryGreen: return "leaf.fill"
        case .green:     return "leaf"
        case .neutral:   return "minus.circle"
        case .yellow:    return "exclamationmark.triangle"
        case .red:       return "xmark.circle.fill"
        }
    }
}

struct ESGResult {
    let overallScore: Int
    let carbonEstimateKg: Double
    let categoryBreakdown: [TransactionCategory: (ESGRating, Double)]
    let greenSpending: Double
    let highImpactSpending: Double
    let totalSpending: Double
    let insights: [String]
    let topGreenCategory: TransactionCategory?
    let topRedCategory: TransactionCategory?
}

// MARK: - Digital Twin

struct DigitalTwinScenario: Identifiable {
    var id = UUID()
    var name: String
    var description: String
    var monthlySalaryChange: Double
    var monthlyExpenseChange: Double
    var additionalSavingsRate: Double
    var investmentReturnRate: Double
    var projectionYears: Int
}

struct DigitalTwinProjection {
    let years: Int
    let monthlySnapshots: [MonthlySnapshot]
    let netWorthAtEnd: Double
    let totalSavings: Double
    let totalInvestmentGrowth: Double
    let debtFreeMonth: Int?

    struct MonthlySnapshot: Identifiable {
        let id = UUID()
        let month: Int
        let netWorth: Double
        let cumulativeSavings: Double
    }
}

// MARK: - AI Analytics Service

final class AIAnalyticsService {
    static let shared = AIAnalyticsService()
    private init() {}

    // MARK: - 1. Financial Health Score

    func computeHealthScore(
        transactions: [Transaction],
        accounts: [Account],
        budgets: [Budget],
        savingsGoals: [SavingsGoal],
        loans: [Loan],
        investments: [Investment],
        currency: String
    ) -> HealthScoreResult {
        let cal = Calendar.current
        let now = Date()
        let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now) ?? now
        let recent = transactions.filter { $0.date >= threeMonthsAgo && !$0.isPending }
        let months = max(1.0, Double(cal.dateComponents([.month], from: threeMonthsAgo, to: now).month ?? 3))

        let monthlyIncome = recent.filter { $0.type == .income }
            .reduce(0.0) { $0 + $1.amountInBaseCurrency } / months
        let monthlyExpenses = recent.filter { $0.type == .expense }
            .reduce(0.0) { $0 + $1.amountInBaseCurrency } / months
        let netMonthly = monthlyIncome - monthlyExpenses

        // Component 1: Savings Rate (30%)
        let savingsRate = monthlyIncome > 0 ? netMonthly / monthlyIncome : 0
        let savingsScore: Int
        switch savingsRate {
        case 0.30...: savingsScore = 100
        case 0.20..<0.30: savingsScore = 85
        case 0.10..<0.20: savingsScore = 65
        case 0.05..<0.10: savingsScore = 45
        case 0..<0.05:    savingsScore = 20
        default:           savingsScore = 0
        }

        // Component 2: Emergency Fund (25%)
        let liquidBalance = accounts
            .filter { !$0.isArchived && !$0.isHidden && [.current, .savings, .cash].contains($0.type) }
            .reduce(0.0) { $0 + $1.balance }
        let emergencyMonths = monthlyExpenses > 0 ? liquidBalance / monthlyExpenses : 0
        let emergencyScore: Int
        switch emergencyMonths {
        case 6...: emergencyScore = 100
        case 3..<6: emergencyScore = 75
        case 1..<3: emergencyScore = 45
        default:    emergencyScore = 10
        }

        // Component 3: Debt Load (25%)
        let totalDebt = loans.filter { $0.isActive }.reduce(0.0) { $0 + $1.outstandingBalance }
        let annualIncome = monthlyIncome * 12
        let debtRatio = annualIncome > 0 ? totalDebt / annualIncome : 0
        let debtScore: Int
        switch debtRatio {
        case 0: debtScore = 100
        case ..<0.5: debtScore = 85
        case 0.5..<1.0: debtScore = 65
        case 1.0..<2.0: debtScore = 40
        default: debtScore = 15
        }

        // Component 4: Investment Diversification (20%)
        let investCount = investments.count
        let investScore: Int
        switch investCount {
        case 5...: investScore = 100
        case 3..<5: investScore = 80
        case 1..<3: investScore = 55
        default:    investScore = 20
        }

        let finalScore = Int(
            Double(savingsScore) * 0.30 +
            Double(emergencyScore) * 0.25 +
            Double(debtScore) * 0.25 +
            Double(investScore) * 0.20
        )

        let grade: String
        switch finalScore {
        case 90...: grade = "A+"
        case 80..<90: grade = "A"
        case 70..<80: grade = "B+"
        case 60..<70: grade = "B"
        case 50..<60: grade = "C+"
        case 40..<50: grade = "C"
        case 30..<40: grade = "D"
        default: grade = "F"
        }

        var improvements: [String] = []
        if savingsScore < 65 {
            let target = (monthlyIncome * 0.20).formatted(as: currency)
            improvements.append("Increase savings to 20% of income — target \(target)/month")
        }
        if emergencyScore < 75 {
            let needed = max(0, monthlyExpenses * 3 - liquidBalance)
            improvements.append("Build emergency fund: \(needed.formatted(as: currency)) more for 3-month coverage")
        }
        if debtScore < 65 && totalDebt > 0 {
            improvements.append("Reduce debt — focus extra payments on highest-rate loans first")
        }
        if investScore < 55 {
            improvements.append("Diversify investments — add \(max(0, 3 - investCount)) more asset classes")
        }

        return HealthScoreResult(
            score: finalScore,
            grade: grade,
            components: [
                .init(name: "Savings Rate", score: savingsScore, weight: 0.30,
                      icon: "arrow.up.right.circle.fill",
                      detail: "\(savingsRate.asPercentage()) savings rate"),
                .init(name: "Emergency Fund", score: emergencyScore, weight: 0.25,
                      icon: "umbrella.fill",
                      detail: String(format: "%.1f months covered", emergencyMonths)),
                .init(name: "Debt Load", score: debtScore, weight: 0.25,
                      icon: "creditcard.fill",
                      detail: debtRatio == 0 ? "Debt-free" : String(format: "%.1fx annual income", debtRatio)),
                .init(name: "Investments", score: investScore, weight: 0.20,
                      icon: "chart.line.uptrend.xyaxis",
                      detail: "\(investCount) investment\(investCount == 1 ? "" : "s")"),
            ],
            improvements: improvements
        )
    }

    // MARK: - 2. Spending Anomaly Detection

    func detectAnomalies(transactions: [Transaction], currency: String) -> [SpendingAnomaly] {
        var anomalies: [SpendingAnomaly] = []
        let cal = Calendar.current
        let now = Date()
        let sixMonthsAgo = cal.date(byAdding: .month, value: -6, to: now) ?? now
        let currentMonthStart = now.startOfMonth

        let historical = transactions.filter {
            $0.date >= sixMonthsAgo && !$0.date.isSameMonth(as: now) && $0.type == .expense && !$0.isPending
        }
        let current = transactions.filter {
            $0.date >= currentMonthStart && $0.type == .expense && !$0.isPending
        }

        // Category spike via z-score
        var historicalMonthlyByCategory: [TransactionCategory: [Double]] = [:]
        let groupedByMonth = Dictionary(grouping: historical) { tx in
            cal.startOfDay(for: tx.date.startOfMonth)
        }
        for (_, monthTxs) in groupedByMonth {
            var monthCatTotals: [TransactionCategory: Double] = [:]
            for tx in monthTxs { monthCatTotals[tx.category, default: 0] += tx.amountInBaseCurrency }
            for (cat, total) in monthCatTotals { historicalMonthlyByCategory[cat, default: []].append(total) }
        }

        let currentByCategory = Dictionary(grouping: current) { $0.category }
            .mapValues { $0.reduce(0.0) { $0 + $1.amountInBaseCurrency } }

        for (cat, currentAmt) in currentByCategory {
            guard let hist = historicalMonthlyByCategory[cat], hist.count >= 2 else { continue }
            let mean = hist.reduce(0.0, +) / Double(hist.count)
            let variance = hist.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(hist.count)
            let stdDev = sqrt(variance)
            guard stdDev > 0 else { continue }
            let z = (currentAmt - mean) / stdDev
            guard z > 2.0 else { continue }
            let pct = Int((currentAmt / mean - 1) * 100)
            anomalies.append(SpendingAnomaly(
                type: .spendingSpike,
                title: "\(cat.rawValue) Spike",
                description: "Spent \(currentAmt.formatted(as: currency)) on \(cat.rawValue) — \(pct)% above your \(mean.formatted(as: currency)) average.",
                amount: currentAmt, date: now, category: cat,
                severity: z > 3.0 ? .high : .medium, transaction: nil
            ))
        }

        // Large individual transaction (>3x historical average)
        if !historical.isEmpty {
            let avgTx = historical.reduce(0.0) { $0 + $1.amountInBaseCurrency } / Double(historical.count)
            for tx in current where tx.amountInBaseCurrency > max(avgTx * 3, 500) {
                anomalies.append(SpendingAnomaly(
                    type: .largeTransaction,
                    title: "Large Transaction",
                    description: "\(tx.title) — \(tx.amountInBaseCurrency.formatted(as: currency)) is \(Int(tx.amountInBaseCurrency / avgTx))x your average.",
                    amount: tx.amountInBaseCurrency, date: tx.date, category: tx.category,
                    severity: tx.amountInBaseCurrency > avgTx * 5 ? .high : .medium, transaction: tx
                ))
            }
        }

        // New merchant with significant spend
        let historicalMerchants = Set(historical.compactMap { $0.merchant?.lowercased() })
        for tx in current {
            guard let merchant = tx.merchant, !merchant.isEmpty else { continue }
            if !historicalMerchants.contains(merchant.lowercased()) && tx.amountInBaseCurrency > 200 {
                anomalies.append(SpendingAnomaly(
                    type: .unusualMerchant,
                    title: "New Merchant",
                    description: "First-time spend at \(merchant) — \(tx.amountInBaseCurrency.formatted(as: currency)).",
                    amount: tx.amountInBaseCurrency, date: tx.date, category: tx.category,
                    severity: .low, transaction: tx
                ))
            }
        }

        return anomalies.sorted { $0.severity.sortOrder > $1.severity.sortOrder }.prefix(20).map { $0 }
    }

    // MARK: - 3. Predictive Balance

    func predictBalance(
        accounts: [Account],
        transactions: [Transaction],
        bills: [Bill]
    ) -> BalanceForecast {
        let cal = Calendar.current
        let now = Date()
        let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now) ?? now

        let currentBalance = accounts
            .filter { !$0.isArchived && !$0.isHidden && $0.type != .creditCard }
            .reduce(0.0) { $0 + $1.balance }

        let recentExpenses = transactions.filter {
            $0.type == .expense && $0.date >= threeMonthsAgo && !$0.isPending
        }
        let daysCovered = max(1.0, Double(cal.dateComponents([.day], from: threeMonthsAgo, to: now).day ?? 90))
        let avgDailySpend = recentExpenses.reduce(0.0) { $0 + $1.amountInBaseCurrency } / daysCovered

        // Build recurring forecast items from bills
        var recurringItems: [RecurringForecastItem] = []
        let thirtyDaysOut = cal.date(byAdding: .day, value: 30, to: now) ?? now
        for bill in bills where bill.isActive && bill.nextDueDate <= thirtyDaysOut {
            recurringItems.append(RecurringForecastItem(
                title: bill.name, amount: bill.monthlyEquivalent,
                dueDate: bill.nextDueDate, isIncome: false, category: .utilities
            ))
        }

        // Detect recurring from transaction history
        let recurringTxs = AICategorizationService.shared.detectRecurring(transactions: transactions)
        let groups = Dictionary(grouping: recurringTxs) {
            "\(String($0.title.lowercased().prefix(8)))_\(Int($0.amount))"
        }.filter { $0.value.count >= 2 }
        for (_, group) in groups {
            guard let latest = group.max(by: { $0.date < $1.date }) else { continue }
            if let nextDate = cal.date(byAdding: .month, value: 1, to: latest.date),
               nextDate <= thirtyDaysOut {
                recurringItems.append(RecurringForecastItem(
                    title: latest.title, amount: latest.amountInBaseCurrency,
                    dueDate: nextDate, isIncome: latest.type == .income, category: latest.category
                ))
            }
        }

        var balance = currentBalance
        var forecastDays: [BalanceForecastDay] = []
        var totalExpenses = 0.0
        var totalIncome = 0.0
        var lowestBalance = currentBalance
        var lowestDate = now

        for offset in 1...30 {
            guard let date = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            balance -= avgDailySpend
            totalExpenses += avgDailySpend
            for item in recurringItems where cal.isDate(item.dueDate, inSameDayAs: date) {
                if item.isIncome { balance += item.amount; totalIncome += item.amount }
                else { balance -= item.amount; totalExpenses += item.amount }
            }
            if balance < lowestBalance { lowestBalance = balance; lowestDate = date }
            forecastDays.append(BalanceForecastDay(date: date, projectedBalance: balance, isConfident: offset <= 15))
        }

        return BalanceForecast(
            currentBalance: currentBalance, days: forecastDays,
            expectedExpenses: totalExpenses, expectedIncome: totalIncome,
            lowestPoint: lowestBalance, lowestDate: lowestDate,
            confidence: 0.75, recurringItems: Array(recurringItems.prefix(10))
        )
    }

    // MARK: - 4 / 7. Spending Patterns

    func computeSpendingPatterns(transactions: [Transaction]) -> SpendingPatternData {
        let cal = Calendar.current
        let expenses = transactions.filter { $0.type == .expense && !$0.isPending }
        var byDay: [Int: Double] = [:]
        var byHour: [Int: Double] = [:]
        var byMonth: [Int: Double] = [:]

        for tx in expenses {
            let comps = cal.dateComponents([.weekday, .hour, .month], from: tx.date)
            byDay[comps.weekday ?? 1, default: 0]  += tx.amountInBaseCurrency
            byHour[comps.hour ?? 0, default: 0]    += tx.amountInBaseCurrency
            byMonth[comps.month ?? 1, default: 0]  += tx.amountInBaseCurrency
        }

        let byCat = Dictionary(grouping: expenses) { $0.category }
            .mapValues { $0.reduce(0.0) { $0 + $1.amountInBaseCurrency } }
        let topCat = byCat.max(by: { $0.value < $1.value })?.key

        let merchantGroups = Dictionary(grouping: expenses.compactMap { $0.merchant }, by: { $0 })
        let topMerchant = merchantGroups.max(by: { $0.value.count < $1.value.count })?.key

        return SpendingPatternData(
            byDayOfWeek: byDay, byHourOfDay: byHour, byMonth: byMonth,
            peakDay: byDay.max(by: { $0.value < $1.value })?.key ?? 7,
            peakHour: byHour.max(by: { $0.value < $1.value })?.key ?? 12,
            peakMonth: byMonth.max(by: { $0.value < $1.value })?.key ?? 1,
            mostExpensiveCategory: topCat, mostFrequentMerchant: topMerchant,
            totalTransactions: expenses.count
        )
    }

    // MARK: - 5. Savings Opportunities

    func findSavingsOpportunities(
        transactions: [Transaction],
        bills: [Bill],
        currency: String
    ) -> [SavingsOpportunity] {
        var opportunities: [SavingsOpportunity] = []
        let cal = Calendar.current
        let now = Date()
        let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now) ?? now
        let recent = transactions.filter { $0.type == .expense && $0.date >= threeMonthsAgo && !$0.isPending }
        let months = max(1.0, Double(cal.dateComponents([.month], from: threeMonthsAgo, to: now).month ?? 3))

        let avgByCategory = Dictionary(grouping: recent) { $0.category }
            .mapValues { $0.reduce(0.0) { $0 + $1.amountInBaseCurrency } / months }

        if let sub = avgByCategory[.subscriptions], sub > 100 {
            opportunities.append(SavingsOpportunity(
                title: "Subscription Audit",
                description: "You spend \(sub.formatted(as: currency))/mo on subscriptions. Canceling 2-3 unused ones could save 20-30%.",
                potentialMonthly: sub * 0.25, category: .subscriptions, priority: .high, icon: "repeat.circle.fill"
            ))
        }
        if let food = avgByCategory[.food], food > 500 {
            opportunities.append(SavingsOpportunity(
                title: "Meal Planning",
                description: "Cooking at home 2-3 more days/week could cut your \(food.formatted(as: currency))/mo food spending by ~15%.",
                potentialMonthly: food * 0.15, category: .food,
                priority: food > 2000 ? .high : .medium, icon: "fork.knife.circle.fill"
            ))
        }
        if let ent = avgByCategory[.entertainment], ent > 300 {
            opportunities.append(SavingsOpportunity(
                title: "Entertainment Bundles",
                description: "Bundling streaming services could reduce your \(ent.formatted(as: currency))/mo entertainment spend by 20%.",
                potentialMonthly: ent * 0.20, category: .entertainment, priority: .medium, icon: "tv.circle.fill"
            ))
        }
        let fuelTransport = (avgByCategory[.fuel] ?? 0) + (avgByCategory[.transportation] ?? 0)
        if fuelTransport > 400 {
            opportunities.append(SavingsOpportunity(
                title: "Transport Optimization",
                description: "Carpooling or RTA metro for 30% of trips could cut \(fuelTransport.formatted(as: currency))/mo transport costs.",
                potentialMonthly: fuelTransport * 0.20, category: .fuel, priority: .medium, icon: "car.circle.fill"
            ))
        }
        if let util = avgByCategory[.utilities], util > 600 {
            opportunities.append(SavingsOpportunity(
                title: "Utility Savings",
                description: "Smart A/C scheduling & LED lighting could cut your \(util.formatted(as: currency))/mo utility bill by 12%.",
                potentialMonthly: util * 0.12, category: .utilities, priority: .low, icon: "bolt.circle.fill"
            ))
        }
        if let shop = avgByCategory[.shopping], shop > 1000 {
            opportunities.append(SavingsOpportunity(
                title: "48-Hour Rule",
                description: "A 48-hour wait before non-essential purchases could reduce your \(shop.formatted(as: currency))/mo shopping by 15%.",
                potentialMonthly: shop * 0.15, category: .shopping,
                priority: shop > 3000 ? .high : .medium, icon: "bag.circle.fill"
            ))
        }
        if let ins = avgByCategory[.insurance], ins > 300 {
            opportunities.append(SavingsOpportunity(
                title: "Insurance Review",
                description: "Bundling policies or comparing quotes on Yallacompare.ae could save 10-15% on \(ins.formatted(as: currency))/mo.",
                potentialMonthly: ins * 0.12, category: .insurance, priority: .low, icon: "shield.lefthalf.filled"
            ))
        }

        return opportunities.sorted { $0.priority > $1.priority }
    }

    // MARK: - 6. Budgeting Coach

    func generateCoachingInsights(
        transactions: [Transaction],
        savingsGoals: [SavingsGoal],
        currency: String
    ) -> [CoachingInsight] {
        let now = Date()
        let cal = Calendar.current
        let weekNumber = cal.component(.weekOfYear, from: now)
        let currentMonthTxs = transactions.filter { $0.date.isSameMonth(as: now) && !$0.isPending }
        let expenses = currentMonthTxs.filter { $0.type == .expense }
        let income = currentMonthTxs.filter { $0.type == .income }
        let totalIncome = income.reduce(0.0) { $0 + $1.amountInBaseCurrency }
        let totalExpenses = expenses.reduce(0.0) { $0 + $1.amountInBaseCurrency }
        let savingsRate = totalIncome > 0 ? (totalIncome - totalExpenses) / totalIncome : 0

        var insights: [CoachingInsight] = []
        switch weekNumber % 4 {
        case 0:
            insights.append(CoachingInsight(
                weekLabel: "Week \(weekNumber)", headline: "Monthly Checkup",
                body: "You've spent \(totalExpenses.formatted(as: currency)) this month with a \(savingsRate.asPercentage()) savings rate. "
                      + (savingsRate >= 0.20 ? "Excellent discipline — keep it up!" : "Small cuts in discretionary spending add up fast."),
                tips: ["Review your biggest category this month", "Set a concrete savings target", "Check for unused subscriptions"],
                icon: "calendar.badge.checkmark", accentColor: FTColor.accent
            ))
        case 1:
            let topCat = Dictionary(grouping: expenses) { $0.category }
                .mapValues { $0.reduce(0.0) { $0 + $1.amountInBaseCurrency } }
                .max(by: { $0.value < $1.value })
            insights.append(CoachingInsight(
                weekLabel: "Week \(weekNumber)", headline: "Spending Deep Dive",
                body: topCat.map {
                    "Your biggest category is \($0.key.rawValue) at \($0.value.formatted(as: currency)). Is this aligned with your priorities?"
                } ?? "Log every purchase this week — awareness is the foundation of better spending.",
                tips: ["Log cash transactions immediately", "Ask 'Need vs. Want?' before each purchase", "Group similar expenses to spot patterns"],
                icon: "magnifyingglass.circle.fill", accentColor: FTColor.catBlue
            ))
        case 2:
            let activeGoals = savingsGoals.filter { !$0.isCompleted && !$0.isArchived }
            insights.append(CoachingInsight(
                weekLabel: "Week \(weekNumber)", headline: "Goal Progress",
                body: activeGoals.isEmpty
                    ? "You have no active savings goals. Setting one increases savings rates by up to 40%."
                    : "You have \(activeGoals.count) active goal\(activeGoals.count == 1 ? "" : "s"). Focus on your top priority this week.",
                tips: ["Automate savings on payday — pay yourself first", "Even small amounts compound significantly", "Review goal deadlines & adjust contributions"],
                icon: "target", accentColor: FTColor.catTeal
            ))
        default:
            insights.append(CoachingInsight(
                weekLabel: "Week \(weekNumber)", headline: "10% Challenge",
                body: "Challenge: spend 10% less this week than last. Small reductions build lasting habits.",
                tips: ["Batch grocery shopping to avoid impulse buys", "Unsubscribe from retailer emails", "Use the 30-day list for non-essential purchases"],
                icon: "brain.head.profile", accentColor: FTColor.catPurple
            ))
        }
        return insights
    }

    // MARK: - 7. Bill Negotiation Tips

    func generateBillNegotiationTips(
        transactions: [Transaction],
        bills: [Bill],
        currency: String
    ) -> [BillNegotiationTip] {
        var tips: [BillNegotiationTip] = []
        let cal = Calendar.current
        let now = Date()
        let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now) ?? now
        let recent = transactions.filter { $0.type == .expense && $0.date >= threeMonthsAgo && !$0.isPending }
        let months = max(1.0, Double(cal.dateComponents([.month], from: threeMonthsAgo, to: now).month ?? 3))

        let telecomTxs = recent.filter {
            let t = "\($0.title.lowercased()) \(($0.merchant ?? "").lowercased())"
            return t.contains("etisalat") || t.contains("du ") || t.contains("e&") || t.contains("telecom")
        }
        let telecomMonthly = telecomTxs.reduce(0.0) { $0 + $1.amountInBaseCurrency } / months
        if telecomMonthly > 150 {
            tips.append(BillNegotiationTip(
                title: "Telecom Bill", merchantName: telecomTxs.first?.merchant ?? "Telecom Provider",
                amount: telecomMonthly, category: .utilities, potentialSaving: telecomMonthly * 0.20,
                script: "Hi, I've been a loyal customer for [X years]. I'm currently paying \(Int(telecomMonthly)) AED/month and I've seen better competitor rates. Can you review my plan and offer a loyalty discount, or I'll need to consider switching?",
                tips: ["Call at month-end when retention agents have quotas", "Mention competitor (Du vs Etisalat) specific plans", "Ask about loyalty discounts — rarely advertised", "Request a full plan review — you may be on an outdated tier"],
                icon: "phone.fill"
            ))
        }

        let insuranceTxs = recent.filter { $0.category == .insurance }
        let insuranceMonthly = insuranceTxs.reduce(0.0) { $0 + $1.amountInBaseCurrency } / months
        if insuranceMonthly > 250 {
            tips.append(BillNegotiationTip(
                title: "Insurance Premium", merchantName: insuranceTxs.first?.merchant ?? "Insurance Provider",
                amount: insuranceMonthly, category: .insurance, potentialSaving: insuranceMonthly * 0.15,
                script: "I'd like to review my policy. I've maintained a clean record and I'm comparing quotes. What loyalty discount or plan adjustment can you offer to keep my business?",
                tips: ["Bundle home & auto for multi-policy discount", "Compare quotes on Yallacompare.com or PolicyBazaar.ae", "Increase deductible to lower monthly premium", "Ask specifically for the retention department"],
                icon: "shield.fill"
            ))
        }

        let gymTxs = recent.filter {
            let t = "\($0.title.lowercased()) \(($0.merchant ?? "").lowercased())"
            return (t.contains("gym") || t.contains("fitness") || t.contains("flex")) && $0.category == .subscriptions
        }
        let gymMonthly = gymTxs.reduce(0.0) { $0 + $1.amountInBaseCurrency } / months
        if gymMonthly > 150 {
            tips.append(BillNegotiationTip(
                title: "Gym Membership", merchantName: gymTxs.first?.merchant ?? "Gym",
                amount: gymMonthly, category: .subscriptions, potentialSaving: gymMonthly * 0.25,
                script: "I've been a member for [X months]. I'd like to discuss my membership fee — I'm evaluating renewal. Do you offer annual prepay discounts or corporate rates?",
                tips: ["Annual prepay gives 2-3 months free", "Corporate rates via your employer may apply", "Off-peak membership can cut costs 30-40%", "Ask about a 'pause' option instead of canceling"],
                icon: "figure.run.circle.fill"
            ))
        }

        for bill in bills.filter({ $0.amount > 400 && $0.isActive }).prefix(2) {
            if !tips.contains(where: { $0.merchantName.lowercased().contains(bill.name.lowercased()) }) {
                tips.append(BillNegotiationTip(
                    title: "Review \(bill.name)", merchantName: bill.name,
                    amount: bill.monthlyEquivalent, category: .utilities, potentialSaving: bill.amount * 0.10,
                    script: "I've been a customer for a while and I'm reviewing my expenses. Are there any promotions, loyalty rates, or plan adjustments to reduce my monthly cost?",
                    tips: ["Research competitor pricing beforehand", "Ask for the 'retention department' specifically", "Be polite but firm — mention you're comparing alternatives", "Get any offer confirmed via email"],
                    icon: "text.badge.checkmark"
                ))
            }
        }

        return tips
    }

    // MARK: - 8. ESG Analysis

    func analyzeESG(transactions: [Transaction], currency: String) -> ESGResult {
        let expenses = transactions.filter { $0.type == .expense && !$0.isPending }

        let esgMap: [TransactionCategory: ESGRating] = [
            .food: .neutral, .shopping: .yellow, .transportation: .yellow, .fuel: .red,
            .utilities: .neutral, .rent: .neutral, .mortgage: .neutral, .education: .veryGreen,
            .medical: .green, .entertainment: .neutral, .travel: .red, .insurance: .neutral,
            .investments: .green, .subscriptions: .neutral, .gifts: .neutral,
            .personalCare: .neutral, .childcare: .veryGreen, .pets: .green,
            .charity: .veryGreen, .bankFees: .neutral, .interestExpense: .neutral,
        ]
        let carbonFactor: [TransactionCategory: Double] = [
            .fuel: 0.25, .travel: 0.15, .shopping: 0.05, .food: 0.04,
            .transportation: 0.08, .utilities: 0.06,
        ]

        var categoryBreakdown: [TransactionCategory: (ESGRating, Double)] = [:]
        var greenSpending = 0.0
        var highImpactSpending = 0.0
        var totalCarbonKg = 0.0

        let byCategory = Dictionary(grouping: expenses) { $0.category }
            .mapValues { $0.reduce(0.0) { $0 + $1.amountInBaseCurrency } }

        for (cat, amount) in byCategory {
            let rating = esgMap[cat] ?? .neutral
            categoryBreakdown[cat] = (rating, amount)
            if rating == .veryGreen || rating == .green { greenSpending += amount }
            if rating == .red { highImpactSpending += amount }
            totalCarbonKg += amount * (carbonFactor[cat] ?? 0.01)
        }

        let total = byCategory.values.reduce(0.0, +)
        let greenRatio = total > 0 ? greenSpending / total : 0
        let redRatio = total > 0 ? highImpactSpending / total : 0
        let score = max(0, min(100, Int(greenRatio * 60 + (1 - redRatio) * 40)))

        var insights: [String] = []
        if (byCategory[.fuel] ?? 0) > 500 { insights.append("High fuel spend drives your carbon footprint. Consider carpooling or an EV.") }
        if (byCategory[.travel] ?? 0) > 2000 { insights.append("Air travel is high-impact. Consider carbon offsets or train travel when possible.") }
        if (byCategory[.charity] ?? 0) > 0 { insights.append("Your charitable giving creates positive social impact.") }
        if (byCategory[.education] ?? 0) > 0 { insights.append("Education spending generates long-term positive social returns.") }
        if greenRatio > 0.3 { insights.append("Over 30% of your spending goes to socially positive categories — well done!") }
        if insights.isEmpty { insights.append("Review your high-impact categories (fuel & travel) to improve your ESG score.") }

        return ESGResult(
            overallScore: score, carbonEstimateKg: totalCarbonKg,
            categoryBreakdown: categoryBreakdown,
            greenSpending: greenSpending, highImpactSpending: highImpactSpending,
            totalSpending: total, insights: insights,
            topGreenCategory: categoryBreakdown.filter { $0.value.0 == .veryGreen || $0.value.0 == .green }.max(by: { $0.value.1 < $1.value.1 })?.key,
            topRedCategory: categoryBreakdown.filter { $0.value.0 == .red }.max(by: { $0.value.1 < $1.value.1 })?.key
        )
    }

    // MARK: - 9. Digital Twin Simulation

    func runDigitalTwin(
        scenario: DigitalTwinScenario,
        currentNetWorth: Double,
        monthlyIncome: Double,
        monthlyExpenses: Double,
        totalDebt: Double
    ) -> DigitalTwinProjection {
        let adjustedIncome = monthlyIncome + scenario.monthlySalaryChange
        let adjustedExpenses = monthlyExpenses + scenario.monthlyExpenseChange
        let monthlySavings = max(adjustedIncome - adjustedExpenses, 0)
            + adjustedIncome * scenario.additionalSavingsRate
        let monthlyReturn = scenario.investmentReturnRate / 12.0 / 100.0

        var netWorth = currentNetWorth
        var debt = totalDebt
        var cumulativeSavings = 0.0
        var snapshots: [DigitalTwinProjection.MonthlySnapshot] = []
        var debtFreeMonth: Int? = nil
        let totalMonths = scenario.projectionYears * 12

        for month in 1...totalMonths {
            netWorth += monthlySavings
            if monthlyReturn > 0 { netWorth *= (1 + monthlyReturn) }
            cumulativeSavings += monthlySavings
            if debt > 0 {
                let payment = min(debt, max(monthlySavings * 0.3, 50))
                debt -= payment
                netWorth -= payment
                if debt <= 0 && debtFreeMonth == nil { debtFreeMonth = month }
            }
            snapshots.append(.init(month: month, netWorth: max(netWorth - max(debt, 0), currentNetWorth * 0.5), cumulativeSavings: cumulativeSavings))
        }

        let growthAboveSavings = max((snapshots.last?.netWorth ?? currentNetWorth) - currentNetWorth - cumulativeSavings, 0)

        return DigitalTwinProjection(
            years: scenario.projectionYears,
            monthlySnapshots: snapshots,
            netWorthAtEnd: snapshots.last?.netWorth ?? currentNetWorth,
            totalSavings: cumulativeSavings,
            totalInvestmentGrowth: growthAboveSavings,
            debtFreeMonth: debtFreeMonth
        )
    }

    // MARK: - Helpers

    func monthlyAverages(transactions: [Transaction], monthsBack: Int = 3) -> (income: Double, expenses: Double) {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .month, value: -monthsBack, to: now) ?? now
        let recent = transactions.filter { $0.date >= start && !$0.isPending }
        let months = max(1.0, Double(monthsBack))
        let income = recent.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amountInBaseCurrency } / months
        let expenses = recent.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amountInBaseCurrency } / months
        return (income, expenses)
    }
}
