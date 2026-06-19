import Foundation
import NaturalLanguage

final class AICategorizationService {
    static let shared = AICategorizationService()
    private init() {}

    // Rule-based categorization with NLP patterns
    private let categoryKeywords: [TransactionCategory: [String]] = [
        .food: ["restaurant", "cafe", "coffee", "pizza", "burger", "lunch", "dinner", "breakfast",
                "food", "meal", "eat", "starbucks", "mcdonalds", "kfc", "subway", "deliveroo",
                "talabat", "noon food", "careem food", "grocery", "supermarket", "carrefour",
                "lulu", "waitrose", "spinneys", "choithrams", "baqala"],
        .shopping: ["mall", "shop", "store", "amazon", "noon", "namshi", "zara", "h&m",
                   "fashion", "clothes", "clothing", "shoes", "bag", "accessory", "jewelry",
                   "ikea", "home centre", "pottery barn", "ace hardware"],
        .transportation: ["taxi", "uber", "careem", "bus", "metro", "train", "rta", "parking",
                         "transport", "ride", "lyft", "bolt", "tram", "ferry"],
        .fuel: ["petrol", "fuel", "gas station", "enoc", "adnoc", "emarat", "shell", "total",
               "bp", "eppco", "filling station"],
        .utilities: ["dewa", "sewa", "fewa", "addc", "sharjah electricity", "water", "electric",
                    "internet", "du", "etisalat", "e&", "telecom", "phone bill", "utility"],
        .rent: ["rent", "rental", "lease", "landlord", "property"],
        .mortgage: ["mortgage", "home loan", "property loan"],
        .education: ["school", "university", "college", "course", "tuition", "education",
                    "training", "book", "library", "exam", "certification"],
        .medical: ["hospital", "clinic", "doctor", "pharmacy", "medicine", "health", "dental",
                  "dental", "optical", "lab", "medical", "pharmacy", "mediclinic", "aster", "nmc"],
        .entertainment: ["cinema", "movie", "netflix", "spotify", "disney", "hbo", "youtube",
                        "game", "gaming", "bowling", "arcade", "theme park", "concert", "tickets",
                        "vox", "reel cinemas", "novo", "playnation"],
        .travel: ["hotel", "flight", "airline", "booking", "airbnb", "expedia", "travel",
                 "holiday", "vacation", "tour", "airport", "emirates", "etihad", "flydubai",
                 "air arabia", "visa application"],
        .insurance: ["insurance", "takaful", "policy", "premium", "coverage", "oman insurance",
                    "axa", "allianz", "noor takaful", "union insurance"],
        .subscriptions: ["subscription", "monthly fee", "annual fee", "membership", "premium",
                        "adobe", "microsoft", "apple", "icloud", "linkedin", "gym", "fitness"],
        .salary: ["salary", "wages", "payroll", "monthly salary", "pay slip"],
        .bonus: ["bonus", "incentive", "reward", "commission", "performance"],
        .freelance: ["freelance", "project payment", "consulting fee", "invoice"],
        .rental: ["rental income", "rent received", "property income"],
        .investmentIncome: ["dividend", "return", "profit", "capital gain"],
    ]

