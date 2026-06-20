import SwiftUI
import SwiftData

// MARK: - AddDividendView

struct AddDividendView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // MARK: Editing target
    var editingDividend: Dividend? = nil

    // MARK: Form State

    // Section 1: Security
    @State private var securityName: String = ""

    // Section 2: Dividend Details
    @State private var grossAmountText: String = ""
    @State private var currency: String = "USD"
    @State private var paymentDate: Date = Date()
    @State private var hasExDividendDate: Bool = false
    @State private var exDividendDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

    // Section 3: Tax
    @State private var taxWithholdingText: String = "0"

    // Section 4: Notes
    @State private var notes: String = ""

    // Validation
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    // MARK: Constants

    private let currencies = ["USD", "AED", "EUR", "GBP", "SAR"]

    // MARK: Computed

    private var grossAmount: Double {
        Double(grossAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var taxWithholding: Double {
        Double(taxWithholdingText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var netAmount: Double {
        max(0, grossAmount - taxWithholding)
    }

    // MARK: - Init

    init(editingDividend: Dividend? = nil) {
        self.editingDividend = editingDividend
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        securitySection
                        dividendDetailsSection
                        taxSection
                        notesSection
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle(editingDividend == nil ? "New Dividend" : "Edit Dividend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Sections

    // MARK: Section 1 — Security

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("SECURITY")

            VStack(spacing: 0) {
                formRow {
                    fieldLabel("Security Name")
                    Spacer()
                    TextField("e.g. AAPL, VOO", text: $securityName)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                rowDivider

                // Info note about investmentId
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FTColor.textMuted)
                    Text("A new investment ID will be assigned. You can link this to an existing holding later.")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 2 — Dividend Details

    private var dividendDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("DIVIDEND DETAILS")

            VStack(spacing: 0) {
                // Gross Amount
                formRow {
                    fieldLabel("Gross Amount")
                    Spacer()
                    TextField("0.00", text: $grossAmountText)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                rowDivider

                // Currency
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Currency")
                    Spacer()
                    Menu {
                        ForEach(currencies, id: \.self) { code in
                            Button(code) { currency = code }
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

                rowDivider

                // Payment Date
                formRow {
                    fieldLabel("Payment Date")
                    Spacer()
                    DatePicker("", selection: $paymentDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                rowDivider

                // Ex-Dividend Date toggle
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "calendar.badge.minus", tint: FTColor.gold, size: 36)
                    Text("Ex-Dividend Date")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Toggle("", isOn: $hasExDividendDate)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                if hasExDividendDate {
                    rowDivider

                    formRow {
                        fieldLabel("Ex-Div Date")
                        Spacer()
                        DatePicker("", selection: $exDividendDate, in: ...paymentDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(FTColor.accent)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 3 — Tax

    private var taxSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("TAX")

            VStack(spacing: 0) {
                formRow {
                    fieldLabel("Tax Withholding")
                    Spacer()
                    TextField("0.00", text: $taxWithholdingText)
                        .keyboardType(.decimalPad)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }

                rowDivider

                // Net Amount live display
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Net Amount")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                        if taxWithholding > 0 {
                            Text("Gross \(grossAmount.formatted(as: currency)) − Tax \(taxWithholding.formatted(as: currency))")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                    Spacer()
                    Text(netAmount.formatted(as: currency))
                        .font(.ftHeadline)
                        .foregroundStyle(grossAmount > 0 ? FTColor.income : FTColor.textMuted)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.25), value: netAmount)
                }
                .padding(.vertical, FTSpacing.md)

                // Withholding rate hint
                if grossAmount > 0 && taxWithholding > 0 {
                    rowDivider

                    HStack {
                        Text("Effective Withholding Rate")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                        Spacer()
                        Text(((taxWithholding / grossAmount) * 100).asPercentage())
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                    .padding(.vertical, FTSpacing.md)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 4 — Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("NOTES")

            VStack(alignment: .leading) {
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

    // MARK: Save Button Area

    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showValidationError {
                Text(validationMessage)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(editingDividend == nil ? "Save Dividend" : "Update Dividend") {
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
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Sub-views

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.ftLabel)
            .tracking(1.6)
            .foregroundStyle(FTColor.textMuted)
            .padding(.leading, FTSpacing.xs)
            .padding(.bottom, FTSpacing.xs)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.ftBody)
            .foregroundStyle(FTColor.textSecondary)
            .fixedSize()
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.06))
            .frame(height: 0.5)
    }

    private func formRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: FTSpacing.md) { content() }
            .padding(.vertical, FTSpacing.md)
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let dividend = editingDividend else { return }
        securityName        = dividend.securityName ?? ""
        grossAmountText     = dividend.amount > 0 ? String(format: "%.2f", dividend.amount) : ""
        currency            = dividend.currency
        paymentDate         = dividend.date
        hasExDividendDate   = dividend.exDividendDate != nil
        exDividendDate      = dividend.exDividendDate ?? Calendar.current.date(byAdding: .day, value: -30, to: dividend.date) ?? Date()
        taxWithholdingText  = dividend.taxWithholding > 0 ? String(format: "%.2f", dividend.taxWithholding) : "0"
        notes               = dividend.notes ?? ""
    }

    private func save() {
        let trimmedName   = securityName.trimmingCharacters(in: .whitespaces)
        let trimmedNotes  = notes.trimmingCharacters(in: .whitespaces)

        guard grossAmount > 0 else {
            validationMessage = "Please enter a valid gross amount"
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        let resolvedWithholding = max(0, min(taxWithholding, grossAmount))
        let resolvedNetAmount   = grossAmount - resolvedWithholding
        let resolvedSecurityName = trimmedName.isEmpty ? nil : trimmedName
        let resolvedExDiv        = hasExDividendDate ? exDividendDate : nil

        if let dividend = editingDividend {
            // Update existing
            dividend.securityName   = resolvedSecurityName
            dividend.amount         = grossAmount
            dividend.currency       = currency
            dividend.date           = paymentDate
            dividend.exDividendDate = resolvedExDiv
            dividend.taxWithholding = resolvedWithholding
            dividend.notes          = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            // Create new dividend record
            let dividend = Dividend(
                investmentId:   UUID(),
                amount:         grossAmount,
                currency:       currency,
                date:           paymentDate,
                notes:          trimmedNotes.isEmpty ? nil : trimmedNotes,
                securityName:   resolvedSecurityName,
                exDividendDate: resolvedExDiv,
                taxWithholding: resolvedWithholding
            )
            context.insert(dividend)

            // Create matching income transaction for the net amount
            let txTitle = trimmedName.isEmpty
                ? "Dividend Income"
                : "Dividend — \(trimmedName)"
            let tx = Transaction(
                title:        txTitle,
                amount:       resolvedNetAmount,
                currency:     currency,
                type:         .income,
                category:     .dividends,
                date:         paymentDate,
                notes:        trimmedNotes.isEmpty ? nil : trimmedNotes,
                incomeSource: resolvedSecurityName
            )
            context.insert(tx)
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("New Dividend") {
    AddDividendView()
        .modelContainer(for: [Dividend.self, Transaction.self], inMemory: true)
}

#Preview("Edit Dividend") {
    let dividend = Dividend(
        investmentId: UUID(),
        amount: 125.50,
        currency: "USD",
        date: Date(),
        notes: "Quarterly dividend",
        securityName: "AAPL",
        exDividendDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
        taxWithholding: 18.83
    )
    return AddDividendView(editingDividend: dividend)
        .modelContainer(for: [Dividend.self, Transaction.self], inMemory: true)
}
