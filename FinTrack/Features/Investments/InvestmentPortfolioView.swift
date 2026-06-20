import SwiftUI
import SwiftData
import Charts

// MARK: - InvestmentPortfolioView

struct InvestmentPortfolioView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var investments: [Investment]
    @Query private var cryptoHoldings: [CryptoHolding]
    @Query(filter: #Predicate<GoldHolding> { !$0.isArchived }) private var goldHoldings: [GoldHolding]
    @Query private var dividends: [Dividend]
    @Query private var accounts: [Account]

    // MARK: - Tab State
    @State private var selectedTab = 0
    private let tabs = ["Overview", "Holdings", "Crypto", "Gold", "Allocation",
                        "Performance", "Dividends", "Cap Gains", "Scenarios", "Simulation"]

    // MARK: - Sheet State
    @State private var showingAddInvestment = false
    @State private var showingAddCrypto = false
    @State private var showingAddGold = false
    @State private var showingAddDividend = false
    @State private var selectedInvestment: Investment? = nil
    @State private var selectedCrypto: CryptoHolding? = nil
    @State private var selectedGold: GoldHolding? = nil

    // MARK: - Holdings Filter
    @State private var selectedTypeFilter: InvestmentType? = nil

    // MARK: - Gold
    @State private var weightDisplayUnit: WeightUnit = .grams

    // MARK: - Performance
    @State private var selectedBenchmark: BenchmarkType = .sp500
    @State private var benchmarkPeriodIndex = 1

    // MARK: - Capital Gains
    @State private var capitalGainsMethod: CostBasisMethod = .fifo
    @State private var capitalGainsTaxYear = 0

    // MARK: - Scenarios
    @State private var scenarioInitialValue: Double = 10000
    @State private var scenarioMonthly: Double = 1000
    @State private var scenarioFrequency: ContributionFrequency = .monthly
    @State private var scenarioReturn: Double = 7.0
    @State private var scenarioInflation: Double = 2.5
    @State private var scenarioYears: Double = 20
    @State private var projectionPoints: [ProjectionPoint] = []

    // MARK: - Monte Carlo
    @State private var mcInitial: Double = 10000
    @State private var mcMonthly: Double = 500
    @State private var mcYears: Double = 20
    @State private var mcMeanReturn: Double = 7.0
    @State private var mcStdDev: Double = 15.0
    @State private var mcTarget: Double = 500000
    @State private var mcResult: MonteCarloResult? = nil
    @State private var mcRunning = false

    private var baseCurrency: String { appState.baseCurrency }

    // MARK: - Computed Portfolio Values

    private var totalPortfolioValue: Double {
        InvestmentService.shared.totalValue(
            investments: Array(investments), cryptos: Array(cryptoHoldings),
            golds: Array(goldHoldings), currencyService: currencyService, baseCurrency: baseCurrency)
    }

    private var unrealizedPnL: Double {
        InvestmentService.shared.unrealizedPnL(
            investments: Array(investments), cryptos: Array(cryptoHoldings),
            golds: Array(goldHoldings), currencyService: currencyService, baseCurrency: baseCurrency)
    }

    private var realizedPnL: Double {
        InvestmentService.shared.totalRealizedPnL(
            investments: Array(investments), cryptos: Array(cryptoHoldings),
            currencyService: currencyService, baseCurrency: baseCurrency)
    }

    private var portfolioReturnPct: Double {
        InvestmentService.shared.portfolioReturn(
            investments: Array(investments), cryptos: Array(cryptoHoldings),
            golds: Array(goldHoldings), currencyService: currencyService, baseCurrency: baseCurrency)
    }

    private var stocksValue: Double {
        investments.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
    }

    private var cryptoValue: Double {
        cryptoHoldings.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
    }

    private var goldValue: Double {
        goldHoldings.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
    }

    private var annualDividends: Double {
        InvestmentService.shared.annualDividendIncome(
            dividends: Array(dividends), currencyService: currencyService, baseCurrency: baseCurrency)
    }

    private var allocationSlices: [AllocationSlice] {
        InvestmentService.shared.allocationSlices(
            investments: Array(investments), cryptos: Array(cryptoHoldings),
            golds: Array(goldHoldings), accounts: Array(accounts),
            currencyService: currencyService, baseCurrency: baseCurrency)
    }

    private var isEmpty: Bool {
        investments.isEmpty && cryptoHoldings.isEmpty && goldHoldings.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                VStack(spacing: 0) {
                    tabBar.padding(.top, FTSpacing.xs)
                    ScrollView {
                        Group {
                            switch selectedTab {
                            case 0:  overviewTab
                            case 1:  holdingsTab
                            case 2:  cryptoTab
                            case 3:  goldTab
                            case 4:  allocationTab
                            case 5:  performanceTab
                            case 6:  dividendsTab
                            case 7:  capitalGainsTab
                            case 8:  scenariosTab
                            case 9:  simulationTab
                            default: overviewTab
                            }
                        }
                        .padding(.bottom, FTSpacing.xxl + FTSpacing.lg)
                    }
                }
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .sheet(isPresented: $showingAddInvestment) { AddInvestmentView() }
            .sheet(isPresented: $showingAddCrypto) { AddCryptoView() }
            .sheet(isPresented: $showingAddGold) { AddGoldHoldingView() }
            .sheet(isPresented: $showingAddDividend) { AddDividendView() }
            .sheet(item: $selectedInvestment) { inv in InvestmentDetailSheet(investment: inv) }
            .sheet(item: $selectedCrypto) { crypto in CryptoDetailSheet(holding: crypto) }
            .sheet(item: $selectedGold) { gold in GoldDetailSheet(holding: gold) }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { selectedTab = i }
                    } label: {
                        FTChip(symbol: tabIcon(i), title: tabs[i], selected: selectedTab == i)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.xs)
        }
    }

    private func tabIcon(_ i: Int) -> String {
        switch i {
        case 0: return "chart.pie.fill"
        case 1: return "chart.line.uptrend.xyaxis"
        case 2: return "bitcoinsign.circle.fill"
        case 3: return "star.circle.fill"
        case 4: return "chart.pie"
        case 5: return "gauge.medium"
        case 6: return "banknote.fill"
        case 7: return "doc.text.fill"
        case 8: return "function"
        case 9: return "dice.fill"
        default: return "circle"
        }
    }

    // MARK: - Add Button

    @ViewBuilder
    private var addButton: some View {
        if [1, 2, 3, 6].contains(selectedTab) {
            Button {
                switch selectedTab {
                case 1: showingAddInvestment = true
                case 2: showingAddCrypto = true
                case 3: showingAddGold = true
                case 6: showingAddDividend = true
                default: break
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FTColor.accent)
            }
        }
    }

    // MARK: - Section Header Helper

    private func portfolioSectionHeader(_ title: String, symbol: String, tint: Color = FTColor.textSecondary) -> some View {
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

    // MARK: - TAB 0: OVERVIEW

    private var overviewTab: some View {
        VStack(spacing: FTSpacing.lg) {
            overviewHeroCard
                .padding(.horizontal, FTSpacing.screen)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.sm) {
                PortfolioStatCard(label: "Stocks & ETFs", value: stocksValue.asCompact(currency: baseCurrency), icon: "chart.line.uptrend.xyaxis", tint: FTColor.catBlue)
                PortfolioStatCard(label: "Crypto", value: cryptoValue.asCompact(currency: baseCurrency), icon: "bitcoinsign.circle.fill", tint: FTColor.catPurple)
                PortfolioStatCard(label: "Gold & Metals", value: goldValue.asCompact(currency: baseCurrency), icon: "star.circle.fill", tint: FTColor.gold)
                PortfolioStatCard(label: "Annual Dividends", value: annualDividends.asCompact(currency: baseCurrency), icon: "banknote.fill", tint: FTColor.income)
            }
            .padding(.horizontal, FTSpacing.screen)

            if isEmpty {
                EmptyStateView(
                    icon: "chart.pie.fill",
                    title: "No Holdings Yet",
                    message: "Add stocks, crypto, or gold to start tracking your portfolio.",
                    actionTitle: "Add Investment",
                    action: { showingAddInvestment = true }
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                let sorted = investments.sorted { $0.profitLossPercent > $1.profitLossPercent }
                let topPerformers = Array(sorted.prefix(3))
                let worstPerformers = Array(sorted.filter { !$0.isProfit }.suffix(2))

                if !topPerformers.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        portfolioSectionHeader("Top Performers", symbol: "arrow.up.right.circle.fill", tint: FTColor.income)
                            .padding(.horizontal, FTSpacing.screen)
                        VStack(spacing: FTSpacing.sm) {
                            ForEach(topPerformers, id: \.id) { inv in
                                PerformerRow(investment: inv, baseCurrency: baseCurrency, currencyService: currencyService, totalValue: totalPortfolioValue)
                                    .padding(.horizontal, FTSpacing.screen)
                            }
                        }
                    }
                }

                if !worstPerformers.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        portfolioSectionHeader("Worst Performers", symbol: "arrow.down.right.circle.fill", tint: FTColor.expense)
                            .padding(.horizontal, FTSpacing.screen)
                        VStack(spacing: FTSpacing.sm) {
                            ForEach(worstPerformers, id: \.id) { inv in
                                PerformerRow(investment: inv, baseCurrency: baseCurrency, currencyService: currencyService, totalValue: totalPortfolioValue)
                                    .padding(.horizontal, FTSpacing.screen)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    private var overviewHeroCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TOTAL PORTFOLIO VALUE")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            Text(totalPortfolioValue.formatted(as: baseCurrency))
                .font(.ftDisplay)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            HStack(spacing: FTSpacing.xs) {
                Image(systemName: unrealizedPnL >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                Text(unrealizedPnL.formatted(as: baseCurrency))
                    .font(.ftCallout)
                Text("(\(portfolioReturnPct.asPercentage(decimals: 1)))")
                    .font(.ftCallout)
            }
            .foregroundStyle(unrealizedPnL >= 0 ? FTColor.income : FTColor.expense)
            .padding(.horizontal, FTSpacing.sm + 2)
            .padding(.vertical, 5)
            .background((unrealizedPnL >= 0 ? FTColor.income : FTColor.expense).opacity(0.18), in: .capsule)

            Divider().background(.white.opacity(0.25))

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("UNREALIZED")
                        .font(.ftLabel).tracking(1.0).foregroundStyle(.white.opacity(0.7))
                    Text(unrealizedPnL.formatted(as: baseCurrency))
                        .font(.ftCallout)
                        .foregroundStyle(unrealizedPnL >= 0 ? FTColor.income : FTColor.expense)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("REALIZED")
                        .font(.ftLabel).tracking(1.0).foregroundStyle(.white.opacity(0.7))
                    Text(realizedPnL.formatted(as: baseCurrency))
                        .font(.ftCallout)
                        .foregroundStyle(realizedPnL >= 0 ? FTColor.income : FTColor.expense)
                }
            }
        }
        .padding(FTSpacing.xl)
        .background(FTColor.portfolioGradient, in: .rect(cornerRadius: FTRadius.xl))
        .shadow(color: Color(hex: 0x0B141E).opacity(0.4), radius: 24, y: 10)
    }

    // MARK: - TAB 1: HOLDINGS

    private var holdingsTab: some View {
        VStack(spacing: FTSpacing.lg) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { selectedTypeFilter = nil }
                    } label: {
                        FTChip(symbol: "square.grid.2x2.fill", title: "All", selected: selectedTypeFilter == nil)
                    }
                    .buttonStyle(.plain)

                    ForEach(InvestmentType.allCases, id: \.self) { type in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { selectedTypeFilter = type }
                        } label: {
                            FTChip(symbol: type.icon, title: type.rawValue, selected: selectedTypeFilter == type)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.vertical, FTSpacing.xs)
            }

            let filtered = selectedTypeFilter == nil
                ? Array(investments)
                : investments.filter { $0.type == selectedTypeFilter }

            if filtered.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No Holdings",
                    message: "Add your first stock, ETF, bond, or mutual fund.",
                    actionTitle: "Add Investment",
                    action: { showingAddInvestment = true }
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(filtered.sorted { $0.currentValue > $1.currentValue }, id: \.id) { inv in
                        Button { selectedInvestment = inv } label: {
                            HoldingRow(
                                investment: inv,
                                baseCurrency: baseCurrency,
                                currencyService: currencyService,
                                totalValue: totalPortfolioValue
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 2: CRYPTO

    private var cryptoTab: some View {
        VStack(spacing: FTSpacing.lg) {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("TOTAL CRYPTO VALUE")
                    .font(.ftLabel).tracking(1.6).foregroundStyle(.white.opacity(0.8))
                Text(cryptoValue.formatted(as: baseCurrency))
                    .font(.ftAmount).foregroundStyle(.white)
                    .minimumScaleFactor(0.5).lineLimit(1)

                if !cryptoHoldings.isEmpty {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(cryptoHoldings.sorted { $0.currentValue > $1.currentValue }, id: \.id) { c in
                                let fraction = cryptoValue > 0 ? c.currentValue / cryptoValue : 0
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(cryptoBarColor(symbol: c.symbol))
                                    .frame(width: max(4, geo.size.width * fraction))
                            }
                        }
                    }
                    .frame(height: 8)

                    HStack(spacing: FTSpacing.md) {
                        ForEach(Array(cryptoHoldings.sorted { $0.currentValue > $1.currentValue }.prefix(4)), id: \.id) { c in
                            HStack(spacing: 4) {
                                Circle().fill(cryptoBarColor(symbol: c.symbol)).frame(width: 8, height: 8)
                                Text(c.symbol.uppercased())
                                    .font(.ftLabel).tracking(0.5).foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                }
            }
            .padding(FTSpacing.xl)
            .background(
                LinearGradient(colors: [Color(hex: 0x7C5BD0), Color(hex: 0x4A2EA0)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: FTRadius.xl)
            )
            .shadow(color: Color(hex: 0x4A2EA0).opacity(0.4), radius: 20, y: 8)
            .padding(.horizontal, FTSpacing.screen)

            if cryptoHoldings.isEmpty {
                EmptyStateView(
                    icon: "bitcoinsign.circle.fill",
                    title: "No Crypto Holdings",
                    message: "Track BTC, ETH, USDT, and any altcoins.",
                    actionTitle: "Add Crypto",
                    action: { showingAddCrypto = true }
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(cryptoHoldings.sorted { $0.currentValue > $1.currentValue }, id: \.id) { crypto in
                        Button { selectedCrypto = crypto } label: {
                            PortfolioCryptoRow(holding: crypto, baseCurrency: baseCurrency, currencyService: currencyService)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    private func cryptoBarColor(symbol: String) -> Color {
        switch symbol.uppercased() {
        case "BTC":          return FTColor.gold
        case "ETH":          return FTColor.catBlue
        case "USDT", "USDC": return FTColor.income
        case "SOL":          return FTColor.catPurple
        case "BNB":          return FTColor.catGold
        default:             return FTColor.catTeal
        }
    }

    // MARK: - TAB 3: GOLD

    private var goldTab: some View {
        VStack(spacing: FTSpacing.lg) {
            FTSegmentedControl(
                options: WeightUnit.allCases.map { $0.rawValue },
                selection: Binding(
                    get: { WeightUnit.allCases.firstIndex(of: weightDisplayUnit) ?? 0 },
                    set: { weightDisplayUnit = WeightUnit.allCases[$0] }
                )
            )
            .padding(.horizontal, FTSpacing.screen)

            let totalWeightGrams = goldHoldings.reduce(0.0) { $0 + $1.weightGrams }
            let displayWeight = weightDisplayUnit.fromGrams(totalWeightGrams)

            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("TOTAL PRECIOUS METALS")
                    .font(.ftLabel).tracking(1.6).foregroundStyle(.white.opacity(0.8))
                Text(goldValue.formatted(as: baseCurrency))
                    .font(.ftAmount).foregroundStyle(.white)
                    .minimumScaleFactor(0.5).lineLimit(1)
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "scalemass.fill").font(.system(size: 13, weight: .semibold))
                    Text(String(format: "%.4g %@", displayWeight, weightDisplayUnit.rawValue)).font(.ftCallout)
                }
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(FTSpacing.xl)
            .background(
                LinearGradient(colors: [Color(hex: 0xC8902B), Color(hex: 0x8B6010)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: FTRadius.xl)
            )
            .shadow(color: Color(hex: 0x8B6010).opacity(0.4), radius: 20, y: 8)
            .padding(.horizontal, FTSpacing.screen)

            if goldHoldings.isEmpty {
                EmptyStateView(
                    icon: "star.circle.fill",
                    title: "No Precious Metals",
                    message: "Track gold bars, coins, jewelry, silver, platinum and more.",
                    actionTitle: "Add Gold",
                    action: { showingAddGold = true }
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                ForEach(PreciousMetal.allCases, id: \.self) { metal in
                    let metalHoldings = goldHoldings.filter { $0.metal == metal }
                    if !metalHoldings.isEmpty {
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            portfolioSectionHeader(metal.rawValue, symbol: metal.icon, tint: Color.fromString(metal.color))
                                .padding(.horizontal, FTSpacing.screen)
                            VStack(spacing: FTSpacing.sm) {
                                ForEach(metalHoldings, id: \.id) { holding in
                                    Button { selectedGold = holding } label: {
                                        GoldRow(holding: holding, displayUnit: weightDisplayUnit,
                                                baseCurrency: baseCurrency, currencyService: currencyService)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, FTSpacing.screen)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 4: ALLOCATION

    private var allocationTab: some View {
        VStack(spacing: FTSpacing.lg) {
            if allocationSlices.isEmpty {
                EmptyStateView(
                    icon: "chart.pie.fill",
                    title: "No Holdings",
                    message: "Add investments to see your allocation breakdown."
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                VStack(spacing: FTSpacing.md) {
                    portfolioSectionHeader("Asset Allocation", symbol: "chart.pie.fill", tint: FTColor.accent)

                    ZStack {
                        Chart(allocationSlices) { slice in
                            SectorMark(
                                angle: .value("Value", slice.value),
                                innerRadius: .ratio(0.58),
                                angularInset: 2
                            )
                            .foregroundStyle(slice.color)
                            .cornerRadius(4)
                        }
                        .frame(height: 220)

                        VStack(spacing: 3) {
                            Text(totalPortfolioValue.asCompact(currency: baseCurrency))
                                .font(.ftTitle)
                                .foregroundStyle(FTColor.textPrimary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("Total")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                        }
                    }
                }
                .padding(FTSpacing.lg)
                .ftGlass(FTRadius.lg)
                .padding(.horizontal, FTSpacing.screen)

                VStack(spacing: FTSpacing.sm) {
                    ForEach(allocationSlices) { slice in
                        AllocationSliceRow(slice: slice, baseCurrency: baseCurrency)
                            .padding(.horizontal, FTSpacing.screen)
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 5: PERFORMANCE

    private var performanceTab: some View {
        VStack(spacing: FTSpacing.lg) {
            VStack(spacing: FTSpacing.md) {
                Text("YOUR PORTFOLIO RETURN")
                    .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                HStack(alignment: .lastTextBaseline, spacing: FTSpacing.sm) {
                    Text(portfolioReturnPct.asPercentage(decimals: 2))
                        .font(.ftDisplay)
                        .foregroundStyle(portfolioReturnPct >= 0 ? FTColor.income : FTColor.expense)
                    Image(systemName: portfolioReturnPct >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(portfolioReturnPct >= 0 ? FTColor.income : FTColor.expense)
                }
                Text("Since Inception (vs. Cost Basis)")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(FTSpacing.xl)
            .ftGlass(FTRadius.xl)
            .padding(.horizontal, FTSpacing.screen)

            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                portfolioSectionHeader("Benchmark Comparison", symbol: "gauge.medium", tint: FTColor.catBlue)
                    .padding(.horizontal, FTSpacing.screen)
                FTSegmentedControl(
                    options: BenchmarkType.allCases.map { $0.rawValue },
                    selection: Binding(
                        get: { BenchmarkType.allCases.firstIndex(of: selectedBenchmark) ?? 0 },
                        set: { selectedBenchmark = BenchmarkType.allCases[$0] }
                    )
                )
                .padding(.horizontal, FTSpacing.screen)
            }

            FTSegmentedControl(options: ["1 Year", "3 Years", "5 Years"], selection: $benchmarkPeriodIndex)
                .padding(.horizontal, FTSpacing.screen)

            let years = [1, 3, 5][benchmarkPeriodIndex]
            let benchmarkTotal = selectedBenchmark.totalReturn(years: years)
            let benchmarkCAGR  = selectedBenchmark.cagr(years: years)
            let excess = portfolioReturnPct - benchmarkTotal

            VStack(spacing: FTSpacing.sm) {
                HStack(spacing: FTSpacing.sm) {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("YOUR PORTFOLIO")
                            .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                        Text(portfolioReturnPct.asPercentage(decimals: 1))
                            .font(.ftTitle)
                            .foregroundStyle(portfolioReturnPct >= 0 ? FTColor.income : FTColor.expense)
                        Text("Since inception")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FTSpacing.md)
                    .background(FTColor.income.opacity(0.07), in: .rect(cornerRadius: FTRadius.sm))

                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text(selectedBenchmark.rawValue.uppercased())
                            .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                        Text(benchmarkTotal.asPercentage(decimals: 1))
                            .font(.ftTitle).foregroundStyle(selectedBenchmark.color)
                        Text("CAGR \(benchmarkCAGR.asPercentage(decimals: 1))")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FTSpacing.md)
                    .background(selectedBenchmark.color.opacity(0.07), in: .rect(cornerRadius: FTRadius.sm))
                }
                .padding(FTSpacing.lg)
                .ftGlass(FTRadius.lg)
                .padding(.horizontal, FTSpacing.screen)

                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: excess >= 0 ? "trophy.fill" : "arrow.down.circle.fill",
                               tint: excess >= 0 ? FTColor.gold : FTColor.expense, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(excess >= 0 ? "Outperforming benchmark" : "Underperforming benchmark")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text("Excess return: \(excess.asPercentage(decimals: 2))")
                            .font(.ftCaption)
                            .foregroundStyle(excess >= 0 ? FTColor.income : FTColor.expense)
                    }
                    Spacer()
                }
                .padding(FTSpacing.lg)
                .ftGlass(FTRadius.lg)
                .padding(.horizontal, FTSpacing.screen)

                PerformanceBarChart(
                    portfolioReturn: portfolioReturnPct,
                    benchmarkReturn: benchmarkTotal,
                    benchmarkName: selectedBenchmark.rawValue,
                    benchmarkColor: selectedBenchmark.color
                )
                .padding(.horizontal, FTSpacing.screen)
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 6: DIVIDENDS

    private var dividendsTab: some View {
        VStack(spacing: FTSpacing.lg) {
            VStack(spacing: FTSpacing.sm) {
                Text("ANNUAL DIVIDEND INCOME")
                    .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                Text(annualDividends.formatted(as: baseCurrency))
                    .font(.ftDisplay).foregroundStyle(FTColor.income)
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text("Year to date (\(Calendar.current.component(.year, from: Date())))")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(FTSpacing.xl)
            .ftGlass(FTRadius.xl)
            .padding(.horizontal, FTSpacing.screen)

            if dividends.isEmpty {
                EmptyStateView(
                    icon: "banknote.fill",
                    title: "No Dividends",
                    message: "Record dividend payments from your stocks and ETFs.",
                    actionTitle: "Add Dividend",
                    action: { showingAddDividend = true }
                )
                .padding(.horizontal, FTSpacing.screen)
            } else {
                let upcoming = dividends
                    .filter { ($0.exDividendDate ?? Date.distantPast) > Date() }
                    .sorted { ($0.exDividendDate ?? Date.distantFuture) < ($1.exDividendDate ?? Date.distantFuture) }
                    .prefix(6)

                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        portfolioSectionHeader("Upcoming Ex-Dividend", symbol: "calendar.badge.clock", tint: FTColor.catBlue)
                            .padding(.horizontal, FTSpacing.screen)
                        VStack(spacing: FTSpacing.sm) {
                            ForEach(Array(upcoming), id: \.id) { div in
                                DividendRow(dividend: div, baseCurrency: baseCurrency, currencyService: currencyService)
                                    .padding(.horizontal, FTSpacing.screen)
                            }
                        }
                    }
                }

                let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
                let recent = dividends.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }

                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        portfolioSectionHeader("Payout History", symbol: "clock.fill", tint: FTColor.income)
                            .padding(.horizontal, FTSpacing.screen)

                        let grouped = Dictionary(grouping: recent) { $0.date.monthName }
                        let sortedMonths = grouped.keys.sorted {
                            let df = DateFormatter(); df.dateFormat = "MMMM yyyy"
                            return (df.date(from: $0) ?? Date()) > (df.date(from: $1) ?? Date())
                        }

                        ForEach(sortedMonths, id: \.self) { month in
                            let monthDivs = grouped[month] ?? []
                            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                                Text(month)
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                    .padding(.horizontal, FTSpacing.screen)
                                VStack(spacing: FTSpacing.sm) {
                                    ForEach(monthDivs, id: \.id) { div in
                                        DividendRow(dividend: div, baseCurrency: baseCurrency, currencyService: currencyService)
                                            .padding(.horizontal, FTSpacing.screen)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 7: CAPITAL GAINS

    private var capitalGainsTab: some View {
        let summary = InvestmentService.shared.capitalGainsSummary(
            investments: Array(investments), cryptos: Array(cryptoHoldings),
            currencyService: currencyService, baseCurrency: baseCurrency)

        return VStack(spacing: FTSpacing.lg) {
            FTSegmentedControl(
                options: CostBasisMethod.allCases.map { $0.rawValue },
                selection: Binding(
                    get: { CostBasisMethod.allCases.firstIndex(of: capitalGainsMethod) ?? 0 },
                    set: { capitalGainsMethod = CostBasisMethod.allCases[$0] }
                )
            )
            .padding(.horizontal, FTSpacing.screen)

            FTSegmentedControl(
                options: ["This Year", "Last Year", "All Time"],
                selection: $capitalGainsTaxYear
            )
            .padding(.horizontal, FTSpacing.screen)

            VStack(spacing: FTSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("REALIZED GAINS")
                            .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                        Text(summary.totalRealizedGain.formatted(as: baseCurrency))
                            .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("REALIZED LOSSES")
                            .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                        Text(summary.totalRealizedLoss.formatted(as: baseCurrency))
                            .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                    }
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NET REALIZED")
                            .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                        Text(summary.netRealized.formatted(as: baseCurrency))
                            .font(.ftTitle)
                            .foregroundStyle(summary.netRealized >= 0 ? FTColor.income : FTColor.expense)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("UNREALIZED")
                            .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                        Text(summary.totalUnrealized.formatted(as: baseCurrency))
                            .font(.ftBodySemibold)
                            .foregroundStyle(summary.totalUnrealized >= 0 ? FTColor.income : FTColor.expense)
                    }
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SHORT-TERM")
                            .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                        Text(summary.shortTermGain.formatted(as: baseCurrency))
                            .font(.ftCallout).foregroundStyle(FTColor.catCoral)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("LONG-TERM")
                            .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                        Text(summary.longTermGain.formatted(as: baseCurrency))
                            .font(.ftCallout).foregroundStyle(FTColor.income)
                    }
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)

            let currentYear = Calendar.current.component(.year, from: Date())
            let allSales: [(SaleRecord, String, String)] =
                investments.flatMap { inv in inv.sales.map { ($0, inv.symbol, inv.currency) } } +
                cryptoHoldings.flatMap { c in c.sales.map { ($0, c.symbol, c.currency) } }

            let filteredSales = allSales.filter { (sale, _, _) in
                let yr = Calendar.current.component(.year, from: sale.saleDate)
                switch capitalGainsTaxYear {
                case 0: return yr == currentYear
                case 1: return yr == currentYear - 1
                default: return true
                }
            }.sorted { $0.0.saleDate > $1.0.saleDate }

            if !filteredSales.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    portfolioSectionHeader("Sale Records", symbol: "list.bullet", tint: FTColor.accent)
                        .padding(.horizontal, FTSpacing.screen)
                    VStack(spacing: FTSpacing.sm) {
                        ForEach(filteredSales, id: \.0.id) { (sale, symbol, currency) in
                            SaleRecordRow(sale: sale, symbol: symbol, currency: currency,
                                          baseCurrency: baseCurrency, currencyService: currencyService)
                                .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            } else {
                Text("No sale records for the selected period.")
                    .font(.ftBody).foregroundStyle(FTColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FTSpacing.xxl)
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 8: SCENARIOS

    private var scenariosTab: some View {
        VStack(spacing: FTSpacing.lg) {
            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                Text("Investment Scenario Modeler")
                    .font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                Text("Project how your portfolio grows with compound interest over time.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FTSpacing.screen)

            VStack(spacing: 0) {
                ScenarioSliderRow(label: "Initial Value", value: $scenarioInitialValue,
                                  range: 0...1_000_000, step: 1000,
                                  format: { $0.asCompact(currency: baseCurrency) })
                Divider().padding(.leading, FTSpacing.screen)
                ScenarioSliderRow(label: "Monthly Contribution", value: $scenarioMonthly,
                                  range: 0...50_000, step: 100,
                                  format: { $0.asCompact(currency: baseCurrency) })
                Divider().padding(.leading, FTSpacing.screen)
                HStack {
                    Text("Frequency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Picker("", selection: $scenarioFrequency) {
                        ForEach(ContributionFrequency.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.menu).tint(FTColor.accent)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.vertical, FTSpacing.md)
                Divider().padding(.leading, FTSpacing.screen)
                ScenarioSliderRow(label: "Expected Return", value: $scenarioReturn,
                                  range: 0...20, step: 0.5,
                                  format: { "\($0.asPercentage(decimals: 1)) / yr" })
                Divider().padding(.leading, FTSpacing.screen)
                ScenarioSliderRow(label: "Inflation Rate", value: $scenarioInflation,
                                  range: 0...10, step: 0.5,
                                  format: { "\($0.asPercentage(decimals: 1)) / yr" })
                Divider().padding(.leading, FTSpacing.screen)
                ScenarioSliderRow(label: "Duration", value: $scenarioYears,
                                  range: 1...40, step: 1,
                                  format: { "\(Int($0)) yrs" })
            }
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)

            Button("Calculate Projection") {
                projectionPoints = InvestmentService.shared.projectPortfolio(
                    initialValue: scenarioInitialValue,
                    monthlyContribution: scenarioMonthly,
                    frequency: scenarioFrequency,
                    annualReturn: scenarioReturn,
                    inflationRate: scenarioInflation,
                    years: Int(scenarioYears)
                )
            }
            .buttonStyle(.ftPrimary)
            .padding(.horizontal, FTSpacing.screen)

            if !projectionPoints.isEmpty {
                if let last = projectionPoints.last {
                    VStack(spacing: FTSpacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("FINAL VALUE (NOMINAL)")
                                    .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                                Text(last.nominalValue.formatted(as: baseCurrency))
                                    .font(.ftTitle).foregroundStyle(FTColor.income)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("REAL (INFLATION-ADJ)")
                                    .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                                Text(last.realValue.formatted(as: baseCurrency))
                                    .font(.ftTitle).foregroundStyle(FTColor.catBlue)
                            }
                        }
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("TOTAL CONTRIBUTIONS")
                                    .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                                Text(last.totalContributions.formatted(as: baseCurrency))
                                    .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("GROWTH")
                                    .font(.ftLabel).tracking(1.0).foregroundStyle(FTColor.textSecondary)
                                Text(last.growthComponent.formatted(as: baseCurrency))
                                    .font(.ftCallout).foregroundStyle(FTColor.income)
                            }
                        }
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.lg)
                    .padding(.horizontal, FTSpacing.screen)
                }

                ProjectionLineChart(points: projectionPoints, baseCurrency: baseCurrency)
                    .padding(.horizontal, FTSpacing.screen)

                let initialVal = projectionPoints.first?.nominalValue ?? 0
                if initialVal > 0 {
                    let milestones: [(String, Double)] = [("2×", initialVal * 2), ("5×", initialVal * 5), ("10×", initialVal * 10)]
                    let reached = milestones.compactMap { (label, target) -> (String, Int)? in
                        guard let pt = projectionPoints.first(where: { $0.nominalValue >= target }) else { return nil }
                        return (label, pt.year)
                    }
                    if !reached.isEmpty {
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            portfolioSectionHeader("Key Milestones", symbol: "flag.fill", tint: FTColor.gold)
                                .padding(.horizontal, FTSpacing.screen)
                            HStack(spacing: FTSpacing.sm) {
                                ForEach(reached, id: \.0) { (label, year) in
                                    VStack(spacing: 4) {
                                        Text(label).font(.ftTitle).foregroundStyle(FTColor.gold)
                                        Text("Year \(year)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(FTSpacing.md)
                                    .background(FTColor.gold.opacity(0.1), in: .rect(cornerRadius: FTRadius.sm))
                                }
                            }
                            .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            }
        }
        .padding(.top, FTSpacing.md)
    }

    // MARK: - TAB 9: SIMULATION

    private var simulationTab: some View {
        VStack(spacing: FTSpacing.lg) {
            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                Text("Monte Carlo Simulation")
                    .font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                Text("Runs 1,000 randomised market scenarios to estimate the probability of reaching your target. Results show statistical ranges, not guarantees.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FTSpacing.screen)

            VStack(spacing: 0) {
                ScenarioSliderRow(label: "Starting Balance", value: $mcInitial,
                                  range: 0...1_000_000, step: 1000,
                                  format: { $0.asCompact(currency: baseCurrency) })
                Divider().padding(.leading, FTSpacing.screen)
                ScenarioSliderRow(label: "Monthly Contribution", value: $mcMonthly,
                                  range: 0...20_000, step: 100,
                                  format: { $0.asCompact(currency: baseCurrency) })
                Divider().padding(.leading, FTSpacing.screen)
                ScenarioSliderRow(label: "Years to Simulate", value: $mcYears,
                                  range: 1...40, step: 1,
                                  format: { "\(Int($0)) yrs" })
                Divider().padding(.leading, FTSpacing.screen)
                ScenarioSliderRow(label: "Mean Annual Return", value: $mcMeanReturn,
                                  range: 0...30, step: 0.5,
                                  format: { $0.asPercentage(decimals: 1) })
                Divider().padding(.leading, FTSpacing.screen)
                ScenarioSliderRow(label: "Std Dev (Volatility)", value: $mcStdDev,
                                  range: 1...50, step: 0.5,
                                  format: { $0.asPercentage(decimals: 1) })
                Divider().padding(.leading, FTSpacing.screen)
                ScenarioSliderRow(label: "Target Amount", value: $mcTarget,
                                  range: 10_000...10_000_000, step: 10_000,
                                  format: { $0.asCompact(currency: baseCurrency) })
            }
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)

            Button {
                mcRunning = true
                mcResult = nil
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = InvestmentService.shared.monteCarlo(
                        initialValue: mcInitial,
                        monthlyContribution: mcMonthly,
                        years: Int(mcYears),
                        meanAnnualReturn: mcMeanReturn,
                        stdDevAnnualReturn: mcStdDev,
                        iterations: 1_000,
                        targetAmount: mcTarget
                    )
                    DispatchQueue.main.async {
                        mcResult = result
                        mcRunning = false
                    }
                }
            } label: {
                if mcRunning {
                    HStack(spacing: FTSpacing.sm) {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Running Simulation…")
                    }
                } else {
                    Text("Run Simulation (1,000 iterations)")
                }
            }
            .buttonStyle(.ftPrimary)
            .disabled(mcRunning)
            .padding(.horizontal, FTSpacing.screen)

            if let result = mcResult {
                let probColor: Color = result.successProbability >= 70 ? FTColor.income
                    : result.successProbability >= 50 ? FTColor.gold : FTColor.expense

                VStack(spacing: FTSpacing.sm) {
                    Text("SUCCESS PROBABILITY")
                        .font(.ftLabel).tracking(1.6).foregroundStyle(.white.opacity(0.8))
                    Text(result.successProbability.asPercentage(decimals: 1))
                        .font(.ftDisplay).foregroundStyle(.white)
                    Text("of \(result.iterations) iterations reached \(result.targetAmount.asCompact(currency: baseCurrency))")
                        .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(FTSpacing.xl)
                .background(probColor, in: .rect(cornerRadius: FTRadius.xl))
                .shadow(color: probColor.opacity(0.4), radius: 20, y: 8)
                .padding(.horizontal, FTSpacing.screen)

                VStack(spacing: FTSpacing.md) {
                    portfolioSectionHeader("Distribution", symbol: "list.number", tint: FTColor.accent)
                    VStack(spacing: FTSpacing.sm) {
                        ForEach([
                            ("P10 (Pessimistic)", result.percentile10, FTColor.expense),
                            ("P25", result.percentile25, FTColor.catCoral),
                            ("Median (P50)", result.median, FTColor.textPrimary),
                            ("P75", result.percentile75, FTColor.catBlue),
                            ("P90 (Optimistic)", result.percentile90, FTColor.income)
                        ], id: \.0) { label, value, color in
                            HStack {
                                Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Text(value.formatted(as: baseCurrency)).font(.ftBodySemibold).foregroundStyle(color)
                            }
                        }
                    }
                }
                .padding(FTSpacing.lg)
                .ftGlass(FTRadius.lg)
                .padding(.horizontal, FTSpacing.screen)

                MonteCarloLineChart(result: result, baseCurrency: baseCurrency)
                    .padding(.horizontal, FTSpacing.screen)

                MonteCarloHistogram(finalValues: result.finalValues, targetAmount: result.targetAmount, baseCurrency: baseCurrency)
                    .padding(.horizontal, FTSpacing.screen)
            }
        }
        .padding(.top, FTSpacing.md)
    }
}

// MARK: - PortfolioStatCard

private struct PortfolioStatCard: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: FTSpacing.sm) {
            FTIconTile(symbol: icon, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(label)
                    .font(.ftLabel).tracking(0.3)
                    .foregroundStyle(FTColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - PerformerRow

private struct PerformerRow: View {
    let investment: Investment
    let baseCurrency: String
    let currencyService: CurrencyService
    let totalValue: Double

    private var value: Double {
        currencyService.convert(investment.currentValue, from: investment.currency, to: baseCurrency)
    }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: investment.type.icon, tint: Color.fromString(investment.type.color), size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(investment.symbol).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(investment.name).font(.ftCaption).foregroundStyle(FTColor.textSecondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 3) {
                    Image(systemName: investment.isProfit ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text(investment.profitLossPercent.asPercentage(decimals: 2)).font(.ftCallout)
                }
                .foregroundStyle(investment.isProfit ? FTColor.income : FTColor.expense)
                Text(value.asCompact(currency: baseCurrency)).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(FTSpacing.md)
        .ftGlassInteractive(FTRadius.md)
    }
}

// MARK: - HoldingRow

private struct HoldingRow: View {
    let investment: Investment
    let baseCurrency: String
    let currencyService: CurrencyService
    let totalValue: Double

    private var value: Double {
        currencyService.convert(investment.currentValue, from: investment.currency, to: baseCurrency)
    }
    private var allocationPct: Double { totalValue > 0 ? (value / totalValue) * 100 : 0 }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: investment.type.icon, tint: Color.fromString(investment.type.color), size: 42)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: FTSpacing.xs) {
                    Text(investment.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                    BadgeView(text: investment.symbol, color: Color.fromString(investment.type.color))
                }
                Text(investment.exchange ?? investment.type.rawValue)
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(value.formatted(as: baseCurrency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    .minimumScaleFactor(0.7).lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: investment.isProfit ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text(investment.profitLossPercent.asPercentage(decimals: 1)).font(.ftCaption)
                }
                .foregroundStyle(investment.isProfit ? FTColor.income : FTColor.expense)
                Text(allocationPct.asPercentage(decimals: 1))
                    .font(.ftLabel).tracking(0.3).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.md)
        .ftGlassInteractive(FTRadius.md)
    }
}

// MARK: - PortfolioCryptoRow

private struct PortfolioCryptoRow: View {
    let holding: CryptoHolding
    let baseCurrency: String
    let currencyService: CurrencyService

    private var value: Double {
        currencyService.convert(holding.currentValue, from: holding.currency, to: baseCurrency)
    }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "bitcoinsign.circle.fill", tint: FTColor.catPurple, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(holding.symbol.uppercased()).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("\(holding.name) · \(String(format: "%.6g", holding.quantity))")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(value.formatted(as: baseCurrency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    .minimumScaleFactor(0.7).lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text(holding.profitLossPercent.asPercentage(decimals: 1)).font(.ftCaption)
                }
                .foregroundStyle(holding.isProfit ? FTColor.income : FTColor.expense)
            }
        }
        .padding(FTSpacing.md)
        .ftGlassInteractive(FTRadius.md)
    }
}

// MARK: - GoldRow

private struct GoldRow: View {
    let holding: GoldHolding
    let displayUnit: WeightUnit
    let baseCurrency: String
    let currencyService: CurrencyService

    private var value: Double {
        currencyService.convert(holding.currentValue, from: holding.currency, to: baseCurrency)
    }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: holding.form.icon, tint: Color.fromString(holding.metal.color), size: 42)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: FTSpacing.xs) {
                    Text(holding.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                    BadgeView(text: holding.form.rawValue, color: Color.fromString(holding.metal.color))
                    if holding.isDubaiGoldSoukPurchase {
                        BadgeView(text: "Souk", color: FTColor.gold)
                    }
                }
                Text(String(format: "%.4g %@ · %@",
                            displayUnit.fromGrams(holding.weightGrams),
                            displayUnit.rawValue,
                            holding.purchaseDate.formatted))
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(value.formatted(as: baseCurrency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    .minimumScaleFactor(0.7).lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text(holding.profitLossPercent.asPercentage(decimals: 1)).font(.ftCaption)
                }
                .foregroundStyle(holding.isProfit ? FTColor.income : FTColor.expense)
            }
        }
        .padding(FTSpacing.md)
        .ftGlassInteractive(FTRadius.md)
    }
}

// MARK: - AllocationSliceRow

private struct AllocationSliceRow: View {
    let slice: AllocationSlice
    let baseCurrency: String

    var body: some View {
        VStack(spacing: FTSpacing.sm) {
            HStack {
                HStack(spacing: FTSpacing.sm) {
                    Circle().fill(slice.color).frame(width: 10, height: 10)
                    Text(slice.label).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                }
                Spacer()
                Text(slice.value.formatted(as: baseCurrency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text(slice.percentage.asPercentage(decimals: 1))
                    .font(.ftCallout).foregroundStyle(slice.color)
                    .frame(width: 52, alignment: .trailing)
            }
            FTProgressBar(value: slice.percentage / 100, color: slice.color, height: 6)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - DividendRow

private struct DividendRow: View {
    let dividend: Dividend
    let baseCurrency: String
    let currencyService: CurrencyService

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "banknote.fill", tint: FTColor.income, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(dividend.securityName ?? "Unknown Security")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                if let exDate = dividend.exDividendDate {
                    Text("Ex-Div: \(exDate.formatted)")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                } else {
                    Text(dividend.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(currencyService.convert(dividend.netAmount, from: dividend.currency, to: baseCurrency).formatted(as: baseCurrency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                if dividend.taxWithholding > 0 {
                    Text("Tax: \(dividend.taxWithholding.formatted(as: dividend.currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.expense)
                }
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - SaleRecordRow

private struct SaleRecordRow: View {
    let sale: SaleRecord
    let symbol: String
    let currency: String
    let baseCurrency: String
    let currencyService: CurrencyService

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: sale.isGain ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                       tint: sale.isGain ? FTColor.income : FTColor.expense, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: FTSpacing.xs) {
                    Text(symbol.uppercased()).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    BadgeView(text: sale.isLongTerm ? "Long-Term" : "Short-Term",
                              color: sale.isLongTerm ? FTColor.income : FTColor.catCoral)
                }
                Text("\(String(format: "%.4g", sale.quantity)) units · \(sale.saleDate.formatted)")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(currencyService.convert(sale.realizedPnL, from: currency, to: baseCurrency).formatted(as: baseCurrency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(sale.isGain ? FTColor.income : FTColor.expense)
                Text("Proceeds: \(currencyService.convert(sale.proceeds, from: currency, to: baseCurrency).asCompact(currency: baseCurrency))")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - ScenarioSliderRow

private struct ScenarioSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            HStack {
                Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text(format(value)).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).monospacedDigit()
            }
            Slider(value: $value, in: range, step: step).tint(FTColor.accent)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - PerformanceBarChart

private struct PerformanceBarChart: View {
    let portfolioReturn: Double
    let benchmarkReturn: Double
    let benchmarkName: String
    let benchmarkColor: Color

    private struct BarPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }

    private var data: [BarPoint] {[
        BarPoint(label: "Portfolio", value: portfolioReturn, color: FTColor.income),
        BarPoint(label: benchmarkName, value: benchmarkReturn, color: benchmarkColor)
    ]}

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: "chart.bar.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(FTColor.textSecondary)
                Text("RETURN COMPARISON").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
            }
            Chart(data) { point in
                BarMark(x: .value("Asset", point.label), y: .value("Return %", point.value))
                    .foregroundStyle(point.color)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text(point.value.asPercentage(decimals: 1))
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent().scale(0.01)).foregroundStyle(FTColor.textMuted).font(.ftLabel)
                    AxisGridLine().foregroundStyle(FTColor.textPrimary.opacity(0.05))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textSecondary).font(.ftCallout)
                }
            }
            .frame(height: 180)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - ProjectionLineChart

private struct ProjectionLineChart: View {
    let points: [ProjectionPoint]
    let baseCurrency: String

    private struct ChartPoint: Identifiable {
        let id = UUID(); let year: Int; let value: Double; let series: String
    }

    private var chartData: [ChartPoint] {
        points.flatMap { p in [
            ChartPoint(year: p.year, value: p.nominalValue, series: "Nominal"),
            ChartPoint(year: p.year, value: p.realValue, series: "Real (Inflation-Adj)")
        ]}
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 13, weight: .semibold)).foregroundStyle(FTColor.textSecondary)
                Text("GROWTH PROJECTION").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
            }
            Chart(chartData) { p in
                LineMark(x: .value("Year", p.year), y: .value("Value", p.value))
                    .foregroundStyle(by: .value("Series", p.series))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            .chartForegroundStyleScale(["Nominal": FTColor.income, "Real (Inflation-Adj)": FTColor.catBlue])
            .chartLegend(position: .bottom, alignment: .center, spacing: FTSpacing.sm)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textMuted).font(.ftLabel)
                    AxisGridLine().foregroundStyle(FTColor.textPrimary.opacity(0.05))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textMuted).font(.ftLabel)
                }
            }
            .frame(height: 200)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - MonteCarloLineChart

private struct MonteCarloLineChart: View {
    let result: MonteCarloResult
    let baseCurrency: String

    private struct YearPoint: Identifiable {
        let id = UUID(); let year: Int; let value: Double; let series: String
    }

    private var chartData: [YearPoint] {
        let count = result.yearlyMedians.count
        guard count > 0, result.median > 0 else { return [] }
        let f10 = result.percentile10 / result.median
        let f90 = result.percentile90 / result.median
        var pts: [YearPoint] = []
        for i in 0..<count {
            let m = result.yearlyMedians[i]
            pts.append(YearPoint(year: i, value: m * f10, series: "P10"))
            pts.append(YearPoint(year: i, value: m, series: "Median"))
            pts.append(YearPoint(year: i, value: m * f90, series: "P90"))
        }
        return pts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: "waveform.path.ecg").font(.system(size: 13, weight: .semibold)).foregroundStyle(FTColor.textSecondary)
                Text("SCENARIO PATHS").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
            }
            Chart(chartData) { pt in
                LineMark(x: .value("Year", pt.year), y: .value("Value", pt.value))
                    .foregroundStyle(by: .value("Percentile", pt.series))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: pt.series == "Median" ? 2.5 : 1.5,
                                           dash: pt.series == "Median" ? [] : [4, 3]))
            }
            .chartForegroundStyleScale(["P10": FTColor.expense, "Median": FTColor.accent, "P90": FTColor.income])
            .chartLegend(position: .bottom, alignment: .center, spacing: FTSpacing.sm)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textMuted).font(.ftLabel)
                    AxisGridLine().foregroundStyle(FTColor.textPrimary.opacity(0.05))
                }
            }
            .frame(height: 200)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - MonteCarloHistogram

private struct MonteCarloHistogram: View {
    let finalValues: [Double]
    let targetAmount: Double
    let baseCurrency: String

    private struct Bucket: Identifiable {
        let id = UUID(); let label: String; let count: Int; let isAboveTarget: Bool
    }

    private var buckets: [Bucket] {
        guard let minVal = finalValues.min(), let maxVal = finalValues.max(), maxVal > minVal else { return [] }
        let n = 10
        let width = (maxVal - minVal) / Double(n)
        return (0..<n).map { i in
            let lo = minVal + Double(i) * width
            let hi = lo + width
            let cnt = finalValues.filter { v in i == n - 1 ? v >= lo && v <= hi : v >= lo && v < hi }.count
            let mid = (lo + hi) / 2
            return Bucket(label: mid.asCompact(currency: baseCurrency), count: cnt, isAboveTarget: mid >= targetAmount)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: "chart.bar.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(FTColor.textSecondary)
                Text("FINAL VALUE DISTRIBUTION").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
            }
            Chart(buckets) { bucket in
                BarMark(x: .value("Value", bucket.label), y: .value("Count", bucket.count))
                    .foregroundStyle(bucket.isAboveTarget ? FTColor.income : FTColor.expense)
                    .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textMuted).font(.system(size: 8))
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textMuted).font(.ftLabel)
                    AxisGridLine().foregroundStyle(FTColor.textPrimary.opacity(0.05))
                }
            }
            .frame(height: 160)

            HStack(spacing: FTSpacing.sm) {
                Circle().fill(FTColor.income).frame(width: 8, height: 8)
                Text("Above target").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Circle().fill(FTColor.expense).frame(width: 8, height: 8)
                Text("Below target").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text("Target: \(targetAmount.asCompact(currency: baseCurrency))")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - InvestmentDetailSheet

private struct InvestmentDetailSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    let investment: Investment
    @State private var showingRecordSale = false
    @State private var showingEdit = false

    private var baseCurrency: String { appState.baseCurrency }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: investment.type.icon, tint: Color.fromString(investment.type.color), size: 64)
                            Text(investment.symbol).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                            Text(investment.name).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            BadgeView(text: investment.type.rawValue, color: Color.fromString(investment.type.color))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, FTSpacing.lg)

                        VStack(spacing: FTSpacing.md) {
                            HStack {
                                detailStat("Quantity", String(format: "%.4g", investment.quantity))
                                Spacer()
                                detailStat("Avg Cost", investment.averageCost.formatted(as: investment.currency))
                                Spacer()
                                detailStat("Current Price", investment.currentPrice.formatted(as: investment.currency))
                            }
                            Divider()
                            HStack {
                                detailStat("Value",
                                    currencyService.convert(investment.currentValue, from: investment.currency, to: baseCurrency).formatted(as: baseCurrency))
                                Spacer()
                                detailStat("P&L",
                                    currencyService.convert(investment.profitLoss, from: investment.currency, to: baseCurrency).formatted(as: baseCurrency),
                                    color: investment.isProfit ? FTColor.income : FTColor.expense)
                                Spacer()
                                detailStat("Return",
                                    investment.profitLossPercent.asPercentage(decimals: 2),
                                    color: investment.isProfit ? FTColor.income : FTColor.expense)
                            }
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        // Purchase Lots
                        if !investment.lots.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                lotHeader("PURCHASE LOTS", symbol: "list.bullet.rectangle")
                                VStack(spacing: FTSpacing.sm) {
                                    ForEach(investment.lots.sorted { $0.purchaseDate < $1.purchaseDate }) { lot in
                                        HStack(spacing: FTSpacing.md) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(lot.purchaseDate.formatted).font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                                                if let n = lot.notes { Text(n).font(.ftCaption).foregroundStyle(FTColor.textMuted).lineLimit(1) }
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 3) {
                                                Text(String(format: "%.4g units", lot.quantity)).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                                Text("@ \(lot.costPerUnit.formatted(as: investment.currency))").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                            }
                                        }
                                        .padding(FTSpacing.md).ftGlass(FTRadius.md)
                                        .padding(.horizontal, FTSpacing.screen)
                                    }
                                }
                            }
                        }

                        // Sale History
                        if !investment.sales.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                lotHeader("SALE HISTORY", symbol: "arrow.left.arrow.right.circle.fill")
                                VStack(spacing: FTSpacing.sm) {
                                    ForEach(investment.sales.sorted { $0.saleDate > $1.saleDate }) { sale in
                                        HStack(spacing: FTSpacing.md) {
                                            FTIconTile(symbol: sale.isGain ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                                                       tint: sale.isGain ? FTColor.income : FTColor.expense, size: 36)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(sale.saleDate.formatted).font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                                                Text("\(String(format: "%.4g", sale.quantity)) @ \(sale.salePricePerUnit.formatted(as: investment.currency))")
                                                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 3) {
                                                Text(sale.realizedPnL.formatted(as: investment.currency))
                                                    .font(.ftBodySemibold)
                                                    .foregroundStyle(sale.isGain ? FTColor.income : FTColor.expense)
                                                BadgeView(text: sale.isLongTerm ? "Long" : "Short",
                                                          color: sale.isLongTerm ? FTColor.income : FTColor.catCoral)
                                            }
                                        }
                                        .padding(FTSpacing.md).ftGlass(FTRadius.md)
                                        .padding(.horizontal, FTSpacing.screen)
                                    }
                                }
                            }
                        }

                        if investment.quantity > 0 {
                            Button { showingRecordSale = true } label: {
                                Label("Record Sale", systemImage: "arrow.up.circle.fill")
                            }
                            .buttonStyle(.ftPrimary)
                            .padding(.horizontal, FTSpacing.screen)
                        }

                        Spacer(minLength: FTSpacing.xxl)
                    }
                }
            }
            .navigationTitle(investment.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingEdit = true } label: { Image(systemName: "pencil").foregroundStyle(FTColor.accent) }
                }
            }
            .sheet(isPresented: $showingRecordSale) { RecordSaleSheet(investment: investment) }
            .sheet(isPresented: $showingEdit) { AddInvestmentView(editingItem: investment) }
        }
    }

    private func detailStat(_ label: String, _ value: String, color: Color = FTColor.textPrimary) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.ftLabel).tracking(0.5).foregroundStyle(FTColor.textSecondary)
            Text(value).font(.ftCallout).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    private func lotHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: FTSpacing.xs) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(FTColor.textSecondary)
            Text(title).font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
        }
        .padding(.horizontal, FTSpacing.screen)
    }
}

// MARK: - RecordSaleSheet

private struct RecordSaleSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let investment: Investment

    @State private var quantityText: String = ""
    @State private var salePriceText: String = ""
    @State private var saleDate: Date = Date()
    @State private var methodIndex: Int = 0
    @State private var notes: String = ""
    @State private var estimatedPnL: Double? = nil

    private var quantity: Double { Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var salePrice: Double { Double(salePriceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var method: CostBasisMethod { CostBasisMethod.allCases[methodIndex] }
    private var isValid: Bool { quantity > 0 && quantity <= investment.quantity && salePrice > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            saleRow("Quantity (max \(String(format: "%.4g", investment.quantity)))") {
                                TextField("0.00", text: $quantityText)
                                    .keyboardType(.decimalPad)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: quantityText) { _, _ in recomputePnL() }
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            saleRow("Sale Price (\(investment.currency))") {
                                TextField("0.00", text: $salePriceText)
                                    .keyboardType(.decimalPad)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: salePriceText) { _, _ in recomputePnL() }
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            saleRow("Sale Date") {
                                DatePicker("", selection: $saleDate, displayedComponents: .date)
                                    .labelsHidden().tint(FTColor.accent)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            saleRow("Notes") {
                                TextField("Optional", text: $notes)
                                    .font(.ftBody).foregroundStyle(FTColor.textPrimary).multilineTextAlignment(.trailing)
                            }
                        }
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("Cost Basis Method").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                .padding(.horizontal, FTSpacing.screen)
                            FTSegmentedControl(
                                options: CostBasisMethod.allCases.map { $0.rawValue },
                                selection: $methodIndex
                            )
                            .padding(.horizontal, FTSpacing.screen)
                            .onChange(of: methodIndex) { _, _ in recomputePnL() }
                        }

                        if let pnl = estimatedPnL {
                            HStack(spacing: FTSpacing.md) {
                                FTIconTile(symbol: pnl >= 0 ? "checkmark.circle.fill" : "xmark.circle.fill",
                                           tint: pnl >= 0 ? FTColor.income : FTColor.expense, size: 42)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Estimated Realized P&L").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text(pnl.formatted(as: investment.currency))
                                        .font(.ftTitle).foregroundStyle(pnl >= 0 ? FTColor.income : FTColor.expense)
                                }
                                Spacer()
                            }
                            .padding(FTSpacing.lg).ftGlass(FTRadius.lg)
                            .padding(.horizontal, FTSpacing.screen)
                        }

                        Button("Confirm Sale") { recordSale() }
                            .buttonStyle(.ftPrimary)
                            .disabled(!isValid)
                            .padding(.horizontal, FTSpacing.screen)

                        Spacer(minLength: FTSpacing.xxl)
                    }
                    .padding(.top, FTSpacing.lg)
                }
            }
            .navigationTitle("Record Sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.accent)
                }
            }
        }
    }

    private func saleRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            content()
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }

    private func recomputePnL() {
        guard quantity > 0, salePrice > 0, !investment.lots.isEmpty else { estimatedPnL = nil; return }
        let r = InvestmentService.shared.calculateGain(lots: investment.lots, selling: quantity, at: salePrice, method: method)
        estimatedPnL = r.realizedPnL
    }

    private func recordSale() {
        guard isValid else { return }
        let gain = InvestmentService.shared.calculateGain(lots: investment.lots, selling: quantity, at: salePrice, method: method)
        let record = SaleRecord(quantity: quantity, salePricePerUnit: salePrice, saleDate: saleDate,
                                costBasis: gain.costBasis, method: method, notes: notes.isEmpty ? nil : notes)
        investment.sales = investment.sales + [record]
        investment.lots = gain.remainingLots
        investment.quantity -= quantity
        investment.realizedPnL += gain.realizedPnL
        investment.updatedAt = Date()
        let tx = Transaction(title: "Sold \(String(format: "%.4g", quantity)) \(investment.symbol)",
                             amount: salePrice * quantity, currency: investment.currency,
                             type: .income, category: .investmentIncome, date: saleDate,
                             notes: notes.isEmpty ? nil : notes)
        context.insert(tx)
        try? context.save()
        dismiss()
    }
}

