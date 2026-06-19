import SwiftUI
import SwiftData
import Charts

// MARK: - InvestmentPortfolioView

struct InvestmentPortfolioView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.dismiss) private var dismiss

    @Query private var investments: [Investment]
    @Query private var cryptos: [CryptoHolding]
    @Query private var golds: [GoldHolding]
    @Query private var dividends: [Dividend]
    @Query private var accounts: [Account]

    @State private var selectedTab: PortfolioTab = .overview
    @State private var showingAddInvestment = false
    @State private var showingAddCrypto = false
    @State private var showingAddGold = false
    @State private var editingInvestment: Investment?
    @State private var editingCrypto: CryptoHolding?
    @State private var editingGold: GoldHolding?

    private var baseCurrency: String { appState.baseCurrency }
    private var svc: InvestmentService { .shared }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                VStack(spacing: 0) {
                    tabBar
                    tabContent
                }
            }
            .navigationTitle("Investment Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addMenu
                }
            }
            .sheet(isPresented: $showingAddInvestment) {
                AddInvestmentView()
            }
            .sheet(isPresented: $showingAddCrypto) {
                AddCryptoView()
            }
            .sheet(isPresented: $showingAddGold) {
                AddGoldHoldingView()
            }
            .sheet(item: $editingInvestment) { inv in
                AddInvestmentView(editingItem: inv)
            }
            .sheet(item: $editingCrypto) { c in
                AddCryptoView(editingItem: c)
            }
            .sheet(item: $editingGold) { g in
                AddGoldHoldingView(editingItem: g)
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(PortfolioTab.allCases, id: \.self) { tab in
                    FilterChip(title: tab.rawValue, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.sm)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:    OverviewTab(investments: investments, cryptos: cryptos, golds: golds, accounts: accounts, dividends: dividends)
        case .holdings:    HoldingsTab(investments: investments, onEdit: { editingInvestment = $0 }, onDelete: deleteInvestment)
        case .crypto:      CryptoTab(cryptos: cryptos, onEdit: { editingCrypto = $0 }, onDelete: deleteCrypto)
        case .gold:        GoldTab(golds: golds, onEdit: { editingGold = $0 }, onDelete: deleteGold)
        case .allocation:  AllocationTab(investments: investments, cryptos: cryptos, golds: golds, accounts: accounts)
        case .performance: PerformanceTab(investments: investments, cryptos: cryptos, golds: golds)
        case .dividends:   DividendsTab(dividends: dividends, investments: investments)
        case .capGains:    CapGainsTab(investments: investments, cryptos: cryptos)
        case .scenarios:   ScenariosTab(investments: investments, cryptos: cryptos, golds: golds)
        case .simulation:  SimulationTab(investments: investments, cryptos: cryptos, golds: golds)
        }
    }

    // MARK: - Add Menu

    private var addMenu: some View {
        Menu {
            Button { showingAddInvestment = true } label: {
                Label("Add Stock / ETF / Fund", systemImage: "chart.line.uptrend.xyaxis")
            }
            Button { showingAddCrypto = true } label: {
                Label("Add Crypto", systemImage: "bitcoinsign.circle")
            }
            Button { showingAddGold = true } label: {
                Label("Add Gold / Precious Metal", systemImage: "star.circle.fill")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    // MARK: - Delete Helpers

    private func deleteInvestment(_ inv: Investment) {
        context.delete(inv)
    }
    private func deleteCrypto(_ c: CryptoHolding) {
        context.delete(c)
    }
    private func deleteGold(_ g: GoldHolding) {
        context.delete(g)
    }
}

// MARK: - Tab Enum

enum PortfolioTab: String, CaseIterable {
    case overview   = "Overview"
    case holdings   = "Stocks"
    case crypto     = "Crypto"
    case gold       = "Gold"
    case allocation = "Allocation"
    case performance = "Performance"
    case dividends  = "Dividends"
    case capGains   = "Cap Gains"
    case scenarios  = "Scenarios"
    case simulation = "Simulation"
}

// MARK: - Overview Tab

private struct OverviewTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let investments: [Investment]
    let cryptos: [CryptoHolding]
    let golds: [GoldHolding]
    let accounts: [Account]
    let dividends: [Dividend]

    private var svc: InvestmentService { .shared }
    private var base: String { appState.baseCurrency }

    private var totalValue: Double { svc.totalValue(investments: investments, cryptos: cryptos, golds: golds, currencyService: currencyService, baseCurrency: base) }
    private var unrealized: Double { svc.unrealizedPnL(investments: investments, cryptos: cryptos, golds: golds, currencyService: currencyService, baseCurrency: base) }
    private var realized: Double { svc.totalRealizedPnL(investments: investments, cryptos: cryptos, currencyService: currencyService, baseCurrency: base) }
    private var slices: [AllocationSlice] { svc.allocationSlices(investments: investments, cryptos: cryptos, golds: golds, accounts: accounts, currencyService: currencyService, baseCurrency: base) }
    private var portfolioRet: Double { svc.portfolioReturn(investments: investments, cryptos: cryptos, golds: golds, currencyService: currencyService, baseCurrency: base) }
    private var ytdDividends: Double { svc.annualDividendIncome(dividends: dividends, currencyService: currencyService, baseCurrency: base) }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                // Hero card
                heroCard
                // Quick metrics
                metricsGrid
                // Allocation donut
                if !slices.isEmpty { miniAllocation }
                // Top movers
                topMovers
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.sm)
            .padding(.bottom, 120)
        }
    }

    private var heroCard: some View {
        VStack(spacing: FTSpacing.sm) {
            Text("Portfolio Value")
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            Text(totalValue.formatted(as: base))
                .font(.ftDisplay).foregroundStyle(FTColor.textPrimary)
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: unrealized >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(unrealized >= 0 ? "+" : "")\(unrealized.asCompact(currency: base)) unrealized")
                Text("·")
                Text("\(portfolioRet >= 0 ? "+" : "")\(portfolioRet.asPercentage(decimals: 2))")
            }
            .font(.ftCallout)
            .foregroundStyle(unrealized >= 0 ? FTColor.income : FTColor.expense)
        }
        .frame(maxWidth: .infinity)
        .padding(FTSpacing.xl)
        .ftGlass(FTRadius.xl)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.md) {
            metricCard(label: "Unrealized P&L", value: unrealized, isGain: unrealized >= 0)
            metricCard(label: "Realized P&L", value: realized, isGain: realized >= 0)
            metricCard(label: "YTD Dividends", value: ytdDividends, isGain: true)
            metricCard(label: "Total Return %", percent: portfolioRet)
        }
    }

    private func metricCard(label: String, value: Double, isGain: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            Text(value.formatted(as: base))
                .font(.ftBodySemibold)
                .foregroundStyle(isGain ? FTColor.income : FTColor.expense)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private func metricCard(label: String, percent: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            Text(percent.asPercentage(decimals: 2))
                .font(.ftBodySemibold)
                .foregroundStyle(percent >= 0 ? FTColor.income : FTColor.expense)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var miniAllocation: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Allocation").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            HStack(alignment: .center, spacing: FTSpacing.xl) {
                Chart(slices) { slice in
                    SectorMark(angle: .value("Value", slice.value), innerRadius: .ratio(0.55), angularInset: 2)
                        .foregroundStyle(slice.color).cornerRadius(3)
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    ForEach(slices.prefix(5)) { slice in
                        HStack(spacing: 6) {
                            Circle().fill(slice.color).frame(width: 8, height: 8)
                            Text(slice.label).font(.ftCaption).foregroundStyle(FTColor.textPrimary)
                            Spacer()
                            Text(slice.percentage.asPercentage()).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                    }
                    if slices.count > 5 {
                        Text("+ \(slices.count - 5) more").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    private var topMovers: some View {
        let allItems: [(name: String, pnlPct: Double, value: Double)] = (
            investments.map { ($0.name, $0.profitLossPercent, $0.currentValue) } +
            cryptos.map { ($0.name, $0.profitLossPercent, $0.currentValue) } +
            golds.filter { !$0.isArchived }.map { ($0.name, $0.profitLossPercent, $0.currentValue) }
        ).sorted { abs($0.pnlPct) > abs($1.pnlPct) }.prefix(4).map { $0 }

        guard !allItems.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("Top Movers").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                VStack(spacing: 0) {
                    ForEach(Array(allItems.enumerated()), id: \.offset) { idx, item in
                        HStack {
                            Text(item.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            Spacer()
                            Text(item.pnlPct >= 0 ? "+\(item.pnlPct.asPercentage())" : item.pnlPct.asPercentage())
                                .font(.ftBodySemibold)
                                .foregroundStyle(item.pnlPct >= 0 ? FTColor.income : FTColor.expense)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .padding(.vertical, FTSpacing.md)
                        if idx < allItems.count - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .ftGlass(FTRadius.lg)
            }
        )
    }
}

// MARK: - Holdings Tab (Stocks / ETF / MF)

private struct HoldingsTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let investments: [Investment]
    let onEdit: (Investment) -> Void
    let onDelete: (Investment) -> Void

    private var base: String { appState.baseCurrency }

    var body: some View {
        if investments.isEmpty {
            emptyState(icon: "chart.line.uptrend.xyaxis", title: "No Holdings", sub: "Add your first stock, ETF, or fund.")
        } else {
            ScrollView {
                VStack(spacing: FTSpacing.lg) {
                    totalsBar
                    VStack(spacing: 0) {
                        ForEach(Array(investments.enumerated()), id: \.element.id) { idx, inv in
                            InvestmentRow(inv: inv, base: base)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { onDelete(inv) } label: { Label("Delete", systemImage: "trash") }
                                    Button { onEdit(inv) } label: { Label("Edit", systemImage: "pencil") }
                                        .tint(FTColor.accent)
                                }
                            if idx < investments.count - 1 { Divider().padding(.leading, 56) }
                        }
                    }
                    .ftGlass(FTRadius.lg)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.sm)
                .padding(.bottom, 120)
            }
        }
    }

    private var totalsBar: some View {
        let total = investments.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base)
        }
        let cost = investments.reduce(0.0) {
            $0 + currencyService.convert($1.totalCost, from: $1.currency, to: base)
        }
        let pnl = total - cost
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Market Value").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(total.formatted(as: base)).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Unrealized P&L").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(pnl.formatted(as: base)).font(.ftBodySemibold)
                    .foregroundStyle(pnl >= 0 ? FTColor.income : FTColor.expense)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

private struct InvestmentRow: View {
    @Environment(CurrencyService.self) private var currencyService
    let inv: Investment
    let base: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: inv.type.icon, tint: Color.fromString(inv.type.color), size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(inv.symbol).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(inv.name).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(currencyService.convert(inv.currentValue, from: inv.currency, to: base).formatted(as: base))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(inv.profitLossPercent >= 0 ? "+\(inv.profitLossPercent.asPercentage())" : inv.profitLossPercent.asPercentage())
                    .font(.ftCaption)
                    .foregroundStyle(inv.isProfit ? FTColor.income : FTColor.expense)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - Crypto Tab

private struct CryptoTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let cryptos: [CryptoHolding]
    let onEdit: (CryptoHolding) -> Void
    let onDelete: (CryptoHolding) -> Void
    private var base: String { appState.baseCurrency }

    var body: some View {
        if cryptos.isEmpty {
            emptyState(icon: "bitcoinsign.circle.fill", title: "No Crypto", sub: "Add your BTC, ETH, or other holdings.")
        } else {
            ScrollView {
                VStack(spacing: FTSpacing.lg) {
                    cryptoTotals
                    VStack(spacing: 0) {
                        ForEach(Array(cryptos.enumerated()), id: \.element.id) { idx, c in
                            CryptoRow(c: c, base: base)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { onDelete(c) } label: { Label("Delete", systemImage: "trash") }
                                    Button { onEdit(c) } label: { Label("Edit", systemImage: "pencil") }.tint(FTColor.accent)
                                }
                            if idx < cryptos.count - 1 { Divider().padding(.leading, 56) }
                        }
                    }
                    .ftGlass(FTRadius.lg)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.sm)
                .padding(.bottom, 120)
            }
        }
    }

    private var cryptoTotals: some View {
        let total = cryptos.reduce(0.0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) }
        let cost  = cryptos.reduce(0.0) { $0 + currencyService.convert($1.totalCost,    from: $1.currency, to: base) }
        let pnl   = total - cost
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Portfolio Value").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(total.formatted(as: base)).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Unrealized P&L").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(pnl.formatted(as: base)).font(.ftBodySemibold)
                    .foregroundStyle(pnl >= 0 ? FTColor.income : FTColor.expense)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

private struct CryptoRow: View {
    @Environment(CurrencyService.self) private var currencyService
    let c: CryptoHolding
    let base: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "bitcoinsign.circle.fill", tint: FTColor.gold, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(c.symbol).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("\(c.quantity.formatted(.number.precision(.fractionLength(4)))) \(c.symbol)")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(currencyService.convert(c.currentValue, from: c.currency, to: base).formatted(as: base))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(c.profitLossPercent >= 0 ? "+\(c.profitLossPercent.asPercentage())" : c.profitLossPercent.asPercentage())
                    .font(.ftCaption).foregroundStyle(c.isProfit ? FTColor.income : FTColor.expense)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - Gold Tab

private struct GoldTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let golds: [GoldHolding]
    let onEdit: (GoldHolding) -> Void
    let onDelete: (GoldHolding) -> Void
    private var base: String { appState.baseCurrency }

    private var activeGolds: [GoldHolding] { golds.filter { !$0.isArchived } }

    var body: some View {
        if activeGolds.isEmpty {
            emptyState(icon: "star.circle.fill", title: "No Precious Metals", sub: "Add gold, silver, or platinum holdings.")
        } else {
            ScrollView {
                VStack(spacing: FTSpacing.lg) {
                    goldTotals
                    VStack(spacing: 0) {
                        ForEach(Array(activeGolds.enumerated()), id: \.element.id) { idx, g in
                            GoldRow(g: g, base: base)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { onDelete(g) } label: { Label("Delete", systemImage: "trash") }
                                    Button { onEdit(g) } label: { Label("Edit", systemImage: "pencil") }.tint(FTColor.accent)
                                }
                            if idx < activeGolds.count - 1 { Divider().padding(.leading, 56) }
                        }
                    }
                    .ftGlass(FTRadius.lg)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.sm)
                .padding(.bottom, 120)
            }
        }
    }

    private var goldTotals: some View {
        let total = activeGolds.reduce(0.0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) }
        let pnl   = activeGolds.reduce(0.0) { $0 + currencyService.convert($1.profitLoss, from: $1.currency, to: base) }
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Value").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(total.formatted(as: base)).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Profit / Loss").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(pnl.formatted(as: base)).font(.ftBodySemibold)
                    .foregroundStyle(pnl >= 0 ? FTColor.income : FTColor.expense)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

private struct GoldRow: View {
    @Environment(CurrencyService.self) private var currencyService
    let g: GoldHolding
    let base: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: g.metal.icon, tint: FTColor.gold, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: FTSpacing.xs) {
                    Text(g.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if g.isDubaiGoldSoukPurchase {
                        Text("DGS").font(.ftLabel)
                            .foregroundStyle(FTColor.gold)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(FTColor.gold.opacity(0.15), in: Capsule())
                    }
                }
                Text("\(g.weightInPreferredUnit.formatted(.number.precision(.fractionLength(2)))) \(g.weightUnit.rawValue) · \(g.metal.rawValue)")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(currencyService.convert(g.currentValue, from: g.currency, to: base).formatted(as: base))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(g.profitLossPercent >= 0 ? "+\(g.profitLossPercent.asPercentage())" : g.profitLossPercent.asPercentage())
                    .font(.ftCaption).foregroundStyle(g.isProfit ? FTColor.income : FTColor.expense)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - Allocation Tab

private struct AllocationTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let investments: [Investment]
    let cryptos: [CryptoHolding]
    let golds: [GoldHolding]
    let accounts: [Account]

    private var base: String { appState.baseCurrency }
    private var slices: [AllocationSlice] {
        InvestmentService.shared.allocationSlices(
            investments: investments, cryptos: cryptos, golds: golds,
            accounts: accounts, currencyService: currencyService, baseCurrency: base)
    }
    private var total: Double { slices.reduce(0) { $0 + $1.value } }

    var body: some View {
        if slices.isEmpty {
            emptyState(icon: "chart.pie.fill", title: "No Data", sub: "Add investments to see allocation.")
        } else {
            ScrollView {
                VStack(spacing: FTSpacing.lg) {
                    donutChart
                    breakdownList
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.sm)
                .padding(.bottom, 120)
            }
        }
    }

    private var donutChart: some View {
        VStack(spacing: FTSpacing.md) {
            Text("Portfolio Allocation")
                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                Chart(slices) { slice in
                    SectorMark(angle: .value("Value", slice.value),
                               innerRadius: .ratio(0.6), angularInset: 2)
                        .foregroundStyle(slice.color).cornerRadius(4)
                }
                .frame(height: 240)
                VStack(spacing: 2) {
                    Text(total.asCompact(currency: base))
                        .font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                    Text("Total").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var breakdownList: some View {
        VStack(spacing: 0) {
            ForEach(Array(slices.enumerated()), id: \.element.id) { idx, slice in
                VStack(spacing: FTSpacing.xs) {
                    HStack(spacing: FTSpacing.md) {
                        Circle().fill(slice.color).frame(width: 12, height: 12)
                        Text(slice.label).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Spacer()
                        Text(slice.value.formatted(as: base))
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text(slice.percentage.asPercentage())
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                    FTProgressBar(value: slice.percentage / 100, color: slice.color)
                }
                .padding(.horizontal, FTSpacing.lg)
                .padding(.vertical, FTSpacing.md)
                if idx < slices.count - 1 { Divider().padding(.leading, 40) }
            }
        }
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - Performance Tab

private struct PerformanceTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let investments: [Investment]
    let cryptos: [CryptoHolding]
    let golds: [GoldHolding]

    @State private var selectedBenchmark: BenchmarkType = .sp500
    @State private var selectedYears: Int = 5

    private var base: String { appState.baseCurrency }
    private var portfolioRet: Double {
        InvestmentService.shared.portfolioReturn(investments: investments, cryptos: cryptos, golds: golds,
                                                 currencyService: currencyService, baseCurrency: base)
    }
    private var benchmarkRet: Double { selectedBenchmark.totalReturn(years: selectedYears) }
    private var excess: Double { portfolioRet - benchmarkRet }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                benchmarkPicker
                returnComparison
                excessReturnCard
                benchmarkDetails
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.sm)
            .padding(.bottom, 120)
        }
    }

    private var benchmarkPicker: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("Benchmark").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            FTSegmentedControl(
                options: BenchmarkType.allCases.map { $0.rawValue },
                selection: Binding(
                    get: { BenchmarkType.allCases.firstIndex(of: selectedBenchmark) ?? 0 },
                    set: { selectedBenchmark = BenchmarkType.allCases[$0] }
                )
            )
            HStack(spacing: FTSpacing.sm) {
                ForEach([1, 3, 5, 10], id: \.self) { y in
                    FilterChip(title: "\(y)Y", isSelected: selectedYears == y) { selectedYears = y }
                }
            }
        }
    }

    private var returnComparison: some View {
        VStack(spacing: FTSpacing.sm) {
            Chart {
                BarMark(x: .value("", "Your Portfolio"), y: .value("Return %", portfolioRet))
                    .foregroundStyle(portfolioRet >= 0 ? FTColor.income : FTColor.expense)
                    .cornerRadius(6)
                BarMark(x: .value("", selectedBenchmark.rawValue), y: .value("Return %", benchmarkRet))
                    .foregroundStyle(FTColor.accent.opacity(0.7))
                    .cornerRadius(6)
            }
            .frame(height: 180)
            .padding(.vertical, FTSpacing.sm)
            .chartYAxis {
                AxisMarks(values: .automatic) { val in
                    AxisGridLine()
                    AxisValueLabel { if let d = val.as(Double.self) { Text(d.asPercentage()) } }
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var excessReturnCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Excess Return vs \(selectedBenchmark.rawValue)")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text("\(excess >= 0 ? "+" : "")\(excess.asPercentage(decimals: 2))")
                    .font(.ftTitle).foregroundStyle(excess >= 0 ? FTColor.income : FTColor.expense)
            }
            Spacer()
            FTIconTile(
                symbol: excess >= 0 ? "trophy.fill" : "arrow.down.circle.fill",
                tint: excess >= 0 ? FTColor.income : FTColor.expense,
                size: 44
            )
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var benchmarkDetails: some View {
        VStack(spacing: 0) {
            benchmarkRow(label: "Your Portfolio", value: portfolioRet, color: portfolioRet >= 0 ? FTColor.income : FTColor.expense)
            Divider().padding(.leading, 16)
            benchmarkRow(label: selectedBenchmark.rawValue, value: benchmarkRet, color: FTColor.accent)
            Divider().padding(.leading, 16)
            benchmarkRow(label: "Alpha", value: excess, color: excess >= 0 ? FTColor.income : FTColor.expense)
            Divider().padding(.leading, 16)
            benchmarkRow(label: "Benchmark CAGR (\(selectedYears)Y)", value: selectedBenchmark.cagr(years: selectedYears), color: FTColor.textPrimary)
        }
        .ftGlass(FTRadius.lg)
    }

    private func benchmarkRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text("\(value >= 0 ? "+" : "")\(value.asPercentage(decimals: 2))")
                .font(.ftBodySemibold).foregroundStyle(color)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - Dividends Tab

private struct DividendsTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let dividends: [Dividend]
    let investments: [Investment]

    private var base: String { appState.baseCurrency }
    private var ytd: Double {
        InvestmentService.shared.annualDividendIncome(dividends: dividends, currencyService: currencyService, baseCurrency: base)
    }
    private var sorted: [Dividend] { dividends.sorted { $0.date > $1.date } }

    var body: some View {
        if dividends.isEmpty {
            emptyState(icon: "dollarsign.circle.fill", title: "No Dividends", sub: "Dividend payments will appear here.")
        } else {
            ScrollView {
                VStack(spacing: FTSpacing.lg) {
                    ytdCard
                    dividendList
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.sm)
                .padding(.bottom, 120)
            }
        }
    }

    private var ytdCard: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "dollarsign.circle.fill", tint: FTColor.income, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("YTD Dividend Income").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(ytd.formatted(as: base)).font(.ftTitle).foregroundStyle(FTColor.income)
            }
            Spacer()
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var dividendList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Dividend History").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, div in
                    HStack(spacing: FTSpacing.md) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(div.securityName ?? "Dividend").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            Text(div.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            if let ex = div.exDividendDate {
                                Text("Ex-div: \(ex.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.ftLabel).foregroundStyle(FTColor.textMuted)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(currencyService.convert(div.netAmount, from: div.currency, to: base).formatted(as: base))
                                .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                            if div.taxWithholding > 0 {
                                Text("Tax: \(div.taxWithholding.formatted(as: div.currency))")
                                    .font(.ftCaption).foregroundStyle(FTColor.expense)
                            }
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .padding(.vertical, FTSpacing.md)
                    if idx < sorted.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .ftGlass(FTRadius.lg)
        }
    }
}

// MARK: - Capital Gains Tab

private struct CapGainsTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let investments: [Investment]
    let cryptos: [CryptoHolding]

    private var base: String { appState.baseCurrency }
    private var summary: CapitalGainsSummary {
        InvestmentService.shared.capitalGainsSummary(investments: investments, cryptos: cryptos,
                                                     currencyService: currencyService, baseCurrency: base)
    }
    private var allSales: [(name: String, date: Date, pnl: Double, isLT: Bool)] {
        let invSales = investments.flatMap { inv in
            inv.sales.map { s in (name: inv.name, date: s.saleDate, pnl: currencyService.convert(s.realizedPnL, from: inv.currency, to: base), isLT: s.isLongTerm) }
        }
        let crySales = cryptos.flatMap { c in
            c.sales.map { s in (name: c.name, date: s.saleDate, pnl: currencyService.convert(s.realizedPnL, from: c.currency, to: base), isLT: s.isLongTerm) }
        }
        return (invSales + crySales).sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                summaryCard
                if !allSales.isEmpty { salesList }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.sm)
            .padding(.bottom, 120)
        }
    }

    private var summaryCard: some View {
        let s = summary
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Capital Gains Summary").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            VStack(spacing: 0) {
                gainRow(label: "Net Realized", value: s.netRealized)
                Divider().padding(.leading, 16)
                gainRow(label: "Short-term Gain", value: s.shortTermGain)
                Divider().padding(.leading, 16)
                gainRow(label: "Long-term Gain", value: s.longTermGain)
                Divider().padding(.leading, 16)
                gainRow(label: "Total Losses", value: -s.totalRealizedLoss)
                Divider().padding(.leading, 16)
                gainRow(label: "Unrealized", value: s.totalUnrealized)
            }
            .ftGlass(FTRadius.lg)
        }
    }

    private func gainRow(label: String, value: Double) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value.formatted(as: base)).font(.ftBodySemibold)
                .foregroundStyle(value >= 0 ? FTColor.income : FTColor.expense)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }

    private var salesList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Sale History").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            VStack(spacing: 0) {
                ForEach(Array(allSales.enumerated()), id: \.offset) { idx, sale in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(sale.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            HStack(spacing: FTSpacing.xs) {
                                Text(sale.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Text(sale.isLT ? "Long-term" : "Short-term")
                                    .font(.ftLabel)
                                    .foregroundStyle(sale.isLT ? FTColor.income : FTColor.catCoral)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background((sale.isLT ? FTColor.income : FTColor.catCoral).opacity(0.12), in: Capsule())
                            }
                        }
                        Spacer()
                        Text(sale.pnl.formatted(as: base)).font(.ftBodySemibold)
                            .foregroundStyle(sale.pnl >= 0 ? FTColor.income : FTColor.expense)
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .padding(.vertical, FTSpacing.md)
                    if idx < allSales.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .ftGlass(FTRadius.lg)
        }
    }
}

