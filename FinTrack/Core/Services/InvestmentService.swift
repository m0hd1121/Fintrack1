import Foundation
import SwiftUI

// MARK: - InvestmentService

final class InvestmentService {
    static let shared = InvestmentService()
    private init() {}

    // MARK: - Portfolio Totals

    func totalValue(
        investments: [Investment],
        cryptos: [CryptoHolding],
        golds: [GoldHolding],
        currencyService: CurrencyService,
        baseCurrency: String
    ) -> Double {
        let inv = investments.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        let cry = cryptos.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        let gld = golds.filter { !$0.isArchived }.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        return inv + cry + gld
    }

    func totalCost(
        investments: [Investment],
        cryptos: [CryptoHolding],
        golds: [GoldHolding],
        currencyService: CurrencyService,
        baseCurrency: String
    ) -> Double {
        let inv = investments.reduce(0.0) {
            $0 + currencyService.convert($1.totalCost, from: $1.currency, to: baseCurrency)
        }
        let cry = cryptos.reduce(0.0) {
            $0 + currencyService.convert($1.totalCost, from: $1.currency, to: baseCurrency)
        }
        let gld = golds.filter { !$0.isArchived }.reduce(0.0) {
            $0 + currencyService.convert($1.totalCost, from: $1.currency, to: baseCurrency)
        }
        return inv + cry + gld
    }

    func unrealizedPnL(
        investments: [Investment],
        cryptos: [CryptoHolding],
        golds: [GoldHolding],
        currencyService: CurrencyService,
        baseCurrency: String
    ) -> Double {
        totalValue(investments: investments, cryptos: cryptos, golds: golds,
                   currencyService: currencyService, baseCurrency: baseCurrency) -
        totalCost(investments: investments, cryptos: cryptos, golds: golds,
                  currencyService: currencyService, baseCurrency: baseCurrency)
    }

    func totalRealizedPnL(
        investments: [Investment],
        cryptos: [CryptoHolding],
        currencyService: CurrencyService,
        baseCurrency: String
    ) -> Double {
        let invRealized = investments.reduce(0.0) {
            $0 + currencyService.convert($1.realizedPnL, from: $1.currency, to: baseCurrency)
        }
        let cryRealized = cryptos.reduce(0.0) {
            $0 + currencyService.convert($1.realizedPnL, from: $1.currency, to: baseCurrency)
        }
        return invRealized + cryRealized
    }

    // MARK: - Allocation by Asset Class

