import Foundation
import Observation

// MARK: - StockPriceService
// Fetches live prices for stocks, ETFs, mutual funds, bonds, and REITs.
// Uses Yahoo Finance's public quote endpoint — no API key required.
// Refresh cadence: every 5 minutes (markets move slower than crypto).

@Observable
@MainActor
final class StockPriceService {
    static let shared = StockPriceService()

    /// Ticker (uppercased) → current price in the ticker's native currency as reported by Yahoo
    var prices: [String: Double] = [:]
    /// Ticker → ISO currency of `prices[ticker]` (pence quotes already normalised).
    var quoteCurrencies: [String: String] = [:]
    var lastUpdated: Date?
    var isRefreshing = false
    var lastError: String?

    private var refreshTask: Task<Void, Never>?
    private var isFetching = false
    private var lastFetchedSymbols: [String] = []

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 20
        return URLSession(configuration: cfg)
    }()

    private init() {
        loadCachedPrices()
        startAutoRefresh()
    }

    // MARK: - Auto-Refresh (every 5 minutes, skips if fresher than 4.5 minutes)

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                if let last = lastUpdated, Date().timeIntervalSince(last) < 270 {
                    let wait = 300 - Date().timeIntervalSince(last)
                    try? await Task.sleep(for: .seconds(max(10, wait)))
                    continue
                }
                await fetchPrices(symbols: lastFetchedSymbols)
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    // MARK: - Fetch

    // Uses the v8 chart endpoint (one request per symbol, run concurrently).
    // The v7 batch-quote endpoint requires a Yahoo session cookie + crumb
    // token and returns 401 for plain API calls — v8 chart does not.
    func fetchPrices(symbols: [String]) async {
        let cleaned = symbols.map { $0.uppercased().trimmingCharacters(in: .whitespaces) }
                             .filter { !$0.isEmpty }
        guard !cleaned.isEmpty, !isFetching else { return }

        lastFetchedSymbols = cleaned
        isFetching = true
        isRefreshing = true
        defer { isFetching = false; isRefreshing = false }

        let fetched = await withTaskGroup(of: Quote?.self) { group in
            for symbol in Set(cleaned) {
                group.addTask { await Self.fetchSingle(symbol: symbol) }
            }
            var results: [String: Quote] = [:]
            for await quote in group {
                if let quote { results[quote.symbol] = quote }
            }
            return results
        }

        guard !fetched.isEmpty else {
            lastError = "Prices unavailable"
            return
        }
        for (symbol, quote) in fetched {
            prices[symbol] = quote.price
            if let currency = quote.currency { quoteCurrencies[symbol] = currency }
        }
        lastUpdated = Date()
        lastError = nil
        cachePrices()
    }

    private struct Quote: Sendable {
        let symbol: String
        let price: Double
        let currency: String?
    }

    private static func fetchSingle(symbol: String) async -> Quote? {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1d&range=1d") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let meta = decoded.chart.result?.first?.meta,
                  let price = meta.regularMarketPrice, price > 0 else { return nil }
            // London listings quote in pence ("GBp"/"GBX"); normalise to GBP.
            switch meta.currency {
            case "GBp", "GBX": return Quote(symbol: symbol, price: price / 100, currency: "GBP")
            case "ZAc", "ZAC": return Quote(symbol: symbol, price: price / 100, currency: "ZAR")
            case "ILA":        return Quote(symbol: symbol, price: price / 100, currency: "ILS")
            default:           return Quote(symbol: symbol, price: price, currency: meta.currency?.uppercased())
            }
        } catch {
            return nil
        }
    }

    // MARK: - Write-back

    func updateHoldings(_ investments: [Investment]) {
        for investment in investments {
            let sym = investment.symbol.uppercased()
            guard let quoted = prices[sym], quoted > 0 else { continue }
            // Holdings are valued in their own currency; the quote may be in
            // another (a US ticker held in an AED-denominated holding).
            let price = quoteCurrencies[sym].map {
                CurrencyService.shared.convert(quoted, from: $0, to: investment.currency)
            } ?? quoted
            if abs(price - investment.currentPrice) > 0.000001 {
                investment.currentPrice = price
                investment.updatedAt = Date()
            }
        }
    }

    // MARK: - Cache

    private func cachePrices() {
        guard let data = try? JSONEncoder().encode(prices) else { return }
        UserDefaults.standard.set(data, forKey: "cached_stock_prices")
        if let currencies = try? JSONEncoder().encode(quoteCurrencies) {
            UserDefaults.standard.set(currencies, forKey: "cached_stock_quote_currencies")
        }
        UserDefaults.standard.set(Date(), forKey: "cached_stock_prices_date")
    }

    private func loadCachedPrices() {
        guard let data = UserDefaults.standard.data(forKey: "cached_stock_prices"),
              let cached = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        prices = cached
        if let data = UserDefaults.standard.data(forKey: "cached_stock_quote_currencies"),
           let currencies = try? JSONDecoder().decode([String: String].self, from: data) {
            quoteCurrencies = currencies
        }
        lastUpdated = UserDefaults.standard.object(forKey: "cached_stock_prices_date") as? Date
    }
}

// MARK: - Yahoo Finance Response Models

private struct YahooChartResponse: Decodable {
    let chart: Chart

    struct Chart: Decodable {
        let result: [Result]?
    }

    struct Result: Decodable {
        let meta: Meta
    }

    struct Meta: Decodable {
        let regularMarketPrice: Double?
        let currency: String?
    }
}
