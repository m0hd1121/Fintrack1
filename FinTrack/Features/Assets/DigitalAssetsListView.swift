import SwiftUI
import SwiftData

struct DigitalAssetsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DigitalAsset> { $0.isArchived == false }, sort: \DigitalAsset.name) private var assets: [DigitalAsset]

    @State private var selectedType: DigitalAssetType? = nil
    @State private var showingAdd = false
    @State private var editingAsset: DigitalAsset? = nil
    @State private var searchText = ""

    private var filtered: [DigitalAsset] {
        assets.filter { a in
            let typeMatch = selectedType == nil || a.assetType == selectedType
            let searchMatch = searchText.isEmpty || a.name.localizedCaseInsensitiveContains(searchText)
            return typeMatch && searchMatch
        }
    }

    private var totalValue: Double { filtered.reduce(0) { $0 + $1.currentValue } }
    private var totalAcquisitionValue: Double { filtered.reduce(0) { $0 + $1.acquisitionValue } }
    private var totalGainLoss: Double { totalValue - totalAcquisitionValue }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        summaryCard
                        filterRow
                        if filtered.isEmpty {
                            emptyState
                        } else {
                            assetList
                        }
                    }
                    .padding(FTSpacing.screen)
                    .padding(.bottom, FTSpacing.xxl)
                }
            }
            .navigationTitle("Digital Assets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(FTColor.accent)
                            .font(.title3)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search digital assets")
            .sheet(isPresented: $showingAdd) {
                AddDigitalAssetView()
            }
            .sheet(item: $editingAsset) { asset in
                AddDigitalAssetView(editingAsset: asset)
            }
        }
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                Text("Total Value")
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.textSecondary)
                Spacer()
                HStack(spacing: 2) {
                    Text(totalGainLoss >= 0 ? "+" : "")
                    Text(totalGainLoss, format: .currency(code: "AED").precision(.fractionLength(0)))
                }
                .foregroundStyle(totalGainLoss >= 0 ? FTColor.income : FTColor.expense)
                .font(.ftCaption)
            }

            Text(totalValue, format: .currency(code: "AED").precision(.fractionLength(0)))
                .font(.ftDisplay)
                .foregroundStyle(FTColor.textPrimary)

            Divider().overlay(Color.white.opacity(0.12))

            HStack(spacing: 0) {
                statItem(label: "Assets", value: "\(filtered.count)")
                Divider().frame(width: 1, height: 32).overlay(Color.white.opacity(0.12))
                statItem(label: "Cost Basis", value: totalAcquisitionValue.formatted(.currency(code: "AED").precision(.fractionLength(0))))
                Divider().frame(width: 1, height: 32).overlay(Color.white.opacity(0.12))
                let pct = totalAcquisitionValue > 0 ? totalGainLoss / totalAcquisitionValue * 100 : 0
                statItem(
                    label: "Return",
                    value: String(format: "%+.1f%%", pct),
                    valueColor: pct >= 0 ? FTColor.income : FTColor.expense
                )
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass()
    }

    private func statItem(label: String, value: String, valueColor: Color = FTColor.textPrimary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Row
    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FilterChip(title: "All", isSelected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(DigitalAssetType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        isSelected: selectedType == type
                    ) {
                        selectedType = selectedType == type ? nil : type
                    }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
        }
        .padding(.horizontal, -FTSpacing.screen)
    }

    // MARK: - Asset List
    private var assetList: some View {
        VStack(spacing: FTSpacing.sm) {
            ForEach(filtered) { asset in
                DigitalAssetRow(asset: asset)
                    .ftGlassInteractive()
                    .onTapGesture { editingAsset = asset }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation { modelContext.delete(asset) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editingAsset = asset
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(FTColor.accent)
                    }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            FTIconTile(symbol: "globe", tint: FTColor.catTeal, size: 56)
            Text(searchText.isEmpty && selectedType == nil ? "No Digital Assets" : "No Results")
                .font(.ftHeadline)
                .foregroundStyle(FTColor.textPrimary)
            Text(searchText.isEmpty && selectedType == nil
                 ? "Track domains, NFTs, IP rights, software licenses, and more."
                 : "Try a different search or filter.")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center)
            if searchText.isEmpty && selectedType == nil {
                Button { showingAdd = true } label: {
                    Label("Add Digital Asset", systemImage: "plus")
                }
                .buttonStyle(FTPrimaryButtonStyle())
            }
        }
        .padding(.top, FTSpacing.xxl)
    }
}

