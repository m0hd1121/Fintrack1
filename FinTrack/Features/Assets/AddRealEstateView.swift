import SwiftUI
import SwiftData

// MARK: - AddRealEstateView

struct AddRealEstateView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // MARK: Editing Target
    let editingItem: RealEstateProperty?

    // MARK: - Form State

    // Section 1: Property Info
    @State private var name: String = ""
    @State private var propertyType: RealEstateType = .apartment
    @State private var address: String = ""

    // Section 2: Financials
    @State private var purchasePriceText: String = ""
    @State private var currentValueText: String = ""
    @State private var mortgageBalanceText: String = ""
    @State private var ownershipPercentageText: String = "100"

    // Section 3: Property Details
    @State private var areaText: String = ""
    @State private var areaUnit: String = "sqm"
    @State private var currency: String = "AED"

    // Section 4: Purchase Date
    @State private var purchaseDate: Date = Date()

    // Section 5: Notes
    @State private var notes: String = ""

    // Validation
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    // MARK: - Constants

    private let currencies = ["AED", "USD", "EUR", "GBP", "SAR", "QAR", "KWD", "BHD", "OMR", "EGP", "INR", "PKR"]

    // MARK: - Init

    init(editingItem: RealEstateProperty? = nil) {
        self.editingItem = editingItem
    }

    // MARK: - Computed

    private var purchasePrice: Double { Double(purchasePriceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var currentValue: Double { Double(currentValueText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var mortgageBalance: Double { Double(mortgageBalanceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var ownershipPercentage: Double { Double(ownershipPercentageText.replacingOccurrences(of: ",", with: ".")) ?? 100 }

    private var equityPreview: Double {
        (currentValue * ownershipPercentage / 100) - mortgageBalance
    }

    private var isEditing: Bool { editingItem != nil }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        propertyInfoSection
                        financialsSection
                        propertyDetailsSection
                        purchaseDateSection
                        notesSection

                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle(isEditing ? "Edit Property" : "Add Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Section 1: Property Info

    private var propertyInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Property Info")

            VStack(spacing: 0) {
                // Name
                formTextField(label: "Name", placeholder: "e.g. Downtown Apartment", text: $name)
                divider

                // Type
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Type")
                    Spacer()
                    Menu {
                        ForEach(RealEstateType.allCases, id: \.self) { type in
                            Button {
                                propertyType = type
                            } label: {
                                Label(type.rawValue, systemImage: type.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Image(systemName: propertyType.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.fromString(propertyType.color))
                            Text(propertyType.rawValue)
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

                // Address
                formTextField(label: "Address", placeholder: "Optional address", text: $address)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 2: Financials

    private var financialsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Financials")

            VStack(spacing: 0) {
                // Purchase Price
                amountField(label: "Purchase Price", text: $purchasePriceText)
                divider

                // Current Market Value
                amountField(label: "Market Value", text: $currentValueText)
                divider

                // Mortgage Balance
                amountField(label: "Mortgage Balance", text: $mortgageBalanceText)
                divider

                // Ownership %
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Ownership %")
                    Spacer()
                    TextField("100", text: $ownershipPercentageText)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Equity Preview
                HStack(spacing: FTSpacing.md) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Equity Preview")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                        Text("(Market × Ownership%) − Mortgage")
                            .font(.ftLabel)
                            .tracking(0.3)
                            .foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    Text(equityPreview.formatted(as: currency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(equityPreview >= 0 ? FTColor.income : FTColor.expense)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 3: Property Details

    private var propertyDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Property Details")

            VStack(spacing: 0) {
                // Area
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Area")
                    TextField("e.g. 120", text: $areaText)
                        .keyboardType(.decimalPad)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                    Spacer()
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Area Unit
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Unit")
                    Spacer()
                    Picker("Unit", selection: $areaUnit) {
                        Text("sqm").tag("sqm")
                        Text("sqft").tag("sqft")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 140)
                    .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Currency
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Currency")
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
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 4: Purchase Date

    private var purchaseDateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Purchase Date")

            VStack(spacing: 0) {
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Date")
                    Spacer()
                    DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.sm)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
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
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Save Button Area

    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showValidationError {
                Text(validationMessage)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(isEditing ? "Update Property" : "Save Property") {
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

    private func amountField(label: String, text: Binding<String>) -> some View {
        HStack(spacing: FTSpacing.md) {
            fieldLabel(label)
            Spacer()
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 160)
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
        guard let item = editingItem else { return }
        name                   = item.name
        propertyType           = item.propertyType
        address                = item.address ?? ""
        purchasePriceText      = item.purchasePrice > 0 ? String(format: "%.2f", item.purchasePrice) : ""
        currentValueText       = item.currentValue > 0 ? String(format: "%.2f", item.currentValue) : ""
        mortgageBalanceText    = item.mortgageBalance > 0 ? String(format: "%.2f", item.mortgageBalance) : ""
        ownershipPercentageText = String(format: "%.0f", item.ownershipPercentage)
        areaText               = item.area.map { String(format: "%.0f", $0) } ?? ""
        areaUnit               = item.areaUnit ?? "sqm"
        currency               = item.currency
        purchaseDate           = item.purchaseDate
        notes                  = item.notes ?? ""
    }

    private func validate() -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            validationMessage = "Property name is required."
            return false
        }
        if purchasePrice <= 0 {
            validationMessage = "Purchase price must be greater than zero."
            return false
        }
        if currentValue < 0 {
            validationMessage = "Current value cannot be negative."
            return false
        }
        let pct = ownershipPercentage
        if pct < 0 || pct > 100 {
            validationMessage = "Ownership must be between 0 and 100%."
            return false
        }
        return true
    }

    private func save() {
        guard validate() else {
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        let trimmedName    = name.trimmingCharacters(in: .whitespaces)
        let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
        let trimmedNotes   = notes.trimmingCharacters(in: .whitespaces)
        let areaValue      = Double(areaText.replacingOccurrences(of: ",", with: "."))

        if let item = editingItem {
            item.name                = trimmedName
            item.propertyType        = propertyType
            item.address             = trimmedAddress.isEmpty ? nil : trimmedAddress
            item.purchasePrice       = purchasePrice
            item.currentValue        = currentValue
            item.mortgageBalance     = mortgageBalance
            item.ownershipPercentage = ownershipPercentage
            item.area                = areaValue
            item.areaUnit            = areaUnit
            item.currency            = currency
            item.purchaseDate        = purchaseDate
            item.notes               = trimmedNotes.isEmpty ? nil : trimmedNotes
            item.updatedAt           = Date()
        } else {
            let property = RealEstateProperty(
                name: trimmedName,
                propertyType: propertyType,
                address: trimmedAddress.isEmpty ? nil : trimmedAddress,
                purchasePrice: purchasePrice,
                purchaseDate: purchaseDate,
                currentValue: currentValue,
                mortgageBalance: mortgageBalance,
                ownershipPercentage: ownershipPercentage,
                currency: currency,
                area: areaValue,
                areaUnit: areaUnit,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            context.insert(property)
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Property") {
    AddRealEstateView()
        .modelContainer(for: RealEstateProperty.self, inMemory: true)
}

#Preview("Edit Property") {
    let p = RealEstateProperty(
        name: "Marina Heights",
        propertyType: .apartment,
        address: "Dubai Marina",
        purchasePrice: 1_200_000,
        currentValue: 1_450_000,
        mortgageBalance: 600_000,
        ownershipPercentage: 100,
        currency: "AED"
    )
    return AddRealEstateView(editingItem: p)
        .modelContainer(for: RealEstateProperty.self, inMemory: true)
}
