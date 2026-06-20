import SwiftUI
import SwiftData

struct LifeEventPlanningView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LifeEventPlan.targetDate) private var plans: [LifeEventPlan]

    @State private var showingAdd = false
    @State private var selectedPlan: LifeEventPlan?

    var activePlans: [LifeEventPlan] { plans.filter { !$0.isCompleted } }
    var completedPlans: [LifeEventPlan] { plans.filter(\.isCompleted) }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                if activePlans.isEmpty && completedPlans.isEmpty {
                    EmptyStateView(
                        icon: "star.fill",
                        title: "Plan Your Life Events",
                        message: "Track and budget for major milestones — marriage, home purchase, baby, education, and more.",
                        actionTitle: "Add Life Event"
                    ) { showingAdd = true }
                    .padding(.top, 60)
                } else {
                    if !activePlans.isEmpty {
                        eventsSection("Upcoming Events", activePlans)
                    }
                    if !completedPlans.isEmpty {
                        eventsSection("Completed", completedPlans)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Life Event Planning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddLifeEventView() }
        .sheet(item: $selectedPlan) { LifeEventDetailView(plan: $0) }
    }

    private func eventsSection(_ title: String, _ events: [LifeEventPlan]) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text(title.uppercased())
                .font(.ftLabel).tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
                .padding(.leading, FTSpacing.xs)

            ForEach(events) { plan in
                LifeEventCard(plan: plan)
                    .onTapGesture { selectedPlan = plan }
            }
        }
    }
}

// MARK: – Event Card

