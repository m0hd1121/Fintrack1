import SwiftUI
import SwiftData

// MARK: - RealEstateListView

struct RealEstateListView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    // MARK: Queries
    @Query(filter: #Predicate<RealEstateProperty> { $0.isArchived == false },
           sort: \RealEstateProperty.createdAt, order: .reverse)
    private var properties: [RealEstateProperty]

    // MARK: State
    @State private var showingAdd = false
    @State private var editingProperty: RealEstateProperty?
    @State private var propertyToDelete: RealEstateProperty?
    @State private var showingDeleteConfirm = false

    // MARK: Computed

    private var baseCurrency: String { appState.baseCurrency }

    private var totalValue: Double {
        NetWorthService.shared.realEstateTotal(
            realEstate: Array(properties),
            currencyService: currencyService,
            base: baseCurrency
        )
    }

    private var totalEquity: Double {
        properties.reduce(0) {
            $0 + currencyService.convert($0 + $1.equity, from: $1.currency, to: baseCurrency) - $0
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            FTBackdrop()

            if properties.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        summaryHeader
                            .padding(.horizontal, FTSpacing.screen)

                        propertiesList
                            .padding(.horizontal, FTSpacing.screen)

                        Color.clear.frame(height: FTSpacing.xxl)
                    }
                    .padding(.top, FTSpacing.md)
                }
            }
        }
        .navigationTitle("Real Estate")
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
            AddRealEstateView()
        }
        .sheet(item: $editingProperty) { property in
            AddRealEstateView(editingItem: property)
        }
        .confirmationDialog("Delete Property", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let p = propertyToDelete {
                    context.delete(p)
                    try? context.save()
                }
            }
            Button("Archive Instead") {
                propertyToDelete?.isArchived = true
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the property.")
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "house.fill", tint: FTColor.catCoral, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Total Portfolio Value")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("\(properties.count) \(properties.count == 1 ? "property" : "properties")")
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
                    Text("owned value")
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
                    Text("TOTAL EQUITY")
                        .font(.ftLabel)
                        .tracking(1.4)
                        .foregroundStyle(FTColor.textMuted)
                    Text(totalEquity.formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(totalEquity >= 0 ? FTColor.income : FTColor.expense)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("PROPERTIES")
                        .font(.ftLabel)
                        .tracking(1.4)
                        .foregroundStyle(FTColor.textMuted)
                    Text("\(properties.count)")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Properties List

    private var propertiesList: some View {
        VStack(spacing: FTSpacing.sm) {
            ForEach(properties) { property in
                propertyRow(property)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            propertyToDelete = property
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        Button {
                            property.isArchived = true
                            try? context.save()
                        } label: {
                            Label("Archive", systemImage: "archivebox.fill")
                        }
                        .tint(FTColor.gold)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            editingProperty = property
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(FTColor.accent)
                    }
            }
        }
    }

    private func propertyRow(_ property: RealEstateProperty) -> some View {
        Button {
            editingProperty = property
        } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(
                    symbol: property.propertyType.icon,
                    tint: Color.fromString(property.propertyType.color),
                    size: 48
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(property.name)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                    if let address = property.address, !address.isEmpty {
                        Text(address)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text(property.propertyType.rawValue)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(currencyService.convert(property.currentValue, from: property.currency, to: baseCurrency).formatted(as: baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    let equity = currencyService.convert(property.equity, from: property.currency, to: baseCurrency)
                    HStack(spacing: 2) {
                        Image(systemName: equity >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(equity.formatted(as: baseCurrency))
                            .font(.ftCaption)
                    }
                    .foregroundStyle(equity >= 0 ? FTColor.income : FTColor.expense)
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
            FTIconTile(symbol: "house.fill", tint: FTColor.catCoral, size: 72)

            VStack(spacing: FTSpacing.xs) {
                Text("No Properties Yet")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Add your real estate holdings to track their value and equity.")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Add Property") {
                showingAdd = true
            }
            .buttonStyle(.ftPrimary)
            .frame(maxWidth: 240)

            Spacer()
        }
        .padding(.horizontal, FTSpacing.xl)
    }
}

// MARK: - Preview

#Preview("Real Estate List") {
    NavigationStack {
        RealEstateListView()
    }
    .modelContainer(for: RealEstateProperty.self, inMemory: true)
    .environment(AppState())
    .environment(CurrencyService.shared)
}
