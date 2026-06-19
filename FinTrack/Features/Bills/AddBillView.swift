import SwiftUI
import SwiftData

// MARK: - AddBillView

struct AddBillView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // MARK: Editing target
    let editingBill: Bill?

    // MARK: - Form state

    // Section 1: Basic Info
    @State private var isSubscription: Bool = true
    @State private var name: String = ""
    @State private var provider: String = ""

    // Section 2: Amount & Cycle
    @State private var amountText: String = ""
    @State private var billingCycle: BillingCycle = .monthly
    @State private var currency: String = "AED"
    @State private var nextDueDate: Date = Date()

    // Section 3: Category & Appearance
    @State private var billCategory: BillCategory = .subscriptions
    @State private var selectedIcon: String = "repeat"
    @State private var selectedColorName: String = "teal"

    // Section 4: Payment
    @State private var paymentMethod: PaymentMethod = .bankTransfer
    @State private var isAutoPay: Bool = false
    @State private var autoPayWindowDays: Int = 3

    // Section 5: Reminders
    @State private var reminderDays: Set<Int> = [3]

    // Section 6: Notes
    @State private var notes: String = ""

    // Validation
    @State private var showValidationError: Bool = false

    // MARK: - Constants

    private let availableIcons: [String] = [
        "repeat", "tv.fill", "music.note", "gamecontroller.fill",
        "cloud.fill", "newspaper.fill", "phone.fill", "wifi",
        "bolt.fill", "drop.fill", "house.fill", "car.fill",
        "shield.fill", "heart.fill", "graduationcap.fill", "building.columns.fill",
        "creditcard.fill", "bag.fill"
    ]

    private let availableColors: [(name: String, color: Color)] = [
        ("teal",   .teal),
        ("blue",   .blue),
        ("purple", .purple),
        ("red",    .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("green",  .green),
        ("indigo", .indigo)
    ]

    private let reminderOptions: [Int] = [1, 3, 7]

    // MARK: - Init

    init(editingBill: Bill? = nil) {
        self.editingBill = editingBill
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        basicInfoSection
                        amountCycleSection
                        categoryAppearanceSection
                        paymentSection
                        remindersSection
                        notesSection

                        // Bottom padding for the save button
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                // Save button pinned to bottom
                saveButtonArea
            }
            .navigationTitle(editingBill == nil ? "Add Bill" : "Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear { populateIfEditing() }
            .onChange(of: isSubscription) { _, newVal in
                applySubscriptionDefaults(newVal)
            }
            .onChange(of: billCategory) { _, newVal in
                selectedIcon = newVal.icon
                selectedColorName = newVal.colorName
            }
        }
    }

    // MARK: - Sections

    // MARK: Section 1 — Basic Info
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Basic Info")

            VStack(spacing: 0) {
                // Type toggle
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(
                        symbol: isSubscription ? "repeat" : "bolt.fill",
                        tint: isSubscription ? .teal : .yellow,
                        size: 36
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                        Text(isSubscription ? "Subscription" : "Bill")
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                    }
                    Spacer()
                    Toggle("", isOn: $isSubscription)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Name
                formTextField(
                    label: "Name",
                    placeholder: isSubscription ? "e.g. Netflix" : "e.g. DEWA",
                    text: $name
                )

                divider

                // Provider
                formTextField(
                    label: "Provider",
                    placeholder: "e.g. Netflix Inc. (optional)",
                    text: $provider
                )
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 2 — Amount & Cycle
    private var amountCycleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Amount & Cycle")

            VStack(spacing: 0) {
                // Amount
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Amount")
                    Spacer()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Billing Cycle
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Billing Cycle")
                    Spacer()
                    Menu {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Button(cycle.rawValue) { billingCycle = cycle }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Text(billingCycle.rawValue)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Currency
                formTextField(
                    label: "Currency",
                    placeholder: "AED",
                    text: $currency
                )

                divider

                // Due Date
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Next Due Date")
                    Spacer()
                    DatePicker(
                        "",
                        selection: $nextDueDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.sm)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 3 — Category & Appearance
    private var categoryAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Category & Appearance")

            VStack(alignment: .leading, spacing: FTSpacing.lg) {
                // Category picker
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Category")
                    Spacer()
                    Menu {
                        ForEach(BillCategory.allCases, id: \.self) { cat in
                            Button {
                                billCategory = cat
                            } label: {
                                Label(cat.rawValue, systemImage: cat.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Image(systemName: billCategory.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.fromString(billCategory.colorName))
                            Text(billCategory.rawValue)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
                .padding(.top, FTSpacing.md)

                divider

                // Icon picker
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Icon")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)

                    iconGrid
                }

                divider

                // Color picker
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Color")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)

                    colorSwatches
                }
                .padding(.bottom, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 4 — Payment
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Payment")

            VStack(spacing: 0) {
                // Payment method
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Method")
                    Spacer()
                    Menu {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Button(method.rawValue) { paymentMethod = method }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Text(paymentMethod.rawValue)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Auto-pay toggle
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "arrow.triangle.2.circlepath", tint: FTColor.accent, size: 36)
                    Text("Auto-Pay")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Toggle("", isOn: $isAutoPay)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                // Auto-pay window stepper (conditional)
                if isAutoPay {
                    divider

                    HStack(spacing: FTSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Pay Check Window")
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Text("\(autoPayWindowDays) \(autoPayWindowDays == 1 ? "day" : "days")")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                        }
                        Spacer()
                        Stepper("", value: $autoPayWindowDays, in: 1...14)
                            .labelsHidden()
                    }
                    .padding(.vertical, FTSpacing.md)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 5 — Reminders
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Reminders")

            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("Notify me before due date")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)

                HStack(spacing: FTSpacing.sm) {
                    ForEach(reminderOptions, id: \.self) { days in
                        reminderChip(days: days)
                    }
                    Spacer()
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 6 — Notes
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Notes")

            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $notes)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Save button area
    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showValidationError {
                Text("Name and amount are required")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(editingBill == nil ? "Save Bill" : "Update Bill") {
                save()
            }
            .buttonStyle(.ftPrimary)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, FTSpacing.xl)
        .padding(.top, FTSpacing.md)
        .background {
            // Subtle gradient fade from clear to bgBase so content doesn't clip harshly
            LinearGradient(
                colors: [FTColor.bgBase.opacity(0), FTColor.bgBase],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Sub-views

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.ftLabel)
            .tracking(1.6)
            .foregroundStyle(FTColor.textMuted)
            .padding(.leading, FTSpacing.xs)
            .padding(.bottom, FTSpacing.xs)
    }

    private func formTextField(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: FTSpacing.md) {
            fieldLabel(label)
            TextField(placeholder, text: text)
                .font(.ftBody)
                .foregroundStyle(FTColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, FTSpacing.md)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.ftBody)
            .foregroundStyle(FTColor.textSecondary)
            .fixedSize()
    }

    private var divider: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 0)
    }

    // MARK: Icon grid (6-per-row)
    private var iconGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: FTSpacing.sm), count: 6),
            spacing: FTSpacing.sm
        ) {
            ForEach(availableIcons, id: \.self) { icon in
                let isSelected = selectedIcon == icon
                let tintColor = Color.fromString(selectedColorName)

                Button {
                    selectedIcon = icon
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : FTColor.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(
                            isSelected
                                ? AnyShapeStyle(tintColor)
                                : AnyShapeStyle(FTColor.textPrimary.opacity(0.07)),
                            in: .rect(cornerRadius: FTRadius.sm - 2)
                        )
                }
                .buttonStyle(.plain)
                .animation(.snappy(duration: 0.2), value: isSelected)
            }
        }
    }

    // MARK: Color swatches
    private var colorSwatches: some View {
        HStack(spacing: FTSpacing.sm) {
            ForEach(availableColors, id: \.name) { item in
                let isSelected = selectedColorName == item.name

                Button {
                    selectedColorName = item.name
                } label: {
                    ZStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 30, height: 30)

                        if isSelected {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2.5)
                                .frame(width: 30, height: 30)

                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .animation(.snappy(duration: 0.2), value: isSelected)
            }
            Spacer()
        }
    }

    // MARK: Reminder chip
    private func reminderChip(days: Int) -> some View {
        let isOn = reminderDays.contains(days)
        let label = days == 1 ? "1 day" : "\(days) days"

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                if isOn {
                    reminderDays.remove(days)
                } else {
                    reminderDays.insert(days)
                }
            }
        } label: {
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: isOn ? "bell.fill" : "bell")
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.ftCallout)
            }
            .padding(.horizontal, FTSpacing.md)
            .padding(.vertical, FTSpacing.sm + 1)
            .foregroundStyle(isOn ? .white : FTColor.textPrimary)
            .background(
                isOn
                    ? AnyShapeStyle(FTColor.accent)
                    : AnyShapeStyle(.regularMaterial),
                in: .capsule
            )
            .overlay(
                Capsule()
                    .strokeBorder(isOn ? Color.clear : Color.white.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let bill = editingBill else { return }

        isSubscription     = bill.isSubscription
        name               = bill.name
        provider           = bill.provider ?? ""
        amountText         = bill.amount > 0 ? String(format: "%.2f", bill.amount) : ""
        billingCycle       = bill.billingCycle
        currency           = bill.currency
        nextDueDate        = bill.nextDueDate
        billCategory       = bill.billCategory
        selectedIcon       = bill.icon
        selectedColorName  = bill.colorName
        paymentMethod      = bill.paymentMethod
        isAutoPay          = bill.isAutoPay
        autoPayWindowDays  = bill.autoPayWindowDays
        reminderDays       = Set(bill.reminderDaysBefore)
        notes              = bill.notes ?? ""
    }

    private func applySubscriptionDefaults(_ isSubscription: Bool) {
        if isSubscription {
            if selectedIcon == "bolt.fill"  { selectedIcon = "repeat" }
            if selectedColorName == "yellow" { selectedColorName = "teal" }
        } else {
            if selectedIcon == "repeat" { selectedIcon = "bolt.fill" }
            if selectedColorName == "teal" { selectedColorName = "yellow" }
        }
    }

    private func save() {
        // Validation
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, amount > 0 else {
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        let trimmedName     = name.trimmingCharacters(in: .whitespaces)
        let trimmedProvider = provider.trimmingCharacters(in: .whitespaces)
        let trimmedNotes    = notes.trimmingCharacters(in: .whitespaces)
        let reminderArray   = reminderDays.sorted()

        if let bill = editingBill {
            // Update existing
            bill.name               = trimmedName
            bill.provider           = trimmedProvider.isEmpty ? nil : trimmedProvider
            bill.amount             = amount
            bill.billingCycle       = billingCycle
            bill.currency           = currency
            bill.nextDueDate        = nextDueDate
            bill.billCategory       = billCategory
            bill.icon               = selectedIcon
            bill.colorName          = selectedColorName
            bill.paymentMethod      = paymentMethod
            bill.isAutoPay          = isAutoPay
            bill.autoPayWindowDays  = autoPayWindowDays
            bill.reminderDaysBefore = reminderArray
            bill.notes              = trimmedNotes.isEmpty ? nil : trimmedNotes
            bill.isSubscription     = isSubscription

            BillService.shared.scheduleReminders(for: bill)
        } else {
            // Create new
            let bill = Bill(
                name:               trimmedName,
                provider:           trimmedProvider.isEmpty ? nil : trimmedProvider,
                billCategory:       billCategory,
                amount:             amount,
                currency:           currency,
                billingCycle:       billingCycle,
                nextDueDate:        nextDueDate,
                isAutoPay:          isAutoPay,
                autoPayWindowDays:  autoPayWindowDays,
                paymentMethod:      paymentMethod,
                notes:              trimmedNotes.isEmpty ? nil : trimmedNotes,
                colorName:          selectedColorName,
                icon:               selectedIcon,
                isActive:           true,
                isSubscription:     isSubscription,
                reminderDaysBefore: reminderArray
            )
            context.insert(bill)
            BillService.shared.scheduleReminders(for: bill)
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Bill") {
    AddBillView()
        .modelContainer(for: Bill.self, inMemory: true)
}

#Preview("Edit Bill") {
    let bill = Bill(
        name: "Netflix",
        provider: "Netflix Inc.",
        billCategory: .subscriptions,
        amount: 55.00,
        currency: "AED",
        billingCycle: .monthly,
        nextDueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        isAutoPay: true,
        autoPayWindowDays: 3,
        paymentMethod: .creditCard,
        notes: "Family plan",
        colorName: "teal",
        icon: "tv.fill",
        isSubscription: true,
        reminderDaysBefore: [1, 3]
    )
    return AddBillView(editingBill: bill)
        .modelContainer(for: Bill.self, inMemory: true)
}