// MARK: - Row
private struct DigitalAssetRow: View {
    let asset: DigitalAsset

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: asset.assetType.icon,
                       tint: Color.fromString(asset.assetType.color),
                       size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                HStack(spacing: FTSpacing.xs) {
                    Text(asset.assetType.displayName)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                    if let platform = asset.platform, !platform.isEmpty {
                        Text("·")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                        Text(platform)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
                if let expiry = asset.expiryDate {
                    let daysLeft = Calendar.current.dateComponents([.day], from: .now, to: expiry).day ?? 0
                    HStack(spacing: 4) {
                        Image(systemName: daysLeft < 30 ? "exclamationmark.circle.fill" : "calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(daysLeft < 30 ? FTColor.expense : FTColor.textMuted)
                        Text("Expires \(expiry, style: .date)")
                            .font(.ftCaption)
                            .foregroundStyle(daysLeft < 30 ? FTColor.expense : FTColor.textMuted)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.currentValue, format: .currency(code: asset.currency).precision(.fractionLength(0)))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                let gl = asset.gainLoss
                if abs(gl) > 0.01 {
                    HStack(spacing: 2) {
                        Text(gl >= 0 ? "+" : "")
                        Text(abs(gl), format: .currency(code: asset.currency).precision(.fractionLength(0)))
                    }
                    .foregroundStyle(gl >= 0 ? FTColor.income : FTColor.expense)
                    .font(.ftCaption)
                }
            }
        }
        .padding(FTSpacing.md)
    }
}

// MARK: - Add/Edit Sheet
struct AddDigitalAssetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var editingAsset: DigitalAsset? = nil

    @State private var name = ""
    @State private var selectedType: DigitalAssetType = .domain
    @State private var platform = ""
    @State private var identifier = ""
    @State private var acquisitionValue = ""
    @State private var acquisitionDate = Date()
    @State private var currentValue = ""
    @State private var currency = "AED"
    @State private var hasExpiry = false
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var notes = ""

    private let currencies = ["AED", "USD", "EUR", "GBP", "BTC", "ETH"]