// MARK: - CryptoDetailSheet

private struct CryptoDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    let holding: CryptoHolding
    @State private var showingEdit = false

    private var baseCurrency: String { appState.baseCurrency }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: "bitcoinsign.circle.fill", tint: FTColor.catPurple, size: 64)
                            Text(holding.symbol.uppercased()).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                            Text(holding.name).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity).padding(.top, FTSpacing.lg)

                        VStack(spacing: FTSpacing.md) {
                            HStack {
                                cs("Quantity", String(format: "%.6g", holding.quantity))
                                Spacer()
                                cs("Avg Cost", holding.averageCost.formatted(as: holding.currency))
                                Spacer()
                                cs("Price", holding.currentPrice.formatted(as: holding.currency))
                            }
                            Divider()
                            HStack {
                                cs("Value", currencyService.convert(holding.currentValue, from: holding.currency, to: baseCurrency).formatted(as: baseCurrency))
                                Spacer()
                                cs("P&L", currencyService.convert(holding.profitLoss, from: holding.currency, to: baseCurrency).formatted(as: baseCurrency),
                                   color: holding.isProfit ? FTColor.income : FTColor.expense)
                                Spacer()
                                cs("Return", holding.profitLossPercent.asPercentage(decimals: 2),
                                   color: holding.isProfit ? FTColor.income : FTColor.expense)
                            }
                        }
                        .padding(FTSpacing.lg).ftGlass(FTRadius.lg).padding(.horizontal, FTSpacing.screen)

                        VStack(spacing: 0) {
                            if let ex = holding.exchange, !ex.isEmpty { cdr("Exchange", ex); Divider().padding(.leading, FTSpacing.screen) }
                            if let w = holding.walletAddress, !w.isEmpty { cdr("Wallet", String(w.prefix(20)) + "…"); Divider().padding(.leading, FTSpacing.screen) }
                            cdr("Purchase Date", holding.purchaseDate.formatted)
                            if let n = holding.notes, !n.isEmpty { Divider().padding(.leading, FTSpacing.screen); cdr("Notes", n) }
                        }
                        .ftGlass(FTRadius.lg).padding(.horizontal, FTSpacing.screen)

                        if !holding.lots.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                sectionLabel("PURCHASE LOTS", symbol: "list.bullet.rectangle")
                                VStack(spacing: FTSpacing.sm) {
                                    ForEach(holding.lots.sorted { $0.purchaseDate < $1.purchaseDate }) { lot in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(lot.purchaseDate.formatted).font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                                                if let n = lot.notes { Text(n).font(.ftCaption).foregroundStyle(FTColor.textMuted).lineLimit(1) }
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 3) {
                                                Text(String(format: "%.6g", lot.quantity)).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                                Text("@ \(lot.costPerUnit.formatted(as: holding.currency))").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                            }
                                        }
                                        .padding(FTSpacing.md).ftGlass(FTRadius.md).padding(.horizontal, FTSpacing.screen)
                                    }
                                }
                            }
                        }

                        if !holding.sales.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                sectionLabel("SALE HISTORY", symbol: "arrow.left.arrow.right.circle.fill")
                                VStack(spacing: FTSpacing.sm) {
                                    ForEach(holding.sales.sorted { $0.saleDate > $1.saleDate }) { sale in
                                        HStack(spacing: FTSpacing.md) {
                                            FTIconTile(symbol: sale.isGain ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                                                       tint: sale.isGain ? FTColor.income : FTColor.expense, size: 36)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(sale.saleDate.formatted).font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                                                Text("\(String(format: "%.6g", sale.quantity)) @ \(sale.salePricePerUnit.formatted(as: holding.currency))")
                                                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                            }
                                            Spacer()
                                            Text(sale.realizedPnL.formatted(as: holding.currency))
                                                .font(.ftBodySemibold)
                                                .foregroundStyle(sale.isGain ? FTColor.income : FTColor.expense)
                                        }
                                        .padding(FTSpacing.md).ftGlass(FTRadius.md).padding(.horizontal, FTSpacing.screen)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: FTSpacing.xxl)
                    }
                }
            }
            .navigationTitle(holding.symbol.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingEdit = true } label: { Image(systemName: "pencil").foregroundStyle(FTColor.accent) }
                }
            }
            .sheet(isPresented: $showingEdit) { AddCryptoView(editingItem: holding) }
        }
    }

    private func cs(_ label: String, _ value: String, color: Color = FTColor.textPrimary) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.ftLabel).tracking(0.5).foregroundStyle(FTColor.textSecondary)
            Text(value).font(.ftCallout).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    private func cdr(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, FTSpacing.screen).padding(.vertical, FTSpacing.md)
    }

    private func sectionLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: FTSpacing.xs) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(FTColor.textSecondary)
            Text(title).font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
        }
        .padding(.horizontal, FTSpacing.screen)
    }
}

