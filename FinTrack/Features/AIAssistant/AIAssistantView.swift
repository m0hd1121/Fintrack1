import SwiftUI
import SwiftData

// MARK: - AI Hub (Main Landing)

struct AIAssistantView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var budgets: [Budget]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var loans: [Loan]
    @Query private var investments: [Investment]
    @Query private var bills: [Bill]

    @State private var showingChat = false
    @State private var healthScore: HealthScoreResult?
    @State private var anomalyCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    heroCard
                    quickStatsRow
                    featuresGrid
                    chatSection
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 32)
            }
            .navigationTitle("AI & Analytics")
            .background { FTBackdrop() }
            .onAppear { computeQuickStats() }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        HStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FTColor.heroGradient)
                    .frame(width: 64, height: 64)
                Image(systemName: "brain.head.profile")
                    .font(.ftTitle)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Financial Intelligence")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("On-device analytics. No data leaves your device.")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                if let score = healthScore {
                    HStack(spacing: 4) {
                        Circle().fill(score.gradeColor).frame(width: 8, height: 8)
                        Text("Health: \(score.grade) · \(score.score)/100")
                            .font(.ftCaption)
                            .foregroundStyle(score.gradeColor)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Quick Stats Row

    private var quickStatsRow: some View {
        let (monthlyIncome, monthlyExpenses) = AIAnalyticsService.shared.monthlyAverages(transactions: transactions)
        let savingsRate = monthlyIncome > 0 ? (monthlyIncome - monthlyExpenses) / monthlyIncome : 0
        return HStack(spacing: FTSpacing.sm) {
            quickStat(value: savingsRate.asPercentage(), label: "Savings Rate", color: savingsRate >= 0.2 ? FTColor.income : FTColor.gold)
            quickStat(value: "\(anomalyCount)", label: "Anomalies", color: anomalyCount > 0 ? FTColor.expense : FTColor.income)
            quickStat(value: "\(savingsGoals.filter { !$0.isCompleted }.count)", label: "Active Goals", color: FTColor.catBlue)
        }
    }

    private func quickStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.ftHeadline)
                .foregroundStyle(color)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Features Grid

    private var featuresGrid: some View {
        let features = AIFeature.allCases
        return VStack(spacing: FTSpacing.md) {
            Text("FEATURES")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.md) {
                ForEach(features) { feature in
                    NavigationLink(destination: feature.destination) {
                        featureCard(feature)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func featureCard(_ feature: AIFeature) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: FTRadius.sm)
                        .fill(feature.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: feature.icon)
                        .font(.ftCallout)
                        .foregroundStyle(feature.color)
                }
                Spacer()
                if feature == .anomalyDetection && anomalyCount > 0 {
                    Text("\(anomalyCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(FTColor.expense)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            Text(feature.title)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(feature.subtitle)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .ftGlassInteractive(FTRadius.lg)
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("AI CHAT ASSISTANT")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            Button {
                showingChat = true
            } label: {
                HStack(spacing: FTSpacing.md) {
                    ZStack {
                        Circle().fill(FTColor.heroGradient).frame(width: 44, height: 44)
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.ftCallout).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ask Me Anything")
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                        Text("\"Can I afford a new iPhone?\" · \"How much did I save this year?\"")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.ftHeadline)
                        .foregroundStyle(FTColor.accent)
                }
                .padding()
                .ftGlassInteractive(FTRadius.lg)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingChat) {
                FinancialChatView()
            }
        }
    }

    // MARK: - Compute

    private func computeQuickStats() {
        healthScore = AIAnalyticsService.shared.computeHealthScore(
            transactions: transactions, accounts: accounts, budgets: budgets,
            savingsGoals: savingsGoals, loans: loans, investments: investments,
            currency: appState.baseCurrency
        )
        anomalyCount = AIAnalyticsService.shared.detectAnomalies(
            transactions: transactions, currency: appState.baseCurrency
        ).filter { $0.severity == .high || $0.severity == .medium }.count
    }
}

// MARK: - AI Feature Enum

enum AIFeature: String, CaseIterable, Identifiable {
    case healthScore       = "Financial Health"
    case anomalyDetection  = "Anomaly Detection"
    case predictiveBalance = "30-Day Forecast"
    case spendingPatterns  = "Spending Patterns"
    case savingsOpportunity = "Savings Finder"
    case budgetingCoach    = "Budgeting Coach"
    case billNegotiation   = "Bill Negotiation"
    case esgAnalysis       = "ESG Analysis"
    case digitalTwin       = "Financial Twin"

