import Foundation
import Observation

// MARK: - CryptoPriceService
// Fetches live USD prices from CoinGecko's public API and auto-refreshes every 60 s.

@Observable
@MainActor
final class CryptoPriceService {
    static let shared = CryptoPriceService()

    /// Symbol (uppercased) → current price in USD
    var prices: [String: Double] = [:]
    var lastUpdated: Date?
    var isRefreshing = false
    var lastError: String?

    // MARK: - Symbol → CoinGecko ID

    static let symbolToId: [String: String] = [
        "BTC": "bitcoin",
        "ETH": "ethereum",
        "USDT": "tether",
        "USDC": "usd-coin",
        "BNB": "binancecoin",
        "SOL": "solana",
        "XRP": "ripple",
        "DOGE": "dogecoin",
        "ADA": "cardano",
        "MATIC": "matic-network",
        "DOT": "polkadot",
        "LINK": "chainlink",
        "UNI": "uniswap",
        "AVAX": "avalanche-2",
        "SHIB": "shiba-inu",
        "LTC": "litecoin",
        "ATOM": "cosmos",
        "DAI": "dai",
        "TRX": "tron",
        "TON": "the-open-network",
        "NEAR": "near",
        "OP": "optimism",
        "ARB": "arbitrum",
        "APT": "aptos",
        "SUI": "sui",
    ]

    private var refreshTask: Task<Void, Never>?
    private var isFetching = false

    private init() {
        loadCachedPrices()
        startAutoRefresh()
    }

    // MARK: - Auto-Refresh

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                if let last = lastUpdated, Date().timeIntervalSince(last) < 20 {
                    let wait = 25 - Date().timeIntervalSince(last)
                    try? await Task.sleep(for: .seconds(max(2, wait)))
                    continue
                }
                await fetchPrices()
                try? await Task.sleep(for: .seconds(25))
            }
        }
    }

    // MARK: - Fetch

    func fetchPrices() async {
        guard !isFetching else { return }
        isFetching = true
        isRefreshing = true
        defer {
            isFetching = false
            isRefreshing = false
        }

        let ids = Self.symbolToId.values.joined(separator: ",")
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else { return }

            let idToSymbol = Dictionary(uniqueKeysWithValues: Self.symbolToId.map { ($1, $0) })
            for (coinId, values) in json {
                if let usdPrice = values["usd"], let symbol = idToSymbol[coinId] {
                    prices[symbol] = usdPrice
                }
            }
            lastUpdated = Date()
            lastError = nil
            cachePrices()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Price Lookup

    func usdPrice(for symbol: String) -> Double? {
        prices[symbol.uppercased()]
    }

    // MARK: - Update Holdings

    /// Write fetched prices back into CryptoHolding.currentPrice, converting from USD
    /// to each holding's own currency via CurrencyService.
    func updateHoldings(_ holdings: [CryptoHolding], currencyService: CurrencyService) {
        for holding in holdings {
            guard let usd = prices[holding.symbol.uppercased()] else { continue }
            let price = currencyService.convert(usd, from: "USD", to: holding.currency)
            if abs(price - holding.currentPrice) > 0.000001 {
                holding.currentPrice = price
                holding.updatedAt = Date()
            }
        }
    }

    // MARK: - Cache

    private func cachePrices() {
        guard let data = try? JSONEncoder().encode(prices) else { return }
        UserDefaults.standard.set(data, forKey: "cached_crypto_prices")
        UserDefaults.standard.set(Date(), forKey: "cached_crypto_prices_date")
    }

    private func loadCachedPrices() {
        guard let data = UserDefaults.standard.data(forKey: "cached_crypto_prices"),
              let cached = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        prices = cached
        lastUpdated = UserDefaults.standard.object(forKey: "cached_crypto_prices_date") as? Date
    }
}
