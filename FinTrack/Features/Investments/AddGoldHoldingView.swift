import SwiftUI
import SwiftData

// MARK: - AddGoldHoldingView

struct AddGoldHoldingView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // MARK: Editing target
    var editingItem: GoldHolding? = nil

    // MARK: - Form state

    // Section 1 — Metal & Form
    @State private var selectedMetal: PreciousMetal = .gold
    @State private var selectedForm: GoldForm = .bar
    @State private var holdingName: String = ""

    // Section 2 — Weight
    @State private var selectedUnitIndex: Int = 0
    @State private var weightText: String = ""

    // Section 3 — Pricing
    @State private var purchasePricePerGramText: String = ""
    @State private var currentPricePerGramText: String = ""
    @State private var currency: String = "AED"

    // Section 4 — Purchase Details
    @State private var purchaseDate: Date = Date()
    @State private var storageLocation: String = ""

    // Section 5 — Dubai Gold Souk
    @State private var isDubaiGoldSouk: Bool = false
    @State private var dubaiShopName: String = "Dubai Gold Souk, Deira"

    // Section 6 — Notes
    @State private var notes: String = ""

    // Name auto-fill guard
    @State private var userEditedName: Bool = false

    // MARK: - Constants

    private let currencies = ["AED", "USD", "EUR", "GBP"]
    private let weightUnitLabels = WeightUnit.allCases.map { $0.rawValue }

    // MARK: - Computed

    private var selectedWeightUnit: WeightUnit {
        WeightUnit.allCases[selectedUnitIndex]
    }

    private var weightInput: Double {
        Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var weightInGrams: Double {
        selectedWeightUnit.toGrams(weightInput)
    }

    private var gramsDisplay: String {
        if weightInGrams <= 0 { return "— g" }
        return String(format: "%.4g g", weightInGrams)
    }

    private var canSave: Bool {
        !holdingName.trimmingCharacters(in: .whitespaces).isEmpty && weightInput > 0
    }

    private var autoName: String {
        "\(selectedMetal.rawValue) \(selectedForm.rawValue)"
    }

    // MARK: - Init

    init(editingItem: GoldHolding? = nil) {
        self.editingItem = editingItem
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        metalFormSection
                        weightSection
                        pricingSection
                        purchaseDetailsSection
                        dubaiGoldSoukSection
                        notesSection
                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                    .animation(.snappy(duration: 0.25), value: isDubaiGoldSouk)
                    .animation(.snappy(duration: 0.2), value: selectedMetal)
                    .animation(.snappy(duration: 0.2), value: selectedForm)
                }

                saveButtonArea
            }
            .navigationTitle(editingItem == nil ? "Add Gold / Metal" : "Edit Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear { populateIfEditing() }
            .onChange(of: selectedMetal) { _, _ in autoFillName() }
            .onChange(of: selectedForm)  { _, _ in autoFillName() }
        }
    }

    // MARK: - Section 1: Metal & Form

    private var metalFormSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Metal & Form")

            VStack(spacing: FTSpacing.md) {
                // Metal grid
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Metal")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)

                    HStack(spacing: FTSpacing.sm) {
                        ForEach(PreciousMetal.allCases, id: \.self) { metal in
                            metalButton(metal)
                        }
                    }
                }

                divider

                // Form picker
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Form")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)

                    HStack(spacing: FTSpacing.sm) {
                        ForEach(GoldForm.allCases, id: \.self) { form in
                            formButton(form)
                        }
                    }
                }

                divider

                // Name
                fieldRow(label: "Name") {
                    TextField(autoName, text: $holdingName)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: holdingName) { old, new in
                            if new != autoName && !new.isEmpty {
                                userEditedName = true
                            } else if new.isEmpty {
                                userEditedName = false
                            }
                        }
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    private func metalButton(_ metal: PreciousMetal) -> some View {
        let isSelected = selectedMetal == metal
        let tint = Color.fromString(metal.color)
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selectedMetal = metal }
        } label: {
            VStack(spacing: FTSpacing.xs) {
                Image(systemName: metal.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : tint)
                Text(metal.symbol)
                    .font(.ftLabel)
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? .white : FTColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FTSpacing.sm + 2)
            .background(
                isSelected
                    ? AnyShapeStyle(tint)
                    : AnyShapeStyle(tint.opacity(0.12)),
                in: .rect(cornerRadius: FTRadius.sm)
            )
        }
        .buttonStyle(.plain)
    }

    private func formButton(_ form: GoldForm) -> some View {
        let isSelected = selectedForm == form
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selectedForm = form }
        } label: {
            VStack(spacing: FTSpacing.xs) {
                Image(systemName: form.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : FTColor.textSecondary)
                Text(form.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : FTColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FTSpacing.sm)
            .background(
                isSelected
                    ? AnyShapeStyle(FTColor.accentGradient)
                    : AnyShapeStyle(FTColor.textPrimary.opacity(0.07)),
                in: .rect(cornerRadius: FTRadius.sm)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 2: Weight

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Weight")

            VStack(spacing: FTSpacing.md) {
                // Unit segmented
                FTSegmentedControl(options: weightUnitLabels, selection: $selectedUnitIndex)

                divider

                // Weight field
                HStack(spacing: FTSpacing.md) {
                    Text("Weight")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    TextField("0.00", text: $weightText)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: 120)
                    Text(selectedWeightUnit.rawValue)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textMuted)
                }

                // Gram equivalent caption
                if weightInput > 0 && selectedWeightUnit != .grams {
                    HStack {
                        Spacer()
                        Text("≈ \(gramsDisplay)")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Section 3: Pricing

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Pricing")

            VStack(spacing: 0) {
                // Purchase price per gram
                VStack(spacing: FTSpacing.xs) {
                    fieldRow(label: "Purchase Price / g") {
                        TextField("0.00", text: $purchasePricePerGramText)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    if selectedWeightUnit != .grams {
                        HStack {
                            Spacer()
                            Text("Price is always stored per gram. Enter per-gram value.")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }

                divider

                // Current price per gram
                VStack(spacing: FTSpacing.xs) {
                    fieldRow(label: "Current Price / g") {
                        TextField("0.00", text: $currentPricePerGramText)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Spacer()
                        Text("Reference: ~\(selectedMetal.referencePriceUSD.formatted(.number.precision(.fractionLength(2)))) USD/g")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }

                divider

                // Currency
                fieldRow(label: "Currency") {
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
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Section 4: Purchase Details

    private var purchaseDetailsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Purchase Details")

            VStack(spacing: 0) {
                // Purchase Date
                HStack(spacing: FTSpacing.md) {
                    Text("Purchase Date")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.sm)

                divider

                // Storage Location
                fieldRow(label: "Storage Location") {
                    TextField("e.g. Home, Bank Safe (optional)", text: $storageLocation)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Section 5: Dubai Gold Souk

    private var dubaiGoldSoukSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Dubai Gold Souk")

            VStack(spacing: 0) {
                FTToggleRow(
                    symbol: "storefront.fill",
                    tint: FTColor.gold,
                    title: "Dubai Gold Souk Purchase",
                    isOn: $isDubaiGoldSouk
                )

                if isDubaiGoldSouk {
                    divider

                    fieldRow(label: "Location / Shop") {
                        TextField("Dubai Gold Souk, Deira", text: $dubaiShopName)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textPrimary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Section 6: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Notes")

            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $notes)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Save Button

    private var saveButtonArea: some View {
        VStack(spacing: 0) {
            Button(editingItem == nil ? "Save Holding" : "Update Holding") {
                save()
            }
            .buttonStyle(.ftPrimary)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.5)
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

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.ftLabel)
            .tracking(1.6)
            .foregroundStyle(FTColor.textMuted)
            .padding(.leading, FTSpacing.xs)
            .padding(.bottom, FTSpacing.xs)
    }

    @ViewBuilder
    private func fieldRow<Trailing: View>(label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize()
            Spacer()
            trailing()
        }
        .padding(.vertical, FTSpacing.md)
    }

    private var divider: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.06))
            .frame(height: 0.5)
    }

    // MARK: - Logic

    private func autoFillName() {
        guard !userEditedName else { return }
        holdingName = autoName
    }

    private func populateIfEditing() {
        guard let item = editingItem else {
            // Default name for new holding
            holdingName = autoName
            return
        }
        selectedMetal      = item.metal
        selectedForm       = item.form
        holdingName        = item.name
        userEditedName     = item.name != "\(item.metal.rawValue) \(item.form.rawValue)"
        currency           = item.currency
        purchaseDate       = item.purchaseDate
        storageLocation    = item.storageLocation ?? ""
        isDubaiGoldSouk    = item.isDubaiGoldSoukPurchase
        dubaiShopName      = item.locationPurchased ?? "Dubai Gold Souk, Deira"
        notes              = item.notes ?? ""

        // Restore weight in item's preferred unit
        let unit = item.weightUnit
        selectedUnitIndex  = WeightUnit.allCases.firstIndex(of: unit) ?? 0
        let displayWeight  = unit.fromGrams(item.weightGrams)
        weightText         = displayWeight > 0 ? String(format: "%g", displayWeight) : ""

        purchasePricePerGramText = item.purchasePricePerGram > 0 ? String(format: "%.2f", item.purchasePricePerGram) : ""
        currentPricePerGramText  = item.currentPricePerGram > 0  ? String(format: "%.2f", item.currentPricePerGram) : ""
    }

    private func save() {
        let purchasePerGram = Double(purchasePricePerGramText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let currentPerGram  = Double(currentPricePerGramText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let trimmedName     = holdingName.trimmingCharacters(in: .whitespaces).isEmpty ? autoName : holdingName.trimmingCharacters(in: .whitespaces)
        let trimmedStorage  = storageLocation.trimmingCharacters(in: .whitespaces)
        let trimmedShop     = dubaiShopName.trimmingCharacters(in: .whitespaces)
        let trimmedNotes    = notes.trimmingCharacters(in: .whitespaces)

        if let item = editingItem {
            item.name                    = trimmedName
            item.metal                   = selectedMetal
            item.form                    = selectedForm
            item.weightGrams             = weightInGrams
            item.weightUnit              = selectedWeightUnit
            item.purchasePricePerGram    = purchasePerGram
            item.currentPricePerGram     = currentPerGram
            item.currency                = currency
            item.purchaseDate            = purchaseDate
            item.storageLocation         = trimmedStorage.isEmpty ? nil : trimmedStorage
            item.isDubaiGoldSoukPurchase = isDubaiGoldSouk
            item.locationPurchased       = isDubaiGoldSouk ? (trimmedShop.isEmpty ? nil : trimmedShop) : nil
            item.notes                   = trimmedNotes.isEmpty ? nil : trimmedNotes
            item.updatedAt               = Date()
        } else {
            let holding = GoldHolding(
                name:                    trimmedName,
                metal:                   selectedMetal,
                form:                    selectedForm,
                weightGrams:             weightInGrams,
                weightUnit:              selectedWeightUnit,
                purchasePricePerGram:    purchasePerGram,
                currentPricePerGram:     currentPerGram,
                currency:                currency,
                storageLocation:         trimmedStorage.isEmpty ? nil : trimmedStorage,
                locationPurchased:       isDubaiGoldSouk ? (trimmedShop.isEmpty ? nil : trimmedShop) : nil,
                isDubaiGoldSoukPurchase: isDubaiGoldSouk,
                purchaseDate:            purchaseDate,
                notes:                   trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            context.insert(holding)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Gold Holding") {
    AddGoldHoldingView()
        .modelContainer(for: GoldHolding.self, inMemory: true)
}

#Preview("Edit Gold Holding") {
    let holding = GoldHolding(
        name: "Gold Bar",
        metal: .gold,
        form: .bar,
        weightGrams: 31.1035,
        weightUnit: .ounces,
        purchasePricePerGram: 88.0,
        currentPricePerGram: 95.0,
        currency: "USD",
        storageLocation: "Bank Safe",
        locationPurchased: "Dubai Gold Souk, Deira",
        isDubaiGoldSoukPurchase: true,
        purchaseDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    )
    return AddGoldHoldingView(editingItem: holding)
        .modelContainer(for: GoldHolding.self, inMemory: true)
}
