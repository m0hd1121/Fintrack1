import SwiftUI
import SwiftData
import Charts

// MARK: - NetWorthDashboardView

struct NetWorthDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // MARK: - Queries

    @Query private var accounts: [Account]
    @Query private var investments: [Investment]
    @Query private var cryptoHoldings: [CryptoHolding]
    @Query(filter: #Predicate<GoldHolding> { !$0.isArchived }) private var goldHoldings: [GoldHolding]
    // isExpired is a computed property — cannot be used in #Predicate (SwiftData SQL translation fails)
    @Query private var allGiftCards: [GiftCard]
    private var giftCards: [GiftCard] { allGiftCards.filter { !$0.isExpired && !$0.isUsedUp } }
    @Query(filter: #Predicate<RealEstateProperty> { !$0.isArchived }) private var realEstateProperties: [RealEstateProperty]
    @Query(filter: #Predicate<Vehicle> { !$0.isArchived }) private var vehicles: [Vehicle]
    @Query(filter: #Predicate<PersonalAsset> { !$0.isArchived }) private var personalAssets: [PersonalAsset]
    @Query(filter: #Predicate<DigitalAsset> { !$0.isArchived }) private var digitalAssets: [DigitalAsset]
    @Query(filter: #Predicate<Loan> { $0.isActive }) private var loans: [Loan]
    @Query(filter: #Predicate<CreditCard> { $0.isActive }) private var creditCards: [CreditCard]
    @Query(filter: #Predicate<BNPLPlan> { !$0.isCompleted }) private var bnplPlans: [BNPLPlan]
    @Query private var moneyBorrowed: [MoneyBorrowed]
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]
    @Query private var milestones: [NetWorthMilestone]

    // MARK: - Tab State

    @State private var selectedTab = 0
    private let tabs = ["Overview", "History", "Forecast", "Allocation", "Milestones"]

    // MARK: - Forecast State

    @State private var forecastMonthlySavings: Double = 5000
    @State private var forecastAnnualReturn: Double = 7.0
    @State private var forecastIncomeGrowth: Double = 3.0
    @State private var forecastInflation: Double = 2.5
    @State private var forecastHorizonIndex: Int = 1

    // MARK: - UI State

    @State private var isRecordingSnapshot = false
    @State private var newMilestone: NetWorthMilestone? = nil

    private var base: String { appState.baseCurrency }

    // MARK: - Computed Net Worth Values

    private var totalAssets: Double {
        NetWorthService.shared.totalAssets(
            accounts: Array(accounts),
            investments: Array(investments),
            cryptos: Array(cryptoHoldings),
            golds: Array(goldHoldings),
            giftCards: Array(giftCards),
            realEstate: Array(realEstateProperties),
            vehicles: Array(vehicles),
            personalAssets: Array(personalAssets),
            digitalAssets: Array(digitalAssets),
            currencyService: currencyService,
            base: base
        )
    }

    private var totalLiabilities: Double {
        NetWorthService.shared.totalLiabilities(
            loans: Array(loans),
            creditCards: Array(creditCards),
            bnpl: Array(bnplPlans),
            moneyBorrowed: moneyBorrowed.filter { !$0.isFullyRepaid },
            currencyService: currencyService,
            base: base
        )
    }

    private var currentNetWorth: Double { totalAssets - totalLiabilities }

    private var cashTotal: Double {
        accounts.filter { !$0.isArchived && !$0.isHidden }.reduce(0.0) {
            $0 + currencyService.convert($1.balance, from: $1.currency, to: base)
        }
    }

    private var investmentTotal: Double {
        investments.reduce(0.0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) }
        + cryptoHoldings.reduce(0.0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) }
    }

    private var realEstateTotal: Double {
        realEstateProperties.reduce(0.0) { $0 + currencyService.convert($1.ownedValue, from: $1.currency, to: base) }
    }

    private var vehicleTotal: Double {
        vehicles.reduce(0.0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) }
    }

    private var goldTotal: Double {
        goldHoldings.reduce(0.0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) }
    }

    private var personalAssetTotal: Double {
        personalAssets.reduce(0.0) { $0 + currencyService.convert($1.estimatedMarketValue, from: $1.currency, to: base) }
    }

    private var digitalAssetTotal: Double {
        digitalAssets.reduce(0.0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) }
    }

    private var loanTotal: Double {
        loans.reduce(0.0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: base) }
    }

    private var creditCardTotal: Double {
        creditCards.reduce(0.0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: base) }
    }

    private var bnplTotal: Double {
        bnplPlans.reduce(0.0) { $0 + currencyService.convert($1.remainingAmount, from: $1.currency, to: base) }
    }

    private var personalDebtTotal: Double {
        moneyBorrowed.filter { !$0.isFullyRepaid }.reduce(0.0) {
            $0 + currencyService.convert($1.remainingBalance, from: $1.currency, to: base)
        }
    }

    // MARK: - Month-Over-Month Change

    private var monthChangeValue: Double? {
        guard snapshots.count >= 2 else { return nil }
        let last = snapshots[snapshots.count - 1]
        let prev = snapshots[snapshots.count - 2]
        return last.netWorth - prev.netWorth
    }

    // MARK: - Allocation Slices

    private var allocationSlices: [AssetAllocationSlice] {
        NetWorthService.shared.assetAllocationSlices(
            accounts: Array(accounts),
            investments: Array(investments),
            cryptos: Array(cryptoHoldings),
            golds: Array(goldHoldings),
            giftCards: Array(giftCards),
            realEstate: Array(realEstateProperties),
            vehicles: Array(vehicles),
            personalAssets: Array(personalAssets),
            digitalAssets: Array(digitalAssets),
            currencyService: currencyService,
            base: base
        )
    }

    // MARK: - Forecast

    private var forecastYears: Int {
        [5, 10, 20, 30][forecastHorizonIndex]
    }

    private var forecastPoints: [NetWorthService.ForecastPoint] {
        NetWorthService.shared.forecastNetWorth(
            currentNetWorth: currentNetWorth,
            monthlySavings: forecastMonthlySavings,
            annualInvestmentReturn: forecastAnnualReturn,
            annualIncomeGrowth: forecastIncomeGrowth,
            annualInflation: forecastInflation,
            years: forecastYears
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                VStack(spacing: 0) {
                    tabBar
                        .padding(.top, FTSpacing.xs)
                    ScrollView {
                        Group {
                            switch selectedTab {
                            case 0: overviewTab
                            case 1: historyTab
                            case 2: forecastTab
                            case 3: allocationTab
                            case 4: milestonesTab
                            default: overviewTab
                            }
                        }
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationTitle("Net Worth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
            }
            .onAppear { checkMilestonesIfNeeded() }
            .overlay(alignment: .top) {
                if let milestone = newMilestone {
                    MilestoneBanner(milestone: milestone, baseCurrency: base) {
                        milestone.isAcknowledged = true
                        newMilestone = nil
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            .animation(.spring(duration: 0.4), value: newMilestone?.id)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(tabs.indices, id: \.self) { i in
                    FilterChip(title: tabs[i], isSelected: selectedTab == i) {
                        withAnimation(.snappy(duration: 0.25)) { selectedTab = i }
                    }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.xs)
        }
    }

    // MARK: - Milestone Check

    private func checkMilestonesIfNeeded() {
        NetWorthService.shared.checkMilestones(
            currentNetWorth: currentNetWorth,
            existingMilestones: Array(milestones),
            base: base,
            context: context
        )
        if let unacknowledged = milestones.first(where: { !$0.isAcknowledged }) {
            newMilestone = unacknowledged
        }
    }

    // MARK: - Record Snapshot

    private func recordSnapshotAndCheckMilestones() {
        isRecordingSnapshot = true
        NetWorthService.shared.recordSnapshot(
            accounts: Array(accounts),
            investments: Array(investments),
            cryptos: Array(cryptoHoldings),
            golds: Array(goldHoldings),
            giftCards: Array(giftCards),
            realEstate: Array(realEstateProperties),
            vehicles: Array(vehicles),
            personalAssets: Array(personalAssets),
            digitalAssets: Array(digitalAssets),
            loans: Array(loans),
            creditCards: Array(creditCards),
            bnpl: Array(bnplPlans),
            moneyBorrowed: moneyBorrowed.filter { !$0.isFullyRepaid },
            currencyService: currencyService,
            base: base,
            context: context
        )
        NetWorthService.shared.checkMilestones(
            currentNetWorth: currentNetWorth,
            existingMilestones: Array(milestones),
            base: base,
            context: context
        )
        if let unacknowledged = milestones.first(where: { !$0.isAcknowledged }) {
            newMilestone = unacknowledged
        }
        isRecordingSnapshot = false
    }
}

// MARK: - Tab 1: Overview

extension NetWorthDashboardView {

    private var overviewTab: some View {
        VStack(spacing: FTSpacing.lg) {
            overviewHeroCard
                .padding(.horizontal, FTSpacing.screen)

            assetsSection
            liabilitiesSection

            Button {
                recordSnapshotAndCheckMilestones()
            } label: {
                HStack(spacing: FTSpacing.sm) {
                    if isRecordingSnapshot {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(isRecordingSnapshot ? "Saving…" : "Record Today's Snapshot")
                }
            }
            .buttonStyle(.ftPrimary)
            .padding(.horizontal, FTSpacing.screen)
            .disabled(isRecordingSnapshot)
        }
        .padding(.top, FTSpacing.md)
    }

    private var overviewHeroCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("NET WORTH")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.7))

            Text(currentNetWorth.formatted(as: base))
                .font(.ftDisplay)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.45)
                .lineLimit(1)

            if let change = monthChangeValue {
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                    Text(change.formatted(as: base))
                        .font(.ftCallout)
                    Text("vs last snapshot")
                        .font(.ftCaption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .foregroundStyle(change >= 0 ? FTColor.income : FTColor.expense)
                .padding(.horizontal, FTSpacing.sm + 2)
                .padding(.vertical, 5)
                .background((change >= 0 ? FTColor.income : FTColor.expense).opacity(0.18), in: .capsule)
            }

            Divider().background(.white.opacity(0.25))

            HStack(spacing: FTSpacing.xxl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ASSETS")
                        .font(.ftLabel).tracking(1.0).foregroundStyle(.white.opacity(0.7))
                    Text(totalAssets.asCompact(currency: base))
                        .font(.ftCallout).foregroundStyle(FTColor.income)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIABILITIES")
                        .font(.ftLabel).tracking(1.0).foregroundStyle(.white.opacity(0.7))
                    Text(totalLiabilities.asCompact(currency: base))
                        .font(.ftCallout).foregroundStyle(FTColor.expense)
                }
                Spacer()
            }
        }
        .padding(FTSpacing.xl)
        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
        .shadow(color: Color(hex: 0x0A6E7E).opacity(0.4), radius: 24, y: 10)
    }

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            nwSectionHeader("Assets", symbol: "banknote.fill", tint: FTColor.income)
                .padding(.horizontal, FTSpacing.screen)

            VStack(spacing: FTSpacing.xs) {
                if cashTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "banknote.fill", label: "Cash & Accounts",
                        tint: FTColor.accent, value: cashTotal,
                        total: totalAssets, base: base
                    )
                }
                if investmentTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "chart.line.uptrend.xyaxis", label: "Investments & Crypto",
                        tint: FTColor.catBlue, value: investmentTotal,
                        total: totalAssets, base: base
                    )
                }
                if realEstateTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "building.fill", label: "Real Estate",
                        tint: FTColor.catCoral, value: realEstateTotal,
                        total: totalAssets, base: base
                    )
                }
                if vehicleTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "car.fill", label: "Vehicles",
                        tint: .blue, value: vehicleTotal,
                        total: totalAssets, base: base
                    )
                }
                if goldTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "star.circle.fill", label: "Gold & Metals",
                        tint: FTColor.gold, value: goldTotal,
                        total: totalAssets, base: base
                    )
                }
                if personalAssetTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "sparkles", label: "Personal Assets",
                        tint: .orange, value: personalAssetTotal,
                        total: totalAssets, base: base
                    )
                }
                if digitalAssetTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "globe", label: "Digital Assets",
                        tint: .teal, value: digitalAssetTotal,
                        total: totalAssets, base: base
                    )
                }
                if totalAssets == 0 {
                    Text("No assets recorded yet.")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FTSpacing.xl)
                }
            }
            .padding(.horizontal, FTSpacing.screen)
        }
    }

    private var liabilitiesSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            nwSectionHeader("Liabilities", symbol: "creditcard.fill", tint: FTColor.expense)
                .padding(.horizontal, FTSpacing.screen)

            VStack(spacing: FTSpacing.xs) {
                if loanTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "building.columns.fill", label: "Bank Loans",
                        tint: FTColor.expense, value: loanTotal,
                        total: totalLiabilities, base: base
                    )
                }
                if creditCardTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "creditcard.fill", label: "Credit Cards",
                        tint: FTColor.catCoral, value: creditCardTotal,
                        total: totalLiabilities, base: base
                    )
                }
                if bnplTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "cart.fill", label: "BNPL Plans",
                        tint: FTColor.catPurple, value: bnplTotal,
                        total: totalLiabilities, base: base
                    )
                }
                if personalDebtTotal > 0 {
                    AssetBreakdownRow(
                        symbol: "person.2.fill", label: "Personal Debts",
                        tint: .orange, value: personalDebtTotal,
                        total: totalLiabilities, base: base
                    )
                }
                if totalLiabilities == 0 {
                    HStack(spacing: FTSpacing.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(FTColor.income)
                        Text("No liabilities — debt free!")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FTSpacing.xl)
                    .ftGlass(FTRadius.lg)
                }
            }
            .padding(.horizontal, FTSpacing.screen)
        }
    }

    private func nwSectionHeader(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: FTSpacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(title.uppercased())
                .font(.ftLabel)
                .tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
        }
    }
}

