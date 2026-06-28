import Foundation
import Observation

// MARK: - CryptoPriceService
// Fetches live USD prices with a 10-second timeout.
// Primary source: Binance public API (api.binance.com) — no key, highly reliable globally.
// Fallback: CryptoCompare (min-api.cryptocompare.com) — free tier, no key.

@Observable
@MainActor
final class CryptoPriceService {
    static let shared = CryptoPriceService()

    /// Symbol (uppercased) → current price in USD
    var prices: [String: Double] = [:]
    var lastUpdated: Date?
    var isRefreshing = false
    var lastError: String?

    // MARK: - Symbols

    // Binance USDT pairs we want prices for
    private static let binanceSymbols: [String] = [
        "BTCUSDT", "ETHUSDT", "USDTUSDT", "BNBUSDT", "SOLUSDT",
        "XRPUSDT", "DOGEUSDT", "ADAUSDT", "MATICUSDT", "DOTUSDT",
        "LINKUSDT", "UNIUSDT", "AVAXUSDT", "SHIBUSDT", "LTCUSDT",
        "ATOMUSDT", "TRXUSDT", "NEARUSDT", "OPUSDT", "ARBUSDT",
        "APTUSDT", "SUIUSDT", "TONUSDT",
    ]

    // CryptoCompare comma-separated symbols (fallback)
    private static let cryptoCompareSymbols =
        "BTC,ETH,USDT,USDC,BNB,SOL,XRP,DOGE,ADA,MATIC,DOT,LINK,UNI,AVAX,SHIB,LTC,ATOM,TRX,TON,NEAR,OP,ARB,APT,SUI"

    // MARK: - Session

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

        if await fetchFromBinance() { return }
        await fetchFromCryptoCompare()
    }

    // MARK: - Binance

    private func fetchFromBinance() async -> Bool {
        // Build the JSON array parameter: ["BTCUSDT","ETHUSDT",...]
        let symbolsJSON = "[" + Self.binanceSymbols.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        guard let encoded = symbolsJSON.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.binance.com/api/v3/ticker/price?symbols=\(encoded)") else {
            return false
        }

        do {
            let (data, _) = try await Self.session.data(from: url)

            struct Ticker: Decodable {
                let symbol: String
                let price: String
            }

            let tickers = try JSONDecoder().decode([Ticker].self, from: data)
            guard !tickers.isEmpty else { return false }

            for ticker in tickers {
                // Strip "USDT" suffix to get the crypto symbol (BTCUSDT → BTC)
                let sym = ticker.symbol.hasSuffix("USDT")
                    ? String(ticker.symbol.dropLast(4))
                    : ticker.symbol
                if let price = Double(ticker.price), sym != "USDT" {
                    prices[sym] = price
                }
            }
            // USDT and USDC are always $1
            prices["USDT"] = 1.0
            prices["USDC"] = 1.0
            prices["DAI"]  = 1.0

            lastUpdated = Date()
            lastError = nil
            cachePrices()
            return true
        } catch {
            return false
        }
    }

    // MARK: - CryptoCompare fallback

    private func fetchFromCryptoCompare() async {
        guard let url = URL(string: "https://min-api.cryptocompare.com/data/pricemulti?fsyms=\(Self.cryptoCompareSymbols)&tsyms=USD") else { return }

        do {
            let (data, _) = try await Self.session.data(from: url)
            // Response: { "BTC": { "USD": 67000 }, "ETH": { "USD": 3500 }, ... }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else { return }

            for (symbol, values) in json {
                if let usd = values["USD"] {
                    prices[symbol.uppercased()] = usd
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
