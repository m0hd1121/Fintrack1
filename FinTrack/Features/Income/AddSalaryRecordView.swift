import SwiftUI
import SwiftData

// MARK: - AddSalaryRecordView

struct AddSalaryRecordView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // MARK: Editing target
    var editingRecord: SalaryRecord? = nil

    // MARK: Form state

    // Section 1: Employer Info
    @State private var employerName: String = ""
    @State private var jobTitle: String = ""

    // Section 2: Payment Details
    @State private var expectedAmount: String = ""
    @State private var selectedFrequency: PaymentFrequency = .monthly
    @State private var expectedPaymentDay: Int = 28

    // Section 3: Currency
    @State private var currency: String = "AED"

    // Section 4: Appearance (8 color swatches)
    @State private var colorName: String = "green"

    // Section 5: Notes
    @State private var notes: String = ""

    // Section 6: Status
    @State private var isActive: Bool = true

    // Validation
    @State private var showingValidationError: Bool = false
    @State private var validationMessage: String = ""

    // MARK: Constants

    private let availableColors: [(name: String, color: Color)] = [
        ("green",  .green),
        ("teal",   .teal),
        ("blue",   .blue),
        ("purple", .purple),
        ("orange", .orange),
        ("red",    .red),
        ("mint",   .mint),
        ("cyan",   .cyan)
    ]

    private let commonCurrencies: [String] = ["AED", "USD", "EUR", "GBP", "SAR", "QAR"]

    // Whether to show the "paid on day X" label (monthly / semi-monthly only)
    private var showPaymentDayPicker: Bool {
        selectedFrequency == .monthly || selectedFrequency == .semiMonthly
    }

    private var parsedAmount: Double {
        Double(expectedAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        employerInfoSection
                        paymentDetailsSection
                        currencySection
                        appearanceSection
                        notesSection
                        statusSection

                        // Space for pinned save button
                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle(editingRecord == nil ? "New Salary Record" : "Edit Salary Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Section 1: Employer Info

    private var employerInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Employer Info")

            VStack(spacing: 0) {
                formTextField(
                    label: "Employer",
                    placeholder: "e.g. Acme Corporation",
                    text: $employerName
                )
                divider
                formTextField(
                    label: "Job Title",
                    placeholder: "e.g. Senior Engineer",
                    text: $jobTitle
                )
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 2: Payment Details

    private var paymentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Payment Details")

            VStack(spacing: 0) {
                // Expected Amount
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Expected Amount")
                    Spacer()
                    TextField("0.00", text: $expectedAmount)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 160)
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Payment Frequency
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Frequency")
                    Spacer()
                    Menu {
                        ForEach(PaymentFrequency.allCases, id: \.self) { freq in
                            Button {
                                selectedFrequency = freq
                            } label: {
                                Label(freq.rawValue, systemImage: freq.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Image(systemName: selectedFrequency.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FTColor.accent)
                            Text(selectedFrequency.rawValue)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
                .padding(.vertical, FTSpacing.md)

                // Payment day stepper (only for monthly / semi-monthly)
                if showPaymentDayPicker {
                    divider

                    HStack(spacing: FTSpacing.md) {
                        VStack(alignment: .leading, spacing: 3) {
                            fieldLabel("Payment Day")
                            Text("Paid on day \(expectedPaymentDay) of each month")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                        }
                        Spacer()
                        Stepper("", value: $expectedPaymentDay, in: 1...31)
                            .labelsHidden()
                    }
                    .padding(.vertical, FTSpacing.md)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 3: Currency

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Currency")

            VStack(spacing: 0) {
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Currency")
                    Spacer()
                    Menu {
                        ForEach(commonCurrencies, id: \.self) { code in
                            Button {
                                currency = code
                            } label: {
                                Text(code)
                            }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Text(currency)
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 4: Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Appearance")

            VStack(alignment: .leading, spacing: FTSpacing.lg) {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Color")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)

                    colorSwatches
                }
                .padding(.top, FTSpacing.md)

                // Preview tile
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(
                        symbol: "banknote.fill",
                        tint: Color.fromString(colorName),
                        size: 40
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(employerName.isEmpty ? "Employer Name" : employerName)
                            .font(.ftBodySemibold)
                            .foregroundStyle(employerName.isEmpty ? FTColor.textMuted : FTColor.textPrimary)
                            .lineLimit(1)
                        Text(jobTitle.isEmpty ? "Job Title" : jobTitle)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if parsedAmount > 0 {
                        Text(parsedAmount.formatted(as: currency))
                            .font(.ftBodySemibold)
                            .foregroundStyle(Color.fromString(colorName))
                    }
                }
                .padding(.bottom, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var colorSwatches: some View {
        HStack(spacing: FTSpacing.sm) {
            ForEach(availableColors, id: \.name) { item in
                let isSelected = colorName == item.name
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        colorName = item.name
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
                                .font(.system(size: 12, weight: .bold))
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

    // MARK: - Section 5: Notes

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
                    .overlay(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Optional notes about this salary…")
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textMuted)
                                .allowsHitTesting(false)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                    }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 6: Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Status")

            VStack(spacing: 0) {
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(
                        symbol: isActive ? "checkmark.circle.fill" : "pause.circle.fill",
                        tint: isActive ? FTColor.income : FTColor.textMuted,
                        size: 36
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Record")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textPrimary)
                        Text(isActive ? "Tracking payments and sending reminders" : "Record is paused — no alerts")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $isActive)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Save Button Area

    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showingValidationError {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(editingRecord == nil ? "Save Salary Record" : "Update Salary Record") {
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
        .animation(.snappy(duration: 0.2), value: showingValidationError)
    }

    // MARK: - Subviews

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
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let record = editingRecord else { return }
        employerName       = record.employerName
        jobTitle           = record.jobTitle
        currency           = record.currency
        expectedAmount     = record.expectedAmount > 0 ? String(format: "%.2f", record.expectedAmount) : ""
        expectedPaymentDay = record.expectedPaymentDay
        selectedFrequency  = record.paymentFrequency
        colorName          = record.colorName
        notes              = record.notes ?? ""
        isActive           = record.isActive
    }

    private func save() {
        let trimmedEmployer = employerName.trimmingCharacters(in: .whitespaces)
        let trimmedTitle    = jobTitle.trimmingCharacters(in: .whitespaces)
        let amount          = parsedAmount
        let trimmedNotes    = notes.trimmingCharacters(in: .whitespaces)

        // Validation
        guard !trimmedEmployer.isEmpty else {
            validationMessage = "Please enter an employer name."
            withAnimation { showingValidationError = true }
            return
        }
        guard amount > 0 else {
            validationMessage = "Please enter a valid expected amount."
            withAnimation { showingValidationError = true }
            return
        }
        showingValidationError = false

        if let record = editingRecord {
            // Update existing record
            record.employerName         = trimmedEmployer
            record.jobTitle             = trimmedTitle
            record.currency             = currency
            record.expectedAmount       = amount
            record.expectedPaymentDay   = expectedPaymentDay
            record.paymentFrequencyRaw  = selectedFrequency.rawValue
            record.colorName            = colorName
            record.notes                = trimmedNotes.isEmpty ? nil : trimmedNotes
            record.isActive             = isActive
            record.updatedAt            = Date()

            if isActive {
                IncomeService.shared.scheduleSalaryReminder(record: record)
            }
        } else {
            // Create new record
            let record = SalaryRecord(
                employerName:        trimmedEmployer,
                jobTitle:            trimmedTitle,
                currency:            currency,
                expectedAmount:      amount,
                expectedPaymentDay:  expectedPaymentDay,
                paymentFrequencyRaw: selectedFrequency.rawValue,
                isActive:            isActive,
                colorName:           colorName,
                notes:               trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            context.insert(record)
            if isActive {
                IncomeService.shared.scheduleSalaryReminder(record: record)
            }
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Salary Record") {
    AddSalaryRecordView()
        .modelContainer(for: SalaryRecord.self, inMemory: true)
        .environment(AppState())
}

#Preview("Edit Salary Record") {
    let record = SalaryRecord(
        employerName: "Acme Corp",
        jobTitle: "Senior Software Engineer",
        currency: "AED",
        expectedAmount: 28_000,
        expectedPaymentDay: 28,
        paymentFrequencyRaw: PaymentFrequency.monthly.rawValue,
        isActive: true,
        colorName: "teal",
        notes: "Includes housing allowance"
    )
    return AddSalaryRecordView(editingRecord: record)
        .modelContainer(for: SalaryRecord.self, inMemory: true)
        .environment(AppState())
}
