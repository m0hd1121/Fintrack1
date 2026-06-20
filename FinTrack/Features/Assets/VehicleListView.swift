import SwiftUI
import SwiftData

// MARK: - VehicleListView

struct VehicleListView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    // MARK: Queries
    @Query(filter: #Predicate<Vehicle> { !$0.isArchived },
           sort: \Vehicle.createdAt, order: .reverse)
    private var vehicles: [Vehicle]

    // MARK: State
    @State private var showingAdd = false
    @State private var editingVehicle: Vehicle?
    @State private var vehicleToDelete: Vehicle?
    @State private var showingDeleteConfirm = false

    // MARK: Computed

    private var baseCurrency: String { appState.baseCurrency }

    private var totalValue: Double {
        NetWorthService.shared.vehicleTotal(
            vehicles: Array(vehicles),
            currencyService: currencyService,
            base: baseCurrency
        )
    }

    private var totalDepreciation: Double {
        vehicles.reduce(0) {
            $0 + currencyService.convert($1.depreciation, from: $1.currency, to: baseCurrency)
        }
    }

    private var expiryAlertCount: Int {
        vehicles.filter { $0.isRegistrationExpiringSoon || $0.isInsuranceExpiringSoon }.count
    }

    // MARK: Body

    var body: some View {
        ZStack {
            FTBackdrop()

            if vehicles.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        summaryHeader
                            .padding(.horizontal, FTSpacing.screen)

                        if expiryAlertCount > 0 {
                            expiryWarningBanner
                                .padding(.horizontal, FTSpacing.screen)
                        }

                        vehiclesList
                            .padding(.horizontal, FTSpacing.screen)

                        Color.clear.frame(height: FTSpacing.xxl)
                    }
                    .padding(.top, FTSpacing.md)
                }
            }
        }
        .navigationTitle("Vehicles")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddVehicleView()
        }
        .sheet(item: $editingVehicle) { vehicle in
            AddVehicleView(editingItem: vehicle)
        }
        .confirmationDialog("Delete Vehicle", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let v = vehicleToDelete {
                    context.delete(v)
                    try? context.save()
                }
            }
            Button("Archive Instead") {
                vehicleToDelete?.isArchived = true
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the vehicle.")
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "car.fill", tint: FTColor.catBlue, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Fleet Value")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("\(vehicles.count) \(vehicles.count == 1 ? "vehicle" : "vehicles")")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(totalValue.formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("current value")
                        .font(.ftLabel)
                        .tracking(0.3)
                        .foregroundStyle(FTColor.textMuted)
                }
            }

            Rectangle()
                .fill(FTColor.textPrimary.opacity(0.06))
                .frame(height: 0.5)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TOTAL DEPRECIATION")
                        .font(.ftLabel)
                        .tracking(1.4)
                        .foregroundStyle(FTColor.textMuted)
                    Text(totalDepreciation.formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.expense)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("VEHICLES")
                        .font(.ftLabel)
                        .tracking(1.4)
                        .foregroundStyle(FTColor.textMuted)
                    Text("\(vehicles.count)")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Expiry Warning Banner

    private var expiryWarningBanner: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "exclamationmark.triangle.fill", tint: .orange, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text("Action Required")
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text("\(expiryAlertCount) \(expiryAlertCount == 1 ? "vehicle has" : "vehicles have") expiring registration or insurance")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
        }
        .padding(FTSpacing.lg)
        .background(.orange.opacity(0.10), in: .rect(cornerRadius: FTRadius.lg))
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Vehicles List

    private var vehiclesList: some View {
        VStack(spacing: FTSpacing.sm) {
            ForEach(vehicles) { vehicle in
                vehicleRow(vehicle)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            vehicleToDelete = vehicle
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        Button {
                            vehicle.isArchived = true
                            try? context.save()
                        } label: {
                            Label("Archive", systemImage: "archivebox.fill")
                        }
                        .tint(FTColor.gold)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            editingVehicle = vehicle
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(FTColor.accent)
                    }
            }
        }
    }

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        Button {
            editingVehicle = vehicle
        } label: {
            HStack(spacing: FTSpacing.md) {
                ZStack(alignment: .topTrailing) {
                    FTIconTile(symbol: "car.fill", tint: FTColor.catBlue, size: 48)

                    if vehicle.isRegistrationExpiringSoon || vehicle.isInsuranceExpiringSoon {
                        Circle()
                            .fill(.orange)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: 3, y: -3)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(vehicle.make) \(vehicle.model)")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                    Text("\(vehicle.year) · \(vehicle.depreciationMethod.rawValue)")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(currencyService.convert(vehicle.currentValue, from: vehicle.currency, to: baseCurrency).formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(vehicle.depreciationPercent.asPercentage())
                            .font(.ftCaption)
                    }
                    .foregroundStyle(FTColor.expense)
                }
            }
            .padding(FTSpacing.lg)
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            Spacer()
            FTIconTile(symbol: "car.fill", tint: FTColor.catBlue, size: 72)

            VStack(spacing: FTSpacing.xs) {
                Text("No Vehicles Yet")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Track your vehicles' value, registration, and insurance.")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Add Vehicle") {
                showingAdd = true
            }
            .buttonStyle(.ftPrimary)
            .frame(maxWidth: 240)

            Spacer()
        }
        .padding(.horizontal, FTSpacing.xl)
    }
}

