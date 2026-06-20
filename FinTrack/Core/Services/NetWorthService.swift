import Foundation
import SwiftUI
import SwiftData

// MARK: - NetWorthService

final class NetWorthService {
    static let shared = NetWorthService()
    private init() {}

    // MARK: - Asset Totals

    func totalAssets(
        accounts: [Account],
        investments: [Investment],
        cryptos: [CryptoHolding],
        golds: [GoldHolding],
        giftCards: [GiftCard],
        realEstate: [RealEstateProperty],
        vehicles: [Vehicle],
        personalAssets: [PersonalAsset],
        digitalAssets: [DigitalAsset],
        currencyService: CurrencyService,
        base: String
    ) -> Double {
        cashTotal(accounts: accounts, currencyService: currencyService, base: base) +
        investmentTotal(investments: investments, cryptos: cryptos, golds: golds,
                        currencyService: currencyService, base: base) +
        giftCardTotal(giftCards: giftCards, currencyService: currencyService, base: base) +
        realEstateTotal(realEstate: realEstate, currencyService: currencyService, base: base) +
        vehicleTotal(vehicles: vehicles, currencyService: currencyService, base: base) +
        personalAssetTotal(assets: personalAssets, currencyService: currencyService, base: base) +
        digitalAssetTotal(assets: digitalAssets, currencyService: currencyService, base: base)
    }

