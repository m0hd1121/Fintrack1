import Foundation
import Observation

// MARK: - CryptoPriceService
// Fetches live USD prices with a 10-second timeout.
// Primary source: Binance public API (api.binance.com) — no key, fetches all USDT pairs.
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

    // MARK: - Coin Registry

    static let coinNames: [String: String] = [
        "BTC": "Bitcoin", "ETH": "Ethereum", "BNB": "BNB", "SOL": "Solana",
        "XRP": "XRP", "DOGE": "Dogecoin", "ADA": "Cardano", "AVAX": "Avalanche",
        "LINK": "Chainlink", "DOT": "Polkadot", "MATIC": "Polygon", "POL": "Polygon",
        "SHIB": "Shiba Inu", "LTC": "Litecoin", "TRX": "TRON", "UNI": "Uniswap",
        "ATOM": "Cosmos", "NEAR": "NEAR Protocol", "OP": "Optimism", "ARB": "Arbitrum",
        "APT": "Aptos", "SUI": "Sui", "TON": "Toncoin", "USDT": "Tether",
        "USDC": "USD Coin", "DAI": "Dai", "FTM": "Fantom", "ALGO": "Algorand",
        "VET": "VeChain", "MANA": "Decentraland", "SAND": "The Sandbox",
        "AXS": "Axie Infinity", "THETA": "Theta Network", "FIL": "Filecoin",
        "ICP": "Internet Computer", "XLM": "Stellar", "ETC": "Ethereum Classic",
        "HBAR": "Hedera", "EGLD": "MultiversX", "AAVE": "Aave", "GRT": "The Graph",
        "MKR": "Maker", "SNX": "Synthetix", "CRV": "Curve DAO", "COMP": "Compound",
        "YFI": "Yearn.Finance", "SUSHI": "SushiSwap", "1INCH": "1inch",
        "LDO": "Lido DAO", "RPL": "Rocket Pool", "CAKE": "PancakeSwap", "GMT": "STEPN",
        "APE": "ApeCoin", "GALA": "Gala", "ENJ": "Enjin Coin", "CHZ": "Chiliz",
        "BAT": "Basic Attention Token", "ZIL": "Zilliqa", "NEO": "NEO", "EOS": "EOS",
        "XTZ": "Tezos", "DASH": "Dash", "ZEC": "Zcash", "XMR": "Monero",
        "BCH": "Bitcoin Cash", "FLOW": "Flow", "ROSE": "Oasis Network", "ONE": "Harmony",
        "AR": "Arweave", "KSM": "Kusama", "WAVES": "Waves", "KAVA": "Kava",
        "CELO": "Celo", "ANKR": "Ankr", "AUDIO": "Audius", "BAND": "Band Protocol",
        "C98": "Coin98", "CFX": "Conflux", "CTSI": "Cartesi",
        "ENS": "Ethereum Name Service", "FXS": "Frax Share", "GMX": "GMX",
        "HNT": "Helium", "HOT": "Holo", "IMX": "Immutable", "INJ": "Injective",
        "JASMY": "JasmyCoin", "JUP": "Jupiter", "KNC": "Kyber Network",
        "LRC": "Loopring", "MAGIC": "Magic", "MINA": "Mina Protocol",
        "OCEAN": "Ocean Protocol", "ONT": "Ontology", "PENDLE": "Pendle",
        "PEPE": "Pepe", "PYTH": "Pyth Network", "QNT": "Quant", "RAY": "Raydium",
        "RDNT": "Radiant Capital", "REEF": "Reef", "RENDER": "Render",
        "RLC": "iExec RLC", "RUNE": "THORChain", "RVN": "Ravencoin", "SEI": "Sei",
        "SLP": "Smooth Love Potion", "SSV": "SSV Network", "STG": "Stargate Finance",
        "STX": "Stacks", "STRK": "Starknet", "TAO": "Bittensor", "TNSR": "Tensor",
        "TRB": "Tellor", "TRUMP": "Official Trump", "TURBO": "Turbo",
        "TWT": "Trust Wallet Token", "UMA": "UMA", "VTHO": "VeThor Token",
        "W": "Wormhole", "WIF": "dogwifhat", "WLD": "Worldcoin", "WOO": "WOO Network",
        "XEM": "NEM", "XVS": "Venus", "YGG": "Yield Guild Games",
        "ZEN": "Horizen", "ZETA": "ZetaChain", "ZRX": "0x Protocol",
        "AGIX": "SingularityNET", "AKT": "Akash Network", "ALT": "AltLayer",
        "AMP": "Amp", "API3": "API3", "ARKM": "Arkham", "AXL": "Axelar",
        "BAKE": "BakeryToken", "BB": "BounceBit", "BIGTIME": "Big Time",
        "BLUR": "Blur", "BOND": "BarnBridge", "BONK": "Bonk", "BTT": "BitTorrent",
        "CLV": "CLV", "COTI": "COTI", "CRO": "Cronos", "CYBER": "CyberConnect",
        "DENT": "Dent", "DODO": "DODO", "ELF": "aelf", "ENA": "Ethena",
        "FET": "Fetch.ai", "GHST": "Aavegotchi", "GNO": "Gnosis",
        "HIVE": "Hive", "ID": "SPACE ID", "IOST": "IOST", "JTO": "Jito",
        "LIT": "Litentry", "LOOKS": "LooksRare", "ME": "Magic Eden",
        "METIS": "Metis", "MLN": "Enzyme", "NTRN": "Neutron", "ONDO": "Ondo",
        "ORBS": "Orbs", "OXT": "Orchid", "PAXG": "PAX Gold",
        "PEOPLE": "ConstitutionDAO", "PERP": "Perpetual Protocol",
        "PIXEL": "Pixels", "PNUT": "Peanut the Squirrel", "PORTAL": "Portal",
        "REQ": "Request", "RSR": "Reserve Rights", "SAGA": "Saga",
        "SFP": "SafePal", "SPELL": "Spell Token", "SUPER": "SuperVerse",
        "TFUEL": "Theta Fuel", "TLM": "Alien Worlds", "UTK": "Utrust",
        "VOXEL": "Voxies", "WAN": "Wanchain", "XAI": "Xai", "ZK": "ZKsync",
        "FTT": "FTX Token", "LUNC": "Terra Classic", "SC": "Siacoin",
        "XNO": "Nano", "IOTA": "IOTA", "LPT": "Livepeer", "DUSK": "Dusk Network",
        "NMR": "Numeraire", "STORJ": "Storj", "OGN": "Origin Protocol",
        "BICO": "Biconomy", "ACH": "Alchemy Pay", "REN": "Ren", "CVC": "Civic",
        "BSW": "Biswap", "CHESS": "Tranchess", "CKB": "Nervos Network",
        "HOOK": "Hooked Protocol", "PHB": "Phoenix Global", "REI": "REI Network",
        "HIGH": "Highstreet", "HFT": "Hashflow", "MPLX": "Metaplex",
        "MOG": "Mog Coin", "BRETT": "Brett", "SUNDOG": "Sundog",
        "PONKE": "Ponke", "RATS": "Rats", "HT": "Huobi Token",
        "ALCX": "Alchemix", "VGX": "Voyager Token", "LSK": "Lisk",
        "KEY": "SelfKey", "FRONT": "Frontier", "AURORA": "Aurora",
    ]

    // Market-cap priority order for default display (top to bottom)
    static let preferredOrder: [String] = [
        "BTC", "ETH", "BNB", "SOL", "XRP", "DOGE", "ADA", "AVAX", "LINK", "DOT",
        "MATIC", "SHIB", "LTC", "TRX", "UNI", "ATOM", "NEAR", "OP", "ARB", "APT",
        "SUI", "TON", "FTM", "ALGO", "VET", "MANA", "SAND", "AXS", "THETA", "FIL",
        "ICP", "XLM", "ETC", "HBAR", "EGLD", "AAVE", "GRT", "MKR", "SNX", "CRV",
        "INJ", "IMX", "RUNE", "QNT", "STX", "PEPE", "WIF", "BONK", "TAO", "RENDER",
        "PYTH", "JUP", "ENA", "STRK", "WLD", "PENDLE", "SEI", "ONDO", "TURBO",
        "TRUMP", "LDO", "GMX", "FXS", "RPL", "CAKE", "GMT", "APE", "GALA", "ENJ",
        "CHZ", "BAT", "ZIL", "1INCH", "COMP", "YFI", "SUSHI", "KAVA", "CELO",
        "BLUR", "AGIX", "FET", "AKT", "AXL", "RDNT", "STG", "TWT", "BCH", "EOS",
        "XMR", "ZEC", "DASH", "XTZ", "NEO", "KSM", "AR", "FLOW", "ROSE", "ONE",
    ]

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

    // MARK: - Binance (all USDT pairs)

    private func fetchFromBinance() async -> Bool {
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/price") else { return false }

        do {
            let (data, _) = try await Self.session.data(from: url)

            struct Ticker: Decodable {
                let symbol: String
                let price: String
            }

            let tickers = try JSONDecoder().decode([Ticker].self, from: data)
            guard !tickers.isEmpty else { return false }

            for ticker in tickers {
                guard ticker.symbol.hasSuffix("USDT") else { continue }
                let base = String(ticker.symbol.dropLast(4))
                guard Self.isValidBase(base), let price = Double(ticker.price) else { continue }
                prices[base] = price
            }

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

    // Returns false for leveraged/inverse tokens and other non-standard symbols
    private static func isValidBase(_ base: String) -> Bool {
        guard !base.isEmpty else { return false }
        for suffix in ["UP", "DOWN", "BULL", "BEAR", "3L", "3S", "5L", "5S", "2L", "2S"] {
            if base.hasSuffix(suffix) { return false }
        }
        // Reject symbols starting with 3+ digits (1000SHIB, 100000NEIRO etc.)
        // "1INCH" has 1 leading digit so it passes
        var leadingDigits = 0
        for ch in base {
            guard ch.isNumber else { break }
            leadingDigits += 1
        }
        return leadingDigits < 3
    }

    // MARK: - CryptoCompare fallback

    private static let cryptoCompareSymbols =
        "BTC,ETH,BNB,SOL,XRP,DOGE,ADA,AVAX,LINK,DOT,MATIC,SHIB,LTC,TRX,UNI,ATOM,NEAR,OP,ARB,APT,SUI,TON,USDT,USDC"

    private func fetchFromCryptoCompare() async {
        guard let url = URL(string: "https://min-api.cryptocompare.com/data/pricemulti?fsyms=\(Self.cryptoCompareSymbols)&tsyms=USD") else { return }

        do {
            let (data, _) = try await Self.session.data(from: url)
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

    // MARK: - Coin Search

    /// Returns coins matching `query`, ordered by market-cap priority.
    /// Empty query returns the full preferred-order list.
    func searchCoins(query: String) -> [(symbol: String, name: String)] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()

        if q.isEmpty {
            var results: [(symbol: String, name: String)] = []
            var seen = Set<String>()
            for sym in Self.preferredOrder {
                guard !seen.contains(sym) else { continue }
                results.append((symbol: sym, name: Self.coinNames[sym] ?? sym))
                seen.insert(sym)
            }
            // Append remaining coinNames entries that have live prices
            for (sym, name) in Self.coinNames.sorted(by: { $0.key < $1.key }) where !seen.contains(sym) {
                if prices[sym] != nil {
                    results.append((symbol: sym, name: name))
                    seen.insert(sym)
                }
            }
            return results
        }

        var seen = Set<String>()
        var results: [(symbol: String, name: String)] = []

        // Preferred coins first
        for sym in Self.preferredOrder {
            guard !seen.contains(sym) else { continue }
            let name = Self.coinNames[sym] ?? sym
            if sym.lowercased().contains(q) || name.lowercased().contains(q) {
                results.append((symbol: sym, name: name))
                seen.insert(sym)
            }
        }
        // Rest of coinNames
        for (sym, name) in Self.coinNames.sorted(by: { $0.key < $1.key }) {
            guard !seen.contains(sym) else { continue }
            if sym.lowercased().contains(q) || name.lowercased().contains(q) {
                results.append((symbol: sym, name: name))
                seen.insert(sym)
            }
        }
        // Priced coins not in coinNames (raw Binance symbols)
        for sym in prices.keys.sorted() {
            guard !seen.contains(sym) else { continue }
            if sym.lowercased().contains(q) {
                results.append((symbol: sym, name: sym))
                seen.insert(sym)
            }
        }

        return results
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
