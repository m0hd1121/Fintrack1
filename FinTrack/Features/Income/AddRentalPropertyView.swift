import SwiftUI
import SwiftData

// MARK: - AddRentalPropertyView

struct AddRentalPropertyView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // MARK: Editing target
    var editingProperty: RentalProperty? = nil

    // MARK: Form State

    // Section 1: Property Info
    @State private var propertyName: String = ""
    @State private var propertyType: RentalPropertyType = .apartment
    @State private var address: String = ""

    // Section 2: Financials
    @State private var monthlyRentText: String = ""
    @State private var currency: String = "AED"

    // Section 3: Appearance
    @State private var selectedColorName: String = "brown"

    // Section 4: Notes
    @State private var notes: String = ""

    // Validation
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    // MARK: Constants

    private let currencies = ["AED", "USD", "EUR", "GBP", "SAR"]

    private let availableColors: [(name: String, color: Color)] = [
        ("teal",   .teal),
        ("blue",   .blue),
        ("purple", .purple),
        ("orange", .orange),
        ("red",    .red),
        ("green",  .green),
        ("mint",   .mint),
        ("cyan",   .cyan)
    ]

    // MARK: - Init

    init(editingProperty: RentalProperty? = nil) {
        self.editingProperty = editingProperty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        propertyInfoSection
                        financialsSection
                        appearanceSection
                        notesSection
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle(editingProperty == nil ? "New Property" : "Edit Property")
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

    // MARK: Section 1 — Property Info

    private var propertyInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("PROPERTY INFO")

            VStack(spacing: 0) {
                // Property Name
                formRow {
                    fieldLabel("Property Name")
                    Spacer()
                    TextField("e.g. Downtown Apartment", text: $propertyName)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                rowDivider

                // Property Type picker
                VStack(alignment: .leading, spacing: FTSpacing.xs) {
                    Text("Property Type")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                        .padding(.top, FTSpacing.md)

                    typeGrid
                        .padding(.bottom, FTSpacing.md)
                }

                rowDivider

                // Address
                formRow {
                    fieldLabel("Address")
                    Spacer()
                    TextField("Optional", text: $address)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var typeGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: FTSpacing.sm), count: 4),
            spacing: FTSpacing.sm
        ) {
            ForEach(RentalPropertyType.allCases, id: \.self) { type in
                let isSelected = propertyType == type
                Button {
                    withAnimation(.snappy(duration: 0.2)) { propertyType = type }
                } label: {
                    VStack(spacing: FTSpacing.xs) {
                        Image(systemName: type.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : FTColor.textSecondary)
                            .frame(width: 42, height: 42)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(Color.fromString(selectedColorName))
                                    : AnyShapeStyle(FTColor.textPrimary.opacity(0.07)),
                                in: .rect(cornerRadius: FTRadius.sm - 2)
                            )
                        Text(type.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isSelected ? Color.fromString(selectedColorName) : FTColor.textMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
                .animation(.snappy(duration: 0.2), value: isSelected)
            }
        }
    }

    // MARK: Section 2 — Financials

    private var financialsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("FINANCIALS")

            VStack(spacing: 0) {
                formRow {
                    fieldLabel("Expected Monthly Rent")
                    Spacer()
                    TextField("0.00", text: $monthlyRentText)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                rowDivider

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
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 3 — Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("APPEARANCE")

            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("Color")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)

                colorSwatches

                // Preview
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(
                        symbol: propertyType.icon,
                        tint: Color.fromString(selectedColorName),
                        size: 42
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(propertyName.isEmpty ? "Property Name" : propertyName)
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                        Text(propertyType.rawValue)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
                .padding(.top, FTSpacing.xs)
            }
            .padding(FTSpacing.lg)
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

            Button(editingProperty == nil ? "Save Property" : "Update Property") {
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

    private var colorSwatches: some View {
        HStack(spacing: FTSpacing.sm) {
            ForEach(availableColors, id: \.name) { item in
                let isSelected = selectedColorName == item.name
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selectedColorName = item.name }
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

    // MARK: - Logic

    private func populateIfEditing() {
        guard let prop = editingProperty else { return }
        propertyName      = prop.propertyName
        propertyType      = prop.propertyType
        address           = prop.address ?? ""
        monthlyRentText   = prop.monthlyRentExpected > 0 ? String(format: "%.2f", prop.monthlyRentExpected) : ""
        currency          = prop.currency
        selectedColorName = prop.colorName
        notes             = prop.notes ?? ""
    }

    private func save() {
        let trimmedName    = propertyName.trimmingCharacters(in: .whitespaces)
        let monthlyRent    = Double(monthlyRentText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
        let trimmedNotes   = notes.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            validationMessage = "Property name is required"
            withAnimation { showValidationError = true }
            return
        }
        guard monthlyRent > 0 else {
            validationMessage = "Please enter a valid monthly rent"
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        if let property = editingProperty {
            property.propertyName         = trimmedName
            property.propertyTypeRaw      = propertyType.rawValue
            property.address              = trimmedAddress.isEmpty ? nil : trimmedAddress
            property.monthlyRentExpected  = monthlyRent
            property.currency             = currency
            property.colorName            = selectedColorName
            property.notes                = trimmedNotes.isEmpty ? nil : trimmedNotes
            property.updatedAt            = Date()
        } else {
            let property = RentalProperty(
                propertyName:          trimmedName,
                propertyTypeRaw:       propertyType.rawValue,
                address:               trimmedAddress.isEmpty ? nil : trimmedAddress,
                currency:              currency,
                monthlyRentExpected:   monthlyRent,
                notes:                 trimmedNotes.isEmpty ? nil : trimmedNotes,
                colorName:             selectedColorName
            )
            context.insert(property)
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("New Property") {
    AddRentalPropertyView()
        .modelContainer(for: RentalProperty.self, inMemory: true)
}

#Preview("Edit Property") {
    let property = RentalProperty(
        propertyName: "Downtown Apartment",
        propertyTypeRaw: RentalPropertyType.apartment.rawValue,
        address: "Unit 4B, Marina Tower, Dubai",
        currency: "AED",
        monthlyRentExpected: 8500,
        notes: "2BR with parking",
        colorName: "teal"
    )
    return AddRentalPropertyView(editingProperty: property)
        .modelContainer(for: RentalProperty.self, inMemory: true)
}
