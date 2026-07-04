import Foundation

// MARK: - FinancialIntelligenceService
// Deterministic, on-device financial analysis engine: health score, spending
// patterns, predictions, and auto-generated insights. Every number is computed
// from the user's actual records — nothing is invented — which also makes it
// the grounded data source handed to the AI CFO chat.

// MARK: Result types

struct HealthScoreComponent: Identifiable {
    let id = UUID()
    let name: String
    let score: Double       // 0...100
    let weight: Double      // contribution weight
    let explanation: String
}

struct FinancialHealthScore {
    let overall: Int        // 0...100
    let components: [HealthScoreComponent]
    let grade: String       // A / B / C / D

    static func grade(for score: Int) -> String {
        switch score {
        case 80...: return "A"
        case 65..<80: return "B"
        case 45..<65: return "C"
        default: return "D"
        }
    }
}

struct IntelligenceInsight: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let colorName: String   // for Color.fromString
    let impactScore: Double // ranking weight — higher = more financially important
}

struct IntelligencePrediction: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let confidence: Int     // 0...100 %
    let icon: String
}

enum SpendNecessity: String {
    case essential = "Essential"
    case optional = "Optional"
    case luxury = "Luxury"

    static func classify(_ category: TransactionCategory) -> SpendNecessity {
        switch category {
        case .rent, .mortgage, .utilities, .medical, .insurance, .education,
             .fuel, .transportation, .loanRepayment, .bankFees:
            return .essential
        case .food, .subscriptions, .creditCard:
            return .optional
        case .shopping, .entertainment, .travel, .gifts:
            return .luxury
        default:
            return .optional
        }
    }
}

// MARK: - Service

final class FinancialIntelligenceService {
    static let shared = FinancialIntelligenceService()
    private init() {}

    // MARK: Shared aggregation helpers

