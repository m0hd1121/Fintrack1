import SwiftUI
import SwiftData

// MARK: - AddMoneyBorrowedView

struct AddMoneyBorrowedView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // MARK: Editing target
    let editingItem: MoneyBorrowed?

    // MARK: - Form state

    // Section 1: Person Info
    @State private var lenderName: String = ""
    @State private var contactInfo: String = ""

    // Section 2: Amount & Dates
    @State private var amountText: String = ""
    @State private var currency: String = "AED"
    @State private var borrowDate: Date = Date()
    @State private var dueDateEnabled: Bool = false
    @State private var dueDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    // Section 3: Reminders
    @State private var reminderEnabled: Bool = false
    @State private var reminderDaysBefore: Int = 3

    // Section 4: Appearance
    @State private var selectedColorName: String = "red"

    // Section 5: Notes
    @State private var notes: String = ""

    // Validation
    @State private var showValidationError: Bool = false

    // MARK: - Constants

    private let currencies: [String] = [
        "AED", "USD", "EUR", "GBP", "SAR",
        "INR", "PKR", "EGP", "KWD", "BHD", "QAR", "OMR"
    ]

    private let reminderOptions: [Int] = [1, 3, 7]

    private let availableColors: [(name: String, color: Color)] = [
        ("blue",   .blue),
        ("green",  .green),
        ("orange", .orange),
        ("purple", .purple),
        ("teal",   .teal),
        ("pink",   .pink),
        ("red",    .red),
        ("indigo", .indigo)
    ]

    // MARK: - Init

    init(editingItem: MoneyBorrowed? = nil) {
        self.editingItem = editingItem
        if let item = editingItem {
            _lenderName         = State(initialValue: item.lenderName)
            _contactInfo        = State(initialValue: item.contactInfo ?? "")
            _amountText         = State(initialValue: item.amount > 0 ? String(format: "%.2f", item.amount) : "")
            _currency           = State(initialValue: item.currency)
            _borrowDate         = State(initialValue: item.borrowDate)
            _dueDateEnabled     = State(initialValue: item.dueDate != nil)
            _dueDate            = State(initialValue: item.dueDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
            _reminderEnabled    = State(initialValue: item.reminderEnabled)
            _reminderDaysBefore = State(initialValue: item.reminderDaysBefore)
            _selectedColorName  = State(initialValue: item.color)
            _notes              = State(initialValue: item.notes ?? "")
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        personInfoSection
                        amountDatesSection
                        remindersSection
                        appearanceSection
                        notesSection

                        // Bottom padding for the save button
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                // Save button pinned to bottom
                saveButtonArea
            }
            .navigationTitle(editingItem == nil ? "Borrow Record" : "Edit Borrow Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
        }
    }

    // MARK: - Sections

    // MARK: Section 1 — Person Info
    private var personInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Person Info")

            VStack(spacing: 0) {
                // Lender Name
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "person.badge.minus", tint: FTColor.expense, size: 36)
                    Text("Lender")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    TextField("Lender name", text: $lenderName)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Contact Info
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "phone.fill", tint: FTColor.textSecondary, size: 36)
                    Text("Contact")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    TextField("Phone or email (optional)", text: $contactInfo)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.emailAddress)
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 2 — Amount & Dates
    private var amountDatesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Amount & Dates")

            VStack(spacing: 0) {
                // Amount
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "banknote.fill", tint: FTColor.expense, size: 36)
                    Text("Amount")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
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

                // Currency
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "dollarsign.circle.fill", tint: FTColor.textSecondary, size: 36)
                    Text("Currency")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    Menu {
                        ForEach(currencies, id: \.self) { cur in
                            Button(cur) { currency = cur }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Text(currency)
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

                // Borrow Date
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "calendar", tint: FTColor.accent, size: 36)
                    Text("Borrowed On")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    DatePicker("", selection: $borrowDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.sm)

                divider

                // Due Date toggle
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "calendar.badge.exclamationmark", tint: FTColor.expense, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Repayment Date")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textPrimary)
                        Text("When you need to repay by")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    Toggle("", isOn: $dueDateEnabled)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                // Due date picker (conditional)
                if dueDateEnabled {
                    divider

                    HStack(spacing: FTSpacing.md) {
                        Color.clear.frame(width: 36, height: 36)
                        Text("Due Date")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                            .fixedSize()
                        Spacer()
                        DatePicker("", selection: $dueDate, in: Date()..., displayedComponents: .date)
                            .labelsHidden()
                            .tint(FTColor.accent)
                    }
                    .padding(.vertical, FTSpacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
            .animation(.snappy(duration: 0.25), value: dueDateEnabled)
        }
    }

    // MARK: Section 3 — Reminders
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Reminders")

            VStack(spacing: 0) {
                // Reminder toggle
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "bell.fill", tint: FTColor.accent, size: 36)
                    Text("Remind Me")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Toggle("", isOn: $reminderEnabled)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                // Days-before picker (conditional)
                if reminderEnabled {
                    divider

                    HStack(spacing: FTSpacing.md) {
                        Color.clear.frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Days Before Due")
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Text("Remind before repayment date")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                        }
                        Spacer()
                        HStack(spacing: FTSpacing.xs) {
                            ForEach(reminderOptions, id: \.self) { days in
                                reminderDaysButton(days: days)
                            }
                        }
                    }
                    .padding(.vertical, FTSpacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
            .animation(.snappy(duration: 0.25), value: reminderEnabled)
        }
    }

    // MARK: Section 4 — Appearance
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Appearance")

            VStack(alignment: .leading, spacing: FTSpacing.lg) {
                // Color swatches with live preview
                HStack(alignment: .center, spacing: FTSpacing.lg) {
                    // Live preview tile
                    FTIconTile(
                        symbol: "person.badge.minus",
                        tint: Color.fromString(selectedColorName),
                        size: 48
                    )

                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("Color")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)

                        colorSwatches
                    }
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 5 — Notes
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Notes")

            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "note.text", tint: FTColor.textSecondary, size: 36)
                    Text("Notes")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                }

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
                Text("Please fill in required fields")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(editingItem == nil ? "Save Record" : "Update Record") {
                save()
            }
            .buttonStyle(.ftPrimary)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, FTSpacing.xl)
        .padding(.top, FTSpacing.md)
        .background {
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

    private var divider: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.06))
            .frame(height: 0.5)
    }

    private var colorSwatches: some View {
        HStack(spacing: FTSpacing.sm) {
            ForEach(availableColors, id: \.name) { item in
                let isSelected = selectedColorName == item.name

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedColorName = item.name
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 32, height: 32)

                        if isSelected {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2.5)
                                .frame(width: 32, height: 32)

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

    private func reminderDaysButton(days: Int) -> some View {
        let isSelected = reminderDaysBefore == days
        let label = days == 1 ? "1d" : "\(days)d"

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                reminderDaysBefore = days
            }
        } label: {
            Text(label)
                .font(.ftCallout)
                .padding(.horizontal, FTSpacing.md)
                .padding(.vertical, FTSpacing.sm)
                .foregroundStyle(isSelected ? .white : FTColor.textPrimary)
                .background(
                    isSelected
                        ? AnyShapeStyle(FTColor.accent)
                        : AnyShapeStyle(.regularMaterial),
                    in: .capsule
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }

    // MARK: - Save Logic

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard !lenderName.trimmingCharacters(in: .whitespaces).isEmpty, amount > 0 else {
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        let trimmedName    = lenderName.trimmingCharacters(in: .whitespaces)
        let trimmedContact = contactInfo.trimmingCharacters(in: .whitespaces)
        let trimmedNotes   = notes.trimmingCharacters(in: .whitespaces)
        let resolvedDueDate: Date? = dueDateEnabled ? dueDate : nil

        if let item = editingItem {
            // Cancel old notification before rescheduling
            if item.reminderEnabled {
                NotificationService.shared.cancelNotification(id: "borrowed_\(item.id.uuidString)")
            }

            // Update existing record
            item.lenderName         = trimmedName
            item.contactInfo        = trimmedContact.isEmpty ? nil : trimmedContact
            item.amount             = amount
            item.currency           = currency
            item.borrowDate         = borrowDate
            item.dueDate            = resolvedDueDate
            item.notes              = trimmedNotes.isEmpty ? nil : trimmedNotes
            item.reminderEnabled    = reminderEnabled
            item.reminderDaysBefore = reminderDaysBefore
            item.color              = selectedColorName
            item.updatedAt          = Date()

            if reminderEnabled, let due = resolvedDueDate {
                NotificationService.shared.scheduleBorrowedReminder(
                    id: item.id.uuidString,
                    lenderName: trimmedName,
                    amount: amount,
                    currency: currency,
                    dueDate: due,
                    daysBefore: reminderDaysBefore
                )
            }
        } else {
            // Create new record
            let newItem = MoneyBorrowed(
                lenderName: trimmedName,
                contactInfo: trimmedContact.isEmpty ? nil : trimmedContact,
                amount: amount,
                currency: currency,
                borrowDate: borrowDate,
                dueDate: resolvedDueDate,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                status: .active,
                reminderEnabled: reminderEnabled,
                reminderDaysBefore: reminderDaysBefore,
                color: selectedColorName
            )
            context.insert(newItem)

            if reminderEnabled, let due = resolvedDueDate {
                NotificationService.shared.scheduleBorrowedReminder(
                    id: newItem.id.uuidString,
                    lenderName: trimmedName,
                    amount: amount,
                    currency: currency,
                    dueDate: due,
                    daysBefore: reminderDaysBefore
                )
            }
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Borrowed") {
    AddMoneyBorrowedView()
        .modelContainer(for: MoneyBorrowed.self, inMemory: true)
}

#Preview("Edit Borrowed") {
    let item = MoneyBorrowed(
        lenderName: "Sara Al-Mansouri",
        contactInfo: "sara@example.com",
        amount: 5000,
        currency: "AED",
        borrowDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
        dueDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()),
        notes: "Emergency loan for car repair",
        reminderEnabled: true,
        reminderDaysBefore: 7,
        color: "red"
    )
    return AddMoneyBorrowedView(editingItem: item)
        .modelContainer(for: MoneyBorrowed.self, inMemory: true)
}