    var id: String { rawValue }
    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .healthScore:        return "Score your overall finances"
        case .anomalyDetection:   return "Unusual spending alerts"
        case .predictiveBalance:  return "Balance forecast with chart"
        case .spendingPatterns:   return "Day, time & seasonal trends"
        case .savingsOpportunity: return "Where to cut expenses"
        case .budgetingCoach:     return "Weekly personalized advice"
        case .billNegotiation:    return "Scripts to lower bills"
        case .esgAnalysis:        return "Carbon footprint & impact"
        case .digitalTwin:        return "Simulate financial scenarios"
        }
    }

    var icon: String {
        switch self {
        case .healthScore:        return "heart.text.clipboard.fill"
        case .anomalyDetection:   return "exclamationmark.triangle.fill"
        case .predictiveBalance:  return "chart.line.uptrend.xyaxis"
        case .spendingPatterns:   return "calendar.day.timeline.left"
        case .savingsOpportunity: return "sparkles"
        case .budgetingCoach:     return "brain.head.profile"
        case .billNegotiation:    return "phone.badge.checkmark.fill"
        case .esgAnalysis:        return "leaf.fill"
        case .digitalTwin:        return "slider.horizontal.3"
        }
    }

    var color: Color {
        switch self {
        case .healthScore:        return FTColor.income
        case .anomalyDetection:   return FTColor.expense
        case .predictiveBalance:  return FTColor.accent
        case .spendingPatterns:   return FTColor.catBlue
        case .savingsOpportunity: return FTColor.gold
        case .budgetingCoach:     return FTColor.catPurple
        case .billNegotiation:    return FTColor.catTeal
        case .esgAnalysis:        return Color(hex: "#1B8B4B")
        case .digitalTwin:        return FTColor.catCoral
        }
    }

    var destination: AnyView {
        switch self {
        case .healthScore:        AnyView(FinancialHealthView())
        case .anomalyDetection:   AnyView(AnomalyDetectionView())
        case .predictiveBalance:  AnyView(PredictiveBalanceView())
        case .spendingPatterns:   AnyView(SpendingPatternsView())
        case .savingsOpportunity: AnyView(SavingsOpportunityView())
        case .budgetingCoach:     AnyView(BudgetingCoachView())
        case .billNegotiation:    AnyView(BillNegotiationView())
        case .esgAnalysis:        AnyView(ESGAnalysisView())
        case .digitalTwin:        AnyView(DigitalTwinView())
        }
    }
}

// MARK: - Financial Chat View (Enhanced NLP)