    private var isEditing: Bool { editingAsset != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(currentValue) != nil
            && Double(acquisitionValue) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        typeGrid
                        basicInfoSection
                        financialsSection
                        expirySection
                        notesSection
                    }
                    .padding(FTSpacing.screen)
                    .padding(.bottom, FTSpacing.xxl)
                }
            }
            .navigationTitle(isEditing ? "Edit Digital Asset" : "Add Digital Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Update" : "Save") { save() }
                        .foregroundStyle(canSave ? FTColor.accent : FTColor.textMuted)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: - Type Grid
    private var typeGrid: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("Type")
                .font(.ftCallout)
                .foregroundStyle(FTColor.textSecondary)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: FTSpacing.sm), count: 4),
                spacing: FTSpacing.sm
            ) {
                ForEach(DigitalAssetType.allCases, id: \.self) { t in
                    let isSelected = selectedType == t
                    let tintColor = Color.fromString(t.color)
                    Button {
                        withAnimation(.spring(response: 0.25)) { selectedType = t }
                    } label: {
                        VStack(spacing: FTSpacing.xs) {
                            FTIconTile(symbol: t.icon,
                                       tint: isSelected ? tintColor : FTColor.textMuted,
                                       size: 32)
                            Text(t.displayName)
                                .font(.ftCaption)
                                .foregroundStyle(isSelected ? FTColor.textPrimary : FTColor.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(FTSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? tintColor.opacity(0.15) : Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: FTRadius.sm))
                        .overlay(RoundedRectangle(cornerRadius: FTRadius.sm)
                            .stroke(isSelected ? tintColor : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Basic Info
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("Details")
                .font(.ftCallout)
                .foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                formField(label: "Name") { TextField("e.g., mywebsite.com", text: $name) }
                Divider().overlay(Color.white.opacity(0.08)).padding(.leading, FTSpacing.lg)
                formField(label: "Platform") { TextField("e.g., GoDaddy, OpenSea", text: $platform) }
                Divider().overlay(Color.white.opacity(0.08)).padding(.leading, FTSpacing.lg)
                formField(label: "Identifier") { TextField("Domain, token ID, license key", text: $identifier) }
            }
            .ftGlass()
        }
    }

    // MARK: - Financials
    private var financialsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("Financials")
                .font(.ftCallout)
                .foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                formField(label: "Currency") {
                    Picker("", selection: $currency) {
                        ForEach(currencies, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    .foregroundStyle(FTColor.textPrimary)
                }
                Divider().overlay(Color.white.opacity(0.08)).padding(.leading, FTSpacing.lg)
                formField(label: "Acquisition Value") {
                    TextField("0.00", text: $acquisitionValue).keyboardType(.decimalPad)
                }
                Divider().overlay(Color.white.opacity(0.08)).padding(.leading, FTSpacing.lg)
                formField(label: "Acquisition Date") {
                    DatePicker("", selection: $acquisitionDate, displayedComponents: .date).labelsHidden()
                }
                Divider().overlay(Color.white.opacity(0.08)).padding(.leading, FTSpacing.lg)
                formField(label: "Current Value") {
                    TextField("0.00", text: $currentValue).keyboardType(.decimalPad)
                }
            }
            .ftGlass()

            if let acq = Double(acquisitionValue), let cur = Double(currentValue), acq > 0 {
                let gl = cur - acq
                let pct = gl / acq * 100
                HStack {
                    Image(systemName: gl >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%+.1f%%", pct))
                    Text(gl >= 0 ? "gain" : "loss")
                }
                .font(.ftCaption)
                .foregroundStyle(gl >= 0 ? FTColor.income : FTColor.expense)
                .padding(.horizontal, FTSpacing.sm)
            }
        }
    }

    // MARK: - Expiry
    private var expirySection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("Expiry")
                .font(.ftCallout)
                .foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                HStack {
                    Text("Has Expiry Date")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Toggle("", isOn: $hasExpiry)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(FTSpacing.md)
                if hasExpiry {
                    Divider().overlay(Color.white.opacity(0.08)).padding(.leading, FTSpacing.lg)
                    formField(label: "Expiry Date") {
                        DatePicker("", selection: $expiryDate, in: Date()..., displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
            .ftGlass()
        }
    }

    // MARK: - Notes
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("Notes")
                .font(.ftCallout)
                .foregroundStyle(FTColor.textSecondary)
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .font(.ftBody)
                .foregroundStyle(FTColor.textPrimary)
                .padding(FTSpacing.md)
                .ftGlass()
        }
    }

    // MARK: - Helpers
    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textPrimary)
            Spacer()
            content()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(FTColor.textSecondary)
        }
        .padding(FTSpacing.md)
    }

    private func prefill() {
        guard let a = editingAsset else { return }
        name = a.name
        selectedType = a.assetType
        platform = a.platform ?? ""
        identifier = a.identifier ?? ""
        acquisitionValue = String(a.acquisitionValue)
        acquisitionDate = a.acquisitionDate
        currentValue = String(a.currentValue)
        currency = a.currency
        hasExpiry = a.expiryDate != nil
        if let exp = a.expiryDate { expiryDate = exp }
        notes = a.notes ?? ""
    }

    private func save() {
        guard let acq = Double(acquisitionValue), let cur = Double(currentValue) else { return }
        if let a = editingAsset {
            a.name = name.trimmingCharacters(in: .whitespaces)
            a.assetType = selectedType
            a.platform = platform.isEmpty ? nil : platform
            a.identifier = identifier.isEmpty ? nil : identifier
            a.acquisitionValue = acq
            a.acquisitionDate = acquisitionDate
            a.currentValue = cur
            a.currency = currency
            a.expiryDate = hasExpiry ? expiryDate : nil
            a.notes = notes.isEmpty ? nil : notes
        } else {
            let asset = DigitalAsset(
                name: name.trimmingCharacters(in: .whitespaces),
                type: selectedType,
                acquisitionValue: acq,
                acquisitionDate: acquisitionDate,
                currentValue: cur,
                currency: currency,
                platform: platform.isEmpty ? nil : platform,
                identifier: identifier.isEmpty ? nil : identifier,
                expiryDate: hasExpiry ? expiryDate : nil,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(asset)
        }
        dismiss()
    }
}

// MARK: - DigitalAssetType Display Extensions
extension DigitalAssetType {
    var displayName: String {
        switch self {
        case .domain:   return "Domain"
        case .nft:      return "NFT"
        case .ip:       return "IP Rights"
        case .license:  return "License"
        case .business: return "Business"
        case .software: return "Software"
        case .other:    return "Other"
        }
    }
}
