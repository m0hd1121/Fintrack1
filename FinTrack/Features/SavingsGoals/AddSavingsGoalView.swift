import SwiftUI
import SwiftData

// MARK: - Add / Edit Savings Goal

struct AddSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var transactions: [Transaction]

    var editingGoal: SavingsGoal? = nil

    // MARK: Common fields
    @State private var selectedType: SavingsGoalType = .custom
    @State private var name = ""
    @State private var targetAmount = ""
    @State private var currentAmount = ""
    @State private var currency = "AED"
    @State private var hasTargetDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedIcon = ""
    @State private var selectedColor = ""
    @State private var notes = ""
    @State private var linkedAccountId: UUID? = nil
    @State private var conflictPriority = 0

    // Auto-contribution
    @State private var autoContribEnabled = false
    @State private var autoContribAmount = ""
    @State private var autoContribFreq: GoalContributionFrequency = .monthly
    @State private var autoContribDay = 1
    @State private var roundUpEnabled = false
    @State private var salaryPercentage = ""

    // Template-specific
    @State private var propertyTargetPrice = ""
    @State private var downPaymentPercent = "20"
    @State private var educationInstitution: String? = nil
    @State private var customInstitution = ""
    @State private var hajjTravelYear = Calendar.current.component(.year, from: Date()) + 1
    @State private var selectedHajjPackage = ""
    @State private var isUmrahTrip = false
    @State private var emergencyMonths = 3

    @State private var showTypeSelector = false
    @State private var currentPhase = 0  // 0=type, 1=details, 2=auto

    private var baseCurrency: String { appState.baseCurrency }
    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }

    private let colors = ["blue", "green", "purple", "orange", "teal", "indigo", "pink", "red"]
    private let sfIcons = [
        "star.fill", "house.fill", "car.fill", "airplane", "graduationcap.fill",
        "heart.fill", "gift.fill", "shield.fill", "moon.stars.fill", "umbrella.fill",
        "bag.fill", "creditcard.fill", "banknote.fill", "camera.fill", "gamecontroller.fill"
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        if editingGoal == nil {
                            typeSection
                        }
                        detailsSection
                        templateSection
                        autoContributionSection
                        notesSection
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: {
                    Text(editingGoal == nil ? "Add Goal" : "Save Changes")
                }
                .buttonStyle(.ftPrimary)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(targetAmount) == nil)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(targetAmount) == nil ? 0.55 : 1)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle(editingGoal == nil ? "New Savings Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .dismissKeyboardOnTap()
        }
        .onAppear { populateIfEditing() }
    }

    // MARK: - Type Selector

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("GOAL TYPE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: FTSpacing.sm) {
                ForEach(SavingsGoalType.allCases, id: \.self) { type in
                    Button { withAnimation(.snappy) { selectedType = type; applyTypeDefaults(type) } } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(selectedType == type ? .white : Color.fromString(type.color))
                                .frame(width: 48, height: 48)
                                .background(selectedType == type ? Color.fromString(type.color) : Color.fromString(type.color).opacity(0.15),
                                            in: .rect(cornerRadius: FTRadius.sm))
                            Text(type.rawValue)
                                .font(.ftLabel).foregroundStyle(FTColor.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FTSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(FTSpacing.md)
            .ftGlass(FTRadius.md)

            if !selectedType.shortDescription.isEmpty {
                Text(selectedType.shortDescription)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
                    .padding(.horizontal, FTSpacing.xs)
            }
        }
    }

    // MARK: - Core Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("DETAILS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)

            VStack(spacing: 0) {
                formRow("Goal Name") {
                    TextField(selectedType == .custom ? "e.g. New Car" : selectedType.rawValue, text: $name)
                        .multilineTextAlignment(.trailing)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                }
                divider
                formRow("Target Amount") {
                    Text(currency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                    TextField("0.00", text: $targetAmount).keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        .frame(maxWidth: 120)
                }
                divider
                formRow("Current Savings") {
                    Text(currency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                    TextField("0.00", text: $currentAmount).keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        .frame(maxWidth: 120)
                }
                divider
                formRow("Currency") {
                    Picker("", selection: $currency) {
                        ForEach(["AED", "USD", "EUR", "GBP", "SAR", "KWD"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accentColor(FTColor.accent)
                }

                if !activeAccounts.isEmpty {
                    divider
                    formRow("Linked Account") {
                        Picker("", selection: Binding<UUID?>(
                            get: { linkedAccountId },
                            set: { linkedAccountId = $0 }
                        )) {
                            Text("None").tag(Optional<UUID>(nil))
                            ForEach(activeAccounts) { acc in
                                Text(acc.name).tag(Optional(acc.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(FTColor.accent)
                    }
                }

                divider
                VStack(spacing: 0) {
                    Toggle(isOn: $hasTargetDate) {
                        Text("Set Target Date").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    }.tint(FTColor.accent).padding(.vertical, 13)
                    if hasTargetDate {
                        Divider().opacity(0.4)
                        DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            .tint(FTColor.accent).padding(.vertical, 9)
                    }
                }

                if hasTargetDate {
                    divider
                    formRow("Priority") {
                        Picker("", selection: $conflictPriority) {
                            Text("Normal").tag(0)
                            Text("High").tag(1)
                            Text("Critical").tag(2)
                        }
                        .pickerStyle(.menu)
                        .accentColor(FTColor.accent)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)

            // Icon picker
            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                Text("ICON").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(sfIcons, id: \.self) { icon in
                            Button { selectedIcon = icon } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(selectedIcon == icon ? Color.fromString(effectiveColor) : FTColor.textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.fromString(effectiveColor).opacity(0.18) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                                    .overlay(RoundedRectangle(cornerRadius: FTRadius.sm)
                                        .strokeBorder(selectedIcon == icon ? Color.fromString(effectiveColor) : Color.clear, lineWidth: 1.5))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(FTSpacing.lg).frame(maxWidth: .infinity, alignment: .leading).ftGlass(FTRadius.md)

            // Color picker
            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                Text("COLOR").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(Color.fromString(color))
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: "checkmark").font(.caption).fontWeight(.bold)
                                .foregroundColor(.white).opacity(selectedColor == color ? 1 : 0))
                            .overlay(Circle().strokeBorder(.white.opacity(selectedColor == color ? 0.6 : 0), lineWidth: 2))
                            .onTapGesture { selectedColor = color }
                    }
                }
            }
            .padding(FTSpacing.lg).frame(maxWidth: .infinity, alignment: .leading).ftGlass(FTRadius.md)
        }
    }

    // MARK: - Template-Specific Fields

    @ViewBuilder
    private var templateSection: some View {
        switch selectedType {
        case .emergencyFund:
            emergencyFundTemplate
        case .downPayment:
            downPaymentTemplate
        case .education:
            educationTemplate
        case .hajj:
            hajjTemplate
        default:
            EmptyView()
        }
    }

    private var emergencyFundTemplate: some View {
        let monthly = SavingsGoalService.shared.estimatedMonthlyExpenses(transactions: transactions)
        let suggested = monthly > 0 ? monthly * Double(emergencyMonths) : (emergencyMonths == 3 ? 15_000.0 : 30_000.0)

        return VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("EMERGENCY FUND").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                formRow("Months of Coverage") {
                    Picker("", selection: $emergencyMonths) {
                        Text("3 months").tag(3)
                        Text("6 months").tag(6)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                if monthly > 0 {
                    divider
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Suggested Target")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            Text(suggested.formatted(as: currency))
                                .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                        }
                        Spacer()
                        Button("Apply") {
                            targetAmount = String(format: "%.0f", suggested)
                            emergencyMonths = emergencyMonths
                        }
                        .font(.ftCallout).foregroundStyle(FTColor.accent)
                    }
                    .padding(.vertical, 13)
                    divider
                    Text("Based on \(monthly.asCompact(currency: currency))/mo avg expenses × \(emergencyMonths) months")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
        .onChange(of: emergencyMonths) { _, months in
            let monthly2 = SavingsGoalService.shared.estimatedMonthlyExpenses(transactions: transactions)
            let s = monthly2 > 0 ? monthly2 * Double(months) : (months == 3 ? 15_000.0 : 30_000.0)
            targetAmount = String(format: "%.0f", s)
        }
    }

    private var downPaymentTemplate: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("DOWN PAYMENT").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                formRow("Property Price") {
                    Text(currency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                    TextField("e.g. 1,500,000", text: $propertyTargetPrice).keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        .frame(maxWidth: 140)
                }
                divider
                formRow("Down Payment %") {
                    Picker("", selection: $downPaymentPercent) {
                        Text("10%").tag("10")
                        Text("15%").tag("15")
                        Text("20%").tag("20")
                        Text("25%").tag("25")
                        Text("30%").tag("30")
                    }
                    .pickerStyle(.menu)
                    .accentColor(FTColor.accent)
                }
                if let price = Double(propertyTargetPrice), price > 0, let pct = Double(downPaymentPercent) {
                    divider
                    let dp = price * (pct / 100)
                    let mortgage = price - dp
                    VStack(spacing: 8) {
                        HStack {
                            Text("Down Payment Required")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(dp.formatted(as: currency))
                                .font(.ftBodySemibold).foregroundStyle(FTColor.catTeal)
                        }
                        HStack {
                            Text("Mortgage Amount")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(mortgage.formatted(as: currency))
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        }
                        HStack {
                            Spacer()
                            Button("Apply Down Payment as Target") {
                                targetAmount = String(format: "%.0f", dp)
                            }
                            .font(.ftCallout).foregroundStyle(FTColor.accent)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)

            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                Text("UAE Mortgage Readiness")
                    .font(.ftCaption.weight(.semibold)).foregroundStyle(FTColor.textSecondary)
                ChecklistRow(text: "UAE nationals: 15% down payment minimum (banks vary)")
                ChecklistRow(text: "Expats: typically 20%–25% required")
                ChecklistRow(text: "Properties >AED 5M may require 30%+ in some banks")
            }
            .padding(FTSpacing.md)
            .ftGlass(FTRadius.md)
        }
    }

    private var educationTemplate: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("EDUCATION FUND").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                formRow("Institution") {
                    Picker("", selection: Binding<String>(
                        get: { educationInstitution ?? "" },
                        set: { educationInstitution = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Select…").tag("")
                        ForEach(SavingsGoalService.uaeTuitionBenchmarks, id: \.university) { b in
                            Text(b.university).tag(b.university)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(FTColor.accent)
                }
                if let inst = educationInstitution,
                   let bench = SavingsGoalService.uaeTuitionBenchmarks.first(where: { $0.university == inst }),
                   bench.annualAED > 0 {
                    divider
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Est. Annual Tuition")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            Text(bench.annualAED.formatted(as: "AED"))
                                .font(.ftBodySemibold).foregroundStyle(FTColor.catPurple)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("4-Year Total")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            Text((bench.annualAED * 4).asCompact(currency: "AED"))
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        }
                    }
                    .padding(.vertical, 12)
                    divider
                    HStack {
                        Spacer()
                        Button("Use 4-Year Total as Target") {
                            targetAmount = String(format: "%.0f", bench.annualAED * 4)
                            currency = "AED"
                        }
                        .font(.ftCallout).foregroundStyle(FTColor.accent)
                        .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var hajjTemplate: some View {
        let packages = isUmrahTrip ? SavingsGoalService.umrahPackageEstimates : SavingsGoalService.hajjPackageEstimates
        return VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("HAJJ / UMRAH").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                formRow("Trip Type") {
                    Picker("", selection: $isUmrahTrip) {
                        Text("Hajj").tag(false)
                        Text("Umrah").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .onChange(of: isUmrahTrip) { _, _ in selectedHajjPackage = "" }
                }
                divider
                formRow("Travel Year") {
                    Picker("", selection: $hajjTravelYear) {
                        ForEach(Array(2025...2035), id: \.self) { year in Text(String(year)).tag(year) }
                    }
                    .pickerStyle(.menu)
                    .accentColor(FTColor.accent)
                }
                divider
                formRow("Package") {
                    Picker("", selection: $selectedHajjPackage) {
                        Text("Select…").tag("")
                        ForEach(packages, id: \.tier) { pkg in Text(pkg.tier).tag(pkg.tier) }
                    }
                    .pickerStyle(.menu)
                    .accentColor(FTColor.accent)
                }
                if let pkg = packages.first(where: { $0.tier == selectedHajjPackage }), pkg.costAED > 0 {
                    divider
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimated Package Cost")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            Text(pkg.costAED.formatted(as: "AED"))
                                .font(.ftBodySemibold).foregroundStyle(FTColor.catTeal)
                        }
                        Spacer()
                        Button("Apply") {
                            targetAmount = String(format: "%.0f", pkg.costAED)
                            currency = "AED"
                        }
                        .font(.ftCallout).foregroundStyle(FTColor.accent)
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Auto-Contribution

    private var autoContributionSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("AUTO-CONTRIBUTION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                Toggle(isOn: $autoContribEnabled) {
                    Label("Automatic Contributions", systemImage: "repeat.circle")
                        .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                }
                .tint(FTColor.accent).padding(.vertical, 13)

                if autoContribEnabled {
                    divider
                    formRow("Amount per Period") {
                        Text(currency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                        TextField("0.00", text: $autoContribAmount).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            .frame(maxWidth: 120)
                    }
                    divider
                    formRow("Frequency") {
                        Picker("", selection: $autoContribFreq) {
                            ForEach(GoalContributionFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(FTColor.accent)
                    }
                    if autoContribFreq == .monthly {
                        divider
                        formRow("Day of Month") {
                            Picker("", selection: $autoContribDay) {
                                ForEach(1...28, id: \.self) { day in Text("Day \(day)").tag(day) }
                            }
                            .pickerStyle(.menu)
                            .accentColor(FTColor.accent)
                        }
                    }
                    divider
                    Toggle(isOn: $roundUpEnabled) {
                        Label("Round-Up Contributions", systemImage: "arrow.up.circle")
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    }
                    .tint(FTColor.accent).padding(.vertical, 13)
                    divider
                    formRow("% of Salary") {
                        TextField("0", text: $salaryPercentage).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            .frame(maxWidth: 80)
                        Text("%").font(.ftBody).foregroundStyle(FTColor.textMuted)
                    }
                    if let amount = Double(autoContribAmount), amount > 0,
                       let target = Double(targetAmount), target > 0 {
                        divider
                        let monthly = amount * autoContribFreq.periodsPerMonth
                        let current = Double(currentAmount) ?? 0
                        let remaining = max(target - current, 0)
                        let monthsNeeded = monthly > 0 ? Int(ceil(remaining / monthly)) : 0
                        let projected = Calendar.current.date(byAdding: .month, value: monthsNeeded, to: Date())
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Projected Completion")
                                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                if let projected, monthsNeeded > 0 {
                                    Text(projected.formatted(date: .abbreviated, time: .omitted))
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                                } else {
                                    Text("—").font(.ftBodySemibold).foregroundStyle(FTColor.textMuted)
                                }
                            }
                            Spacer()
                            Text("\(monthsNeeded) months")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("NOTES").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
            TextEditor(text: $notes)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                .frame(minHeight: 80)
                .padding(FTSpacing.md)
                .scrollContentBackground(.hidden)
                .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Helpers

    private var effectiveColor: String {
        selectedColor.isEmpty ? selectedType.color : selectedColor
    }

    private var divider: some View {
        Divider().opacity(0.4).padding(.leading, 0)
    }

    @ViewBuilder
    private func formRow<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            content()
        }.padding(.vertical, 13)
    }

    private func applyTypeDefaults(_ type: SavingsGoalType) {
        if name.isEmpty || name == selectedType.rawValue { name = type.rawValue }
        if selectedIcon.isEmpty { selectedIcon = type.icon }
        if selectedColor.isEmpty { selectedColor = type.color }
        switch type {
        case .emergencyFund:
            let monthly = SavingsGoalService.shared.estimatedMonthlyExpenses(transactions: transactions)
            let suggested = monthly > 0 ? monthly * Double(emergencyMonths) : 15_000.0
            if targetAmount.isEmpty { targetAmount = String(format: "%.0f", suggested) }
        case .hajj:
            if selectedHajjPackage.isEmpty {
                selectedHajjPackage = SavingsGoalService.hajjPackageEstimates.first?.tier ?? ""
            }
        default: break
        }
    }

    private func populateIfEditing() {
        guard let goal = editingGoal else { return }
        selectedType = goal.goalType
        name = goal.name
        targetAmount = String(format: "%.2f", goal.targetAmount)
        currentAmount = goal.currentAmount > 0 ? String(format: "%.2f", goal.currentAmount) : ""
        currency = goal.currency
        if let date = goal.targetDate { hasTargetDate = true; targetDate = date }
        selectedIcon = goal.icon
        selectedColor = goal.color
        notes = goal.notes ?? ""
        linkedAccountId = goal.linkedAccountId
        conflictPriority = goal.conflictPriority
        autoContribEnabled = goal.autoContributionEnabled
        autoContribAmount = goal.autoContributionAmount > 0 ? String(format: "%.2f", goal.autoContributionAmount) : ""
        autoContribFreq = goal.autoContributionFrequency
        autoContribDay = goal.autoContributionDay
        roundUpEnabled = goal.roundUpEnabled
        salaryPercentage = goal.salaryPercentage > 0 ? String(format: "%.1f", goal.salaryPercentage) : ""
        propertyTargetPrice = goal.propertyTargetPrice > 0 ? String(format: "%.0f", goal.propertyTargetPrice) : ""
        downPaymentPercent = String(format: "%.0f", goal.downPaymentPercent)
        educationInstitution = goal.educationInstitution
        hajjTravelYear = goal.hajjTravelYear > 0 ? goal.hajjTravelYear : Calendar.current.component(.year, from: Date()) + 1
        emergencyMonths = goal.emergencyMonthsTarget
    }

    private func save() {
        let targetAmt = Double(targetAmount) ?? 0
        let currentAmt = Double(currentAmount) ?? 0
        let contribAmt = Double(autoContribAmount) ?? 0
        let salaryPct = Double(salaryPercentage) ?? 0

        if let goal = editingGoal {
            goal.name = name.trimmingCharacters(in: .whitespaces)
            goal.targetAmount = targetAmt
            goal.currentAmount = currentAmt
            goal.currency = currency
            goal.targetDate = hasTargetDate ? targetDate : nil
            goal.icon = selectedIcon
            goal.color = selectedColor
            goal.notes = notes.isEmpty ? nil : notes
            goal.linkedAccountId = linkedAccountId
            goal.conflictPriority = conflictPriority
            goal.autoContributionEnabled = autoContribEnabled
            goal.autoContributionAmount = contribAmt
            goal.autoContributionFrequency = autoContribFreq
            goal.autoContributionDay = autoContribDay
            goal.roundUpEnabled = roundUpEnabled
            goal.salaryPercentage = salaryPct
            goal.goalType = selectedType
            goal.propertyTargetPrice = Double(propertyTargetPrice) ?? 0
            goal.downPaymentPercent = Double(downPaymentPercent) ?? 20
            goal.educationInstitution = educationInstitution
            goal.hajjTravelYear = hajjTravelYear
            goal.emergencyMonthsTarget = emergencyMonths
            goal.updatedAt = Date()
            if goal.currentAmount >= goal.targetAmount { goal.isCompleted = true }
        } else {
            let goal = SavingsGoal(
                name: name.trimmingCharacters(in: .whitespaces),
                targetAmount: targetAmt,
                currentAmount: currentAmt,
                currency: currency,
                targetDate: hasTargetDate ? targetDate : nil,
                icon: selectedIcon,
                color: selectedColor,
                notes: notes.isEmpty ? nil : notes,
                goalType: selectedType,
                linkedAccountId: linkedAccountId,
                autoContributionEnabled: autoContribEnabled,
                autoContributionAmount: contribAmt,
                autoContributionFrequency: autoContribFreq,
                autoContributionDay: autoContribDay,
                roundUpEnabled: roundUpEnabled,
                salaryPercentage: salaryPct,
                conflictPriority: conflictPriority,
                propertyTargetPrice: Double(propertyTargetPrice) ?? 0,
                downPaymentPercent: Double(downPaymentPercent) ?? 20,
                educationInstitution: educationInstitution,
                hajjTravelYear: selectedType == .hajj ? hajjTravelYear : 0,
                emergencyMonthsTarget: emergencyMonths
            )
            context.insert(goal)
            if autoContribEnabled && contribAmt > 0 {
                NotificationService.shared.scheduleSavingsGoalContributionReminder(
                    goal: goal,
                    frequency: autoContribFreq,
                    dayOfMonth: autoContribDay
                )
            }
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Checklist Row Helper

private struct ChecklistRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: FTSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(FTColor.income)
                .padding(.top, 1)
            Text(text)
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
    }
}