struct LifeEventCard: View {
    @Bindable var plan: LifeEventPlan
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FTColor.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: plan.eventType.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title.isEmpty ? plan.eventType.rawValue : plan.title)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    if plan.monthsUntilEvent > 0 {
                        Text("\(plan.monthsUntilEvent) months away")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    } else {
                        Text(plan.targetDate.formatted)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                if plan.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FTColor.income)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(plan.estimatedCost.formatted(as: plan.currency))
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                        Text("goal")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
            }

            if !plan.isCompleted && plan.estimatedCost > 0 {
                VStack(spacing: 4) {
                    FTProgressBar(value: plan.progress, color: FTColor.accent, height: 6)
                    HStack {
                        Text(plan.savedAmount.formatted(as: plan.currency) + " saved")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text(plan.remaining.formatted(as: plan.currency) + " to go")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

// MARK: – Detail View

struct LifeEventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var plan: LifeEventPlan

    @State private var showingEdit = false
    @State private var localChecklist: [LifeEventChecklistItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    heroCard
                    aiInsightCard
                    budgetCard
                    if !localChecklist.isEmpty { checklistCard }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.vertical, FTSpacing.lg)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle(plan.eventType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showingEdit = true }.foregroundStyle(FTColor.accent)
                }
            }
            .sheet(isPresented: $showingEdit) { AddLifeEventView(editing: plan) }
            .onAppear { loadChecklist() }
        }
    }

    private var heroCard: some View {
        VStack(spacing: FTSpacing.md) {
            ZStack {
                Circle()
                    .fill(FTColor.heroGradient)
                    .frame(width: 72, height: 72)
                Image(systemName: plan.eventType.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(plan.title.isEmpty ? plan.eventType.rawValue : plan.title)
                .font(.ftTitle)
                .foregroundStyle(FTColor.textPrimary)
            Text(plan.targetDate, style: .date)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            if plan.monthsUntilEvent > 0 {
                BadgeView(text: "\(plan.monthsUntilEvent) months away", color: FTColor.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FTSpacing.xl)
        .ftGlass(FTRadius.lg)
    }

    private var aiInsightCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Image(systemName: "brain.head.profile").foregroundStyle(FTColor.accent)
                Text("AI Guidance").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            }
            Text(aiGuidanceText)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .lineSpacing(4)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Budget Tracker").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            FTProgressBar(value: plan.progress, color: progressColor, height: 10)

            HStack {
                metricPill("Saved", plan.savedAmount.formatted(as: plan.currency), FTColor.income)
                Spacer()
                metricPill("Goal", plan.estimatedCost.formatted(as: plan.currency), FTColor.accent)
                Spacer()
                metricPill("Remaining", plan.remaining.formatted(as: plan.currency), FTColor.expense)
            }

            if plan.monthsUntilEvent > 0 && plan.remaining > 0 {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "calendar.badge.clock").foregroundStyle(FTColor.gold)
                    Text("Save \(plan.requiredMonthlySaving.formatted(as: plan.currency))/month to reach your goal on time.")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Text("Checklist").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Text("\(plan.completedChecklistCount)/\(localChecklist.count)")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }

            ForEach(localChecklist.indices, id: \.self) { idx in
                HStack(spacing: FTSpacing.md) {
                    Button {
                        localChecklist[idx].isCompleted.toggle()
                        plan.checklist = localChecklist
                        try? context.save()
                    } label: {
                        Image(systemName: localChecklist[idx].isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(localChecklist[idx].isCompleted ? FTColor.income : FTColor.textMuted)
                            .font(.system(size: 20))
                    }
                    Text(localChecklist[idx].title)
                        .font(.ftBody)
                        .foregroundStyle(localChecklist[idx].isCompleted ? FTColor.textMuted : FTColor.textPrimary)
                        .strikethrough(localChecklist[idx].isCompleted)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var progressColor: Color {
        plan.progress < 0.33 ? FTColor.expense : plan.progress < 0.66 ? FTColor.gold : FTColor.income
    }

    private var aiGuidanceText: String {
        switch plan.eventType {
        case .marriage:
            return "Budget for venue, catering, mahr, and rings. In UAE, set aside for typicaly 30-50% of income for 6-12 months. Consider a joint account post-wedding for shared expenses. Don't forget visa/residency updates for your spouse."
        case .baby:
            return "UAE hospitals charge AED 10k–30k for delivery without insurance. Budget for baby gear (AED 5k–15k), formula/childcare (AED 2k–5k/month), and update health insurance immediately. Start an education fund early — UAE school fees average AED 30k–100k/year."
        case .homeBuying:
            return "In UAE, budget 4% DLD fee + 2% agent fee + AED 5k–20k for Oqood registration. Down payment is typically 20-25% for expats. Factor in service charges (AED 10–25/sqft/year) and maintenance reserves."
        case .jobChange:
            return "Calculate your EOSG (End of Service Gratuity) entitlement. Build a 6-month emergency fund before transitioning. Review your visa situation — UAE work visas are employer-linked, requiring a grace period or new employer sponsorship."
        case .emigration:
            return "Close UAE accounts or convert to non-resident. Transfer funds via Wise or bank transfer to avoid forex losses. Compare remittance costs for large amounts. Plan for housing deposits abroad and healthcare setup before arrival."
        case .education:
            return "Tuition fees vary widely — AED 15k–100k+ per year in UAE private universities. Consider education loans, scholarships, and part-time work. ROI analysis: compare post-graduation salary increases to total cost."
        case .retirement:
            return "Claim your UAE EOSG upon leaving employment. Consider whether to remain in UAE on a retirement visa (requires AED 1M property or savings). Set up a systematic withdrawal plan (4% rule) from your investment portfolio."
        case .other:
            return "Define a clear budget and timeline. Break the goal into monthly savings targets and review progress regularly."
        }
    }

    private func metricPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
    }

    private func loadChecklist() {
        if plan.checklist.isEmpty {
            let defaults = plan.eventType.checklistItems.map { LifeEventChecklistItem(title: $0) }
            plan.checklist = defaults
            try? context.save()
        }
        localChecklist = plan.checklist
    }
}

// MARK: – Add/Edit Sheet

struct AddLifeEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var editing: LifeEventPlan?

    @State private var eventType: LifeEventType = .other
    @State private var title = ""
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var estimatedCost = 0.0
    @State private var savedAmount = 0.0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Type") {
                    Picker("Type", selection: $eventType) {
                        ForEach(LifeEventType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .onChange(of: eventType) { _, t in
                        if estimatedCost == 0 { estimatedCost = t.defaultBudget }
                    }
                }
                Section("Details") {
                    TextField("Custom Name (optional)", text: $title)
                    DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                }
                Section("Budget") {
                    HStack {
                        Text("Estimated Cost")
                        Spacer()
                        TextField("0", value: $estimatedCost, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Already Saved")
                        Spacer()
                        TextField("0", value: $savedAmount, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
            }
            .navigationTitle(editing == nil ? "New Life Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }.foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        guard let e = editing else { return }
        eventType = e.eventType
        title = e.title
        targetDate = e.targetDate
        estimatedCost = e.estimatedCost
        savedAmount = e.savedAmount
        notes = e.notes ?? ""
    }

    private func save() {
        if let e = editing {
            e.eventTypeRaw = eventType.rawValue
            e.title = title
            e.targetDate = targetDate
            e.estimatedCost = estimatedCost
            e.savedAmount = savedAmount
            e.notes = notes.isEmpty ? nil : notes
        } else {
            let plan = LifeEventPlan(
                eventType: eventType,
                title: title,
                targetDate: targetDate,
                estimatedCost: estimatedCost,
                currency: "AED",
                savedAmount: savedAmount,
                notes: notes.isEmpty ? nil : notes
            )
            context.insert(plan)
        }
        try? context.save()
        dismiss()
    }
}