struct FinancialChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var loans: [Loan]

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isThinking = false

    init() {
        _messages = State(initialValue: [
            ChatMessage(role: .assistant, content: "Hi! I'm your AI financial assistant. Ask me anything about your spending, savings, budgets, or finances.\n\nTry: **\"Can I afford a new iPhone?\"** or **\"What's my savings rate?\"**")
        ])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message).id(message.id)
                            }
                            if isThinking { ThinkingBubble() }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                    }
                }

                if messages.count <= 1 { suggestionChips }

                HStack(spacing: 12) {
                    TextField("Ask about your finances…", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.ftBody)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .ftGlass(FTRadius.pill)
                        .lineLimit(1...4)

                    Button { sendMessage() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.ftAmount)
                            .foregroundStyle(inputText.isEmpty ? FTColor.textMuted : FTColor.accent)
                    }
                    .disabled(inputText.isEmpty || isThinking)
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { s in
                    Button { inputText = s; sendMessage() } label: {
                        Text(s).font(.ftCallout).foregroundStyle(FTColor.accent)
                            .padding(.horizontal, 14).padding(.vertical, 8).ftGlass(FTRadius.pill)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private let suggestions = [
        "How much did I spend this month?",
        "Can I afford a ₹5,000 purchase?",
        "What's my savings rate?",
        "Where am I overspending?",
        "Forecast next month's expenses",
    ]

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        isThinking = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            let response = generateResponse(for: text)
            messages.append(ChatMessage(role: .assistant, content: response))
            isThinking = false
        }
    }

    private func generateResponse(for query: String) -> String {
        let lower = query.lowercased()
        let now = Date()
        let currency = appState.baseCurrency
        let cal = Calendar.current

        let currentMonthTxs = transactions.filter { $0.date.isSameMonth(as: now) && !$0.isPending }
        let expenses = currentMonthTxs.filter { $0.type == .expense }
        let income = currentMonthTxs.filter { $0.type == .income }
        let totalExpenses = expenses.reduce(0.0) { $0 + $1.amountInBaseCurrency }
        let totalIncome = income.reduce(0.0) { $0 + $1.amountInBaseCurrency }
        let savingsRate = totalIncome > 0 ? (totalIncome - totalExpenses) / totalIncome : 0

        // "Can I afford X?" — extract amount
        let affordPattern = #/(?:can i afford|afford|buy|purchase)\s+(?:a\s+)?(?:[^0-9]*)?([0-9,]+(?:\.[0-9]+)?)\s*([A-Za-z]*)?/#
        if let match = query.firstMatch(of: affordPattern) {
            let amtStr = String(match.output.1).replacingOccurrences(of: ",", with: "")
            if let amount = Double(amtStr) {
                let liquidBalance = accounts.filter { !$0.isArchived && !$0.isHidden && $0.type != .creditCard }
                    .reduce(0.0) { $0 + $1.balance }
                let monthlySurplus = totalIncome - totalExpenses
                let monthsToSave = monthlySurplus > 0 ? Int(ceil(amount / monthlySurplus)) : -1

                if liquidBalance >= amount {
                    return "Based on your current balance of \(liquidBalance.formatted(as: currency)), you **can afford** \(amount.formatted(as: currency)) without impacting your monthly budget. However, consider whether it aligns with your savings goals."
                } else if monthlySurplus > 0 && monthsToSave <= 6 {
                    return "You can't cover \(amount.formatted(as: currency)) from liquid savings (\(liquidBalance.formatted(as: currency))), but with your \(monthlySurplus.formatted(as: currency))/mo surplus you can save up in **\(monthsToSave) month\(monthsToSave == 1 ? "" : "s")**."
                } else {
                    return "Your current balance (\(liquidBalance.formatted(as: currency))) and monthly surplus (\(monthlySurplus.formatted(as: currency))) make \(amount.formatted(as: currency)) a stretch right now. I'd suggest waiting or adjusting other expenses first."
                }
            }
        }

        // Monthly spending
        if (lower.contains("spend") && lower.contains("month")) || lower.contains("expenses this month") {
            let byCategory = Dictionary(grouping: expenses) { $0.category }
                .mapValues { $0.reduce(0.0) { $0 + $1.amountInBaseCurrency } }
                .sorted { $0.value > $1.value }.prefix(3)
            let catBreakdown = byCategory.map { "• \($0.key.rawValue): \($0.value.formatted(as: currency))" }.joined(separator: "\n")
            return "This month you've spent **\(totalExpenses.formatted(as: currency))**.\n\nTop categories:\n\(catBreakdown)"
        }

        // Savings rate
        if lower.contains("savings rate") || (lower.contains("saving") && !lower.contains("savings goal")) {
            let advice = savingsRate >= 0.20 ? "Excellent — you're above the recommended 20%." :
                        savingsRate >= 0.10 ? "Good — try to reach the 20% target." :
                        "Below the recommended 20%. Consider cutting discretionary spending."
            return "Your savings rate this month is **\(savingsRate.asPercentage())**. \(advice)"
        }

        // Overspending / biggest expenses
        if lower.contains("overspend") || lower.contains("biggest expense") || lower.contains("top expense") {
            let byCategory = Dictionary(grouping: expenses) { $0.category }
                .mapValues { $0.reduce(0.0) { $0 + $1.amountInBaseCurrency } }
                .sorted { $0.value > $1.value }.prefix(3)
            if byCategory.isEmpty { return "No expenses recorded this month yet." }
            let list = byCategory.map { "• \($0.key.rawValue): \($0.value.formatted(as: currency))" }.joined(separator: "\n")
            return "Your top spending categories this month:\n\n\(list)\n\nCheck the Savings Finder for specific reduction tips."
        }

        // Forecast / predict
        if lower.contains("forecast") || lower.contains("next month") || lower.contains("predict") {
            let (forecastIncome, forecastExpenses) = AICategorizationService.shared.forecastNextMonth(transactions: transactions)
            let net = forecastIncome - forecastExpenses
            return "Based on your 3-month average:\n\n• **Income**: \(forecastIncome.formatted(as: currency))\n• **Expenses**: \(forecastExpenses.formatted(as: currency))\n• **Net**: \(net.formatted(as: currency))\n\nSee the 30-Day Forecast for a day-by-day balance projection."
        }

        // Annual spending / income
        if lower.contains("year") || lower.contains("annual") || lower.contains("last year") {
            let yearStart = now.startOfYear
            let yearTxs = transactions.filter { $0.date >= yearStart && !$0.isPending }
            let yearIncome = yearTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amountInBaseCurrency }
            let yearExpenses = yearTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amountInBaseCurrency }
            return "Year-to-date (\(now.startOfYear.formatted) to now):\n\n• **Income**: \(yearIncome.formatted(as: currency))\n• **Expenses**: \(yearExpenses.formatted(as: currency))\n• **Savings**: \((yearIncome - yearExpenses).formatted(as: currency))"
        }

        // Income this month
        if lower.contains("income") && lower.contains("month") {
            return "Your income this month is **\(totalIncome.formatted(as: currency))**."
        }

        // Balance / net worth
        if lower.contains("balance") || lower.contains("net worth") {
            let total = accounts.filter { !$0.isArchived && !$0.isHidden }
                .reduce(0.0) { $0 + ($1.type.isLiability ? -$1.balance : $1.balance) }
            return "Your current net worth (accounts) is **\(total.formatted(as: currency))**. For a full breakdown including investments and loans, see the Net Worth section in Reports."
        }

        // Savings goals
        if lower.contains("goal") || lower.contains("target") {
            let active = savingsGoals.filter { !$0.isCompleted && !$0.isArchived }
            if active.isEmpty { return "You have no active savings goals. Add one in the Savings Goals section to start tracking progress." }
            let list = active.prefix(3).map { "• \($0.name): \($0.currentAmount.formatted(as: currency)) / \($0.targetAmount.formatted(as: currency)) (\($0.progress.asPercentage()))" }.joined(separator: "\n")
            return "Your active savings goals:\n\n\(list)"
        }

        // Debt
        if lower.contains("debt") || lower.contains("loan") {
            let activeLoans = loans.filter { $0.isActive }
            if activeLoans.isEmpty { return "You have no active loans recorded. 🎉" }
            let total = activeLoans.reduce(0.0) { $0 + $1.outstandingBalance }
            let list = activeLoans.prefix(3).map { "• \($0.name): \($0.outstandingBalance.formatted(as: currency))" }.joined(separator: "\n")
            return "Total outstanding debt: **\(total.formatted(as: currency))**\n\n\(list)\n\nSee the Financial Twin to simulate accelerated payoff."
        }

        // Health score
        if lower.contains("health") || lower.contains("score") || lower.contains("grade") {
            return "Go to **Financial Health** in the AI hub to see your detailed health score, grade, and personalized improvement tips."
        }

        // Anomalies
        if lower.contains("unusual") || lower.contains("anomal") || lower.contains("spike") {
            let anomalies = AIAnalyticsService.shared.detectAnomalies(transactions: transactions, currency: currency)
            if anomalies.isEmpty { return "No spending anomalies detected this month. Your spending looks normal!" }
            let high = anomalies.filter { $0.severity == .high }
            if high.isEmpty { return "Found \(anomalies.count) minor anomalies this month. Check **Anomaly Detection** for details." }
            return "⚠️ Found \(high.count) high-severity anomal\(high.count == 1 ? "y" : "ies"):\n\n• \(high.first!.title): \(high.first!.amount.formatted(as: currency))\n\nSee Anomaly Detection for the full list."
        }

        // Generic insight fallback
        let insights = AICategorizationService.shared.generateInsights(
            transactions: currentMonthTxs,
            previousMonthTransactions: transactions.filter {
                let lastMonth = cal.date(byAdding: .month, value: -1, to: now) ?? now
                return $0.date.isSameMonth(as: lastMonth)
            },
            baseCurrency: currency
        )
        if let first = insights.first {
            return first.message + "\n\nI can answer questions about:\n• Spending & income\n• Savings rate & goals\n• Balance & net worth\n• Forecasts & anomalies\n• Debt & affordability"
        }

        return "I can help you analyze your finances. Try asking:\n• \"How much did I spend on food this month?\"\n• \"Can I afford a \(currency) 2,000 purchase?\"\n• \"What is my savings rate?\"\n• \"Show me my savings goals\"\n• \"Any unusual spending this month?\""
    }
}