// MARK: - Tab 2: History

extension NetWorthDashboardView {

    private var historyTab: some View {
        VStack(spacing: FTSpacing.lg) {
            if snapshots.count < 2 {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No History Yet",
                    message: "Record your first snapshot from the Overview tab to start building your history."
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                historyChartCard
                historySummaryCard
                historySnapshotList
            }
        }
        .padding(.top, FTSpacing.md)
    }

    private var historyChartCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            nwSectionHeader("Net Worth Over Time", symbol: "chart.line.uptrend.xyaxis", tint: FTColor.accent)

            let displaySnapshots = snapshots.suffix(60)

            Chart(Array(displaySnapshots), id: \.id) { snapshot in
                AreaMark(
                    x: .value("Date", snapshot.date),
                    y: .value("Net Worth", snapshot.netWorth)
                )
                .foregroundStyle(FTColor.accent.opacity(0.15))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", snapshot.date),
                    y: .value("Net Worth", snapshot.netWorth)
                )
                .foregroundStyle(FTColor.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                PointMark(
                    x: .value("Date", snapshot.date),
                    y: .value("Net Worth", snapshot.netWorth)
                )
                .foregroundStyle(FTColor.accent)
                .symbolSize(36)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.asCompact(currency: base))
                                .font(.ftLabel)
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                    AxisGridLine().foregroundStyle(FTColor.textPrimary.opacity(0.05))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(d.shortMonthName)
                                .font(.ftLabel)
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
            }
            .frame(height: 240)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
        .padding(.horizontal, FTSpacing.screen)
    }

    private var historySummaryCard: some View {
        let sorted = snapshots.sorted { $0.date < $1.date }
        let highest = sorted.max(by: { $0.netWorth < $1.netWorth })?.netWorth ?? 0
        let lowest  = sorted.min(by: { $0.netWorth < $1.netWorth })?.netWorth ?? 0
        let first   = sorted.first?.netWorth ?? 0
        let last    = sorted.last?.netWorth ?? 0
        let change  = last - first
        let months  = max(
            Double(Calendar.current.dateComponents([.month],
                from: sorted.first?.date ?? Date(),
                to: sorted.last?.date ?? Date()).month ?? 1), 1
        )
        let avgMonthlyGrowth = change / months

        return VStack(spacing: FTSpacing.md) {
            HStack {
                StatPairView(label: "All-Time High", value: highest.asCompact(currency: base), color: FTColor.income)
                Spacer()
                StatPairView(label: "All-Time Low", value: lowest.asCompact(currency: base), color: FTColor.expense, alignment: .trailing)
            }
            Divider()
            HStack {
                StatPairView(label: "Total Change", value: change.formatted(as: base), color: change >= 0 ? FTColor.income : FTColor.expense)
                Spacer()
                StatPairView(label: "Avg. Monthly Growth", value: avgMonthlyGrowth.asCompact(currency: base), color: FTColor.catBlue, alignment: .trailing)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
        .padding(.horizontal, FTSpacing.screen)
    }

    private var historySnapshotList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            nwSectionHeader("Snapshot History", symbol: "clock.fill", tint: FTColor.textSecondary)
                .padding(.horizontal, FTSpacing.screen)

            VStack(spacing: FTSpacing.xs) {
                ForEach(snapshots.sorted { $0.date > $1.date }, id: \.id) { snapshot in
                    SnapshotRow(snapshot: snapshot, base: base) {
                        context.delete(snapshot)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                }
            }
        }
    }
}