// MARK: - AddVehicleView

struct AddVehicleView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    // MARK: Editing Target
    let editingItem: Vehicle?

    // MARK: Form State

    // Section 1: Vehicle Info
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var vehicleColor: String = ""

    // Section 2: Purchase
    @State private var purchasePriceText: String = ""
    @State private var purchaseDate: Date = Date()
    @State private var currency: String = "AED"

    // Section 3: Depreciation
    @State private var depreciationRate: Double = 15.0
    @State private var depreciationMethod: VehicleDepreciationMethod = .decliningBalance
    @State private var useManualValue: Bool = false
    @State private var manualValueText: String = ""

    // Section 4: Registration
    @State private var registrationNumber: String = ""
    @State private var hasRegistrationExpiry: Bool = false
    @State private var registrationExpiry: Date = Date()

    // Section 5: Insurance
    @State private var insuranceProvider: String = ""
    @State private var hasInsuranceExpiry: Bool = false
    @State private var insuranceExpiry: Date = Date()

    // Section 6: Notes
    @State private var notes: String = ""

    // Validation
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    // MARK: Constants

    private let currencies = ["AED", "USD", "EUR", "GBP", "SAR", "QAR", "KWD", "BHD", "OMR", "EGP", "INR", "PKR"]

    // MARK: Init

    init(editingItem: Vehicle? = nil) {
        self.editingItem = editingItem
    }

    // MARK: Computed

    private var baseCurrency: String { appState.baseCurrency }
    private var purchasePrice: Double { Double(purchasePriceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var isEditing: Bool { editingItem != nil }

    private var estimatedCurrentValue: Double {
        guard purchasePrice > 0 else { return 0 }
        let rate = depreciationRate / 100.0
        let years = max(0, Date().timeIntervalSince(purchaseDate) / (365.25 * 24 * 3600))
        switch depreciationMethod {
        case .straightLine:
            let usefulLife = rate > 0 ? 1.0 / rate : 10
            let annualDep  = purchasePrice / usefulLife
            return max(0, purchasePrice - annualDep * years)
        case .decliningBalance:
            return purchasePrice * pow(max(0, 1 - rate), years)
        }
    }

    private var displayValue: Double {
        if useManualValue, let mv = Double(manualValueText.replacingOccurrences(of: ",", with: ".")) {
            return mv
        }
        return estimatedCurrentValue
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        vehicleInfoSection
                        purchaseSection
                        depreciationSection
                        registrationSection
                        insuranceSection
                        notesSection

                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
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

    // MARK: - Section 1: Vehicle Info

    private var vehicleInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Vehicle Info")

            VStack(spacing: 0) {
                formTextField(label: "Make", placeholder: "e.g. Toyota", text: $make)
                divider
                formTextField(label: "Model", placeholder: "e.g. Land Cruiser", text: $model)
                divider

                // Year Stepper
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Year")
                    Spacer()
                    Stepper("\(year)", value: $year, in: 1980...2030)
                        .labelsHidden()
                    Text("\(year)")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .monospacedDigit()
                        .frame(minWidth: 50, alignment: .trailing)
                }
                .padding(.vertical, FTSpacing.md)

                divider
                formTextField(label: "Color", placeholder: "e.g. White (optional)", text: $vehicleColor)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 2: Purchase

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Purchase")

            VStack(spacing: 0) {
                amountField(label: "Purchase Price", text: $purchasePriceText)
                divider

                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Purchase Date")
                    Spacer()
                    DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.sm)

                divider

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

    // MARK: - Section 3: Depreciation

    private var depreciationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Depreciation")

            VStack(spacing: 0) {
                // Rate Slider
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    HStack {
                        fieldLabel("Annual Rate")
                        Spacer()
                        Text(depreciationRate.asPercentage())
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                    }
                    Slider(value: $depreciationRate, in: 5...30, step: 0.5)
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Method Picker
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Method")
                    Spacer()
                    Menu {
                        ForEach(VehicleDepreciationMethod.allCases, id: \.self) { method in
                            Button {
                                depreciationMethod = method
                            } label: {
                                Text(method.rawValue)
                            }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Text(depreciationMethod.rawValue)
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

                // Estimated Value
                HStack(spacing: FTSpacing.md) {
                    VStack(alignment: .leading, spacing: 3) {
                        fieldLabel("Estimated Value")
                        Text(depreciationMethod.description)
                            .font(.ftLabel)
                            .tracking(0.3)
                            .foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    Text(currencyService.convert(estimatedCurrentValue, from: currency, to: baseCurrency).formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.catBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, FTSpacing.md)

                divider

                // Manual Override Toggle
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "hand.point.up.fill", tint: FTColor.accent, size: 36)
                    Text("Manual Value Override")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Toggle("", isOn: $useManualValue)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                if useManualValue {
                    divider
                    amountField(label: "Current Value", text: $manualValueText)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 4: Registration

    private var registrationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Registration")

            VStack(spacing: 0) {
                formTextField(label: "Plate / Number", placeholder: "Optional", text: $registrationNumber)
                divider

                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "calendar.badge.exclamationmark", tint: .orange, size: 36)
                    Text("Has Expiry Date")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Toggle("", isOn: $hasRegistrationExpiry)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                if hasRegistrationExpiry {
                    divider
                    HStack(spacing: FTSpacing.md) {
                        fieldLabel("Expiry Date")
                        Spacer()
                        DatePicker("", selection: $registrationExpiry, displayedComponents: .date)
                            .labelsHidden()
                            .tint(FTColor.accent)
                    }
                    .padding(.vertical, FTSpacing.sm)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 5: Insurance

    private var insuranceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Insurance")

            VStack(spacing: 0) {
                formTextField(label: "Provider", placeholder: "Optional", text: $insuranceProvider)
                divider

                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "shield.fill", tint: FTColor.catBlue, size: 36)
                    Text("Has Expiry Date")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Toggle("", isOn: $hasInsuranceExpiry)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                if hasInsuranceExpiry {
                    divider
                    HStack(spacing: FTSpacing.md) {
                        fieldLabel("Expiry Date")
                        Spacer()
                        DatePicker("", selection: $insuranceExpiry, displayedComponents: .date)
                            .labelsHidden()
                            .tint(FTColor.accent)
                    }
                    .padding(.vertical, FTSpacing.sm)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Section 6: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Notes")

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

    // MARK: - Save Button Area

    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showValidationError {
                Text(validationMessage)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(isEditing ? "Update Vehicle" : "Save Vehicle") {
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
        make                   = item.make
        model                  = item.model
        year                   = item.year
        vehicleColor           = item.color ?? ""
        purchasePriceText      = item.purchasePrice > 0 ? String(format: "%.2f", item.purchasePrice) : ""
        purchaseDate           = item.purchaseDate
        currency               = item.currency
        depreciationRate       = item.depreciationRate
        depreciationMethod     = item.depreciationMethod
        useManualValue         = item.manualCurrentValue != nil
        manualValueText        = item.manualCurrentValue.map { String(format: "%.2f", $0) } ?? ""
        registrationNumber     = item.registrationNumber ?? ""
        hasRegistrationExpiry  = item.registrationExpiry != nil
        registrationExpiry     = item.registrationExpiry ?? Date()
        insuranceProvider      = item.insuranceProvider ?? ""
        hasInsuranceExpiry     = item.insuranceExpiry != nil
        insuranceExpiry        = item.insuranceExpiry ?? Date()
        notes                  = item.notes ?? ""
    }

    private func save() {
        let trimmedMake = make.trimmingCharacters(in: .whitespaces)
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)

        if trimmedMake.isEmpty || trimmedModel.isEmpty {
            validationMessage = "Make and Model are required."
            withAnimation { showValidationError = true }
            return
        }

        let price = purchasePrice
        if price <= 0 {
            validationMessage = "Purchase price must be greater than zero."
            withAnimation { showValidationError = true }
            return
        }

        showValidationError = false

        let trimmedNotes    = notes.trimmingCharacters(in: .whitespaces)
        let trimmedRegNum   = registrationNumber.trimmingCharacters(in: .whitespaces)
        let trimmedProvider = insuranceProvider.trimmingCharacters(in: .whitespaces)
        let trimmedColor    = vehicleColor.trimmingCharacters(in: .whitespaces)
        let manualValue     = useManualValue ? Double(manualValueText.replacingOccurrences(of: ",", with: ".")) : nil

        if let item = editingItem {
            item.make                 = trimmedMake
            item.model                = trimmedModel
            item.year                 = year
            item.color                = trimmedColor.isEmpty ? nil : trimmedColor
            item.purchasePrice        = price
            item.purchaseDate         = purchaseDate
            item.currency             = currency
            item.depreciationRate     = depreciationRate
            item.depreciationMethod   = depreciationMethod
            item.manualCurrentValue   = manualValue
            item.registrationNumber   = trimmedRegNum.isEmpty ? nil : trimmedRegNum
            item.registrationExpiry   = hasRegistrationExpiry ? registrationExpiry : nil
            item.insuranceProvider    = trimmedProvider.isEmpty ? nil : trimmedProvider
            item.insuranceExpiry      = hasInsuranceExpiry ? insuranceExpiry : nil
            item.notes                = trimmedNotes.isEmpty ? nil : trimmedNotes
            item.updatedAt            = Date()
        } else {
            let vehicle = Vehicle(
                make: trimmedMake,
                model: trimmedModel,
                year: year,
                purchasePrice: price,
                purchaseDate: purchaseDate,
                currency: currency,
                registrationNumber: trimmedRegNum.isEmpty ? nil : trimmedRegNum,
                registrationExpiry: hasRegistrationExpiry ? registrationExpiry : nil,
                insuranceProvider: trimmedProvider.isEmpty ? nil : trimmedProvider,
                insuranceExpiry: hasInsuranceExpiry ? insuranceExpiry : nil,
                depreciationRate: depreciationRate,
                depreciationMethod: depreciationMethod,
                manualCurrentValue: manualValue,
                color: trimmedColor.isEmpty ? nil : trimmedColor,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            context.insert(vehicle)
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Previews

#Preview("Vehicle List") {
    NavigationStack {
        VehicleListView()
    }
    .modelContainer(for: Vehicle.self, inMemory: true)
    .environment(AppState())
    .environment(CurrencyService.shared)
}

#Preview("Add Vehicle") {
    AddVehicleView()
        .modelContainer(for: Vehicle.self, inMemory: true)
        .environment(AppState())
        .environment(CurrencyService.shared)
}
