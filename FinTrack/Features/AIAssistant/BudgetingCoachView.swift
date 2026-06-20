import SwiftUI
import SwiftData

struct BudgetingCoachView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var savingsGoals: [SavingsGoal]

    @State private var insights: [CoachingInsight] = []
    @State private var expandedTips: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    headerCard
                    if insights.isEmpty {
                        loadingView
                    } else {
                        insightsList
                    }
                    weeklyHabitsSection
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 32)
            }
            .navigationTitle("Budgeting Coach")
            .background { FTBackdrop() }
            .onAppear { generate() }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FTColor.heroGradient)
                    .frame(width: 56, height: 56)
                Image(systemName: "brain.head.profile")
                    .font(.ftHeadline)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Your AI Coach")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                let cal = Calendar.current
                Text("Week \(cal.component(.weekOfYear, from: Date())) · \(Date().monthName)")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                Text("Personalized advice based on your spending history")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }
            Spacer()
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Insights List

    private var insightsList: some View {
        VStack(spacing: FTSpacing.md) {
            ForEach(insights) { insight in
                insightCard(insight)
            }
        }
    }

    private func insightCard(_ insight: CoachingInsight) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FTRadius.sm)
                        .fill(insight.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: insight.icon)
                        .font(.ftHeadline)
                        .foregroundStyle(insight.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.weekLabel)
                        .font(.ftCaption)
                        .foregroundStyle(insight.accentColor)
                    Text(insight.headline)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                }
            }

            Text(insight.body)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(.spring) {
                    if expandedTips.contains(insight.id) {
                        expandedTips.remove(insight.id)
                    } else {
                        expandedTips.insert(insight.id)
                    }
                }
            } label: {
                HStack {
                    Text(expandedTips.contains(insight.id) ? "Hide Tips" : "Show \(insight.tips.count) Tips")
                        .font(.ftCallout)
                        .foregroundStyle(insight.accentColor)
                    Image(systemName: "chevron.down")
                        .font(.ftCaption)
                        .foregroundStyle(insight.accentColor)
                        .rotationEffect(.degrees(expandedTips.contains(insight.id) ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if expandedTips.contains(insight.id) {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    ForEach(Array(insight.tips.enumerated()), id: \.offset) { i, tip in
                        HStack(alignment: .top, spacing: FTSpacing.sm) {
                            Text("\(i + 1)")
                                .font(.ftLabel)
                                .tracking(1.2)
                                .foregroundStyle(insight.accentColor)
                                .frame(width: 18)
                            Text(tip)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .background(insight.accentColor.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Weekly Habits

    private var weeklyHabitsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("PROVEN MONEY HABITS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                ForEach(habits, id: \.title) { habit in
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: habit.icon)
                            .foregroundStyle(FTColor.accent)
                            .font(.ftCallout)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.title)
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                            Text(habit.detail)
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .ftGlass(FTRadius.md)
                }
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: FTSpacing.lg) {
            ProgressView().scaleEffect(1.2)
            Text("Analyzing your financial patterns…")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
        }
        .padding(.top, 40)
    }

    // MARK: - Data

    private func generate() {
        insights = AIAnalyticsService.shared.generateCoachingInsights(
            transactions: transactions,
            savingsGoals: savingsGoals,
            currency: appState.baseCurrency
        )
    }

    private let habits: [(title: String, detail: String, icon: String)] = [
        ("Pay Yourself First", "Save before spending — automate transfers on payday.", "arrow.left.arrow.right.circle.fill"),
        ("50/30/20 Rule", "50% needs, 30% wants, 20% savings & debt.", "chart.pie.fill"),
        ("Zero-Based Budget", "Allocate every dirham with intent each month.", "equal.circle.fill"),
        ("48-Hour Purchase Rule", "Wait 48 hours before non-essential buys.", "clock.fill"),
        ("Weekly Money Date", "Spend 15 minutes each week reviewing your finances.", "calendar.circle.fill"),
        ("Emergency Fund First", "3-6 months of expenses before investing.", "umbrella.fill"),
    ]
}