    private func monthlyExpenses(_ transactions: [Transaction], monthsBack: Int) -> Double {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -monthsBack, to: Date().startOfMonth),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return 0 }
        return transactions
            .filter { $0.type == .expense && !$0.isPending && $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    private func monthlyIncome(_ transactions: [Transaction], monthsBack: Int) -> Double {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -monthsBack, to: Date().startOfMonth),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return 0 }
        return transactions
            .filter { $0.type == .income && !$0.isPending && $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    private func categorySpend(_ transactions: [Transaction], monthsBack: Int) -> [TransactionCategory: Double] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -monthsBack, to: Date().startOfMonth),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return [:] }
        let expenses = transactions.filter {
            $0.type == .expense && !$0.isPending && $0.date >= start && $0.date < end
        }
        return Dictionary(grouping: expenses) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amountInBaseCurrency } }
    }

    // MARK: - Financial Health Score

    func healthScore(
        transactions: [Transaction],
        accounts: [Account],
        budgets: [Budget],
        goals: [SavingsGoal],
        loans: [Loan]
    ) -> FinancialHealthScore {
        var components: [HealthScoreComponent] = []

        let income = monthlyIncome(transactions, monthsBack: 1) + monthlyIncome(transactions, monthsBack: 2)
        let expenses = monthlyExpenses(transactions, monthsBack: 1) + monthlyExpenses(transactions, monthsBack: 2)

        // 1. Savings rate (weight 25)
        let savingsRate = income > 0 ? max(0, (income - expenses) / income) : 0
        let savingsScore = min(100, savingsRate / 0.25 * 100)   // 25%+ savings = full marks
        components.append(HealthScoreComponent(
            name: "Savings Rate", score: savingsScore, weight: 25,
            explanation: income > 0
                ? "You saved \(Int(savingsRate * 100))% of income over the last two full months (20%+ is healthy)."
                : "No income recorded recently — savings rate can't be measured."))

        // 2. Cash flow (weight 20)
        let netFlow = income - expenses
        let flowScore: Double = income > 0 ? (netFlow > 0 ? min(100, 60 + netFlow / income * 160) : max(0, 50 + netFlow / max(income, 1) * 100)) : 30
        components.append(HealthScoreComponent(
            name: "Cash Flow", score: flowScore, weight: 20,
            explanation: netFlow >= 0
                ? "Income exceeded spending by \(netFlow.asCompact(currency: "AED")) over two months."
                : "Spending exceeded income by \((-netFlow).asCompact(currency: "AED")) over two months."))

        // 3. Emergency fund / liquidity (weight 20): months of expenses covered by liquid balances
        let liquid = accounts.filter { !$0.isArchived }.reduce(0.0) {
            $0 + CurrencyService.shared.convert($1.balance, from: $1.currency, to: "AED")
        }
        let avgMonthlyExpense = max(1, expenses / 2)
        let runway = liquid / avgMonthlyExpense
        let runwayScore = min(100, runway / 6 * 100)   // 6 months = full marks
        components.append(HealthScoreComponent(
            name: "Emergency Fund", score: runwayScore, weight: 20,
            explanation: String(format: "Liquid balances cover %.1f months of average spending (6 months is the target).", runway)))

        // 4. Budget discipline (weight 15)
        let currentSpend = categorySpend(transactions, monthsBack: 0)
        let activeBudgets = budgets.filter { $0.isActive }
        if activeBudgets.isEmpty {
            components.append(HealthScoreComponent(
                name: "Budget Discipline", score: 40, weight: 15,
                explanation: "No active budgets — creating category budgets makes overspending visible early."))
        } else {
            let overCount = activeBudgets.filter { budget in
                let spent = currentSpend[budget.category] ?? 0
                return spent > CurrencyService.shared.convert(budget.amount, from: budget.currency, to: "AED")
            }.count
            let ratio = 1 - Double(overCount) / Double(activeBudgets.count)
            components.append(HealthScoreComponent(
                name: "Budget Discipline", score: ratio * 100, weight: 15,
                explanation: overCount == 0
                    ? "All \(activeBudgets.count) budgets are within limits this month."
                    : "\(overCount) of \(activeBudgets.count) budgets exceeded this month."))
        }

        // 5. Debt pressure (weight 10): loan EMIs vs income
        let monthlyDebt = loans.filter { $0.isActive }.reduce(0.0) {
            $0 + CurrencyService.shared.convert($1.emiAmount, from: $1.currency, to: "AED")
        }
        let avgMonthlyIncome = max(1, income / 2)
        let debtRatio = monthlyDebt / avgMonthlyIncome
        let debtScore = debtRatio <= 0 ? 100 : max(0, 100 - debtRatio / 0.36 * 100 * 0.7)  // 36% DTI reference
        components.append(HealthScoreComponent(
            name: "Debt Load", score: min(100, debtScore), weight: 10,
            explanation: monthlyDebt <= 0
                ? "No active loan payments."
                : "Loan payments take \(Int(debtRatio * 100))% of monthly income (under 36% is considered safe)."))

        // 6. Goal progress (weight 10)
        let activeGoals = goals.filter { !$0.isCompleted }
        if activeGoals.isEmpty {
            components.append(HealthScoreComponent(
                name: "Goals", score: 50, weight: 10,
                explanation: "No active savings goals — a concrete target makes saving automatic."))
        } else {
            let progress = activeGoals.reduce(0.0) {
                $0 + min(1, $1.targetAmount > 0 ? $1.currentAmount / $1.targetAmount : 0)
            } / Double(activeGoals.count)
            components.append(HealthScoreComponent(
                name: "Goals", score: progress * 100, weight: 10,
                explanation: "Average progress across \(activeGoals.count) active goals is \(Int(progress * 100))%."))
        }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let overall = Int((components.reduce(0) { $0 + $1.score * $1.weight } / totalWeight).rounded())
        return FinancialHealthScore(overall: overall, components: components,
                                    grade: FinancialHealthScore.grade(for: overall))
    }

    // MARK: - Automatic insights (ranked by financial impact)

    func insights(
        transactions: [Transaction],
        budgets: [Budget],
        baseCurrency: String
    ) -> [IntelligenceInsight] {
        var results: [IntelligenceInsight] = []
        let thisMonth = categorySpend(transactions, monthsBack: 0)
        let lastMonth = categorySpend(transactions, monthsBack: 1)

        // Category month-over-month swings
        for (category, current) in thisMonth {
            let previous = lastMonth[category] ?? 0
            guard previous > 100 else { continue }
            let change = (current - previous) / previous * 100
            if change > 20 {
                results.append(IntelligenceInsight(
                    title: "\(category.rawValue) up \(Int(change))%",
                    message: "You've spent \(current.asCompact(currency: baseCurrency)) on \(category.rawValue) this month vs \(previous.asCompact(currency: baseCurrency)) last month.",
                    icon: "arrow.up.right.circle.fill", colorName: "red",
                    impactScore: current - previous))
            } else if change < -20 {
                results.append(IntelligenceInsight(
                    title: "\(category.rawValue) down \(Int(-change))%",
                    message: "Nice work — \(category.rawValue) spending dropped from \(previous.asCompact(currency: baseCurrency)) to \(current.asCompact(currency: baseCurrency)).",
                    icon: "arrow.down.right.circle.fill", colorName: "green",
                    impactScore: (previous - current) * 0.6))
            }
        }

        // Hidden recurring charges: same merchant, similar amount, in 3 consecutive months
        let cal = Calendar.current
        let recent = transactions.filter {
            $0.type == .expense && $0.date > (cal.date(byAdding: .month, value: -3, to: Date()) ?? Date())
        }
        let byMerchant = Dictionary(grouping: recent) {
            ImportLearningService.merchantKey($0.merchant ?? $0.title)
        }
        for (_, txs) in byMerchant where txs.count >= 3 {
            let amounts = txs.map(\.amountInBaseCurrency)
            guard let sample = amounts.first, sample > 10 else { continue }
            let similar = amounts.allSatisfy { abs($0 - sample) < sample * 0.15 }
            let months = Set(txs.map { cal.component(.month, from: $0.date) })
            if similar && months.count >= 3 {
                let name = txs[0].merchant ?? txs[0].title
                let annual = sample * 12
                results.append(IntelligenceInsight(
                    title: "Recurring charge: \(name)",
                    message: "\(name) charges about \(sample.asCompact(currency: baseCurrency)) monthly — roughly \(annual.asCompact(currency: baseCurrency)) per year. Still using it?",
                    icon: "repeat.circle.fill", colorName: "orange",
                    impactScore: annual * 0.3))
            }
        }

        // Small frequent purchases annualized (the "coffee math")
        let smallFrequent = recent.filter { $0.amountInBaseCurrency > 5 && $0.amountInBaseCurrency < 80 }
        let smallByMerchant = Dictionary(grouping: smallFrequent) {
            ImportLearningService.merchantKey($0.merchant ?? $0.title)
        }
        if let (_, txs) = smallByMerchant.max(by: { $0.value.count < $1.value.count }), txs.count >= 8 {
            let total = txs.reduce(0) { $0 + $1.amountInBaseCurrency }
            let annualized = total * 4  // 3 months → year
            let name = txs[0].merchant ?? txs[0].title
            results.append(IntelligenceInsight(
                title: "\(txs.count) visits to \(name)",
                message: "Small purchases at \(name) add up to about \(annualized.asCompact(currency: baseCurrency)) per year at this pace.",
                icon: "cup.and.saucer.fill", colorName: "teal",
                impactScore: annualized * 0.25))
        }

        // Budget overrun early warning
        let dayOfMonth = cal.component(.day, from: Date())
        let daysInMonth = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        for budget in budgets.filter({ $0.isActive }) {
            let limit = CurrencyService.shared.convert(budget.amount, from: budget.currency, to: baseCurrency)
            guard limit > 0, dayOfMonth >= 5 else { continue }
            let spent = thisMonth[budget.category] ?? 0
            let projected = spent / Double(dayOfMonth) * Double(daysInMonth)
            if spent < limit && projected > limit {
                let daysToBreach = Int(Double(dayOfMonth) * limit / max(spent, 1)) - dayOfMonth
                results.append(IntelligenceInsight(
                    title: "\(budget.category.rawValue) budget at risk",
                    message: "At the current pace you'll exceed the \(limit.asCompact(currency: baseCurrency)) budget in about \(max(1, daysToBreach)) days.",
                    icon: "exclamationmark.triangle.fill", colorName: "orange",
                    impactScore: projected - limit + 500))
            }
        }

        // Weekend and night spending behavior
        let monthExpenses = transactions.filter {
            $0.type == .expense && !$0.isPending && $0.date >= Date().startOfMonth
        }
        let total = monthExpenses.reduce(0) { $0 + $1.amountInBaseCurrency }
        if total > 500 {
            let weekend = monthExpenses.filter { cal.isDateInWeekend($0.date) }
                .reduce(0) { $0 + $1.amountInBaseCurrency }
            if weekend / total > 0.5 {
                results.append(IntelligenceInsight(
                    title: "Weekend-heavy spending",
                    message: "\(Int(weekend / total * 100))% of this month's spending happened on weekends (\(weekend.asCompact(currency: baseCurrency))).",
                    icon: "calendar.badge.exclamationmark", colorName: "purple",
                    impactScore: weekend * 0.1))
            }
        }

        // Savings rate trend
        let incomeNow = monthlyIncome(transactions, monthsBack: 1)
        let incomePrev = monthlyIncome(transactions, monthsBack: 2)
        let expenseNow = monthlyExpenses(transactions, monthsBack: 1)
        let expensePrev = monthlyExpenses(transactions, monthsBack: 2)
        if incomeNow > 0 && incomePrev > 0 {
            let rateNow = (incomeNow - expenseNow) / incomeNow
            let ratePrev = (incomePrev - expensePrev) / incomePrev
            let delta = (rateNow - ratePrev) * 100
            if abs(delta) >= 5 {
                results.append(IntelligenceInsight(
                    title: delta > 0 ? "Savings rate up \(Int(delta))pp" : "Savings rate down \(Int(-delta))pp",
                    message: "Last full month you saved \(Int(rateNow * 100))% of income, vs \(Int(ratePrev * 100))% the month before.",
                    icon: delta > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                    colorName: delta > 0 ? "green" : "red",
                    impactScore: abs(delta) * 100))
            }
        }

        return results.sorted { $0.impactScore > $1.impactScore }
    }

    // MARK: - Predictions

    func predictions(
        transactions: [Transaction],
        accounts: [Account],
        bills: [Bill],
        baseCurrency: String
    ) -> [IntelligencePrediction] {
        var results: [IntelligencePrediction] = []
        let cal = Calendar.current

        // 3-month averages with variance-based confidence
        let expenseHistory = (1...3).map { monthlyExpenses(transactions, monthsBack: $0) }
        let incomeHistory = (1...3).map { monthlyIncome(transactions, monthsBack: $0) }

        func meanAndConfidence(_ values: [Double]) -> (Double, Int) {
            let nonZero = values.filter { $0 > 0 }
            guard !nonZero.isEmpty else { return (0, 0) }
            let mean = nonZero.reduce(0, +) / Double(nonZero.count)
            let variance = nonZero.reduce(0) { $0 + pow($1 - mean, 2) } / Double(nonZero.count)
            let cv = mean > 0 ? sqrt(variance) / mean : 1
            let confidence = Int(max(30, min(95, 95 - cv * 100)))
            return (mean, confidence)
        }

        let (expExp, expConf) = meanAndConfidence(expenseHistory)
        if expExp > 0 {
            results.append(IntelligencePrediction(
                label: "Next month's expenses",
                value: expExp.asCompact(currency: baseCurrency),
                confidence: expConf, icon: "arrow.up.forward.circle"))
        }
        let (expInc, incConf) = meanAndConfidence(incomeHistory)
        if expInc > 0 {
            results.append(IntelligencePrediction(
                label: "Expected income",
                value: expInc.asCompact(currency: baseCurrency),
                confidence: incConf, icon: "arrow.down.backward.circle"))
        }

        // Projected end-of-month balance
        let liquid = accounts.filter { !$0.isArchived }.reduce(0.0) {
            $0 + CurrencyService.shared.convert($1.balance, from: $1.currency, to: baseCurrency)
        }
        let day = cal.component(.day, from: Date())
        let daysInMonth = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        let spentSoFar = transactions
            .filter { $0.type == .expense && !$0.isPending && $0.date >= Date().startOfMonth }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
        if day >= 3, spentSoFar > 0 {
            let remainingSpend = spentSoFar / Double(day) * Double(daysInMonth - day)
            results.append(IntelligencePrediction(
                label: "Projected end-of-month balance",
                value: (liquid - remainingSpend).asCompact(currency: baseCurrency),
                confidence: max(35, 90 - (daysInMonth - day) * 2),
                icon: "calendar.circle"))
        }

        // Upcoming bills in the next 30 days
        let upcoming = bills.filter {
            $0.isActive && $0.nextDueDate > Date()
                && $0.nextDueDate < (cal.date(byAdding: .day, value: 30, to: Date()) ?? Date())
        }
        if !upcoming.isEmpty {
            let totalDue = upcoming.reduce(0.0) {
                $0 + CurrencyService.shared.convert($1.amount, from: $1.currency, to: baseCurrency)
            }
            results.append(IntelligencePrediction(
                label: "Bills due in 30 days (\(upcoming.count))",
                value: totalDue.asCompact(currency: baseCurrency),
                confidence: 98, icon: "doc.text.circle"))
        }

        // Projected yearly savings
        if expInc > 0 && expExp > 0 {
            results.append(IntelligencePrediction(
                label: "Projected yearly savings",
                value: ((expInc - expExp) * 12).asCompact(currency: baseCurrency),
                confidence: min(expConf, incConf), icon: "banknote"))
        }

        return results
    }

    // MARK: - Compact context for the AI CFO (grounded numbers, no raw records)

    func buildAIContext(
        transactions: [Transaction],
        accounts: [Account],
        budgets: [Budget],
        goals: [SavingsGoal],
        loans: [Loan],
        bills: [Bill],
        baseCurrency: String
    ) -> String {
        var lines: [String] = []
        let score = healthScore(transactions: transactions, accounts: accounts,
                                budgets: budgets, goals: goals, loans: loans)
        lines.append("FINANCIAL SNAPSHOT (all amounts in \(baseCurrency), computed by the app's deterministic engine — treat as ground truth):")
        lines.append("Health score: \(score.overall)/100 (\(score.grade))")
        for component in score.components {
            lines.append("- \(component.name): \(Int(component.score))/100 — \(component.explanation)")
        }

        let liquid = accounts.filter { !$0.isArchived }.reduce(0.0) {
            $0 + CurrencyService.shared.convert($1.balance, from: $1.currency, to: baseCurrency)
        }
        lines.append("Liquid balance across \(accounts.filter { !$0.isArchived }.count) accounts: \(String(format: "%.0f", liquid))")

        for monthsBack in 0...2 {
            let income = monthlyIncome(transactions, monthsBack: monthsBack)
            let expense = monthlyExpenses(transactions, monthsBack: monthsBack)
            let label = monthsBack == 0 ? "This month (partial)" : "\(monthsBack) month(s) ago"
            lines.append("\(label): income \(String(format: "%.0f", income)), expenses \(String(format: "%.0f", expense))")
        }

        let byCat = categorySpend(transactions, monthsBack: 0).sorted { $0.value > $1.value }.prefix(8)
        lines.append("Top categories this month: " + byCat.map { "\($0.key.rawValue) \(String(format: "%.0f", $0.value))" }.joined(separator: ", "))

        let activeBudgets = budgets.filter { $0.isActive }
        if !activeBudgets.isEmpty {
            let spend = categorySpend(transactions, monthsBack: 0)
            lines.append("Budgets: " + activeBudgets.prefix(8).map {
                "\($0.category.rawValue) \(String(format: "%.0f", spend[$0.category] ?? 0))/\(String(format: "%.0f", $0.amount))"
            }.joined(separator: ", "))
        }

        let activeGoals = goals.filter { !$0.isCompleted }
        if !activeGoals.isEmpty {
            lines.append("Goals: " + activeGoals.prefix(6).map {
                "\($0.name) \(String(format: "%.0f", $0.currentAmount))/\(String(format: "%.0f", $0.targetAmount))"
            }.joined(separator: ", "))
        }

        let activeLoans = loans.filter { $0.isActive }
        if !activeLoans.isEmpty {
            lines.append("Active loans: \(activeLoans.count), total monthly EMI \(String(format: "%.0f", activeLoans.reduce(0.0) { $0 + CurrencyService.shared.convert($1.emiAmount, from: $1.currency, to: baseCurrency) }))")
        }

        let topInsights = insights(transactions: transactions, budgets: budgets, baseCurrency: baseCurrency).prefix(6)
        if !topInsights.isEmpty {
            lines.append("Engine-detected insights:")
            for insight in topInsights { lines.append("- \(insight.title): \(insight.message)") }
        }

        let preds = predictions(transactions: transactions, accounts: accounts, bills: bills, baseCurrency: baseCurrency)
        if !preds.isEmpty {
            lines.append("Predictions:")
            for pred in preds { lines.append("- \(pred.label): \(pred.value) (confidence \(pred.confidence)%)") }
        }

        return lines.joined(separator: "\n")
    }
}