    func allocationSlices(
        investments: [Investment],
        cryptos: [CryptoHolding],
        golds: [GoldHolding],
        accounts: [Account],
        currencyService: CurrencyService,
        baseCurrency: String
    ) -> [AllocationSlice] {
        var buckets: [(label: String, value: Double, color: Color)] = []

        // Group investments by type
        for type in InvestmentType.allCases {
            let val = investments.filter { $0.type == type }.reduce(0.0) {
                $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
            }
            guard val > 0 else { continue }
            let color: Color = Color.fromString(type.color)
            buckets.append((type.rawValue, val, color))
        }

        // Crypto bucket
        let cryptoTotal = cryptos.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        if cryptoTotal > 0 { buckets.append(("Crypto", cryptoTotal, FTColor.catPurple)) }

        // Gold bucket (grouped)
        let goldTotal = golds.filter { !$0.isArchived }.reduce(0.0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        if goldTotal > 0 { buckets.append(("Gold", goldTotal, FTColor.gold)) }

        // Cash (non-investment accounts)
        let cashTotal = accounts.filter { !$0.isArchived && !$0.isHidden }.reduce(0.0) {
            $0 + currencyService.convert($1.balance, from: $1.currency, to: baseCurrency)
        }
        if cashTotal > 0 { buckets.append(("Cash", cashTotal, FTColor.accent)) }

        let total = buckets.reduce(0.0) { $0 + $1.value }
        guard total > 0 else { return [] }

        return buckets.map { b in
            var s = AllocationSlice(label: b.label, value: b.value, color: b.color)
            s.percentage = (b.value / total) * 100
            return s
        }.sorted { $0.value > $1.value }
    }

    // MARK: - Capital Gains (FIFO / LIFO / Average)

    struct GainResult {
        let costBasis: Double
        let remainingLots: [PurchaseLot]
        let realizedPnL: Double
    }

    func calculateGain(
        lots: [PurchaseLot],
        selling quantity: Double,
        at salePrice: Double,
        method: CostBasisMethod
    ) -> GainResult {
        var mutableLots = lots
        var remaining = quantity
        var costBasis = 0.0

        switch method {
        case .averageCost:
            let totalQty  = lots.reduce(0.0) { $0 + $1.quantity }
            let totalCost = lots.reduce(0.0) { $0 + $1.totalCost }
            let avgCost   = totalQty > 0 ? totalCost / totalQty : 0
            costBasis = min(quantity, totalQty) * avgCost
            let proportionSold = totalQty > 0 ? quantity / totalQty : 0
            mutableLots = lots.map { lot in
                var l = lot
                l.quantity = lot.quantity * (1 - proportionSold)
                return l
            }.filter { $0.quantity > 0.0001 }

        case .fifo:
            let ordered = lots.sorted { $0.purchaseDate < $1.purchaseDate }
            var newLots: [PurchaseLot] = []
            for i in ordered.indices {
                if remaining <= 0 { newLots.append(ordered[i]); continue }
                let take = min(remaining, ordered[i].quantity)
                costBasis += take * ordered[i].costPerUnit
                remaining -= take
                if ordered[i].quantity - take > 0.0001 {
                    var lot = ordered[i]
                    lot.quantity -= take
                    newLots.append(lot)
                }
            }
            mutableLots = newLots

        case .lifo:
            let ordered = lots.sorted { $0.purchaseDate > $1.purchaseDate }
            var newLots: [PurchaseLot] = []
            for i in ordered.indices {
                if remaining <= 0 { newLots.append(ordered[i]); continue }
                let take = min(remaining, ordered[i].quantity)
                costBasis += take * ordered[i].costPerUnit
                remaining -= take
                if ordered[i].quantity - take > 0.0001 {
                    var lot = ordered[i]
                    lot.quantity -= take
                    newLots.append(lot)
                }
            }
            mutableLots = newLots
        }

        let proceeds   = quantity * salePrice
        let realizedPnL = proceeds - costBasis
        return GainResult(costBasis: costBasis, remainingLots: mutableLots, realizedPnL: realizedPnL)
    }

    func capitalGainsSummary(
        investments: [Investment],
        cryptos: [CryptoHolding],
        currencyService: CurrencyService,
        baseCurrency: String
    ) -> CapitalGainsSummary {
        var summary = CapitalGainsSummary()
        let allSales: [(SaleRecord, String)] =
            investments.flatMap { inv in inv.sales.map { ($0, inv.currency) } } +
            cryptos.flatMap    { cry in cry.sales.map { ($0, cry.currency) } }

        for (sale, currency) in allSales {
            let pnl = currencyService.convert(sale.realizedPnL, from: currency, to: baseCurrency)
            if pnl >= 0 {
                summary.totalRealizedGain += pnl
                if sale.isLongTerm { summary.longTermGain += pnl }
                else               { summary.shortTermGain += pnl }
            } else {
                summary.totalRealizedLoss += abs(pnl)
            }
        }
        summary.totalUnrealized = unrealizedPnL(
            investments: investments, cryptos: cryptos, golds: [],
            currencyService: currencyService, baseCurrency: baseCurrency
        )
        return summary
    }

    // MARK: - Dividend Aggregation

    func annualDividendIncome(
        dividends: [Dividend],
        currencyService: CurrencyService,
        baseCurrency: String
    ) -> Double {
        let start = Date().startOfYear
        return dividends
            .filter { $0.date >= start }
            .reduce(0.0) { $0 + currencyService.convert($1.netAmount, from: $1.currency, to: baseCurrency) }
    }

    // MARK: - Scenario Modeler

    func projectPortfolio(
        initialValue: Double,
        monthlyContribution: Double,
        frequency: ContributionFrequency,
        annualReturn: Double,
        inflationRate: Double,
        years: Int
    ) -> [ProjectionPoint] {
        let monthlyRate      = annualReturn / 100.0 / 12.0
        let monthlyInflation = inflationRate / 100.0 / 12.0
        let contributionPerMonth = monthlyContribution * (frequency.periodsPerYear / 12.0)

        var balance       = initialValue
        var realBalance   = initialValue
        var contributions = initialValue
        var points: [ProjectionPoint] = [
            ProjectionPoint(year: 0, nominalValue: initialValue, realValue: initialValue,
                            totalContributions: initialValue, growthComponent: 0)
        ]

        for year in 1...max(1, years) {
            for _ in 1...12 {
                balance     = balance * (1 + monthlyRate) + contributionPerMonth
                realBalance = realBalance * (1 + monthlyRate - monthlyInflation) + contributionPerMonth
                contributions += contributionPerMonth
            }
            let growth = balance - contributions
            points.append(ProjectionPoint(
                year: year,
                nominalValue: balance,
                realValue: realBalance,
                totalContributions: contributions,
                growthComponent: max(0, growth)
            ))
        }
        return points
    }

    // MARK: - Monte Carlo Simulation

    func monteCarlo(
        initialValue: Double,
        monthlyContribution: Double,
        years: Int,
        meanAnnualReturn: Double,
        stdDevAnnualReturn: Double,
        iterations: Int = 1_000,
        targetAmount: Double
    ) -> MonteCarloResult {
        let months = years * 12
        let meanMonthly  = meanAnnualReturn  / 100.0 / 12.0
        let stdDevMonthly = stdDevAnnualReturn / 100.0 / sqrt(12.0)

        var finalValues = [Double]()
        finalValues.reserveCapacity(iterations)
        var yearlyAccumulator = Array(repeating: 0.0, count: years + 1)

        for _ in 0..<iterations {
            var balance = initialValue
            yearlyAccumulator[0] += balance

            for m in 1...max(1, months) {
                let r = randomNormal(mean: meanMonthly, stdDev: stdDevMonthly)
                balance = balance * (1 + r) + monthlyContribution
                if m % 12 == 0, m / 12 <= years {
                    yearlyAccumulator[m / 12] += balance
                }
            }
            finalValues.append(balance)
        }

        let n = Double(iterations)
        let sorted = finalValues.sorted()
        let successCount = sorted.filter { $0 >= targetAmount }.count

        return MonteCarloResult(
            iterations: iterations,
            successProbability: (Double(successCount) / n) * 100,
            percentile10: percentile(sorted, 0.10),
            percentile25: percentile(sorted, 0.25),
            median:       percentile(sorted, 0.50),
            percentile75: percentile(sorted, 0.75),
            percentile90: percentile(sorted, 0.90),
            finalValues:  sorted,
            yearlyMedians: yearlyAccumulator.map { $0 / n },
            targetAmount: targetAmount
        )
    }

    // MARK: - Benchmark Comparison

    func portfolioReturn(
        investments: [Investment],
        cryptos: [CryptoHolding],
        golds: [GoldHolding],
        currencyService: CurrencyService,
        baseCurrency: String
    ) -> Double {
        let cost = totalCost(investments: investments, cryptos: cryptos, golds: golds,
                             currencyService: currencyService, baseCurrency: baseCurrency)
        let value = totalValue(investments: investments, cryptos: cryptos, golds: golds,
                               currencyService: currencyService, baseCurrency: baseCurrency)
        guard cost > 0 else { return 0 }
        return ((value - cost) / cost) * 100
    }

    // MARK: - Helpers

    private func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let idx = Int(Double(sorted.count - 1) * p)
        return sorted[min(idx, sorted.count - 1)]
    }

    private func randomNormal(mean: Double, stdDev: Double) -> Double {
        // Box-Muller transform
        let u1 = Double.random(in: Double.leastNormalMagnitude...1)
        let u2 = Double.random(in: 0...1)
        let z  = sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
        return mean + stdDev * z
    }
}
