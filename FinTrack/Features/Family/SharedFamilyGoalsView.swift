import SwiftUI
import SwiftData

struct SharedFamilyGoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var allGoals: [SharedFamilyGoal]

    let group: FamilyGroup

    @State private var showingAddGoal = false
    @State private var selectedGoal: SharedFamilyGoal?
    @State private var showArchived = false

    private var activeGoals: [SharedFamilyGoal] { allGoals.filter { !$0.isCompleted && !$0.isArchived } }
    private var completedGoals: [SharedFamilyGoal] { allGoals.filter { $0.isCompleted } }
    private var archivedGoals: [SharedFamilyGoal] { allGoals.filter { $0.isArchived && !$0.isCompleted } }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                if allGoals.isEmpty {
                    emptyState
                } else {
                    summaryStrip
                    if !activeGoals.isEmpty {
                        goalsSection(title: "ACTIVE GOALS", goals: activeGoals)
                    }
                    if !completedGoals.isEmpty {
                        goalsSection(title: "COMPLETED", goals: completedGoals)
                    }
                    if showArchived && !archivedGoals.isEmpty {
                        goalsSection(title: "ARCHIVED", goals: archivedGoals)
                    }
                    if !archivedGoals.isEmpty {
                        Button { withAnimation { showArchived.toggle() } } label: {
                            Label(showArchived ? "Hide Archived" : "Show Archived (\(archivedGoals.count))",
                                  systemImage: showArchived ? "archivebox" : "archivebox.fill")
                                .font(.ftCallout).foregroundStyle(FTColor.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Shared Goals")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddGoal = true } label: {
                    Image(systemName: "plus").font(.ftCallout).foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddSharedGoalSheet(currency: appState.baseCurrency) { goal in
                context.insert(goal)
                try? context.save()
            }
        }
        .sheet(item: $selectedGoal) { goal in
            SharedGoalDetailSheet(goal: goal, group: group)
        }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: FTSpacing.sm) {
            let totalSaved = activeGoals.reduce(0.0) { $0 + $1.totalContributed }
            let nearComplete = activeGoals.filter { $0.progress > 0.9 }.count

            summaryTile(value: "\(activeGoals.count)", label: "Active", color: FTColor.accent, icon: "star.fill")
            summaryTile(value: totalSaved.asCompact(currency: appState.baseCurrency), label: "Total Saved", color: FTColor.income, icon: "banknote.fill")
            summaryTile(value: "\(nearComplete)", label: "Near Goal", color: FTColor.gold, icon: "flag.fill")
        }
    }

    private func summaryTile(value: String, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.ftCallout).foregroundStyle(color)
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Goals Section

    private func goalsSection(title: String, goals: [SharedFamilyGoal]) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text(title).font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ForEach(goals) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    private func goalCard(_ goal: SharedFamilyGoal) -> some View {
        Button { selectedGoal = goal } label: {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                HStack(spacing: FTSpacing.md) {
                    ZStack {
                        Circle().fill(Color(hex: goal.colorHex).opacity(0.15)).frame(width: 48, height: 48)
                        Image(systemName: goal.icon).font(.ftTitle).foregroundStyle(Color(hex: goal.colorHex))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        if !goal.goalDescription.isEmpty {
                            Text(goal.goalDescription).font(.ftCaption).foregroundStyle(FTColor.textSecondary).lineLimit(1)
                        }
                        if let days = goal.daysRemaining, !goal.isCompleted {
                            Text("\(days) days remaining").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(goal.progress.asPercentage())
                            .font(.ftBodySemibold).foregroundStyle(Color(hex: goal.colorHex))
                        if goal.isCompleted {
                            Text("Complete").font(.ftCaption).foregroundStyle(FTColor.income)
                        }
                    }
                }

                VStack(spacing: 6) {
                    FTProgressBar(value: goal.progress, color: Color(hex: goal.colorHex), height: 8)
                    HStack {
                        Text(goal.totalContributed.asCompact(currency: appState.baseCurrency))
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text(goal.targetAmount.asCompact(currency: appState.baseCurrency))
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }

                if !goal.contributionsByMember.isEmpty {
                    contributorsRow(goal)
                }
            }
            .padding()
            .ftGlassInteractive(FTRadius.xl)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(goal)
                try? context.save()
            } label: { Label("Delete", systemImage: "trash") }

            Button {
                goal.isArchived.toggle()
                try? context.save()
            } label: {
                Label(goal.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
            }
            .tint(FTColor.catBlue)
        }
    }

    private func contributorsRow(_ goal: SharedFamilyGoal) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(goal.contributionsByMember.sorted(by: { $0.value > $1.value }), id: \.key) { entry in
                    HStack(spacing: 4) {
                        Circle().fill(FTColor.accent.opacity(0.2)).frame(width: 6, height: 6)
                        Text(entry.key).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text(entry.value.asCompact(currency: appState.baseCurrency))
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(hex: goal.colorHex))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(hex: goal.colorHex).opacity(0.08), in: Capsule())
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.xl) {
            ZStack {
                Circle().fill(FTColor.catTeal.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "star.circle.fill").font(.system(size: 40)).foregroundStyle(FTColor.catTeal)
            }
            Text("No Shared Goals").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("Create collaborative savings goals for vacations, home purchases, emergency funds, and more.")
                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, FTSpacing.xl)

            VStack(spacing: FTSpacing.sm) {
                ForEach(SharedFamilyGoal.presets, id: \.name) { preset in
                    Button {
                        let goal = SharedFamilyGoal(
                            name: preset.name,
                            targetAmount: preset.targetAmount,
                            currency: appState.baseCurrency,
                            icon: preset.icon,
                            colorHex: preset.colorHex
                        )
                        context.insert(goal)
                        try? context.save()
                    } label: {
                        HStack(spacing: FTSpacing.md) {
                            ZStack {
                                Circle().fill(Color(hex: preset.colorHex).opacity(0.12)).frame(width: 36, height: 36)
                                Image(systemName: preset.icon).font(.ftCallout).foregroundStyle(Color(hex: preset.colorHex))
                            }
                            Text(preset.name).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(preset.targetAmount.asCompact(currency: appState.baseCurrency))
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            Image(systemName: "plus.circle").font(.ftCallout).foregroundStyle(FTColor.accent)
                        }
                        .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)

            Button { showingAddGoal = true } label: {
                Label("Create Custom Goal", systemImage: "plus")
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                    .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, FTSpacing.xxl)
    }
}

// MARK: - Add Shared Goal Sheet

struct AddSharedGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currency: String
    let onAdd: (SharedFamilyGoal) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var targetAmount = ""
    @State private var hasDeadline = false
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor = "#0E9C8A"

    private let icons = ["star.fill", "house.fill", "car.fill", "airplane", "graduationcap.fill", "heart.fill", "dollarsign.circle.fill", "umbrella.fill", "🎉", "gift.fill"]
    private let sfIcons = ["star.fill", "house.fill", "car.fill", "airplane", "graduationcap.fill", "heart.fill", "dollarsign.circle.fill", "umbrella.fill", "gift.fill", "sparkles"]
    private let colors = ["#0E9C8A", "#4A90D9", "#E8963C", "#9B59B6", "#E74C3C", "#1B8B4B", "#E67E22", "#F1C40F"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    goalPreview

                    VStack(spacing: FTSpacing.sm) {
                        fieldRow("Goal Name", placeholder: "e.g. Family Vacation 2026", text: $name)
                        fieldRow("Description (optional)", placeholder: "What are you saving for?", text: $description)
                    }
                    .padding().ftGlass(FTRadius.xl)

                    VStack(spacing: FTSpacing.sm) {
                        fieldRow("Target Amount (\(currency))", placeholder: "e.g. 10000", text: $targetAmount, keyboard: .decimalPad)
                        Toggle("Set Deadline", isOn: $hasDeadline).tint(FTColor.accent)
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        if hasDeadline {
                            DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        }
                    }
                    .padding().ftGlass(FTRadius.xl)

                    iconPickerSection
                    colorPickerSection

                    Button(action: addGoal) {
                        Text("Create Goal")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
                    }
                    .buttonStyle(.plain).disabled(name.isEmpty || targetAmount.isEmpty)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("New Shared Goal")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var goalPreview: some View {
        VStack(spacing: FTSpacing.sm) {
            ZStack {
                Circle().fill(Color(hex: selectedColor).opacity(0.15)).frame(width: 80, height: 80)
                Image(systemName: selectedIcon).font(.system(size: 36)).foregroundStyle(Color(hex: selectedColor))
            }
            Text(name.isEmpty ? "New Goal" : name)
                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("ICON").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: FTSpacing.sm) {
                ForEach(sfIcons, id: \.self) { icon in
                    Button { selectedIcon = icon } label: {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(selectedIcon == icon ? Color(hex: selectedColor) : FTColor.textMuted)
                            .frame(maxWidth: .infinity).padding(FTSpacing.md)
                            .background(
                                selectedIcon == icon ? Color(hex: selectedColor).opacity(0.12) : FTColor.textMuted.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: FTRadius.sm)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding().ftGlass(FTRadius.lg)
    }

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("COLOR").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            HStack(spacing: FTSpacing.md) {
                ForEach(colors, id: \.self) { c in
                    Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                        .overlay(Circle().stroke(.white, lineWidth: selectedColor == c ? 3 : 0))
                        .onTapGesture { selectedColor = c }
                }
            }
        }
        .padding().ftGlass(FTRadius.lg)
    }

    private func fieldRow(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            TextField(placeholder, text: text).keyboardType(keyboard)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
    }

    private func addGoal() {
        let amount = Double(targetAmount) ?? 0
        let goal = SharedFamilyGoal(
            name: name,
            goalDescription: description,
            targetAmount: amount,
            currency: currency,
            targetDate: hasDeadline ? targetDate : nil,
            icon: selectedIcon,
            colorHex: selectedColor
        )
        onAdd(goal)
        dismiss()
    }
}

// MARK: - Shared Goal Detail Sheet

struct SharedGoalDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let goal: SharedFamilyGoal
    let group: FamilyGroup

    @State private var showingContribute = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    goalHeroCard
                    milestonesSection
                    contributionsSection
                    memberBreakdownSection
                    if !goal.isCompleted {
                        contributeButton
                    }
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .navigationTitle(goal.name)
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showingContribute) {
                ContributeToGoalSheet(goal: goal, group: group, currency: appState.baseCurrency)
            }
        }
    }

    private var goalHeroCard: some View {
        VStack(spacing: FTSpacing.xl) {
            HStack {
                ZStack {
                    Circle().fill(Color(hex: goal.colorHex).opacity(0.15)).frame(width: 64, height: 64)
                    Image(systemName: goal.icon).font(.system(size: 28)).foregroundStyle(Color(hex: goal.colorHex))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    if !goal.goalDescription.isEmpty {
                        Text(goal.goalDescription).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                if goal.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.ftTitle).foregroundStyle(FTColor.income)
                }
            }

            VStack(spacing: FTSpacing.sm) {
                HStack {
                    Text("Progress")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(goal.totalContributed.asCompact(currency: appState.baseCurrency) + " / " + goal.targetAmount.asCompact(currency: appState.baseCurrency))
                        .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                    Text(goal.progress.asPercentage())
                        .font(.ftBodySemibold).foregroundStyle(Color(hex: goal.colorHex))
                }
                FTProgressBar(value: goal.progress, color: Color(hex: goal.colorHex), height: 10)
            }

            HStack(spacing: FTSpacing.md) {
                goalStat(label: "Remaining", value: goal.remaining.asCompact(currency: appState.baseCurrency), color: FTColor.expense)
                Divider().frame(height: 36)
                goalStat(label: "Contributors", value: "\(goal.contributionsByMember.count)", color: FTColor.accent)
                Divider().frame(height: 36)
                if let days = goal.daysRemaining {
                    goalStat(label: "Days Left", value: "\(days)", color: FTColor.gold)
                } else {
                    goalStat(label: "No Deadline", value: "—", color: FTColor.textMuted)
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func goalStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var milestonesSection: some View {
        let milestones = FamilyService.shared.milestones(for: goal)
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("MILESTONES").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            HStack(spacing: 0) {
                ForEach(milestones) { milestone in
                    VStack(spacing: FTSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(goal.progress >= milestone.percentage
                                      ? Color(hex: goal.colorHex) : FTColor.textMuted.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: goal.progress >= milestone.percentage ? "checkmark" : "flag.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(goal.progress >= milestone.percentage ? .white : FTColor.textMuted)
                        }
                        Text(milestone.label).font(.system(size: 9)).foregroundStyle(FTColor.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    if milestone.id != milestones.last?.id {
                        Rectangle()
                            .fill(goal.progress >= milestone.percentage ? Color(hex: goal.colorHex) : FTColor.textMuted.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .offset(y: -14)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.sm)
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private var contributionsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("RECENT CONTRIBUTIONS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if goal.contributions.isEmpty {
                Text("No contributions yet. Be the first to contribute!")
                    .font(.ftBody).foregroundStyle(FTColor.textMuted)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(goal.contributions.sorted { $0.date > $1.date }.prefix(5)) { contribution in
                        contributionRow(contribution)
                    }
                }
            }
        }
    }

    private func contributionRow(_ contribution: SharedGoalContribution) -> some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(Color(hex: goal.colorHex).opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: "plus.circle.fill").font(.ftCaption).foregroundStyle(Color(hex: goal.colorHex))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(contribution.memberName).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(contribution.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                if let notes = contribution.notes, !notes.isEmpty {
                    Text(notes).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
            Spacer()
            Text(contribution.amount.formatted(as: appState.baseCurrency))
                .font(.ftBodySemibold).foregroundStyle(Color(hex: goal.colorHex))
        }
        .padding()
        .ftGlass(FTRadius.md)
    }

    private var memberBreakdownSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("BY MEMBER").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ForEach(goal.contributionsByMember.sorted(by: { $0.value > $1.value }), id: \.key) { entry in
                    HStack {
                        Text(String(entry.key.prefix(2)).uppercased())
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: goal.colorHex).opacity(0.7))
                            .clipShape(Circle())
                        Text(entry.key).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text(entry.value.formatted(as: appState.baseCurrency))
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        if goal.totalContributed > 0 {
                            Text((entry.value / goal.totalContributed).asPercentage())
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                    .padding()
                    .ftGlass(FTRadius.sm)
                }
            }
        }
    }

    private var contributeButton: some View {
        Button { showingContribute = true } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Contribution")
            }
            .font(.ftBodySemibold).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
            .background(
                LinearGradient(colors: [Color(hex: goal.colorHex), Color(hex: goal.colorHex).opacity(0.7)],
                               startPoint: .leading, endPoint: .trailing),
                in: .rect(cornerRadius: FTRadius.pill)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Contribute To Goal Sheet

struct ContributeToGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let goal: SharedFamilyGoal
    let group: FamilyGroup
    let currency: String

    @State private var amount = ""
    @State private var notes = ""
    @State private var selectedMemberName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    goalSummary

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("CONTRIBUTION DETAILS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        VStack(spacing: FTSpacing.sm) {
                            fieldRow("Amount (\(currency))", placeholder: "e.g. 500", text: $amount, keyboard: .decimalPad)
                            fieldRow("Notes (optional)", placeholder: "e.g. Monthly contribution", text: $notes)
                        }
                    }
                    .padding().ftGlass(FTRadius.xl)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("CONTRIBUTING AS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        VStack(spacing: FTSpacing.sm) {
                            ForEach(group.members, id: \.id) { member in
                                Button { selectedMemberName = member.name } label: {
                                    HStack(spacing: FTSpacing.md) {
                                        Text(member.initials)
                                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                            .frame(width: 36, height: 36)
                                            .background(Color(hex: member.avatarColorHex))
                                            .clipShape(Circle())
                                        Text(member.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                        Spacer()
                                        if selectedMemberName == member.name {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(FTColor.accent)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        selectedMemberName == member.name ? FTColor.accent.opacity(0.06) : FTColor.textMuted.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: FTRadius.sm)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding().ftGlass(FTRadius.xl)

                    Button(action: contribute) {
                        Text("Add Contribution")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(
                                LinearGradient(colors: [Color(hex: goal.colorHex), Color(hex: goal.colorHex).opacity(0.7)],
                                               startPoint: .leading, endPoint: .trailing),
                                in: .rect(cornerRadius: FTRadius.pill)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(amount.isEmpty || selectedMemberName.isEmpty)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Contribute to Goal")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                selectedMemberName = group.members.first(where: { $0.isCurrentUser })?.name ?? group.members.first?.name ?? ""
            }
        }
    }

    private var goalSummary: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(Color(hex: goal.colorHex).opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: goal.icon).font(.ftTitle).foregroundStyle(Color(hex: goal.colorHex))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("\(goal.remaining.asCompact(currency: currency)) remaining")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            Text(goal.progress.asPercentage())
                .font(.ftBodySemibold).foregroundStyle(Color(hex: goal.colorHex))
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private func fieldRow(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            TextField(placeholder, text: text).keyboardType(keyboard)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
    }

    private func contribute() {
        let contributed = Double(amount) ?? 0
        goal.addContribution(
            amount: contributed,
            memberId: selectedMemberName,
            memberName: selectedMemberName,
            notes: notes.isEmpty ? nil : notes
        )
        try? context.save()
        dismiss()
    }
}