    func totalLiabilities(
        loans: [Loan],
        creditCards: [CreditCard],
        bnpl: [BNPLPlan],
        moneyBorrowed: [MoneyBorrowed],
        currencyService: CurrencyService,
        base: String
    ) -> Double {
        loans.filter { $0.isActive }.reduce(0) {
            $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: base)
        } +
        creditCards.filter { $0.isActive }.reduce(0) {
            $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: base)
        } +
        bnpl.filter { !$0.isCompleted }.reduce(0) {
            $0 + currencyService.convert($1.remainingAmount, from: $1.currency, to: base)
        } +
        moneyBorrowed.filter { !$0.isFullyRepaid }.reduce(0) {
            $0 + currencyService.convert($1.remainingBalance, from: $1.currency, to: base)
        }
    }

    func netWorth(
        accounts: [Account],
        investments: [Investment],
        cryptos: [CryptoHolding],
        golds: [GoldHolding],
        giftCards: [GiftCard],
        realEstate: [RealEstateProperty],
        vehicles: [Vehicle],
        personalAssets: [PersonalAsset],
        digitalAssets: [DigitalAsset],
        loans: [Loan],
        creditCards: [CreditCard],
        bnpl: [BNPLPlan],
        moneyBorrowed: [MoneyBorrowed],
        currencyService: CurrencyService,
        base: String
    ) -> Double {
        totalAssets(accounts: accounts, investments: investments, cryptos: cryptos,
                    golds: golds, giftCards: giftCards, realEstate: realEstate,
                    vehicles: vehicles, personalAssets: personalAssets,
                    digitalAssets: digitalAssets, currencyService: currencyService, base: base) -
        totalLiabilities(loans: loans, creditCards: creditCards, bnpl: bnpl,
                         moneyBorrowed: moneyBorrowed, currencyService: currencyService, base: base)
    }

    // MARK: - Breakdown by Asset Class

    func assetAllocationSlices(
        accounts: [Account],
        investments: [Investment],
        cryptos: [CryptoHolding],
        golds: [GoldHolding],
        giftCards: [GiftCard],
        realEstate: [RealEstateProperty],
        vehicles: [Vehicle],
        personalAssets: [PersonalAsset],
        digitalAssets: [DigitalAsset],
        currencyService: CurrencyService,
        base: String
    ) -> [AssetAllocationSlice] {
        var buckets: [(label: String, value: Double, color: Color)] = []

        let cash = cashTotal(accounts: accounts, currencyService: currencyService, base: base)
        if cash > 0 { buckets.append(("Cash & Accounts", cash, FTColor.accent)) }

        let inv = investments.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base)
        }
        if inv > 0 { buckets.append(("Stocks & ETFs", inv, FTColor.catBlue)) }

        let cry = cryptos.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base)
        }
        if cry > 0 { buckets.append(("Crypto", cry, FTColor.catPurple)) }

        let gld = golds.filter { !$0.isArchived }.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base)
        }
        if gld > 0 { buckets.append(("Gold & Metals", gld, FTColor.gold)) }

        let re = realEstateTotal(realEstate: realEstate, currencyService: currencyService, base: base)
        if re > 0 { buckets.append(("Real Estate", re, FTColor.catCoral)) }

        let veh = vehicleTotal(vehicles: vehicles, currencyService: currencyService, base: base)
        if veh > 0 { buckets.append(("Vehicles", veh, .blue)) }

        let pa = personalAssetTotal(assets: personalAssets, currencyService: currencyService, base: base)
        if pa > 0 { buckets.append(("Personal Assets", pa, .orange)) }

        let da = digitalAssetTotal(assets: digitalAssets, currencyService: currencyService, base: base)
        if da > 0 { buckets.append(("Digital Assets", da, .teal)) }

        let gc = giftCardTotal(giftCards: giftCards, currencyService: currencyService, base: base)
        if gc > 0 { buckets.append(("Gift Cards", gc, .green)) }

        let total = buckets.reduce(0) { $0 + $1.value }
        guard total > 0 else { return [] }

        return buckets.map { b in
            AssetAllocationSlice(label: b.label, value: b.value, color: b.color,
                                 percentage: (b.value / total) * 100)
        }.sorted { $0.value > $1.value }
    }

    // MARK: - Milestone Detection

    static let milestoneAmounts: [Double] = [
        100_000, 250_000, 500_000, 1_000_000, 2_500_000, 5_000_000, 10_000_000
    ]

    func checkMilestones(
        currentNetWorth: Double,
        existingMilestones: [NetWorthMilestone],
        base: String,
        context: ModelContext
    ) {
        let achieved = existingMilestones.map { $0.amount }
        for target in Self.milestoneAmounts {
            guard currentNetWorth >= target else { continue }
            guard !achieved.contains(where: { abs($0 - target) < 1 }) else { continue }
            let milestone = NetWorthMilestone(amount: target, currency: base)
            context.insert(milestone)
        }
    }

    // MARK: - Historical Snapshot

    func recordSnapshot(
        accounts: [Account],
        investments: [Investment],
        cryptos: [CryptoHolding],
        golds: [GoldHolding],
        giftCards: [GiftCard],
        realEstate: [RealEstateProperty],
        vehicles: [Vehicle],
        personalAssets: [PersonalAsset],
        digitalAssets: [DigitalAsset],
        loans: [Loan],
        creditCards: [CreditCard],
        bnpl: [BNPLPlan],
        moneyBorrowed: [MoneyBorrowed],
        currencyService: CurrencyService,
        base: String,
        context: ModelContext
    ) {
        let assets = totalAssets(accounts: accounts, investments: investments, cryptos: cryptos,
                                 golds: golds, giftCards: giftCards, realEstate: realEstate,
                                 vehicles: vehicles, personalAssets: personalAssets,
                                 digitalAssets: digitalAssets, currencyService: currencyService, base: base)
        let liabilities = totalLiabilities(loans: loans, creditCards: creditCards, bnpl: bnpl,
                                           moneyBorrowed: moneyBorrowed, currencyService: currencyService, base: base)

        let breakdown: [String: Double] = [
            "Cash": cashTotal(accounts: accounts, currencyService: currencyService, base: base),
            "Investments": investments.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) },
            "Crypto": cryptos.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) },
            "Gold": golds.filter { !$0.isArchived }.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) },
            "RealEstate": realEstateTotal(realEstate: realEstate, currencyService: currencyService, base: base),
            "Vehicles": vehicleTotal(vehicles: vehicles, currencyService: currencyService, base: base),
            "PersonalAssets": personalAssetTotal(assets: personalAssets, currencyService: currencyService, base: base),
            "DigitalAssets": digitalAssetTotal(assets: digitalAssets, currencyService: currencyService, base: base)
        ]

        let snapshot = NetWorthSnapshot(date: Date(), totalAssets: assets,
                                        totalLiabilities: liabilities, currency: base,
                                        breakdown: breakdown)
        context.insert(snapshot)
    }

    // MARK: - Net Worth Forecast

    struct ForecastPoint: Identifiable {
        let id = UUID()
        let year: Int
        let netWorth: Double
        let optimistic: Double
        let pessimistic: Double
    }

    func forecastNetWorth(
        currentNetWorth: Double,
        monthlySavings: Double,
        annualInvestmentReturn: Double,   // %
        annualIncomeGrowth: Double,       // %
        annualInflation: Double,          // %
        years: Int
    ) -> [ForecastPoint] {
        let monthlyRate    = annualInvestmentReturn / 100 / 12
        let optMonthly     = (annualInvestmentReturn + 3) / 100 / 12
        let pessMonthly    = max(0, (annualInvestmentReturn - 4)) / 100 / 12
        let annualSavings  = monthlySavings * 12
        let savingsGrowth  = annualIncomeGrowth / 100

        var base   = currentNetWorth
        var opt    = currentNetWorth
        var pess   = currentNetWorth
        var annualContrib = annualSavings

        var points: [ForecastPoint] = [
            ForecastPoint(year: 0, netWorth: base, optimistic: opt, pessimistic: pess)
        ]

        for year in 1...max(1, years) {
            for _ in 1...12 {
                base = base * (1 + monthlyRate) + annualContrib / 12
                opt  = opt  * (1 + optMonthly)  + annualContrib / 12
                pess = pess * (1 + pessMonthly)  + annualContrib / 12
            }
            annualContrib *= (1 + savingsGrowth)
            points.append(ForecastPoint(year: year, netWorth: base, optimistic: opt, pessimistic: pess))
        }
        return points
    }

    // MARK: - Wealth Percentile

    struct PercentileResult {
        let percentile: Double
        let explanation: String
        let tier: String
    }

    /// Estimates wealth percentile vs UAE/GCC adult population.
    /// Uses approximate wealth distribution data (World Inequality Database proxies).
    func wealthPercentile(netWorth: Double, baseCurrency: String,
                          currencyService: CurrencyService) -> PercentileResult {
        // Convert to USD for comparison (standard benchmark)
        let nwUSD = currencyService.convert(netWorth, from: baseCurrency, to: "USD")

        // Approximate UAE wealth distribution thresholds (adults aged 25+)
        // Source: World Inequality Database / Credit Suisse Global Wealth Report estimates
        let thresholds: [(pct: Double, usd: Double)] = [
            (10,  1_000),
            (25,  5_000),
            (40,  15_000),
            (50,  30_000),
            (60,  60_000),
            (70,  120_000),
            (80,  250_000),
            (90,  500_000),
            (95,  1_000_000),
            (99,  5_000_000),
            (99.9, 25_000_000)
        ]

        var percentile = 5.0
        for t in thresholds {
            if nwUSD >= t.usd { percentile = t.pct }
        }

        let tier: String
        let explanation: String
        switch percentile {
        case ..<25:
            tier = "Building Wealth"
            explanation = "You're in the early stages of wealth accumulation, ahead of the bottom \(Int(percentile))% of UAE adults."
        case ..<50:
            tier = "Emerging Wealth"
            explanation = "Your net worth places you in the top \(Int(100 - percentile))% of UAE adults by estimated wealth."
        case ..<70:
            tier = "Middle Wealth"
            explanation = "You're above the median UAE adult, ranking higher than \(Int(percentile))% of the population."
        case ..<90:
            tier = "Upper-Middle Wealth"
            explanation = "You're in the top \(Int(100 - percentile))% of UAE adults by wealth — well above average."
        case ..<95:
            tier = "High Net Worth"
            explanation = "You're in the top \(Int(100 - percentile))% — a high-net-worth individual in the UAE context."
        default:
            tier = "Ultra-High Net Worth"
            explanation = "You rank in the top \(String(format: "%.1f", 100 - percentile))% of UAE adults — an elite wealth tier."
        }

        return PercentileResult(percentile: percentile, explanation: explanation, tier: tier)
    }

    // MARK: - Private Helpers

    private func cashTotal(accounts: [Account], currencyService: CurrencyService, base: String) -> Double {
        accounts.filter { !$0.isArchived && !$0.isHidden }.reduce(0) {
            $0 + currencyService.convert($1.balance, from: $1.currency, to: base)
        }
    }

    private func investmentTotal(investments: [Investment], cryptos: [CryptoHolding],
                                 golds: [GoldHolding], currencyService: CurrencyService, base: String) -> Double {
        investments.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) } +
        cryptos.reduce(0)     { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) } +
        golds.filter { !$0.isArchived }.reduce(0) { $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base) }
    }

    private func giftCardTotal(giftCards: [GiftCard], currencyService: CurrencyService, base: String) -> Double {
        giftCards.filter { !$0.isExpired }.reduce(0) {
            $0 + currencyService.convert($1.balance, from: $1.currency, to: base)
        }
    }

    func realEstateTotal(realEstate: [RealEstateProperty], currencyService: CurrencyService, base: String) -> Double {
        realEstate.filter { !$0.isArchived }.reduce(0) {
            $0 + currencyService.convert($1.ownedValue, from: $1.currency, to: base)
        }
    }

    func vehicleTotal(vehicles: [Vehicle], currencyService: CurrencyService, base: String) -> Double {
        vehicles.filter { !$0.isArchived }.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base)
        }
    }

    func personalAssetTotal(assets: [PersonalAsset], currencyService: CurrencyService, base: String) -> Double {
        assets.filter { !$0.isArchived }.reduce(0) {
            $0 + currencyService.convert($1.estimatedMarketValue, from: $1.currency, to: base)
        }
    }

    func digitalAssetTotal(assets: [DigitalAsset], currencyService: CurrencyService, base: String) -> Double {
        assets.filter { !$0.isArchived }.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: base)
        }
    }
}

// MARK: - AssetAllocationSlice

struct AssetAllocationSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
    var percentage: Double
}