// MARK: - Scenarios Tab (DCA Modeler)

private struct ScenariosTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let investments: [Investment]
    let cryptos: [CryptoHolding]
    let golds: [GoldHolding]

    @State private var monthlyContribution: String = "1000"
    @State private var annualReturn: String = "8"
    @State private var inflationRate: String = "3"
    @State private var years: String = "20"
    @State private var frequency: ContributionFrequency = .monthly
    @State private var projections: [ProjectionPoint] = []

    private var base: String { appState.baseCurrency }
    private var currentValue: Double {
        InvestmentService.shared.totalValue(investments: investments, cryptos: cryptos,
                                            golds: golds, currencyService: currencyService,
                                            baseCurrency: base)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                inputSection
                if !projections.isEmpty {
                    projectionChart
                    projectionSummary
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.sm)
            .padding(.bottom, 120)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("DCA Scenario Modeler").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            VStack(spacing: 0) {
                inputRow(label: "Monthly Contribution", text: $monthlyContribution, suffix: base)
                Divider().padding(.leading, 16)
                inputRow(label: "Annual Return (%)", text: $annualReturn, suffix: "%")
                Divider().padding(.leading, 16)
                inputRow(label: "Inflation Rate (%)", text: $inflationRate, suffix: "%")
                Divider().padding(.leading, 16)
                inputRow(label: "Time Horizon (Years)", text: $years, suffix: "yrs")
                Divider().padding(.leading, 16)
                HStack {
                    Text("Contribution Frequency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Picker("", selection: $frequency) {
                        ForEach(ContributionFrequency.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, FTSpacing.lg)
                .padding(.vertical, FTSpacing.md)
            }
            .ftGlass(FTRadius.lg)

            Button("Run Projection") { runProjection() }
                .buttonStyle(FTPrimaryButtonStyle())
        }
    }

    private func inputRow(label: String, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)
                .frame(width: 80)
            Text(suffix).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }

    private func runProjection() {
        let contrib = Double(monthlyContribution) ?? 1000
        let ret     = Double(annualReturn) ?? 8
        let infl    = Double(inflationRate) ?? 3
        let yrs     = Int(years) ?? 20
        projections = InvestmentService.shared.projectPortfolio(
            initialValue: currentValue,
            monthlyContribution: contrib,
            frequency: frequency,
            annualReturn: ret,
            inflationRate: infl,
            years: yrs)
    }

    private var projectionChart: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Growth Projection").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Chart {
                ForEach(projections) { p in
                    AreaMark(x: .value("Year", p.year), y: .value("Growth", p.growthComponent))
                        .foregroundStyle(FTColor.income.opacity(0.25))
                    LineMark(x: .value("Year", p.year), y: .value("Nominal", p.nominalValue))
                        .foregroundStyle(FTColor.income)
                    LineMark(x: .value("Year", p.year), y: .value("Real", p.realValue))
                        .foregroundStyle(FTColor.accent)
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                }
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(values: .automatic) { val in
                    AxisGridLine()
                    AxisValueLabel { if let d = val.as(Double.self) { Text(d.asCompact(currency: base)) } }
                }
            }
            HStack(spacing: FTSpacing.lg) {
                legendItem(color: FTColor.income, label: "Nominal")
                legendItem(color: FTColor.accent, label: "Real (inflation-adj.)")
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 16, height: 3)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
    }

    private var projectionSummary: some View {
        guard let last = projections.last else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 0) {
                summaryRow(label: "Final Value (Nominal)", value: last.nominalValue)
                Divider().padding(.leading, 16)
                summaryRow(label: "Final Value (Real)", value: last.realValue)
                Divider().padding(.leading, 16)
                summaryRow(label: "Total Contributions", value: last.totalContributions)
                Divider().padding(.leading, 16)
                summaryRow(label: "Growth from Returns", value: last.growthComponent)
            }
            .ftGlass(FTRadius.lg)
        )
    }

    private func summaryRow(label: String, value: Double) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value.formatted(as: base)).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - Monte Carlo Simulation Tab

