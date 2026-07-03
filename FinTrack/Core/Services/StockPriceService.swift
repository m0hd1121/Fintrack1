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

    func fetchPrices(symbols: [String]) async {
        let cleaned = symbols.map { $0.uppercased().trimmingCharacters(in: .whitespaces) }
                             .filter { !$0.isEmpty }
        guard !cleaned.isEmpty, !isFetching else { return }

        lastFetchedSymbols = cleaned
        isFetching = true
        isRefreshing = true
        defer { isFetching = false; isRefreshing = false }

        // Yahoo Finance v7 quote — batch up to ~200 symbols per request
        let joined = cleaned.joined(separator: ",")
        let urlString = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(joined)&fields=regularMarketPrice,currency"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://finance.yahoo.com", forHTTPHeaderField: "Referer")

        do {
            let (data, _) = try await Self.session.data(for: request)
            let response = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)
            guard let results = response.quoteResponse.result, !results.isEmpty else { return }

            for quote in results {
                guard quote.regularMarketPrice > 0 else { continue }
                prices[quote.symbol.uppercased()] = quote.regularMarketPrice
            }
            lastUpdated = Date()
            lastError = nil
            cachePrices()
        } catch {
            lastError = "Prices unavailable"
        }
    }

    // MARK: - Write-back

    func updateHoldings(_ investments: [Investment]) {
        for investment in investments {
            let sym = investment.symbol.uppercased()
            guard let price = prices[sym], price > 0 else { continue }
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
        UserDefaults.standard.set(Date(), forKey: "cached_stock_prices_date")
    }

    private func loadCachedPrices() {
        guard let data = UserDefaults.standard.data(forKey: "cached_stock_prices"),
              let cached = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        prices = cached
        lastUpdated = UserDefaults.standard.object(forKey: "cached_stock_prices_date") as? Date
    }
}

// MARK: - Yahoo Finance Response Models

private struct YahooQuoteResponse: Decodable {
    let quoteResponse: QuoteResult

    struct QuoteResult: Decodable {
        let result: [Quote]?
    }

    struct Quote: Decodable {
        let symbol: String
        let regularMarketPrice: Double
        let currency: String?
    }
}