// MARK: - Chat Models & Views

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp = Date()
    enum ChatRole { case user, assistant }
}

struct ChatBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer() }
            if !isUser {
                ZStack {
                    Circle().fill(FTColor.heroGradient).frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile").font(.ftCaption).foregroundColor(.white)
                }
            }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubbleContent
                Text(message.timestamp.relativeFormatted)
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary).padding(.horizontal, 4)
            }
            if isUser {
                Circle().fill(FTColor.textMuted.opacity(0.4)).frame(width: 32, height: 32)
                    .overlay(Image(systemName: "person.fill").font(.ftCaption).foregroundColor(.white))
            }
            if !isUser { Spacer() }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let text = Text(LocalizedStringKey(message.content)).font(.ftBody).padding(.horizontal, 14).padding(.vertical, 10)
        if isUser {
            text.foregroundStyle(.white).background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.lg))
        } else {
            text.foregroundStyle(FTColor.textPrimary).ftGlass(FTRadius.lg)
        }
    }
}

struct ThinkingBubble: View {
    @State private var dotScale: [CGFloat] = [1, 1, 1]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(FTColor.heroGradient).frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile").font(.ftCaption).foregroundColor(.white)
            }
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(FTColor.textSecondary).frame(width: 8, height: 8).scaleEffect(dotScale[i])
                        .animation(Animation.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: dotScale[i])
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14).ftGlass(FTRadius.lg)
            Spacer()
        }
        .padding(.horizontal, 4)
        .onAppear {
            for i in 0..<3 {
                withAnimation(Animation.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15)) {
                    dotScale[i] = 1.5
                }
            }
        }
    }
}
