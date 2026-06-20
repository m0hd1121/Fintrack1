import SwiftUI
import SwiftData

struct ChildAllowanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var children: [ChildProfile]

    @State private var showingAddChild = false
    @State private var selectedChild: ChildProfile?
    @State private var showingPayment = false
    @State private var paymentTarget: ChildProfile?

    private var activeChildren: [ChildProfile] { children.filter { $0.isActive } }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                if activeChildren.isEmpty {
                    emptyState
                } else {
                    summaryStrip
                    ForEach(activeChildren) { child in
                        childCard(child)
                    }
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Child Allowances")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddChild = true } label: {
                    Image(systemName: "plus").font(.ftCallout).foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddChild) {
            AddChildProfileSheet(currency: appState.baseCurrency) { child in
                context.insert(child)
                try? context.save()
            }
        }
        .sheet(item: $selectedChild) { child in
            ChildDetailSheet(child: child)
        }
        .sheet(item: $paymentTarget) { child in
            RecordAllowancePaymentSheet(child: child, currency: appState.baseCurrency)
        }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: FTSpacing.sm) {
            let totalMonthly = activeChildren.reduce(0.0) { $0 + $1.monthlyAllowance }
            let dueCount = activeChildren.filter { $0.isAllowanceDue }.count
            let totalSavings = activeChildren.reduce(0.0) { $0 + $1.currentSavings }

            summaryTile(
                icon: "calendar.circle.fill",
                value: totalMonthly.asCompact(currency: appState.baseCurrency),
                label: "Monthly Total",
                color: FTColor.gold
            )
            summaryTile(
                icon: "exclamationmark.circle.fill",
                value: "\(dueCount)",
                label: "Due Now",
                color: dueCount > 0 ? FTColor.expense : FTColor.income
            )
            summaryTile(
                icon: "banknote.fill",
                value: totalSavings.asCompact(currency: appState.baseCurrency),
                label: "Total Saved",
                color: FTColor.catTeal
            )
        }
    }

    private func summaryTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.ftCallout).foregroundStyle(color)
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Child Card

    private func childCard(_ child: ChildProfile) -> some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    Circle().fill(Color(hex: child.colorHex).opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: child.icon).font(.ftTitle).foregroundStyle(Color(hex: child.colorHex))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: FTSpacing.sm) {
                        Text(child.name).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        if child.isAllowanceDue {
                            Text("DUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(FTColor.expense).clipShape(Capsule())
                        }
                    }
                    Text("Age \(child.age) · \(child.allowanceFrequency.rawValue)")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    if let next = child.nextDueDate {
                        Text("Next: \(next.formatted(date: .abbreviated, time: .omitted))")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(child.monthlyAllowance.formatted(as: appState.baseCurrency))
                        .font(.ftBodySemibold).foregroundStyle(FTColor.gold)
                    Text("per month").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }

            if !child.savingsGoalName.isEmpty && child.savingsGoalAmount > 0 {
                savingsGoalRow(child)
            }

            HStack(spacing: FTSpacing.sm) {
                Button {
                    paymentTarget = child
                } label: {
                    Label("Pay Now", systemImage: "checkmark.circle.fill")
                        .font(.ftCallout).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.sm)
                        .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.md))
                }
                .buttonStyle(.plain)

                Button {
                    selectedChild = child
                } label: {
                    Label("History", systemImage: "clock.fill")
                        .font(.ftCallout).foregroundStyle(FTColor.accent)
                        .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.sm)
                        .background(FTColor.accent.opacity(0.1), in: .rect(cornerRadius: FTRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func savingsGoalRow(_ child: ChildProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(child.savingsGoalName).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text("\(child.currentSavings.asCompact(currency: appState.baseCurrency)) / \(child.savingsGoalAmount.asCompact(currency: appState.baseCurrency))")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                Text(child.savingsProgress.asPercentage())
                    .font(.ftCallout).foregroundStyle(Color(hex: child.colorHex))
            }
            FTProgressBar(value: child.savingsProgress, color: Color(hex: child.colorHex), height: 6)
        }
        .padding(.vertical, FTSpacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.xl) {
            ZStack {
                Circle().fill(FTColor.gold.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "figure.and.child.holdinghands")
                    .font(.system(size: 36)).foregroundStyle(FTColor.gold)
            }
            Text("No Children Added").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("Add children to track their allowances, payment history, and savings goals.")
                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, FTSpacing.xl)
            Button { showingAddChild = true } label: {
                Label("Add Child Profile", systemImage: "plus")
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                    .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .ftGlass(FTRadius.xl)
        .padding(.top, FTSpacing.xxl)
    }
}

