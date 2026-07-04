import SwiftUI
import SwiftData

// MARK: - AICFOView
// The Financial Intelligence hub: deterministic health score, insights and
// predictions computed on-device, plus the AI CFO chat grounded in those
// numbers via the Claude API.

struct AICFOView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var budgets: [Budget]
    @Query private var goals: [SavingsGoal]
    @Query private var loans: [Loan]
    @Query private var bills: [Bill]

    @State private var selectedTab = 0
    @State private var score: FinancialHealthScore? = nil
    @State private var insightList: [IntelligenceInsight] = []
    @State private var predictionList: [IntelligencePrediction] = []

    private var baseCurrency: String { appState.baseCurrency }

    var body: some View {
        VStack(spacing: 0) {
            FTSegmentedControl(options: ["Intelligence", "Ask Your CFO"], selection: $selectedTab)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.vertical, FTSpacing.sm)

            if selectedTab == 0 {
                intelligenceTab
            } else {
                CFOChatView(financialContext: buildContext())
            }
        }
        .navigationTitle("AI CFO")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .onAppear(perform: recompute)
    }

    private func recompute() {
        let engine = FinancialIntelligenceService.shared
        score = engine.healthScore(transactions: Array(transactions), accounts: Array(accounts),
                                   budgets: Array(budgets), goals: Array(goals), loans: Array(loans))
        insightList = engine.insights(transactions: Array(transactions), budgets: Array(budgets),
                                      baseCurrency: baseCurrency)
        predictionList = engine.predictions(transactions: Array(transactions), accounts: Array(accounts),
                                            bills: Array(bills), baseCurrency: baseCurrency)
    }

    private func buildContext() -> String {
        FinancialIntelligenceService.shared.buildAIContext(
            transactions: Array(transactions), accounts: Array(accounts),
            budgets: Array(budgets), goals: Array(goals),
            loans: Array(loans), bills: Array(bills),
            baseCurrency: baseCurrency)
    }

    // MARK: - Intelligence tab

    private var intelligenceTab: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                if let score {
                    healthScoreCard(score)
                }

                if !predictionList.isEmpty {
                    VStack(spacing: FTSpacing.md) {
                        Text("PREDICTIONS")
                            .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.sm) {
                            ForEach(predictionList) { prediction in
                                VStack(alignment: .leading, spacing: 6) {
                                    Image(systemName: prediction.icon)
                                        .font(.ftCallout).foregroundStyle(FTColor.accent)
                                    Text(prediction.value)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                    Text(prediction.label)
                                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                        .lineLimit(2)
                                    Text("Confidence \(prediction.confidence)%")
                                        .font(.ftLabel).tracking(0.4).foregroundStyle(FTColor.textMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(FTSpacing.md)
                                .ftGlass(FTRadius.md)
                            }
                        }
                    }
                }

                VStack(spacing: FTSpacing.md) {
                    Text("INSIGHTS")
                        .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if insightList.isEmpty {
                        EmptyStateView(
                            icon: "sparkles",
                            title: "Not Enough Data Yet",
                            message: "Insights appear once a couple of months of transactions are recorded.")
                    } else {
                        ForEach(insightList.prefix(12)) { insight in
                            HStack(alignment: .top, spacing: FTSpacing.md) {
                                FTIconTile(symbol: insight.icon,
                                           tint: Color.fromString(insight.colorName), size: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(insight.title)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text(insight.message)
                                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(FTSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .ftGlass(FTRadius.md)
                        }
                    }
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .refreshable { recompute() }
    }

    private func healthScoreCard(_ score: FinancialHealthScore) -> some View {
        VStack(spacing: FTSpacing.lg) {
            HStack(alignment: .center, spacing: FTSpacing.xl) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(score.overall) / 100)
                        .stroke(scoreColor(score.overall), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(score.overall)")
                            .font(.ftAmount).foregroundStyle(.white)
                        Text(score.grade)
                            .font(.ftCaption).foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("FINANCIAL HEALTH")
                        .font(.ftLabel).tracking(1.6).foregroundStyle(.white.opacity(0.8))
                    ForEach(score.components.prefix(3)) { component in
                        HStack(spacing: FTSpacing.xs) {
                            Text(component.name)
                                .font(.ftCaption).foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("\(Int(component.score))")
                                .font(.ftCaption).bold()
                                .foregroundStyle(scoreColor(Int(component.score)))
                        }
                    }
                }
            }

            VStack(spacing: FTSpacing.sm) {
                ForEach(score.components) { component in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(component.name).font(.ftCaption).foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Text("\(Int(component.score))/100")
                                .font(.ftCaption).foregroundStyle(.white.opacity(0.7))
                        }
                        FTProgressBar(value: component.score / 100,
                                      color: scoreColor(Int(component.score)), height: 5)
                        Text(component.explanation)
                            .font(.ftLabel).tracking(0.2)
                            .foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(FTSpacing.xl)
        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
    }

    private func scoreColor(_ value: Int) -> Color {
        switch value {
        case 70...: return FTColor.income
        case 45..<70: return FTColor.gold
        default: return FTColor.expense
        }
    }
}

// MARK: - CFOChatView

private struct CFOChatView: View {
    let financialContext: String

    @State private var service = AICFOService.shared
    @State private var draft = ""
    @State private var apiKeyDraft = ""
    @State private var showingKeySetup = false

    private let suggestions = [
        "How healthy are my finances?",
        "Where can I save the most money?",
        "Will I stay within budget this month?",
        "What subscriptions should I cancel?",
    ]

    var body: some View {
        VStack(spacing: 0) {
            if !service.isConfigured {
                keySetupCard
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: FTSpacing.md) {
                        if service.messages.isEmpty {
                            VStack(spacing: FTSpacing.md) {
                                FTIconTile(symbol: "brain.head.profile", tint: FTColor.accent, size: 52)
                                Text("Your personal CFO knows your real numbers — balances, budgets, trends — and never invents figures.")
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                    .multilineTextAlignment(.center)
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button {
                                        Task { await service.send(suggestion, financialContext: financialContext) }
                                    } label: {
                                        Text(suggestion)
                                            .font(.ftCallout).foregroundStyle(FTColor.accent)
                                            .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.sm)
                                            .ftGlassInteractive(FTRadius.pill)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!service.isConfigured)
                                }
                            }
                            .padding(.top, FTSpacing.xxl)
                        }

                        ForEach(service.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if service.isThinking {
                            HStack(spacing: FTSpacing.sm) {
                                ProgressView().scaleEffect(0.8)
                                Text("Analyzing your finances…")
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, FTSpacing.screen)
                        }

                        if let error = service.lastError {
                            Text(error)
                                .font(.ftCaption).foregroundStyle(FTColor.expense)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                    .padding(.vertical, FTSpacing.md)
                }
                .onChange(of: service.messages.count) {
                    if let last = service.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            inputBar
        }
        .sheet(isPresented: $showingKeySetup) { keySheet }
    }

    private func messageBubble(_ message: CFOChatMessage) -> some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 40) }
            Text(message.text)
                .font(.ftBody)
                .foregroundStyle(message.role == "user" ? .white : FTColor.textPrimary)
                .padding(.horizontal, FTSpacing.lg)
                .padding(.vertical, FTSpacing.md)
                .background {
                    if message.role == "user" {
                        RoundedRectangle(cornerRadius: FTRadius.lg).fill(FTColor.accentGradient)
                    } else {
                        RoundedRectangle(cornerRadius: FTRadius.lg).fill(FTColor.bgElevated.opacity(0.8))
                    }
                }
                .textSelection(.enabled)
            if message.role != "user" { Spacer(minLength: 40) }
        }
        .padding(.horizontal, FTSpacing.screen)
    }

    private var inputBar: some View {
        HStack(spacing: FTSpacing.sm) {
            TextField("Ask about your finances…", text: $draft, axis: .vertical)
                .font(.ftBody)
                .lineLimit(1...4)
                .padding(.horizontal, FTSpacing.lg)
                .padding(.vertical, FTSpacing.md)
                .ftGlass(FTRadius.pill)

            Button {
                let text = draft
                draft = ""
                Task { await service.send(text, financialContext: financialContext) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty || service.isThinking
                                     ? FTColor.textMuted : FTColor.accent)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || service.isThinking || !service.isConfigured)

            Menu {
                Button { showingKeySetup = true } label: {
                    Label("API Key", systemImage: "key.fill")
                }
                Button(role: .destructive) { service.clearHistory() } label: {
                    Label("Clear Conversation", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.ftHeadline).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.sm)
    }

    private var keySetupCard: some View {
        Button { showingKeySetup = true } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "key.fill", tint: FTColor.gold, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Claude")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text("One-time setup: paste an Anthropic API key to enable the chat")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            .padding(FTSpacing.md)
            .ftGlassInteractive(FTRadius.md)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, FTSpacing.screen)
        .padding(.top, FTSpacing.sm)
    }

    private var keySheet: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                VStack(alignment: .leading, spacing: FTSpacing.lg) {
                    Text("Create a key at console.anthropic.com → API Keys, then paste it here. It's stored in the iOS Keychain and used only to talk to Claude. The chat sends a numeric summary of your finances — computed on-device — with each question.")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)

                    SecureField("sk-ant-…", text: $apiKeyDraft)
                        .font(.ftBody)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(FTSpacing.md)
                        .ftGlass(FTRadius.sm)

                    Spacer()
                }
                .padding(FTSpacing.screen)

                PrimaryButton("Save Key", icon: "checkmark.circle.fill") {
                    AICFOService.shared.apiKey = apiKeyDraft
                    showingKeySetup = false
                }
                .disabled(apiKeyDraft.trimmingCharacters(in: .whitespaces).count < 10)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.md)
            }
            .navigationTitle("Claude API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingKeySetup = false }
                }
            }
            .onAppear { apiKeyDraft = AICFOService.shared.apiKey }
        }
    }
}
