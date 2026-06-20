import SwiftUI
import SwiftData
import Charts

// MARK: - SavingsGoalsView

struct SavingsGoalsView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context

    @Query(sort: \SavingsGoal.createdAt, order: .reverse) private var allGoals: [SavingsGoal]
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]

    @State private var filterIndex = 0         // 0=Active, 1=On Track, 2=Completed, 3=All
    @State private var showingAdd = false
    @State private var showingConflicts = false
    @State private var detailGoal: SavingsGoal?
    @State private var insights: [SavingsGoalService.SavingsInsight] = []

    private let filters = ["Active", "On Track", "Completed", "All"]
    private let svc = SavingsGoalService.shared
    private var base: String { appState.baseCurrency }

    private var filtered: [SavingsGoal] {
        let nonArchived = allGoals.filter { !$0.isArchived }
        switch filterIndex {
        case 0: return nonArchived.filter { !$0.isCompleted }
        case 1: return nonArchived.filter { !$0.isCompleted && svc.goalStatus(for: $0) == .onTrack }
        case 2: return nonArchived.filter { $0.isCompleted }
        default: return allGoals
        }
    }

    private var totalSaved: Double {
        allGoals.filter { !$0.isArchived }.reduce(0) {
            $0 + currencyService.convert($1.currentAmount, from: $1.currency, to: base)
        }
    }

    private var totalTarget: Double {
        allGoals.filter { !$0.isArchived }.reduce(0) {
            $0 + currencyService.convert($1.targetAmount, from: $1.currency, to: base)
        }
    }

    private var overallProgress: Double {
        totalTarget > 0 ? min(totalSaved / totalTarget, 1.0) : 0
    }

    private var conflict: SavingsGoalService.GoalConflict {
        svc.analyzeConflicts(goals: allGoals, transactions: transactions,
                              currencyService: currencyService, base: base)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        heroCard
                        if conflict.hasConflict { conflictBanner }
                        filterRow
                        if filtered.isEmpty {
                            emptyState
                        } else {
                            goalsGrid
                        }
                        if !insights.isEmpty { insightsSection }
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
            }
            .navigationTitle("Savings Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(FTColor.accent)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddSavingsGoalView()
            }
            .sheet(item: $detailGoal) { goal in
                NavigationStack { SavingsGoalDetailView(goal: goal) }
            }
            .sheet(isPresented: $showingConflicts) {
                GoalConflictView(conflict: conflict, base: base)
            }
            .onAppear { refreshInsights() }
            .onChange(of: allGoals.count) { _, _ in refreshInsights() }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            Text("TOTAL SAVINGS PROGRESS")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .firstTextBaseline, spacing: FTSpacing.sm) {
                Text(totalSaved.asCompact(currency: base))
                    .font(.ftDisplay).foregroundStyle(.white)
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text("of \(totalTarget.asCompact(currency: base))")
                    .font(.ftBodySemibold).foregroundStyle(.white.opacity(0.7))
            }

            VStack(spacing: FTSpacing.xs) {
                FTProgressBar(value: overallProgress, color: .white.opacity(0.9))
                    .frame(height: 10)
                HStack {
                    Text("\(Int(overallProgress * 100))% funded across \(allGoals.filter { !$0.isArchived }.count) goal\(allGoals.filter { !$0.isArchived }.count == 1 ? "" : "s")")
                        .font(.ftCaption).foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    let remaining = totalTarget - totalSaved
                    if remaining > 0 {
                        Text("\(remaining.asCompact(currency: base)) to go")
                            .font(.ftCaption).foregroundStyle(.white.opacity(0.75))
                    } else {
                        Text("All goals funded!")
                            .font(.ftCallout.weight(.semibold)).foregroundStyle(.white)
                    }
                }
            }

            HStack(spacing: 0) {
                let activeCount = allGoals.filter { !$0.isCompleted && !$0.isArchived }.count
                let completedCount = allGoals.filter { $0.isCompleted }.count
                let onTrackCount = allGoals.filter { !$0.isCompleted && !$0.isArchived && svc.goalStatus(for: $0) == .onTrack }.count

                heroMetric(label: "Active", value: "\(activeCount)")
                Divider().frame(width: 1, height: 28).overlay(.white.opacity(0.3))
                heroMetric(label: "On Track", value: "\(onTrackCount)")
                Divider().frame(width: 1, height: 28).overlay(.white.opacity(0.3))
                heroMetric(label: "Completed", value: "\(completedCount)")
            }
        }
        .padding(FTSpacing.xl)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1FA463), Color(hex: 0x0D7A4A)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: FTRadius.xl)
        )
        .shadow(color: Color(hex: 0x0D7A4A).opacity(0.4), radius: 20, y: 8)
    }

    private func heroMetric(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.ftHeadline).foregroundStyle(.white)
            Text(label).font(.ftCaption).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Conflict Banner

    private var conflictBanner: some View {
        Button { showingConflicts = true } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "exclamationmark.triangle.fill", tint: FTColor.gold, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Goal Funding Conflict Detected")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text("Monthly shortfall: \(conflict.shortfall.asCompact(currency: base)). Tap to see recommendations.")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FTColor.textMuted)
            }
            .padding(FTSpacing.md)
            .background(FTColor.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: FTRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: FTRadius.lg).stroke(FTColor.gold.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(filters.indices, id: \.self) { i in
                    FilterChip(title: filters[i], isSelected: filterIndex == i) {
                        withAnimation(.snappy(duration: 0.2)) { filterIndex = i }
                    }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
        }
        .padding(.horizontal, -FTSpacing.screen)
    }

    // MARK: - Goals Grid

    private var goalsGrid: some View {
        VStack(spacing: FTSpacing.md) {
            ForEach(filtered) { goal in
                GoalCard(goal: goal, base: base, currencyService: currencyService)
                    .onTapGesture { detailGoal = goal }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation { context.delete(goal) }
                        } label: { Label("Delete", systemImage: "trash") }
                        Button {
                            goal.isArchived = true
                            goal.updatedAt = Date()
                        } label: { Label("Archive", systemImage: "archivebox") }
                        .tint(FTColor.textSecondary)
                    }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            FTIconTile(symbol: "star.fill", tint: FTColor.income, size: 64)
            VStack(spacing: FTSpacing.sm) {
                Text(filterIndex == 2 ? "No Completed Goals" : "No Savings Goals")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text(filterIndex == 2
                     ? "Completed goals will appear here."
                     : "Set a goal and start saving towards what matters most.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if filterIndex != 2 {
                Button { showingAdd = true } label: {
                    Label("Add Savings Goal", systemImage: "plus")
                }
                .buttonStyle(FTPrimaryButtonStyle())
                .padding(.horizontal, FTSpacing.xxl)
            }
        }
        .padding(.top, FTSpacing.xxl)
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("AI INSIGHTS")
                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.md) {
                    ForEach(insights) { insight in
                        SavingsInsightCard(insight: insight)
                            .frame(width: 260)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Helpers

    private func refreshInsights() {
        insights = svc.generateInsights(
            goals: allGoals,
            transactions: transactions,
            currencyService: currencyService,
            base: base
        )
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    @Bindable var goal: SavingsGoal
    let base: String
    let currencyService: CurrencyService
    @Environment(\.modelContext) private var context
    @State private var showingContribute = false

    private let svc = SavingsGoalService.shared

    var body: some View {
        VStack(spacing: FTSpacing.md) {
            // Header
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: goal.effectiveIcon,
                           tint: Color.fromString(goal.effectiveColor), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: FTSpacing.sm) {
                        Text(goal.name)
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        if goal.isCompleted {
                            BadgeView(text: "Complete", color: FTColor.income)
                        } else if goal.goalType != .custom {
                            BadgeView(text: goal.goalType.rawValue, color: Color.fromString(goal.effectiveColor))
                        }
                    }
                    if let date = goal.targetDate {
                        let days = goal.daysRemaining ?? 0
                        Text(days == 0 ? "Overdue" : "\(days) days left · \(date.formatted)")
                            .font(.ftCaption)
                            .foregroundStyle(days < 30 && days > 0 ? FTColor.gold :
                                             days == 0 ? FTColor.expense : FTColor.textSecondary)
                    } else {
                        Text("No deadline")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(goal.currentAmount.formatted(as: goal.currency))
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text("of \(goal.targetAmount.formatted(as: goal.currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }

            // Progress Bar
            VStack(spacing: FTSpacing.xs) {
                FTProgressBar(value: goal.progress,
                              color: goal.isCompleted ? FTColor.income : Color.fromString(goal.effectiveColor))
                    .frame(height: 9)
                HStack {
                    let status = svc.goalStatus(for: goal)
                    HStack(spacing: 4) {
                        Circle().fill(svc.statusColor(for: status)).frame(width: 7, height: 7)
                        Text(svc.statusLabel(for: status))
                            .font(.ftCaption).foregroundStyle(svc.statusColor(for: status))
                    }
                    Spacer()
                    Text("\(Int(goal.progress * 100))%")
                        .font(.ftCaption.weight(.semibold)).foregroundStyle(FTColor.textSecondary)
                }
            }

            // Key Metrics Row
            if !goal.isCompleted {
                Divider().overlay(Color.white.opacity(0.1))
                HStack(spacing: 0) {
                    metricItem(label: "Remaining",
                               value: goal.remaining.asCompact(currency: goal.currency))
                    Divider().frame(width: 1, height: 28).overlay(Color.white.opacity(0.15))
                    if let months = goal.monthsRemaining, months > 0 {
                        metricItem(label: "Months Left", value: "\(months)")
                    } else if let days = goal.daysRemaining, days > 0 {
                        metricItem(label: "Days Left", value: "\(days)")
                    } else {
                        metricItem(label: "Deadline", value: "None")
                    }
                    Divider().frame(width: 1, height: 28).overlay(Color.white.opacity(0.15))
                    metricItem(label: "Need/mo",
                               value: goal.requiredMonthlyContribution.asCompact(currency: goal.currency))
                }

                // Contribute Button
                Button {
                    showingContribute = true
                } label: {
                    Label("Contribute", systemImage: "plus.circle.fill")
                        .font(.ftCallout)
                        .foregroundStyle(FTColor.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FTSpacing.sm)
                        .background(FTColor.accent.opacity(0.1), in: .capsule)
                        .overlay(Capsule().stroke(FTColor.accent.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlassInteractive()
        .sheet(isPresented: $showingContribute) {
            ContributeToGoalView(goal: goal)
        }
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.ftCallout.weight(.semibold))
                .foregroundStyle(FTColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Savings Insight Card

struct SavingsInsightCard: View {
    let insight: SavingsGoalService.SavingsInsight

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: insight.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(insight.severity.color)
                Text(insight.title)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Spacer()
            }
            Text(insight.message)
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                .lineLimit(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass()
    }
}

// MARK: - Goal Conflict View

struct GoalConflictView: View {
    @Environment(\.dismiss) private var dismiss
    let conflict: SavingsGoalService.GoalConflict
    let base: String

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Summary card
                        VStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: "exclamationmark.triangle.fill",
                                       tint: FTColor.gold, size: 52)
                            Text("Goal Funding Conflict")
                                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                            Text("Your active goals require more monthly savings than your current capacity.")
                                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(FTSpacing.xl)
                        .ftGlass()

                        // Numbers
                        VStack(spacing: 0) {
                            conflictRow(label: "Required/month", value: conflict.totalRequiredMonthly.formatted(as: base), color: FTColor.expense)
                            Divider().overlay(Color.white.opacity(0.08))
                            conflictRow(label: "Available/month", value: conflict.availableMonthly.formatted(as: base), color: FTColor.income)
                            Divider().overlay(Color.white.opacity(0.08))
                            conflictRow(label: "Monthly shortfall", value: conflict.shortfall.formatted(as: base), color: FTColor.gold)
                        }
                        .ftGlass()

                        // Suggestions
                        if !conflict.suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("AI RECOMMENDATIONS")
                                    .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                                ForEach(conflict.suggestions.indices, id: \.self) { i in
                                    HStack(alignment: .top, spacing: FTSpacing.md) {
                                        Image(systemName: "\(i + 1).circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(FTColor.accent)
                                        Text(conflict.suggestions[i])
                                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(FTSpacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .ftGlass(FTRadius.md)
                                }
                            }
                        }

                        // Goals involved
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("AFFECTED GOALS")
                                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                            ForEach(conflict.goals) { goal in
                                HStack(spacing: FTSpacing.md) {
                                    FTIconTile(symbol: goal.effectiveIcon,
                                               tint: Color.fromString(goal.effectiveColor), size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(goal.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        if let months = goal.monthsRemaining, months > 0 {
                                            Text("\(months) months remaining")
                                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Text(goal.requiredMonthlyContribution.asCompact(currency: goal.currency) + "/mo")
                                        .font(.ftCallout).foregroundStyle(FTColor.textSecondary)
                                }
                                .padding(FTSpacing.md)
                                .ftGlass(FTRadius.md)
                            }
                        }

                        Color.clear.frame(height: FTSpacing.xxl)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
            }
            .navigationTitle("Conflict Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(FTColor.accent)
                }
            }
        }
    }

    private func conflictRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
        }
        .padding(FTSpacing.md)
    }
}
