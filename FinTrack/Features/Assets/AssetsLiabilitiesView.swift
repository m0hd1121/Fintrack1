import SwiftUI
import SwiftData

// MARK: - AssetsLiabilitiesView

struct AssetsLiabilitiesView: View {

    // MARK: Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    // MARK: Queries
    @Query(filter: #Predicate<RealEstateProperty> { !$0.isArchived })
    private var realEstate: [RealEstateProperty]

    @Query(filter: #Predicate<Vehicle> { !$0.isArchived })
    private var vehicles: [Vehicle]

    @Query(filter: #Predicate<PersonalAsset> { !$0.isArchived })
    private var personalAssets: [PersonalAsset]

    @Query(filter: #Predicate<DigitalAsset> { !$0.isArchived })
    private var digitalAssets: [DigitalAsset]

    // MARK: Computed Totals

    private var baseCurrency: String { appState.baseCurrency }

    private var realEstateTotal: Double {
        NetWorthService.shared.realEstateTotal(
            realEstate: Array(realEstate),
            currencyService: currencyService,
            base: baseCurrency
        )
    }

    private var vehicleTotal: Double {
        NetWorthService.shared.vehicleTotal(
            vehicles: Array(vehicles),
            currencyService: currencyService,
            base: baseCurrency
        )
    }

    private var personalAssetTotal: Double {
        NetWorthService.shared.personalAssetTotal(
            assets: Array(personalAssets),
            currencyService: currencyService,
            base: baseCurrency
        )
    }

    private var digitalAssetTotal: Double {
        NetWorthService.shared.digitalAssetTotal(
            assets: Array(digitalAssets),
            currencyService: currencyService,
            base: baseCurrency
        )
    }

    private var combinedTotal: Double {
        realEstateTotal + vehicleTotal + personalAssetTotal + digitalAssetTotal
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Total Assets Hero Card
                        totalAssetsHeroCard
                            .padding(.horizontal, FTSpacing.screen)

                        // Section Header
                        sectionHeader("Asset Categories")
                            .padding(.horizontal, FTSpacing.screen)

                        // Asset Category Cards
                        VStack(spacing: FTSpacing.sm) {
                            NavigationLink(destination: RealEstateListView()) {
                                assetCard(
                                    symbol: "house.fill",
                                    tint: FTColor.catCoral,
                                    title: "Real Estate",
                                    subtitle: "\(realEstate.count) \(realEstate.count == 1 ? "property" : "properties")",
                                    total: realEstateTotal
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: VehicleListView()) {
                                assetCard(
                                    symbol: "car.fill",
                                    tint: FTColor.catBlue,
                                    title: "Vehicles",
                                    subtitle: "\(vehicles.count) \(vehicles.count == 1 ? "vehicle" : "vehicles")",
                                    total: vehicleTotal
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: PersonalAssetsListView()) {
                                assetCard(
                                    symbol: "sparkles",
                                    tint: FTColor.gold,
                                    title: "Personal Assets",
                                    subtitle: "\(personalAssets.count) \(personalAssets.count == 1 ? "item" : "items")",
                                    total: personalAssetTotal
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: DigitalAssetsListView()) {
                                assetCard(
                                    symbol: "globe",
                                    tint: FTColor.catPurple,
                                    title: "Digital Assets",
                                    subtitle: "\(digitalAssets.count) \(digitalAssets.count == 1 ? "asset" : "assets")",
                                    total: digitalAssetTotal
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, FTSpacing.screen)

                        Color.clear.frame(height: FTSpacing.xxl)
                    }
                    .padding(.top, FTSpacing.md)
                }
            }
            .navigationTitle("Assets & Liabilities")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
            }
        }
    }

    // MARK: - Total Assets Hero Card

    private var totalAssetsHeroCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TOTAL ASSETS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            Text(combinedTotal.formatted(as: baseCurrency))
                .font(.ftDisplay)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            HStack(spacing: 0) {
                assetHeroMetric(
                    label: "Real Estate",
                    value: realEstateTotal.asCompact(currency: baseCurrency)
                )
                Spacer()
                assetHeroMetric(
                    label: "Vehicles",
                    value: vehicleTotal.asCompact(currency: baseCurrency)
                )
                Spacer()
                assetHeroMetric(
                    label: "Other",
                    value: (personalAssetTotal + digitalAssetTotal).asCompact(currency: baseCurrency)
                )
            }
        }
        .padding(FTSpacing.xl)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x0E9C8A), Color(hex: 0x0A6E7E)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: FTRadius.xl)
        )
        .shadow(color: Color(hex: 0x0A6E7E).opacity(0.35), radius: 20, y: 8)
    }

    private func assetHeroMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.ftLabel)
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.ftCallout)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Asset Category Card

    private func assetCard(
        symbol: String,
        tint: Color,
        title: String,
        subtitle: String,
        total: Double
    ) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: symbol, tint: tint, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text(subtitle)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(total.formatted(as: baseCurrency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("total value")
                    .font(.ftLabel)
                    .tracking(0.3)
                    .foregroundStyle(FTColor.textMuted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FTColor.textMuted)
        }
        .padding(FTSpacing.lg)
        .ftGlassInteractive(FTRadius.lg)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: FTSpacing.xs) {
            Text(title.uppercased())
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Assets & Liabilities") {
    AssetsLiabilitiesView()
        .modelContainer(for: [
            RealEstateProperty.self,
            Vehicle.self,
            PersonalAsset.self,
            DigitalAsset.self
        ], inMemory: true)
        .environment(AppState())
        .environment(CurrencyService.shared)
}