private struct SimulationTab: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    let investments: [Investment]
    let cryptos: [CryptoHolding]
    let golds: [GoldHolding]

    @State private var monthlyContrib: String = "1000"
    @State private var meanReturn: String = "8"
    @State private var stdDev: String = "15"
    @State private var years: String = "20"
    @State private var targetAmount: String = "1000000"
    @State private var result: MonteCarloResult?
    @State private var isRunning = false

    private var base: String { appState.baseCurrency }
    private var initialValue: Double {
        InvestmentService.shared.totalValue(investments: investments, cryptos: cryptos, golds: golds,
                                            currencyService: currencyService, baseCurrency: base)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                inputSection
                if let res = result {
                    successCard(res)
                    percentilesCard(res)
                    histogramCard(res)
                    medianPathCard(res)
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.sm)
            .padding(.bottom, 120)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Monte Carlo Simulation").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("1,000 randomized scenarios using your portfolio's current value as starting point.")
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            VStack(spacing: 0) {
                simRow(label: "Monthly Contribution", text: $monthlyContrib, suffix: base)
                Divider().padding(.leading, 16)
                simRow(label: "Mean Annual Return (%)", text: $meanReturn, suffix: "%")
                Divider().padding(.leading, 16)
                simRow(label: "Std Dev Return (%)", text: $stdDev, suffix: "%")
                Divider().padding(.leading, 16)
                simRow(label: "Time Horizon (Years)", text: $years, suffix: "yrs")
                Divider().padding(.leading, 16)
                simRow(label: "Target Amount", text: $targetAmount, suffix: base)
            }
            .ftGlass(FTRadius.lg)

            Button(isRunning ? "Running…" : "Run Simulation") {
                guard !isRunning else { return }
                runSimulation()
            }
            .buttonStyle(FTPrimaryButtonStyle())
            .disabled(isRunning)
        }
    }

    private func simRow(label: String, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            TextField("0", text: text).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary).frame(width: 80)
            Text(suffix).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
    }

    private func runSimulation() {
        isRunning = true
        Task.detached(priority: .userInitiated) {
            let r = InvestmentService.shared.monteCarlo(
                initialValue: initialValue,
                monthlyContribution: Double(monthlyContrib) ?? 1000,
                years: Int(years) ?? 20,
                meanAnnualReturn: Double(meanReturn) ?? 8,
                stdDevAnnualReturn: Double(stdDev) ?? 15,
                iterations: 1_000,
                targetAmount: Double(targetAmount) ?? 1_000_000)
            await MainActor.run {
                result = r
                isRunning = false
            }
        }
    }

    private func successCard(_ r: MonteCarloResult) -> some View {
        HStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 8)
                Circle().trim(from: 0, to: r.successProbability / 100)
                    .stroke(r.successProbability >= 70 ? FTColor.income : r.successProbability >= 40 ? FTColor.gold : FTColor.expense,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(r.successProbability.asPercentage()).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                    Text("Success").font(.ftLabel).foregroundStyle(FTColor.textSecondary)
                }
            }
            .frame(width: 90, height: 90)
            VStack(alignment: .leading, spacing: 6) {
                Text("Probability of reaching")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text((Double(targetAmount) ?? 1_000_000).formatted(as: base))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("in \(years) years based on 1,000 paths")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private func percentilesCard(_ r: MonteCarloResult) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Outcome Range").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            VStack(spacing: 0) {
                pctRow(label: "10th Percentile (Bear)", value: r.percentile10, color: FTColor.expense)
                Divider().padding(.leading, 16)
                pctRow(label: "25th Percentile", value: r.percentile25, color: FTColor.catCoral)
                Divider().padding(.leading, 16)
                pctRow(label: "Median (50th)", value: r.median, color: FTColor.accent)
                Divider().padding(.leading, 16)
                pctRow(label: "75th Percentile", value: r.percentile75, color: FTColor.income)
                Divider().padding(.leading, 16)
                pctRow(label: "90th Percentile (Bull)", value: r.percentile90, color: FTColor.catTeal)
            }
            .ftGlass(FTRadius.lg)
        }
    }

    private func pctRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value.formatted(as: base)).font(.ftBodySemibold).foregroundStyle(color)
        }
        .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.md)
    }

    private func histogramCard(_ r: MonteCarloResult) -> some View {
        let buckets = buildBuckets(r.finalValues, count: 20)
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Distribution of Final Values").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Chart(buckets, id: \.mid) { b in
                BarMark(x: .value("Value", b.mid), y: .value("Count", b.count))
                    .foregroundStyle(b.mid >= (Double(targetAmount) ?? 1e6) ? FTColor.income : FTColor.expense.opacity(0.7))
                    .cornerRadius(2)
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { val in
                    AxisGridLine()
                    AxisValueLabel { if let d = val.as(Double.self) { Text(d.asCompact(currency: base)).font(.ftLabel) } }
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private func medianPathCard(_ r: MonteCarloResult) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Median Growth Path").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Chart(Array(r.yearlyMedians.enumerated()), id: \.offset) { idx, val in
                LineMark(x: .value("Year", idx), y: .value("Value", val))
                    .foregroundStyle(FTColor.accent)
                AreaMark(x: .value("Year", idx), y: .value("Value", val))
                    .foregroundStyle(FTColor.accent.opacity(0.15))
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { val in
                    AxisGridLine()
                    AxisValueLabel { if let d = val.as(Double.self) { Text(d.asCompact(currency: base)).font(.ftLabel) } }
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    struct HistogramBucket { let mid: Double; let count: Int }
    private func buildBuckets(_ values: [Double], count: Int) -> [HistogramBucket] {
        guard !values.isEmpty, let min = values.first, let max = values.last, max > min else { return [] }
        let width = (max - min) / Double(count)
        var buckets = Array(repeating: 0, count: count)
        for v in values {
            let idx = min(Int((v - min) / width), count - 1)
            buckets[idx] += 1
        }
        return buckets.enumerated().map { i, c in
            HistogramBucket(mid: min + (Double(i) + 0.5) * width, count: c)
        }
    }
}

// MARK: - Shared Helpers

private func emptyState(icon: String, title: String, sub: String) -> some View {
    VStack(spacing: FTSpacing.lg) {
        Spacer()
        Image(systemName: icon)
            .font(.system(size: 52, weight: .light))
            .foregroundStyle(FTColor.textMuted)
        VStack(spacing: FTSpacing.sm) {
            Text(title).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
            Text(sub).font(.ftBody).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
        }
        Spacer()
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, FTSpacing.screen)
}
