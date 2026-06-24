import SwiftUI
import SwiftData

// MARK: - PersonalAssetsListView

struct PersonalAssetsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    @Query(filter: #Predicate<PersonalAsset> { $0.isArchived == false },
           sort: \PersonalAsset.createdAt, order: .reverse)
    private var assets: [PersonalAsset]

    @State private var showingAdd = false
    @State private var editingAsset: PersonalAsset?
    @State private var selectedCategory: PersonalAssetCategory?

    private var base: String { appState.baseCurrency }

    private var filtered: [PersonalAsset] {
        guard let cat = selectedCategory else { return assets }
        return assets.filter { $0.category == cat }
    }

    private var totalMarketValue: Double {
        assets.reduce(0) { $0 + currencyService.convert($1.estimatedMarketValue, from: $1.currency, to: base) }
    }
    private var totalInsuranceValue: Double {
        assets.reduce(0) { $0 + currencyService.convert($1.insuranceValue, from: $1.currency, to: base) }
    }
    private var totalPurchaseValue: Double {
        assets.reduce(0) { $0 + currencyService.convert($1.purchasePrice, from: $1.currency, to: base) }
    }

    var body: some View {
        ZStack {
            FTBackdrop()
            if assets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        summaryCard
                        categoryFilter
                        assetList
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Personal Assets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddPersonalAssetView() }
        .sheet(item: $editingAsset) { AddPersonalAssetView(editingItem: $0) }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: FTSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Market Value").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    Text(totalMarketValue.formatted(as: base)).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Insurance Value").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    Text(totalInsuranceValue.formatted(as: base)).font(.ftBodySemibold).foregroundStyle(FTColor.catBlue)
                }
            }
            Divider()
            HStack {
                Text("\(assets.count) item\(assets.count == 1 ? "" : "s")")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Spacer()
                let gain = totalMarketValue - totalPurchaseValue
                Text(gain >= 0 ? "+\(gain.asCompact(currency: base))" : gain.asCompact(currency: base))
                    .font(.ftCaption)
                    .foregroundStyle(gain >= 0 ? FTColor.income : FTColor.expense)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FilterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(PersonalAssetCategory.allCases, id: \.self) { cat in
                    FilterChip(title: cat.rawValue, isSelected: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
        }
        .padding(.horizontal, -FTSpacing.screen)
    }

    // MARK: - Asset List

    private var assetList: some View {
        VStack(spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, asset in
                PersonalAssetRow(asset: asset, base: base)
                    .contentShape(Rectangle())
                    .onTapGesture { editingAsset = asset }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { deleteAsset(asset) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { editingAsset = asset } label: {
                            Label("Edit", systemImage: "pencil")
                        }.tint(FTColor.accent)
                    }
                if idx < filtered.count - 1 {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            Spacer()
            FTIconTile(symbol: "sparkles", tint: FTColor.gold, size: 64)
            VStack(spacing: FTSpacing.sm) {
                Text("No Personal Assets").font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                Text("Track jewelry, watches, electronics,\nart, and other high-value items.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Add Item") { showingAdd = true }
                .buttonStyle(FTPrimaryButtonStyle())
                .padding(.horizontal, FTSpacing.xxl)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, FTSpacing.screen)
    }

    private func deleteAsset(_ asset: PersonalAsset) {
        context.delete(asset)
    }
}

// MARK: - PersonalAssetRow

private struct PersonalAssetRow: View {
    @Environment(CurrencyService.self) private var currencyService
    let asset: PersonalAsset
    let base: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: asset.category.icon,
                       tint: Color.fromString(asset.category.color), size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                HStack(spacing: FTSpacing.xs) {
                    Text(asset.category.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    if let brand = asset.brand {
                        Text("·").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        Text(brand).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(currencyService.convert(asset.estimatedMarketValue, from: asset.currency, to: base)
                    .formatted(as: base))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                let gain = asset.appreciationPercent
                Text(gain >= 0 ? "+\(gain.asPercentage())" : gain.asPercentage())
                    .font(.ftCaption)
                    .foregroundStyle(asset.isAppreciated ? FTColor.income : FTColor.expense)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - AddPersonalAssetView

struct AddPersonalAssetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    var editingItem: PersonalAsset? = nil

    @State private var name = ""
    @State private var brand = ""
    @State private var selectedCategory: PersonalAssetCategory = .other
    @State private var purchasePrice = ""
    @State private var purchaseDate = Date()
    @State private var estimatedMarketValue = ""
    @State private var insuranceValue = ""
    @State private var serialNumber = ""
    @State private var currency = "AED"
    @State private var notes = ""
    @State private var showingValidation = false

    private let currencies = ["AED","USD","EUR","GBP","SAR","QAR","KWD","BHD","OMR","EGP","INR","PKR"]

    init(editingItem: PersonalAsset? = nil) {
        self.editingItem = editingItem
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        categoryGrid
                        basicInfoSection
                        financialsSection
                        detailsSection
                        notesSection
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle(editingItem == nil ? "Add Asset" : "Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { prefill() }
            .safeAreaInset(edge: .bottom) {
                saveButton.padding([.horizontal, .bottom], FTSpacing.screen)
            }
        }
    }

    // MARK: Category Grid

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("CATEGORY").font(.ftLabel).foregroundStyle(FTColor.textMuted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: FTSpacing.sm), count: 4),
                      spacing: FTSpacing.sm) {
                ForEach(PersonalAssetCategory.allCases, id: \.self) { cat in
                    Button {
                        selectedCategory = cat
                        if name.isEmpty { name = cat.rawValue }
                    } label: {
                        VStack(spacing: FTSpacing.xs) {
                            FTIconTile(symbol: cat.icon,
                                       tint: selectedCategory == cat ? Color.fromString(cat.color) : FTColor.textMuted,
                                       size: 40)
                            Text(cat.rawValue)
                                .font(.ftLabel)
                                .foregroundStyle(selectedCategory == cat ? FTColor.textPrimary : FTColor.textSecondary)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .padding(.vertical, FTSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(selectedCategory == cat ? Color.fromString(cat.color).opacity(0.1) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: FTRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: FTRadius.sm)
                                .stroke(selectedCategory == cat ? Color.fromString(cat.color).opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            Text("ITEM DETAILS").font(.ftLabel).foregroundStyle(FTColor.textMuted)
            VStack(spacing: 0) {
                HStack {
                    Text("Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    TextField("e.g. Rolex Submariner", text: $name)
                        .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                }
                .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
                Divider().padding(.leading, FTSpacing.lg)
                HStack {
                    Text("Brand").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    TextField("Optional", text: $brand)
                        .multilineTextAlignment(.trailing).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                }
                .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
                Divider().padding(.leading, FTSpacing.lg)
                HStack {
                    Text("Serial Number").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    TextField("Optional", text: $serialNumber)
                        .multilineTextAlignment(.trailing).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                }
                .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
            }
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: Financials

    private var financialsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            Text("VALUATION").font(.ftLabel).foregroundStyle(FTColor.textMuted)
            VStack(spacing: 0) {
                amountRow(label: "Purchase Price", text: $purchasePrice, placeholder: "0.00")
                Divider().padding(.leading, FTSpacing.lg)
                DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
                Divider().padding(.leading, FTSpacing.lg)
                amountRow(label: "Market Value", text: $estimatedMarketValue, placeholder: "Current estimate")
                Divider().padding(.leading, FTSpacing.lg)
                amountRow(label: "Insurance Value", text: $insuranceValue, placeholder: "0.00 (optional)")
                Divider().padding(.leading, FTSpacing.lg)
                HStack {
                    Text("Currency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Picker("", selection: $currency) {
                        ForEach(currencies, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                }
                .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
            }
            .ftGlass(FTRadius.lg)
            // Gain/loss preview
            if let pp = Double(purchasePrice), let mv = Double(estimatedMarketValue), pp > 0 {
                let gain = mv - pp
                HStack {
                    Image(systemName: gain >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(gain >= 0
                         ? "+\(gain.formatted(as: currency)) (\((gain/pp*100).asPercentage()))"
                         : "\(gain.formatted(as: currency)) (\((gain/pp*100).asPercentage()))")
                }
                .font(.ftCaption)
                .foregroundStyle(gain >= 0 ? FTColor.income : FTColor.expense)
                .padding(.horizontal, FTSpacing.sm)
            }
        }
    }

    // MARK: Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            Text("PURCHASE DETAILS").font(.ftLabel).foregroundStyle(FTColor.textMuted)
            VStack(spacing: 0) {
                DatePicker("Acquisition Date", selection: $purchaseDate, displayedComponents: .date)
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
            }
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            Text("NOTES").font(.ftLabel).foregroundStyle(FTColor.textMuted)
            TextEditor(text: $notes)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                .frame(minHeight: 80)
                .padding(FTSpacing.md)
                .ftGlass(FTRadius.lg)
        }
    }

    // MARK: Save Button

    private var saveButton: some View {
        Button(editingItem == nil ? "Save Asset" : "Update Asset") {
            guard validate() else { showingValidation = true; return }
            save()
        }
        .buttonStyle(FTPrimaryButtonStyle())
        .alert("Missing Information", isPresented: $showingValidation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enter a name, purchase price, and market value.")
        }
    }

    // MARK: Helpers

    private func amountRow(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            TextField(placeholder, text: text).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                .frame(width: 140)
        }
        .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
    }

    private func validate() -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(purchasePrice) != nil &&
        Double(estimatedMarketValue) != nil
    }

    private func prefill() {
        guard let item = editingItem else { return }
        name = item.name
        brand = item.brand ?? ""
        selectedCategory = item.category
        purchasePrice = String(item.purchasePrice)
        purchaseDate = item.purchaseDate
        estimatedMarketValue = String(item.estimatedMarketValue)
        insuranceValue = item.insuranceValue > 0 ? String(item.insuranceValue) : ""
        serialNumber = item.serialNumber ?? ""
        currency = item.currency
        notes = item.notes ?? ""
    }

    private func save() {
        let pp  = Double(purchasePrice) ?? 0
        let mv  = Double(estimatedMarketValue) ?? 0
        let ins = Double(insuranceValue) ?? 0

        if let item = editingItem {
            item.name = name.trimmingCharacters(in: .whitespaces)
            item.brand = brand.isEmpty ? nil : brand
            item.category = selectedCategory
            item.purchasePrice = pp
            item.purchaseDate = purchaseDate
            item.estimatedMarketValue = mv
            item.insuranceValue = ins
            item.serialNumber = serialNumber.isEmpty ? nil : serialNumber
            item.currency = currency
            item.notes = notes.isEmpty ? nil : notes
            item.updatedAt = Date()
        } else {
            let asset = PersonalAsset(
                name: name.trimmingCharacters(in: .whitespaces),
                category: selectedCategory,
                purchasePrice: pp,
                purchaseDate: purchaseDate,
                insuranceValue: ins,
                estimatedMarketValue: mv,
                currency: currency,
                serialNumber: serialNumber.isEmpty ? nil : serialNumber,
                brand: brand.isEmpty ? nil : brand,
                notes: notes.isEmpty ? nil : notes
            )
            context.insert(asset)
        }
        dismiss()
    }
}