    func suggestCategory(for title: String, amount: Double, type: TransactionType) -> TransactionCategory {
        let lowerTitle = title.lowercased()

        // Check keywords
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if lowerTitle.contains(keyword) {
                    return category
                }
            }
        }

        // Default by type
        return type == .income ? .other : .other
    }

    func detectRecurring(transactions: [Transaction]) -> [Transaction] {
        // Group transactions by similar title and amount
        let grouped = Dictionary(grouping: transactions) { tx in
            "\(tx.title.lowercased().prefix(10))_\(Int(tx.amount))"
        }

        return grouped.filter { $0.value.count >= 2 }.flatMap { $0.value }
    }

    func detectDuplicates(transactions: [Transaction]) -> [UUID] {
        var seen: [String: UUID] = [:]
        var duplicates: [UUID] = []

        for tx in transactions.sorted(by: { $0.date < $1.date }) {
            let key = "\(tx.title.lowercased())_\(tx.amount)_\(Calendar.current.startOfDay(for: tx.date))"
            if let existingId = seen[key] {
                duplicates.append(tx.id)
                _ = existingId
            } else {
                seen[key] = tx.id
            }
        }
        return duplicates
    }

    func generateInsights(
        transactions: [Transaction],
        previousMonthTransactions: [Transaction],
        baseCurrency: String
    ) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []

        // Compare monthly spending by category
        let currentExpenses = transactions.filter { $0.type == .expense }
        let previousExpenses = previousMonthTransactions.filter { $0.type == .expense }

        let currentByCategory = Dictionary(grouping: currentExpenses) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amountInBaseCurrency } }
        let previousByCategory = Dictionary(grouping: previousExpenses) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amountInBaseCurrency } }

        for (category, currentAmount) in currentByCategory {
            let previousAmount = previousByCategory[category] ?? 0
            if previousAmount > 0 {
                let change = ((currentAmount - previousAmount) / previousAmount) * 100
                if change > 15 {
                    insights.append(FinancialInsight(
                        type: .spendingIncrease,
                        title: "Spending Increase",
                        message: "You spent \(Int(change))% more on \(category.rawValue) this month compared to last month.",
                        category: category,
                        severity: change > 30 ? .high : .medium
                    ))
                } else if change < -15 {
                    insights.append(FinancialInsight(
                        type: .spendingDecrease,
                        title: "Good Job!",
                        message: "You spent \(Int(abs(change)))% less on \(category.rawValue) this month. Keep it up!",
                        category: category,
                        severity: .low
                    ))
                }
            }
        }

        // Savings rate insight
        let totalIncome = transactions.filter { $0.type == .income }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
        let totalExpenses = currentExpenses.reduce(0) { $0 + $1.amountInBaseCurrency }
        if totalIncome > 0 {
            let savingsRate = ((totalIncome - totalExpenses) / totalIncome) * 100
            if savingsRate < 10 {
                insights.append(FinancialInsight(
                    type: .lowSavings,
                    title: "Low Savings Rate",
                    message: "Your savings rate is \(Int(savingsRate))%. Financial experts recommend saving at least 20% of income.",
                    severity: .high
                ))
            } else if savingsRate >= 20 {
                insights.append(FinancialInsight(
                    type: .goodSavings,
                    title: "Excellent Savings!",
                    message: "Your savings rate is \(Int(savingsRate))%. You're on track with healthy financial habits.",
                    severity: .low
                ))
            }
        }

        return insights
    }

    func forecastNextMonth(transactions: [Transaction]) -> (income: Double, expenses: Double) {
        let calendar = Calendar.current
        let now = Date()
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now

        let recent = transactions.filter { $0.date >= threeMonthsAgo }
        let months = max(1.0, Double(calendar.dateComponents([.month], from: threeMonthsAgo, to: now).month ?? 1))

        let avgIncome = recent.filter { $0.type == .income }
            .reduce(0.0) { $0 + $1.amountInBaseCurrency } / months
        let avgExpenses = recent.filter { $0.type == .expense }
            .reduce(0.0) { $0 + $1.amountInBaseCurrency } / months

        return (avgIncome, avgExpenses)
    }
}

struct FinancialInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
    var category: TransactionCategory?
    let severity: InsightSeverity

    enum InsightType {
        case spendingIncrease, spendingDecrease, lowSavings, goodSavings,
             unusualSpending, duplicateDetected, recurringDetected, budgetWarning
    }

    enum InsightSeverity {
        case low, medium, high

        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "orange"
            case .high: return "red"
            }
        }

        var icon: String {
            switch self {
            case .low: return "checkmark.circle.fill"
            case .medium: return "exclamationmark.triangle.fill"
            case .high: return "exclamationmark.circle.fill"
            }
        }
    }
}