// MARK: - Tab 3: Forecast

extension NetWorthDashboardView {

    private var forecastTab: some View {
        VStack(spacing: FTSpacing.lg) {
            forecastInputsCard
            forecastChartCard
            forecastSummaryCard
        }
        .padding(.top, FTSpacing.md)
    }

    private var forecastInputsCard: some View {
        VStack(spacing: 0) {
            ForecastSliderRow(
                label: "Monthly Savings",
                value: $forecastMonthlySavings,
                range: 0...50_000,
                step: 500,
                format: { $0.asCompact(currency: base) }
            )
            Divider().padding(.leading, FTSpacing.screen)

            ForecastSliderRow(
                label: "Annual Return",
                value: $forecastAnnualReturn,
                range: 3...15,
                step: 0.5,
                format: { $0.asPercentage(decimals: 1) }
            )
            Divider().padding(.leading, FTSpacing.screen)

            ForecastSliderRow(
                label: "Income Growth",
                value: $forecastIncomeGrowth,
                range: 0...10,
                step: 0.5,
                format: { $0.asPercentage(decimals: 1) }
            )
            Divider().padding(.leading, FTSpacing.screen)

            ForecastSliderRow(
                label: "Annual Inflation",
                value: $forecastInflation,
                range: 0...8,
                step: 0.5,
                format: { $0.asPercentage(decimals: 1) }
            )
            Divider().padding(.leading, FTSpacing.screen)

            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                Text("Time Horizon")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                FTSegmentedControl(options: ["5Y", "10Y", "20Y", "30Y"], selection: $forecastHorizonIndex)
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.md)
        }
        .ftGlass(FTRadius.lg)
        .padding(.horizontal, FTSpacing.screen)
    }

    private var forecastChartCard: some View {
        let points = forecastPoints

        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            nwSectionHeader("Projection — \(forecastYears) Years", symbol: "chart.line.uptrend.xyaxis", tint: FTColor.accent)

            Chart(points) { point in
                LineMark(
                    x: .value("Year", point.year),
                    y: .value("Net Worth", point.netWorth)
                )
                .foregroundStyle(FTColor.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Year", point.year),
                    y: .value("Optimistic", point.optimistic)
                )
                .foregroundStyle(FTColor.income)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Year", point.year),
                    y: .value("Pessimistic", point.pessimistic)
                )
                .foregroundStyle(FTColor.expense)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.asCompact(currency: base))
                                .font(.ftLabel)
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                    AxisGridLine().foregroundStyle(FTColor.textPrimary.opacity(0.05))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textMuted).font(.ftLabel)
                }
            }
            .frame(height: 240)

            // Legend
            HStack(spacing: FTSpacing.lg) {
                ForecastLegendItem(color: FTColor.accent, dashed: false, label: "Base")
                ForecastLegendItem(color: FTColor.income, dashed: true, label: "Optimistic (+3%)")
                ForecastLegendItem(color: FTColor.expense, dashed: true, label: "Pessimistic (−4%)")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
        .padding(.horizontal, FTSpacing.screen)
    }

    private var forecastSummaryCard: some View {
        let points = forecastPoints
        guard let last = points.last, let first = points.first else {
            return AnyView(EmptyView())
        }

        let totalContributions = forecastMonthlySavings * 12 * Double(forecastYears)
        let projectedGrowth    = last.netWorth - first.netWorth - totalContributions

        return AnyView(
            VStack(spacing: FTSpacing.md) {
                HStack {
                    StatPairView(label: "Base Case", value: last.netWorth.asCompact(currency: base), color: FTColor.accent)
                    Spacer()
                    StatPairView(label: "Optimistic", value: last.optimistic.asCompact(currency: base), color: FTColor.income, alignment: .center)
                    Spacer()
                    StatPairView(label: "Pessimistic", value: last.pessimistic.asCompact(currency: base), color: FTColor.expense, alignment: .trailing)
                }
                Divider()
                HStack {
                    StatPairView(label: "Total Contributions", value: totalContributions.asCompact(currency: base), color: FTColor.catBlue)
                    Spacer()
                    StatPairView(label: "Projected Growth", value: projectedGrowth.asCompact(currency: base), color: FTColor.income, alignment: .trailing)
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)
        )
    }
}