// MARK: - GoldDetailSheet

private struct GoldDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    let holding: GoldHolding
    @State private var showingEdit = false

    private var baseCurrency: String { appState.baseCurrency }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: holding.form.icon, tint: Color.fromString(holding.metal.color), size: 64)
                            Text(holding.name).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                            HStack(spacing: FTSpacing.xs) {
                                BadgeView(text: holding.metal.rawValue, color: Color.fromString(holding.metal.color))
                                BadgeView(text: holding.form.rawValue, color: FTColor.textSecondary)
                                if holding.isDubaiGoldSoukPurchase {
                                    BadgeView(text: "Dubai Gold Souk", color: FTColor.gold)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.top, FTSpacing.lg)

                        VStack(spacing: FTSpacing.md) {
                            HStack {
                                gs("Weight", String(format: "%.4g g", holding.weightGrams))
                                Spacer()
                                gs("Buy/g", holding.purchasePricePerGram.formatted(as: holding.currency))
                                Spacer()
                                gs("Current/g", holding.currentPricePerGram.formatted(as: holding.currency))
                            }
                            Divider()
                            HStack {
                                gs("Cost", currencyService.convert(holding.totalCost, from: holding.currency, to: baseCurrency).formatted(as: baseCurrency))
                                Spacer()
                                gs("Value", currencyService.convert(holding.currentValue, from: holding.currency, to: baseCurrency).formatted(as: baseCurrency))
                                Spacer()
                                gs("P&L", currencyService.convert(holding.profitLoss, from: holding.currency, to: baseCurrency).formatted(as: baseCurrency),
                                   color: holding.isProfit ? FTColor.income : FTColor.expense)
                            }
                        }
                        .padding(FTSpacing.lg).ftGlass(FTRadius.lg).padding(.horizontal, FTSpacing.screen)

                        VStack(spacing: 0) {
                            gdr("Purchase Date", holding.purchaseDate.formatted)
                            if let loc = holding.storageLocation, !loc.isEmpty {
                                Divider().padding(.leading, FTSpacing.screen)
                                gdr("Storage", loc)
                            }
                            if let src = holding.locationPurchased, !src.isEmpty {
                                Divider().padding(.leading, FTSpacing.screen)
                                gdr("Purchased At", src)
                            }
                            if let n = holding.notes, !n.isEmpty {
                                Divider().padding(.leading, FTSpacing.screen)
                                gdr("Notes", n)
                            }
                        }
                        .ftGlass(FTRadius.lg).padding(.horizontal, FTSpacing.screen)

                        Spacer(minLength: FTSpacing.xxl)
                    }
                }
            }
            .navigationTitle(holding.metal.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingEdit = true } label: { Image(systemName: "pencil").foregroundStyle(FTColor.accent) }
                }
            }
            .sheet(isPresented: $showingEdit) { AddGoldHoldingView(editingItem: holding) }
        }
    }

    private func gs(_ label: String, _ value: String, color: Color = FTColor.textPrimary) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.ftLabel).tracking(0.5).foregroundStyle(FTColor.textSecondary)
            Text(value).font(.ftCallout).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    private func gdr(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, FTSpacing.screen).padding(.vertical, FTSpacing.md)
    }
}
