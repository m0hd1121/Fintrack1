import SwiftUI
import SwiftData
import Charts

// MARK: - Savings Goal Detail View

struct SavingsGoalDetailView: View {
    @Bindable var goal: SavingsGoal
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]
    @Query(filter: #Predicate<SavingsGoal> { !$0.isArchived && !$0.isCompleted }) private var activeGoals: [SavingsGoal]

    @State private var selectedTab = 0
    @State private var showingContribute = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    private let tabs = ["Overview", "Progress", "Auto-Save", "Insights"]
    private var baseCurrency: String { appState.baseCurrency }
    private var tint: Color { Color.fromString(goal.effectiveColor) }
    private var svc = SavingsGoalService.shared

    var body: some View {
        ZStack {
            FTBackdrop()
            VStack(spacing: 0) {
                heroCard
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.md)

                FTSegmentedControl(options: tabs, selection: .init(
                    get: { selectedTab },
                    set: { withAnimation(.snappy(duration: 0.22)) { selectedTab = $0 } }
                ))
                .padding(.horizontal, FTSpacing.screen)
                .padding(.vertical, FTSpacing.md)

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        switch selectedTab {
                        case 0: overviewTab
                        case 1: progressTab
                        case 2: autoSaveTab
                        default: insightsTab
                        }
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showingContribute = true } label: {
                        Label("Add Funds", systemImage: "plus.circle")
                    }
                    Button { showingEdit = true } label: {
                        Label("Edit Goal", systemImage: "pencil")
                    }
                    Divider()
                    Button {
                        goal.isArchived.toggle()
                        goal.updatedAt = Date()
                        try? context.save()
                        dismiss()
                    } label: {
                        Label(goal.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                    }
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Delete Goal", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingContribute) {
            ContributeToGoalView(goal: goal)
        }
        .sheet(isPresented: $showingEdit) {
            AddSavingsGoalView(editingGoal: goal)
        }
        .alert("Delete Goal?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                context.delete(goal)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete '\(goal.name)' and all its data.")
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: goal.effectiveIcon, tint: tint, size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name).font(.ftTitle).foregroundStyle(.white)
                    let status = svc.goalStatus(for: goal)
                    BadgeView(text: svc.statusLabel(for: status), color: svc.statusColor(for: status))
                }
                Spacer()
                Button { showingContribute = true } label: {
                    Label("Add", systemImage: "plus")
                        .font(.ftCallout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.white.opacity(0.2), in: .capsule)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(goal.currentAmount.formatted(as: goal.currency))
                    .font(.ftAmount).foregroundStyle(.white)
                Text("/ \(goal.targetAmount.formatted(as: goal.currency))")
                    .font(.ftBodySemibold).foregroundStyle(.white.opacity(0.75))
            }

            FTProgressBar(value: goal.progress, color: .white.opacity(0.9))

            HStack {
                Text("\(Int(goal.progress * 100))% complete")
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(goal.remaining.asCompact(currency: goal.currency) + " to go")
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(FTSpacing.xl)
        .background(
            LinearGradient(colors: [tint, tint.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: FTRadius.xl)
        )
    }

    // MARK: - Tab 0: Overview

    private var overviewTab: some View {
        VStack(spacing: FTSpacing.lg) {
            metricsRow
            if goal.goalType == .downPayment { downPaymentSummary }
            if goal.goalType == .education { educationSummary }
            if goal.goalType == .hajj { hajjSummary }
            if goal.goalType == .emergencyFund { emergencyFundSummary }
            if let notes = goal.notes, !notes.isEmpty { notesCard(notes) }
            goalDetailsCard
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 0) {
            metricCell(label: "Saved", value: goal.currentAmount.asCompact(currency: goal.currency), color: tint)
            dividerLine
            metricCell(label: "Remaining", value: goal.remaining.asCompact(currency: goal.currency), color: FTColor.textPrimary)
            dividerLine
            if let months = goal.monthsRemaining {
                metricCell(label: "Months Left", value: "\(months)", color: FTColor.textPrimary)
            } else {
                metricCell(label: "Days Since", value: "\(Calendar.current.dateComponents([.day], from: goal.createdAt, to: Date()).day ?? 0)", color: FTColor.textPrimary)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private func metricCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.ftHeadline).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle().fill(FTColor.textMuted.opacity(0.3)).frame(width: 1, height: 36)
    }

    private var downPaymentSummary: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("DOWN PAYMENT DETAILS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: FTSpacing.xs) {
                if goal.propertyTargetPrice > 0 {
                    detailRow("Property Value", goal.propertyTargetPrice.formatted(as: goal.currency))
                    detailRow("Down Payment %", "\(Int(goal.downPaymentPercent))%")
                    detailRow("Mortgage Amount",
                              (goal.propertyTargetPrice * (1 - goal.downPaymentPercent / 100)).asCompact(currency: goal.currency))
                }
            }
            .padding(FTSpacing.md)
            .ftGlass(FTRadius.md)
        }
    }

    private var educationSummary: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("EDUCATION DETAILS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            if let inst = goal.educationInstitution {
                detailCard {
                    detailRow("Institution", inst)
                    if let bench = SavingsGoalService.uaeTuitionBenchmarks.first(where: { $0.university == inst }), bench.annualAED > 0 {
                        detailRow("Est. Annual Tuition", bench.annualAED.formatted(as: "AED"))
                        detailRow("4-Year Total", (bench.annualAED * 4).asCompact(currency: "AED"))
                    }
                }
            }
        }
    }

    private var hajjSummary: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("HAJJ / UMRAH DETAILS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            detailCard {
                if goal.hajjTravelYear > 0 {
                    detailRow("Target Year", String(goal.hajjTravelYear))
                    let yearsLeft = goal.hajjTravelYear - Calendar.current.component(.year, from: Date())
                    detailRow("Years to Save", "\(max(0, yearsLeft))")
                }
                detailRow("Package Type", "Custom")
            }
        }
    }

    private var emergencyFundSummary: some View {
        let monthly = SavingsGoalService.shared.estimatedMonthlyExpenses(transactions: transactions)
        return VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("EMERGENCY FUND DETAILS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            detailCard {
                detailRow("Coverage Target", "\(goal.emergencyMonthsTarget) months")
                if monthly > 0 {
                    detailRow("Avg Monthly Expenses", monthly.asCompact(currency: baseCurrency))
                    let monthsCovered = monthly > 0 ? goal.currentAmount / monthly : 0
                    detailRow("Current Coverage", String(format: "%.1f months", monthsCovered))
                }
            }
        }
    }

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            Text("NOTES").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            Text(notes).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                .padding(FTSpacing.md)
                .ftGlass(FTRadius.md)
        }
    }

    private var goalDetailsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("GOAL DETAILS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            detailCard {
                detailRow("Type", goal.goalType.rawValue)
                detailRow("Currency", goal.currency)
                if let date = goal.targetDate {
                    detailRow("Target Date", date.formatted(date: .abbreviated, time: .omitted))
                }
                detailRow("Created", goal.createdAt.formatted(date: .abbreviated, time: .omitted))
                if goal.conflictPriority > 0 {
                    detailRow("Priority", goal.conflictPriority == 1 ? "High" : "Critical")
                }
            }
        }
    }

    // MARK: - Tab 1: Progress

    private var progressTab: some View {
        VStack(spacing: FTSpacing.lg) {
            projectionCard
            milestonesCard
            if let projected = goal.projectedCompletionDate {
                projectedCompletionCard(projected)
            }
        }
    }

    private var projectionCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("SAVINGS PROJECTION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: FTSpacing.sm) {
                if let months = goal.monthsRemaining, months > 0 {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Required Monthly")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            Text(goal.requiredMonthlyContribution.formatted(as: goal.currency))
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("Months Remaining")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            Text("\(months)")
                                .font(.ftBodySemibold).foregroundStyle(tint)
                        }
                    }
                    .padding(FTSpacing.md)
                    .ftGlass(FTRadius.md)
                }
                if goal.autoContributionEnabled && goal.autoContributionAmount > 0 {
                    let monthly = goal.autoContributionAmount * goal.autoContributionFrequency.periodsPerMonth
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Auto-Contribution (monthly equiv.)")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            Text(monthly.formatted(as: goal.currency))
                                .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                        }
                        Spacer()
                        let delta = monthly - goal.requiredMonthlyContribution
                        if delta >= 0 {
                            BadgeView(text: "On Track", color: FTColor.income)
                        } else {
                            BadgeView(text: "\((-delta).asCompact(currency: goal.currency))/mo short", color: FTColor.gold)
                        }
                    }
                    .padding(FTSpacing.md)
                    .ftGlass(FTRadius.md)
                }
            }
        }
    }

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("MILESTONES").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                ForEach(SavingsGoalService.milestoneThresholds, id: \.self) { threshold in
                    let reached = goal.progress >= threshold
                    let notified = goal.notifiedMilestones.contains(where: { abs($0 - threshold) < 0.001 })
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(reached ? FTColor.income : FTColor.textMuted)
                            .font(.system(size: 20))
                        Text("\(Int(threshold * 100))%")
                            .font(.ftBodySemibold)
                            .foregroundStyle(reached ? FTColor.textPrimary : FTColor.textSecondary)
                        Text(reached ? (goal.targetAmount * threshold).formatted(as: goal.currency) : "—")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        if notified {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 12)).foregroundStyle(FTColor.income)
                        }
                    }
                    .padding(.vertical, 10)
                    if threshold < SavingsGoalService.milestoneThresholds.last ?? 1.0 {
                        Divider().opacity(0.4)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private func projectedCompletionCard(_ date: Date) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "calendar.badge.checkmark", tint: FTColor.income, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("Projected Completion")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.ftCaption).foregroundStyle(FTColor.income)
            }
            Spacer()
            if let target = goal.targetDate {
                if date <= target {
                    BadgeView(text: "Ahead", color: FTColor.income)
                } else {
                    BadgeView(text: "Behind", color: FTColor.gold)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlassInteractive(FTRadius.lg)
    }

    // MARK: - Tab 2: Auto-Save

    private var autoSaveTab: some View {
        VStack(spacing: FTSpacing.lg) {
            autoContribCard
            if goal.roundUpEnabled {
                roundUpCard
            }
            if goal.salaryPercentage > 0 {
                salaryCard
            }
            nextContributionCard
        }
    }

    private var autoContribCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("AUTO-CONTRIBUTIONS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "repeat.circle.fill", tint: FTColor.accent, size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.autoContributionEnabled ? "Enabled" : "Disabled")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text(goal.autoContributionEnabled ?
                             "\(goal.autoContributionAmount.formatted(as: goal.currency)) · \(goal.autoContributionFrequency.rawValue)" :
                             "Set up automatic contributions to stay on track")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: goal.autoContributionEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(goal.autoContributionEnabled ? FTColor.income : FTColor.textMuted)
                }
                .padding(.vertical, FTSpacing.md)

                if goal.autoContributionEnabled && goal.autoContributionFrequency == .monthly {
                    Divider().opacity(0.4)
                    HStack {
                        Text("Contribution Day").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text("Day \(goal.autoContributionDay) of each month")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var roundUpCard: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "arrow.up.circle.fill", tint: FTColor.catTeal, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text("Round-Up Contributions").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("Spare change from purchases goes to this goal")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(FTColor.income)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var salaryCard: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "banknote.fill", tint: FTColor.income, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text("Salary Allocation").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("\(String(format: "%.1f", goal.salaryPercentage))% of each salary goes here")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var nextContributionCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("NEXT CONTRIBUTION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            if goal.autoContributionEnabled && goal.autoContributionAmount > 0 {
                let next = goal.autoContributionFrequency.nextContributionDate(from: Date(), dayOfMonth: goal.autoContributionDay)
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "calendar", tint: FTColor.accent, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(next.formatted(date: .long, time: .omitted))
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text(goal.autoContributionAmount.formatted(as: goal.currency) + " · " + goal.autoContributionFrequency.rawValue)
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                }
                .padding(FTSpacing.lg)
                .ftGlass(FTRadius.md)
            } else {
                EmptyStateView(
                    icon: "repeat.circle",
                    title: "No Auto-Contributions",
                    message: "Edit this goal to set up automatic contributions.",
                    actionTitle: "Edit Goal"
                ) { }
                .ftGlass(FTRadius.md)
            }
        }
    }

    // MARK: - Tab 3: Insights

    private var insightsTab: some View {
        let insights = svc.generateInsights(
            goals: activeGoals,
            transactions: transactions,
            currencyService: currencyService,
            base: baseCurrency
        )
        let conflict = svc.analyzeConflicts(
            goals: activeGoals,
            transactions: transactions,
            currencyService: currencyService,
            base: baseCurrency
        )
        let status = svc.goalStatus(for: goal)

        return VStack(spacing: FTSpacing.lg) {
            statusInsightCard(status: status)

            if conflict.hasConflict {
                conflictCard(conflict: conflict)
            }

            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.md) {
                    Text("AI INSIGHTS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                    VStack(spacing: FTSpacing.sm) {
                        ForEach(insights) { insight in
                            insightRow(insight)
                        }
                    }
                }
            }
        }
    }

    private func statusInsightCard(status: SavingsGoalService.GoalStatus) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: statusIcon(status), tint: svc.statusColor(for: status), size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(svc.statusLabel(for: status))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(statusMessage(status))
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private func statusIcon(_ status: SavingsGoalService.GoalStatus) -> String {
        switch status {
        case .onTrack: return "checkmark.circle.fill"
        case .slightlyBehind: return "exclamationmark.circle"
        case .atRisk: return "exclamationmark.triangle.fill"
        case .overdue: return "calendar.badge.exclamationmark"
        case .completed: return "star.fill"
        case .noDate: return "calendar.circle"
        }
    }

    private func statusMessage(_ status: SavingsGoalService.GoalStatus) -> String {
        switch status {
        case .onTrack: return "You're on track to meet your goal by the target date."
        case .slightlyBehind: return "You're slightly behind. Consider increasing monthly contributions."
        case .atRisk: return "You're significantly behind. Increase contributions or extend the deadline."
        case .overdue: return "This goal has passed its target date. Update the deadline or make a large contribution."
        case .completed: return "Congratulations! You've reached your savings goal."
        case .noDate: return "No target date set. Add one to track your progress."
        }
    }

    private func conflictCard(conflict: SavingsGoalService.GoalConflict) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(FTColor.gold)
                Text("Goal Funding Conflict").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            Text("Your active goals require \(conflict.totalRequiredMonthly.asCompact(currency: baseCurrency))/mo but estimated savings capacity is \(conflict.availableMonthly.asCompact(currency: baseCurrency))/mo (shortfall: \(conflict.shortfall.asCompact(currency: baseCurrency))/mo).")
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            if !conflict.suggestions.isEmpty {
                Divider().opacity(0.4)
                VStack(alignment: .leading, spacing: FTSpacing.xs) {
                    ForEach(conflict.suggestions.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: FTSpacing.xs) {
                            Text("\(i + 1).").font(.ftCaption.weight(.semibold)).foregroundStyle(FTColor.gold)
                            Text(conflict.suggestions[i]).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(FTSpacing.lg)
        .background(FTColor.gold.opacity(0.1), in: .rect(cornerRadius: FTRadius.md))
        .overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(FTColor.gold.opacity(0.3), lineWidth: 1))
    }

    private func insightRow(_ insight: SavingsGoalService.SavingsInsight) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            Image(systemName: insight.icon)
                .font(.system(size: 18))
                .foregroundStyle(insight.severity.color)
                .frame(width: 32, height: 32)
                .background(insight.severity.color.opacity(0.15), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(insight.message).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Detail Helpers

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func detailCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}
