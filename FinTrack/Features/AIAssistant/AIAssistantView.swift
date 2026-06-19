import SwiftUI
import SwiftData

struct AIAssistantView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isThinking = false

    init() {
        let welcomeMessage = ChatMessage(
            role: .assistant,
            content: "Hello! I'm your AI financial assistant. I can analyze your spending, forecast your finances, and provide personalized insights. Ask me anything!"
        )
        _messages = State(initialValue: [welcomeMessage])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            if isThinking {
                                ThinkingBubble()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }

                // Suggestions
                if messages.count <= 1 {
                    suggestionChips
                }

                // Input
                HStack(spacing: 12) {
                    TextField("Ask about your finances...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.ftBody)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .ftGlass(FTRadius.pill)
                        .lineLimit(1...4)

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.ftAmount)
                            .foregroundStyle(inputText.isEmpty ? FTColor.textMuted : FTColor.accent)
                    }
                    .disabled(inputText.isEmpty || isThinking)
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .background { FTBackdrop() }
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        inputText = suggestion
                        sendMessage()
                    } label: {
                        Text(suggestion)
                            .font(.ftCallout)
                            .foregroundStyle(FTColor.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .ftGlass(FTRadius.pill)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private let suggestions = [
        "How much did I spend this month?",
        "What's my savings rate?",
        "Where am I overspending?",
        "Forecast next month's expenses",
        "What are my biggest expenses?",
    ]

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        isThinking = true

        Task {
            try? await Task.sleep(for: .seconds(1))
            // generateResponse reads SwiftData @Query models, which are not
            // Sendable — keep the computation on the MainActor.
            let response = generateResponse(for: text)
            messages.append(ChatMessage(role: .assistant, content: response))
            isThinking = false
        }
    }

    private func generateResponse(for query: String) -> String {
        let lower = query.lowercased()
        let now = Date()
        let currentMonthTxs = transactions.filter { $0.date.isSameMonth(as: now) }
        let expenses = currentMonthTxs.filter { $0.type == .expense }
        let income = currentMonthTxs.filter { $0.type == .income }

        let totalExpenses = expenses.reduce(0) { $0 + $1.amountInBaseCurrency }
        let totalIncome = income.reduce(0) { $0 + $1.amountInBaseCurrency }
        let savingsRate = totalIncome > 0 ? ((totalIncome - totalExpenses) / totalIncome) * 100 : 0
        let currency = appState.baseCurrency

        if lower.contains("spend") && lower.contains("month") || lower.contains("expenses") {
            return "This month you've spent **\(totalExpenses.formatted(as: currency))**. " +
                   (totalExpenses > totalIncome ? "⚠️ This exceeds your income of \(totalIncome.formatted(as: currency))." :
                   "That's \(Int(totalExpenses/max(totalIncome, 1)*100))% of your \(totalIncome.formatted(as: currency)) income.")
        }

        if lower.contains("savings rate") || lower.contains("saving") {
            let advice = savingsRate >= 20 ? "Excellent! You're above the recommended 20% savings rate." :
                        savingsRate >= 10 ? "Good progress! Try to reach the 20% savings target." :
                        "Your savings rate needs improvement. Consider reducing discretionary spending."
            return "Your savings rate this month is **\(savingsRate.asPercentage())**. \(advice)"
        }

        if lower.contains("biggest expense") || lower.contains("top expense") || lower.contains("overspend") {
            let byCategory = Dictionary(grouping: expenses) { $0.category }
                .map { ($0.key, $0.value.reduce(0) { $0 + $1.amountInBaseCurrency }) }
                .sorted { $0.1 > $1.1 }
                .prefix(3)
            if byCategory.isEmpty { return "No expenses recorded this month yet." }
            let list = byCategory.map { "• \($0.0.rawValue): \($0.1.formatted(as: currency))" }.joined(separator: "\n")
            return "Your top spending categories this month:\n\n\(list)"
        }

        if lower.contains("forecast") || lower.contains("next month") || lower.contains("predict") {
            let (forecastIncome, forecastExpenses) = AICategorizationService.shared.forecastNextMonth(transactions: transactions)
            return "Based on your 3-month average, I forecast:\n\n• Income: **\(forecastIncome.formatted(as: currency))**\n• Expenses: **\(forecastExpenses.formatted(as: currency))**\n• Net: **\((forecastIncome - forecastExpenses).formatted(as: currency))**"
        }

        if lower.contains("income") {
            return "Your total income this month is **\(totalIncome.formatted(as: currency))**."
        }

        if lower.contains("balance") || lower.contains("net worth") {
            return "For a detailed net worth breakdown, check the Reports tab → Net Worth section. I can see your current month has \(totalIncome.formatted(as: currency)) income and \(totalExpenses.formatted(as: currency)) in expenses."
        }

        // Generic helpful response
        let insights = AICategorizationService.shared.generateInsights(
            transactions: currentMonthTxs,
            previousMonthTransactions: transactions.filter {
                let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
                return $0.date.isSameMonth(as: lastMonth)
            },
            baseCurrency: currency
        )

        if let insight = insights.first {
            return insight.message + "\n\nYou can ask me about your spending, savings rate, biggest expenses, or financial forecasts."
        }

        return "I can help you analyze:\n• Monthly spending by category\n• Your savings rate\n• Biggest expense areas\n• Financial forecasts\n• Income trends\n\nWhat would you like to know?"
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp = Date()

    enum ChatRole {
        case user, assistant
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer() }

            if !isUser {
                ZStack {
                    Circle()
                        .fill(FTColor.heroGradient)
                        .frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile")
                        .font(.ftCaption)
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubbleContent

                Text(message.timestamp.relativeFormatted)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
                    .padding(.horizontal, 4)
            }

            if isUser {
                Circle()
                    .fill(FTColor.textMuted.opacity(0.4))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.ftCaption)
                            .foregroundColor(.white)
                    )
            }

            if !isUser { Spacer() }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let text = Text(LocalizedStringKey(message.content))
            .font(.ftBody)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

        if isUser {
            text
                .foregroundStyle(.white)
                .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.lg))
        } else {
            text
                .foregroundStyle(FTColor.textPrimary)
                .ftGlass(FTRadius.lg)
        }
    }
}

struct ThinkingBubble: View {
    @State private var dotScale: [CGFloat] = [1, 1, 1]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(FTColor.heroGradient)
                    .frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile")
                    .font(.ftCaption)
                    .foregroundColor(.white)
            }

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(FTColor.textSecondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotScale[i])
                        .animation(
                            Animation.easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: dotScale[i]
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .ftGlass(FTRadius.lg)

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
