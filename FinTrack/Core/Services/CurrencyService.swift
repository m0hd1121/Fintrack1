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
        CurrencyInfo(code: "INR", name: "Indian Rupee", symbol: "₹", flag: "🇮🇳"),
        CurrencyInfo(code: "PKR", name: "Pakistani Rupee", symbol: "₨", flag: "🇵🇰"),
        CurrencyInfo(code: "EGP", name: "Egyptian Pound", symbol: "E£", flag: "🇪🇬"),
        CurrencyInfo(code: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵"),
        CurrencyInfo(code: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳"),
        CurrencyInfo(code: "CHF", name: "Swiss Franc", symbol: "Fr", flag: "🇨🇭"),
        CurrencyInfo(code: "CAD", name: "Canadian Dollar", symbol: "CA$", flag: "🇨🇦"),
        CurrencyInfo(code: "AUD", name: "Australian Dollar", symbol: "A$", flag: "🇦🇺"),
        CurrencyInfo(code: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "🇸🇬"),
        CurrencyInfo(code: "IRR", name: "Iranian Rial", symbol: "﷼", flag: "🇮🇷"),
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
                rates = response.rates
                lastUpdated = Date()
                cacheRates()
            }
        } catch {
            // Keep fallback rates
        }
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
