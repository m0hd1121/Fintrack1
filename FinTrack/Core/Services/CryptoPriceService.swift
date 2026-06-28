import Foundation
import Observation

// MARK: - CryptoPriceService
// Fetches live USD prices with a 10-second timeout.
// Primary source: CoinCap (api.coincap.io) — no key required, reliable globally.
// Fallback: CoinGecko (api.coingecko.com/api/v3).

@Observable
@MainActor
final class CryptoPriceService {
    static let shared = CryptoPriceService()

    /// Symbol (uppercased) → current price in USD
    var prices: [String: Double] = [:]
    var lastUpdated: Date?
    var isRefreshing = false
    var lastError: String?

    // MARK: - Mappings

    // CoinCap uses its own lowercase IDs (different from CoinGecko)
    private static let symbolToCoinCapId: [String: String] = [
        "BTC": "bitcoin",
        "ETH": "ethereum",
        "USDT": "tether",
        "USDC": "usd-coin",
        "BNB": "binance-coin",
        "SOL": "solana",
        "XRP": "xrp",
        "DOGE": "dogecoin",
        "ADA": "cardano",
        "MATIC": "polygon",
        "DOT": "polkadot",
        "LINK": "chainlink",
        "UNI": "uniswap",
        "AVAX": "avalanche",
        "SHIB": "shiba-inu",
        "LTC": "litecoin",
        "ATOM": "cosmos",
        "DAI": "multi-collateral-dai",
        "TRX": "tron",
        "TON": "toncoin",
        "NEAR": "near-protocol",
        "OP": "optimism",
        "ARB": "arbitrum",
        "APT": "aptos",
        "SUI": "sui",
    ]

    // CoinGecko fallback IDs
    private static let symbolToCoinGeckoId: [String: String] = [
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

    // MARK: - Session with short timeout

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

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

    // MARK: - Fetch (primary → fallback)

    func fetchPrices() async {
        guard !isFetching else { return }
        isFetching = true
        isRefreshing = true
        defer {
            isFetching = false
            isRefreshing = false
        }

        if await fetchFromCoinCap() { return }
        await fetchFromCoinGecko()
    }

    // MARK: - CoinCap

    private func fetchFromCoinCap() async -> Bool {
        let ids = Self.symbolToCoinCapId.values.joined(separator: ",")
        guard let url = URL(string: "https://api.coincap.io/v2/assets?ids=\(ids)") else { return false }

        do {
            let (data, _) = try await Self.session.data(from: url)

            struct Response: Decodable {
                struct Asset: Decodable {
                    let symbol: String
                    let priceUsd: String
                }
                let data: [Asset]
            }

            let response = try JSONDecoder().decode(Response.self, from: data)
            guard !response.data.isEmpty else { return false }

            for asset in response.data {
                if let price = Double(asset.priceUsd) {
                    prices[asset.symbol.uppercased()] = price
                }
            }
            lastUpdated = Date()
            lastError = nil
            cachePrices()
            return true
        } catch {
            return false
        }
    }

    // MARK: - CoinGecko fallback

    private func fetchFromCoinGecko() async {
        let ids = Self.symbolToCoinGeckoId.values.joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd") else { return }

        do {
            let (data, _) = try await Self.session.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else { return }

            let idToSymbol = Dictionary(uniqueKeysWithValues: Self.symbolToCoinGeckoId.map { ($1, $0) })
            for (coinId, values) in json {
                if let usdPrice = values["usd"], let symbol = idToSymbol[coinId] {
                    prices[symbol] = usdPrice
                }
            }
            lastUpdated = Date()
            lastError = nil
            cachePrices()
        } catch {
            lastError = "Prices unavailable"
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