// MARK: - Tab 4: Allocation

extension NetWorthDashboardView {

    private var allocationTab: some View {
        VStack(spacing: FTSpacing.lg) {
            if allocationSlices.isEmpty {
                EmptyStateView(
                    icon: "chart.pie.fill",
                    title: "No Assets Recorded",
                    message: "Add accounts, investments, or other assets to see how your wealth is allocated."
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                allocationDonutCard
                allocationSliceList
            }
        }
        .padding(.top, FTSpacing.md)
    }

    private var allocationDonutCard: some View {
        VStack(spacing: FTSpacing.md) {
            nwSectionHeader("Asset Allocation", symbol: "chart.pie.fill", tint: FTColor.accent)

            ZStack {
                Chart(allocationSlices) { slice in
                    SectorMark(
                        angle: .value("Value", slice.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(4)
                }
                .frame(height: 240)

                VStack(spacing: 3) {
                    Text(totalAssets.asCompact(currency: base))
                        .font(.ftTitle)
                        .foregroundStyle(FTColor.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("Total Assets")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
        .padding(.horizontal, FTSpacing.screen)
    }

    private var allocationSliceList: some View {
        VStack(spacing: FTSpacing.xs) {
            ForEach(allocationSlices) { slice in
                NWAllocationSliceRow(slice: slice, base: base)
                    .padding(.horizontal, FTSpacing.screen)
            }
        }
    }
}

// MARK: - Tab 5: Milestones

extension NetWorthDashboardView {

    private var milestonesTab: some View {
        VStack(spacing: FTSpacing.lg) {
            milestoneListCard
            percentileCard
        }
        .padding(.top, FTSpacing.md)
    }

    private var milestoneListCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            nwSectionHeader("Wealth Milestones", symbol: "trophy.fill", tint: FTColor.gold)
                .padding(.horizontal, FTSpacing.screen)

            VStack(spacing: FTSpacing.xs) {
                ForEach(NetWorthService.milestoneAmounts, id: \.self) { amount in
                    let achieved = milestones.first(where: { abs($0.amount - amount) < 1 })
                    MilestoneRow(
                        amount: amount,
                        baseCurrency: base,
                        achievedMilestone: achieved,
                        isUnlocked: currentNetWorth >= amount
                    )
                    .padding(.horizontal, FTSpacing.screen)
                }
            }
        }
    }

    private var percentileCard: some View {
        let result = NetWorthService.shared.wealthPercentile(
            netWorth: currentNetWorth,
            baseCurrency: base,
            currencyService: currencyService
        )

        return VStack(alignment: .leading, spacing: FTSpacing.lg) {
            nwSectionHeader("Wealth Percentile", symbol: "chart.bar.fill", tint: FTColor.catBlue)

            PercentileGaugeView(percentile: result.percentile)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                HStack(spacing: FTSpacing.sm) {
                    BadgeView(text: result.tier, color: tierColor(result.percentile))
                    Spacer()
                    Text("Top \(String(format: "%.1f", 100 - result.percentile))%")
                        .font(.ftBodySemibold)
                        .foregroundStyle(tierColor(result.percentile))
                }
                Text(result.explanation)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Estimates based on approximate UAE wealth distribution data")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                    .padding(.top, FTSpacing.xs)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
        .padding(.horizontal, FTSpacing.screen)
    }

    private func tierColor(_ percentile: Double) -> Color {
        switch percentile {
        case ..<50:  return FTColor.catBlue
        case ..<80:  return FTColor.accent
        case ..<95:  return FTColor.gold
        default:     return FTColor.catPurple
        }
    }
}

// MARK: - AssetBreakdownRow

private struct AssetBreakdownRow: View {
    let symbol: String
    let label: String
    let tint: Color
    let value: Double
    let total: Double
    let base: String

    private var percentage: Double { total > 0 ? (value / total) * 100 : 0 }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: symbol, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                FTProgressBar(value: percentage / 100, color: tint, height: 4)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(value.formatted(as: base))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(percentage.asPercentage(decimals: 1))
                    .font(.ftLabel)
                    .tracking(0.3)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.12), in: .capsule)
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - SnapshotRow

private struct SnapshotRow: View {
    let snapshot: NetWorthSnapshot
    let base: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "camera.fill", tint: FTColor.accent, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.date.formatted)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                HStack(spacing: FTSpacing.sm) {
                    Text("Assets: \(snapshot.totalAssets.asCompact(currency: base))")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.income)
                    Text("·")
                        .foregroundStyle(FTColor.textMuted)
                    Text("Liabilities: \(snapshot.totalLiabilities.asCompact(currency: base))")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.expense)
                }
            }
            Spacer()
            Text(snapshot.netWorth.asCompact(currency: base))
                .font(.ftBodySemibold)
                .foregroundStyle(snapshot.netWorth >= 0 ? FTColor.textPrimary : FTColor.expense)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }
}

