import Foundation
import Observation

@Observable
@MainActor
final class CurrencyService {
    static let shared = CurrencyService()

    var rates: [String: Double] = [:]
    var lastUpdated: Date?
    var isLoading = false

    let supportedCurrencies: [CurrencyInfo] = [
        CurrencyInfo(code: "AED", name: "UAE Dirham", symbol: "د.إ", flag: "🇦🇪"),
        CurrencyInfo(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸"),
        CurrencyInfo(code: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺"),
        CurrencyInfo(code: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧"),
        CurrencyInfo(code: "SAR", name: "Saudi Riyal", symbol: "﷼", flag: "🇸🇦"),
        CurrencyInfo(code: "QAR", name: "Qatari Riyal", symbol: "﷼", flag: "🇶🇦"),
        CurrencyInfo(code: "KWD", name: "Kuwaiti Dinar", symbol: "KD", flag: "🇰🇼"),
        CurrencyInfo(code: "BHD", name: "Bahraini Dinar", symbol: "BD", flag: "🇧🇭"),
        CurrencyInfo(code: "OMR", name: "Omani Rial", symbol: "OMR", flag: "🇴🇲"),
        CurrencyInfo(code: "IRR", name: "Iranian Rial", symbol: "﷼", flag: "🇮🇷"),
        CurrencyInfo(code: "INR", name: "Indian Rupee", symbol: "₹", flag: "🇮🇳"),
        CurrencyInfo(code: "PKR", name: "Pakistani Rupee", symbol: "₨", flag: "🇵🇰"),
        CurrencyInfo(code: "EGP", name: "Egyptian Pound", symbol: "E£", flag: "🇪🇬"),
        CurrencyInfo(code: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵"),
        CurrencyInfo(code: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳"),
        CurrencyInfo(code: "CHF", name: "Swiss Franc", symbol: "Fr", flag: "🇨🇭"),
        CurrencyInfo(code: "CAD", name: "Canadian Dollar", symbol: "CA$", flag: "🇨🇦"),
        CurrencyInfo(code: "AUD", name: "Australian Dollar", symbol: "A$", flag: "🇦🇺"),
        CurrencyInfo(code: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "🇸🇬"),
        CurrencyInfo(code: "TRY", name: "Turkish Lira", symbol: "₺", flag: "🇹🇷"),
        CurrencyInfo(code: "RUB", name: "Russian Ruble", symbol: "₽", flag: "🇷🇺"),
        CurrencyInfo(code: "MYR", name: "Malaysian Ringgit", symbol: "RM", flag: "🇲🇾"),
        CurrencyInfo(code: "BTC", name: "Bitcoin", symbol: "₿", flag: "🟠"),
        CurrencyInfo(code: "ETH", name: "Ethereum", symbol: "Ξ", flag: "🔷"),
    ]

    private let fallbackRates: [String: Double] = [
        "AED": 1.0, "USD": 0.2723, "EUR": 0.2497, "GBP": 0.2145,
        "SAR": 1.0208, "QAR": 0.9918, "KWD": 0.0837, "BHD": 0.1027,
        "OMR": 0.1048, "INR": 22.67, "PKR": 75.97, "EGP": 13.24,
        "JPY": 41.25, "CNY": 1.973, "CHF": 0.2452, "CAD": 0.3701,
        "AUD": 0.4193, "SGD": 0.3664, "IRR": 11523, "TRY": 9.01,
        "RUB": 24.92, "MYR": 1.27
    ]

    private var refreshTask: Task<Void, Never>?
    private var isFetching = false

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    private init() {
        rates = fallbackRates
        loadCachedRates()
        startAutoRefresh()
    }

    // #19 – auto-refresh every hour; skip if rates are fresher than 30 minutes
    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                if let last = lastUpdated, Date().timeIntervalSince(last) < 1800 {
                    try? await Task.sleep(for: .seconds(3600))
                    continue
                }
                await fetchLiveRates()
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    func convert(_ amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        let fromRate = rates[from] ?? 1.0
        let toRate = rates[to] ?? 1.0
        let inAED = amount / fromRate
        return inAED * toRate
    }

    /// The user's current base currency (persisted by Settings/onboarding).
    var baseCurrencyCode: String {
        UserDefaults.standard.string(forKey: "base_currency") ?? "AED"
    }

    /// Base-currency value of `amount` at *today's* rate. Call this when creating
    /// a transaction so its `amountInBaseCurrency` is locked at the rate of that
    /// moment — the base equivalent then never drifts as live rates move. Works
    /// from any context (reads the base currency itself; no AppState needed).
    func amountInBase(_ amount: Double, from currency: String) -> Double {
        convert(amount, from: currency, to: baseCurrencyCode)
    }

    func symbol(for code: String) -> String {
        supportedCurrencies.first { $0.code == code }?.symbol ?? code
    }

    func info(for code: String) -> CurrencyInfo? {
        supportedCurrencies.first { $0.code == code }
    }

    func fetchLiveRates(baseCurrency: String = "AED") async {
        guard !isFetching else { return }
        isFetching = true
        isLoading = true
        defer {
            isFetching = false
            isLoading = false
        }

        let urlString = "https://open.er-api.com/v6/latest/\(baseCurrency)"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try Self.decoder.decode(ExchangeRateResponse.self, from: data)
            if response.result == "success" {
                var updatedRates = response.rates
                if let irrRate = await fetchLiveIRRRate(usdPerBaseCurrency: updatedRates["USD"]) {
                    updatedRates["IRR"] = irrRate
                }
                rates = updatedRates
                lastUpdated = Date()
                cacheRates()
            }
        } catch {
            // Keep fallback rates
        }
    }

    // Forex APIs report Iran's official government peg for IRR, which sits far below
    // the real free-market value. Use the USDT/IRR market rate (USDT tracks the US
    // dollar ~1:1) as a proxy for the actual street rate instead.
    // Iranian .ir domains are often DNS-blocked outside Iran, so several sources
    // are tried in order; any failure falls through to the next.
    private func fetchLiveIRRRate(usdPerBaseCurrency: Double?) async -> Double? {
        guard let usdPerBaseCurrency, usdPerBaseCurrency > 0 else { return nil }
        // Ordered by reachability: Tetherland and CoinGecko run on global
        // CDNs (UAE ISPs DNS-block tgju.org and .ir domains), the rest are
        // regional fallbacks. 50,000 IRR/USD sanity floor rejects garbage.
        for fetch in [fetchIRRFromTetherland, fetchIRRFromCoinGecko,
                      fetchIRRFromTGJU, fetchIRRFromNobitex, fetchIRRFromWallex] {
            if let irrPerUSD = await fetch(), irrPerUSD > 50_000 {
                return irrPerUSD * usdPerBaseCurrency
            }
        }
        return nil
    }

    // Tetherland (.com, Cloudflare) — USDT price in Toman on the Iranian market
    private func fetchIRRFromTetherland() async -> Double? {
        guard let data = await quickGet("https://api.tetherland.com/currencies"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["data"] as? [String: Any],
              let currencies = payload["currencies"] as? [String: Any],
              let usdt = currencies["USDT"] as? [String: Any] else { return nil }
        let toman: Double?
        if let number = usdt["price"] as? Double {
            toman = number
        } else if let text = usdt["price"] as? String {
            toman = Double(text.replacingOccurrences(of: ",", with: ""))
        } else {
            toman = nil
        }
        guard let toman, toman > 0 else { return nil }
        return toman * 10
    }

    // CoinGecko (global CDN) — Tether price expressed in IRR
    private func fetchIRRFromCoinGecko() async -> Double? {
        guard let data = await quickGet("https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=irr"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tether = json["tether"] as? [String: Any] else { return nil }
        return tether["irr"] as? Double
    }

    private func quickGet(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        let request = URLRequest(url: url, timeoutInterval: 10)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    // TGJU (.org, reachable worldwide) — free-market USD/IRR reference rate in rials
    private func fetchIRRFromTGJU() async -> Double? {
        guard let data = await quickGet("https://call1.tgju.org/ajax.json"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let dollar = current["price_dollar_rl"] as? [String: Any],
              let priceText = dollar["p"] as? String else { return nil }
        return Double(priceText.replacingOccurrences(of: ",", with: ""))
    }

    // Nobitex — USDT/IRR last trade
    private func fetchIRRFromNobitex() async -> Double? {
        guard let data = await quickGet("https://api.nobitex.ir/market/stats?srcCurrency=usdt&dstCurrency=rls"),
              let response = try? Self.decoder.decode(NobitexStatsResponse.self, from: data),
              response.status == "ok" else { return nil }
        return response.stats["usdt-rls"]?.latest
    }

    // Wallex — USDT/TMN last trade (Toman × 10 = Rial)
    private func fetchIRRFromWallex() async -> Double? {
        guard let data = await quickGet("https://api.wallex.ir/v1/markets"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let symbols = result["symbols"] as? [String: Any],
              let usdtTmn = symbols["USDTTMN"] as? [String: Any],
              let stats = usdtTmn["stats"] as? [String: Any] else { return nil }
        let lastPrice = (stats["lastPrice"] as? String).flatMap(Double.init)
            ?? (stats["lastPrice"] as? Double)
        guard let toman = lastPrice, toman > 0 else { return nil }
        return toman * 10
    }

    private func cacheRates() {
        if let data = try? Self.encoder.encode(rates) {
            UserDefaults.standard.set(data, forKey: "cached_exchange_rates")
            UserDefaults.standard.set(Date(), forKey: "exchange_rates_date")
        }
    }

    private func loadCachedRates() {
        if let data = UserDefaults.standard.data(forKey: "cached_exchange_rates"),
           let cached = try? Self.decoder.decode([String: Double].self, from: data) {
            rates = cached
            lastUpdated = UserDefaults.standard.object(forKey: "exchange_rates_date") as? Date
        }
    }
}

struct CurrencyInfo: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let symbol: String
    let flag: String
}

private struct ExchangeRateResponse: Codable {
    let result: String
    let rates: [String: Double]
}

private struct NobitexStatsResponse: Decodable {
    let status: String
    let stats: [String: NobitexMarketStat]
}

private struct NobitexMarketStat: Decodable {
    let latest: Double?

    enum CodingKeys: String, CodingKey {
        case latest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringValue = try? container.decode(String.self, forKey: .latest) {
            latest = Double(stringValue)
        } else {
            latest = try? container.decode(Double.self, forKey: .latest)
        }
    }
}
