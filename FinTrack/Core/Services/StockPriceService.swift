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

        let fetched = await withTaskGroup(of: (String, Double)?.self) { group in
            for symbol in Set(cleaned) {
                group.addTask { await Self.fetchSingle(symbol: symbol) }
            }
            var results: [String: Double] = [:]
            for await pair in group {
                if let (symbol, price) = pair { results[symbol] = price }
            }
            return results
        }

        guard !fetched.isEmpty else {
            lastError = "Prices unavailable"
            return
        }
        for (symbol, price) in fetched { prices[symbol] = price }
        lastUpdated = Date()
        lastError = nil
        cachePrices()
    }

    nonisolated private static func fetchSingle(symbol: String) async -> (String, Double)? {
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
            guard let price = decoded.chart.result?.first?.meta.regularMarketPrice, price > 0 else { return nil }
            return (symbol, price)
        } catch {
            return nil
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