// MARK: - StatPairView

private struct StatPairView: View {
    let label: String
    let value: String
    let color: Color
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label)
                .font(.ftLabel)
                .tracking(0.5)
                .foregroundStyle(FTColor.textSecondary)
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - ForecastSliderRow

private struct ForecastSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            HStack {
                Text(label)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text(format(value))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
                .tint(FTColor.accent)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - ForecastLegendItem

private struct ForecastLegendItem: View {
    let color: Color
    let dashed: Bool
    let label: String

    var body: some View {
        HStack(spacing: FTSpacing.xs) {
            if dashed {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color)
                            .frame(width: 6, height: 2)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 18, height: 2)
            }
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
    }
}

// MARK: - NWAllocationSliceRow

private struct NWAllocationSliceRow: View {
    let slice: AssetAllocationSlice
    let base: String

    var body: some View {
        VStack(spacing: FTSpacing.sm) {
            HStack {
                HStack(spacing: FTSpacing.sm) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)
                    Text(slice.label)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                }
                Spacer()
                Text(slice.value.formatted(as: base))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(slice.percentage.asPercentage(decimals: 1))
                    .font(.ftCallout)
                    .foregroundStyle(slice.color)
                    .frame(width: 52, alignment: .trailing)
            }
            FTProgressBar(value: slice.percentage / 100, color: slice.color, height: 6)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - MilestoneRow

private struct MilestoneRow: View {
    let amount: Double
    let baseCurrency: String
    let achievedMilestone: NetWorthMilestone?
    let isUnlocked: Bool