// MARK: - Add Child Profile Sheet

struct AddChildProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currency: String
    let onAdd: (ChildProfile) -> Void

    @State private var name = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date()
    @State private var monthlyAllowance = ""
    @State private var frequency: AllowanceFrequency = .monthly
    @State private var goalName = ""
    @State private var goalAmount = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor = "#4A90D9"

    private let icons = ["star.fill", "heart.fill", "sparkles", "gamecontroller.fill", "book.fill", "bicycle", "football.fill", "music.note"]
    private let colors = ["#4A90D9", "#0E9C8A", "#E8963C", "#9B59B6", "#E74C3C", "#1B8B4B", "#E67E22", "#F1C40F"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    avatarPreview

                    VStack(spacing: FTSpacing.sm) {
                        fieldRow("Name", placeholder: "Child's name", text: $name)
                        DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            .padding(.vertical, 4)
                    }
                    .padding().ftGlass(FTRadius.xl)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("ALLOWANCE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        VStack(spacing: FTSpacing.sm) {
                            fieldRow("Monthly Amount (\(currency))", placeholder: "e.g. 200", text: $monthlyAllowance, keyboard: .decimalPad)
                            Picker("Frequency", selection: $frequency) {
                                ForEach(AllowanceFrequency.allCases, id: \.rawValue) { f in
                                    Text(f.rawValue).tag(f)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding().ftGlass(FTRadius.xl)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("SAVINGS GOAL (OPTIONAL)").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        VStack(spacing: FTSpacing.sm) {
                            fieldRow("Goal Name", placeholder: "e.g. New Bicycle", text: $goalName)
                            fieldRow("Target Amount (\(currency))", placeholder: "e.g. 500", text: $goalAmount, keyboard: .decimalPad)
                        }
                    }
                    .padding().ftGlass(FTRadius.xl)

                    iconPicker
                    colorPicker

                    Button(action: addChild) {
                        Text("Add Child Profile")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
                    }
                    .buttonStyle(.plain).disabled(name.isEmpty || monthlyAllowance.isEmpty)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Add Child Profile")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var avatarPreview: some View {
        VStack(spacing: FTSpacing.sm) {
            ZStack {
                Circle().fill(Color(hex: selectedColor).opacity(0.15)).frame(width: 80, height: 80)
                Image(systemName: selectedIcon).font(.system(size: 36)).foregroundStyle(Color(hex: selectedColor))
            }
            Text(name.isEmpty ? "Child Name" : name)
                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("ICON").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: FTSpacing.sm) {
                ForEach(icons, id: \.self) { icon in
                    Button { selectedIcon = icon } label: {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(selectedIcon == icon ? Color(hex: selectedColor) : FTColor.textMuted)
                            .frame(maxWidth: .infinity).padding()
                            .background(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.12) : FTColor.textMuted.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: FTRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding().ftGlass(FTRadius.lg)
    }

    private var colorPicker: some View {
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

    private func addChild() {
        let amount = Double(monthlyAllowance) ?? 0
        let goal = Double(goalAmount) ?? 0
        let child = ChildProfile(
            name: name,
            dateOfBirth: dateOfBirth,
            monthlyAllowance: amount,
            currency: currency,
            allowanceFrequency: frequency,
            savingsGoalName: goalName,
            savingsGoalAmount: goal,
            colorHex: selectedColor,
            icon: selectedIcon
        )
        onAdd(child)
        dismiss()
    }
}

// MARK: - Record Allowance Payment Sheet

struct RecordAllowancePaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let child: ChildProfile
    let currency: String

    @State private var amount: String
    @State private var notes = ""
    @State private var date = Date()
    @State private var isConfirmed = true

    init(child: ChildProfile, currency: String) {
        self.child = child
        self.currency = currency
        _amount = State(initialValue: String(format: "%.2f", child.monthlyAllowance))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    childSummaryHeader

                    VStack(spacing: FTSpacing.sm) {
                        fieldSection("PAYMENT DETAILS") {
                            VStack(spacing: FTSpacing.sm) {
                                fieldRow("Amount (\(currency))", text: $amount, keyboard: .decimalPad)
                                DatePicker("Date", selection: $date, displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                    .padding(.vertical, 4)
                                fieldRow("Notes (optional)", text: $notes)
                            }
                        }

                        Toggle(isOn: $isConfirmed) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mark as Confirmed").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                Text("10% automatically saved to child's savings")
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            }
                        }
                        .tint(FTColor.accent)
                        .padding()
                        .ftGlass(FTRadius.md)
                    }

                    Button(action: recordPayment) {
                        Text("Record Payment")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
                    }
                    .buttonStyle(.plain).disabled(amount.isEmpty)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Pay Allowance")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var childSummaryHeader: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(Color(hex: child.colorHex).opacity(0.15)).frame(width: 52, height: 52)
                Image(systemName: child.icon).font(.ftTitle).foregroundStyle(Color(hex: child.colorHex))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(child.name).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("Last paid: \(child.lastPaymentDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Never")")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(child.monthlyAllowance.formatted(as: currency)).font(.ftBodySemibold).foregroundStyle(FTColor.gold)
                Text("standard").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private func fieldSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text(title).font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            content()
        }
        .padding().ftGlass(FTRadius.xl)
    }

    private func fieldRow(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            TextField(label, text: text).keyboardType(keyboard)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
    }

    private func recordPayment() {
        let paid = Double(amount) ?? child.monthlyAllowance
        child.addPayment(amount: paid, notes: notes.isEmpty ? nil : notes, isConfirmed: isConfirmed)
        try? context.save()
        dismiss()
    }
}

// MARK: - Child Detail Sheet

struct ChildDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let child: ChildProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    savingsCard
                    paymentHistorySection
                    insightsSection
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .navigationTitle("\(child.name)'s Allowance")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var savingsCard: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SAVINGS PROGRESS").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(child.currentSavings.formatted(as: appState.baseCurrency))
                        .font(.ftAmount).foregroundStyle(FTColor.catTeal)
                    if child.savingsGoalAmount > 0 {
                        Text("Goal: \(child.savingsGoalAmount.formatted(as: appState.baseCurrency))")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle().fill(FTColor.catTeal.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "banknote.fill").font(.ftTitle).foregroundStyle(FTColor.catTeal)
                }
            }
            if child.savingsGoalAmount > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Text(child.savingsGoalName.isEmpty ? "Savings Goal" : child.savingsGoalName)
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text(child.savingsProgress.asPercentage()).font(.ftCallout).foregroundStyle(FTColor.catTeal)
                    }
                    FTProgressBar(value: child.savingsProgress, color: FTColor.catTeal, height: 8)
                }
            }
            HStack(spacing: FTSpacing.md) {
                statTile(label: "Total Paid", value: child.totalPaid.asCompact(currency: appState.baseCurrency), color: FTColor.gold)
                Divider().frame(height: 36)
                statTile(label: "Payments", value: "\(child.payments.count)", color: FTColor.accent)
                Divider().frame(height: 36)
                statTile(label: "Age", value: "\(child.age) yrs", color: FTColor.catPurple)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func statTile(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var paymentHistorySection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("PAYMENT HISTORY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if child.sortedPayments.isEmpty {
                Text("No payments recorded yet.")
                    .font(.ftBody).foregroundStyle(FTColor.textMuted)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(child.sortedPayments) { payment in
                        paymentRow(payment)
                    }
                }
            }
        }
    }

    private func paymentRow(_ payment: AllowancePayment) -> some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill((payment.isConfirmed ? FTColor.income : FTColor.textMuted).opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: payment.isConfirmed ? "checkmark.circle.fill" : "clock.fill")
                    .font(.ftCaption).foregroundStyle(payment.isConfirmed ? FTColor.income : FTColor.textMuted)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                if let notes = payment.notes, !notes.isEmpty {
                    Text(notes).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
            Spacer()
            Text(payment.amount.formatted(as: appState.baseCurrency))
                .font(.ftBodySemibold).foregroundStyle(FTColor.gold)
        }
        .padding()
        .ftGlass(FTRadius.md)
    }

    private var insightsSection: some View {
        let insights = FamilyService.shared.allowanceInsights(child: child, currency: appState.baseCurrency)
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("INSIGHTS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: FTSpacing.sm) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(FTColor.gold).font(.ftCaption)
                        Text(insight).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(FTColor.gold.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                }
            }
        }
    }
}