    private var isAchieved: Bool { achievedMilestone != nil }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle()
                    .fill(isAchieved ? FTColor.gold.opacity(0.15) : FTColor.textPrimary.opacity(0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: isAchieved ? "trophy.fill" : (isUnlocked ? "checkmark.circle.fill" : "lock.fill"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isAchieved ? FTColor.gold : (isUnlocked ? FTColor.income : FTColor.textMuted))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(amount.asCompact(currency: baseCurrency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(isAchieved ? FTColor.textPrimary : FTColor.textMuted)
                if let milestone = achievedMilestone {
                    Text("Achieved \(milestone.achievedAt.formatted)")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                } else if isUnlocked {
                    Text("Unlocked")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.income)
                } else {
                    Text("Not yet reached")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }
            }

            Spacer()

            if isAchieved {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FTColor.gold)
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
        .opacity(isAchieved || isUnlocked ? 1 : 0.55)
    }
}

// MARK: - PercentileGaugeView

private struct PercentileGaugeView: View {
    let percentile: Double
    @State private var animatedPercent: Double = 0

    private var angle: Double { (animatedPercent / 100) * 180 }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(FTColor.textPrimary.opacity(0.08), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(180))
                .frame(width: 160, height: 160)

            // Fill arc
            Circle()
                .trim(from: 0.5, to: 0.5 + (animatedPercent / 100) * 0.5)
                .stroke(
                    AngularGradient(
                        colors: [FTColor.expense, FTColor.gold, FTColor.income],
                        center: .center,
                        startAngle: .degrees(180),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(180))
                .frame(width: 160, height: 160)
                .animation(.spring(duration: 1.2), value: animatedPercent)

            VStack(spacing: 2) {
                Text(String(format: "%.0f", animatedPercent) + "%")
                    .font(.ftTitle)
                    .foregroundStyle(FTColor.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("Percentile")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }
            .offset(y: 16)
        }
        .frame(height: 110)
        .onAppear {
            withAnimation(.spring(duration: 1.2).delay(0.2)) {
                animatedPercent = percentile
            }
        }
    }
}

// MARK: - MilestoneBanner

private struct MilestoneBanner: View {
    let milestone: NetWorthMilestone
    let baseCurrency: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle()
                    .fill(FTColor.gold.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FTColor.gold)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Milestone Reached!")
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Your net worth crossed \(milestone.amount.asCompact(currency: baseCurrency))")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            Button {
                withAnimation { onDismiss() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.md)
        .background(FTColor.gold.opacity(0.08))
        .ftGlass(FTRadius.lg)
        .shadow(color: FTColor.gold.opacity(0.2), radius: 12, y: 4)
        .padding(.horizontal, FTSpacing.screen)
        .padding(.top, FTSpacing.md)
    }
}
