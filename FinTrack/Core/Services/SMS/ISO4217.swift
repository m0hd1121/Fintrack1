import Foundation

/// Currency validation for the SMS extraction pipeline. Deliberately dumb: it
/// answers "is this a real code?" and nothing else — all the reasoning about
/// *which* currency a message means happens in the parser/model.
enum ISO4217 {

    static let codes: Set<String> = [
        "AED","AFN","ALL","AMD","ANG","AOA","ARS","AUD","AWG","AZN",
        "BAM","BBD","BDT","BGN","BHD","BIF","BMD","BND","BOB","BOV","BRL","BSD","BTN","BWP","BYN","BZD",
        "CAD","CDF","CHE","CHF","CHW","CLF","CLP","CNY","COP","COU","CRC","CUP","CVE","CZK",
        "DJF","DKK","DOP","DZD",
        "EGP","ERN","ETB","EUR",
        "FJD","FKP",
        "GBP","GEL","GHS","GIP","GMD","GNF","GTQ","GYD",
        "HKD","HNL","HTG","HUF",
        "IDR","ILS","INR","IQD","IRR","ISK",
        "JMD","JOD","JPY",
        "KES","KGS","KHR","KMF","KPW","KRW","KWD","KYD","KZT",
        "LAK","LBP","LKR","LRD","LSL","LYD",
        "MAD","MDL","MGA","MKD","MMK","MNT","MOP","MRU","MUR","MVR","MWK","MXN","MXV","MYR","MZN",
        "NAD","NGN","NIO","NOK","NPR","NZD",
        "OMR",
        "PAB","PEN","PGK","PHP","PKR","PLN","PYG",
        "QAR",
        "RON","RSD","RUB","RWF",
        "SAR","SBD","SCR","SDG","SEK","SGD","SHP","SLE","SOS","SRD","SSP","STN","SVC","SYP","SZL",
        "THB","TJS","TMT","TND","TOP","TRY","TTD","TWD","TZS",
        "UAH","UGX","USD","USN","UYU","UYW","UZS",
        "VED","VES","VND","VUV",
        "WST",
        "XAF","XAG","XAU","XCD","XCG","XDR","XOF","XPD","XPF","XPT","XSU","XUA",
        "YER",
        "ZAR","ZMW","ZWG"
    ]

    /// Exceptions to the two-decimal default.
    private static let minorUnitExceptions: [String: Int] = [
        "BHD": 3, "IQD": 3, "JOD": 3, "KWD": 3, "LYD": 3, "OMR": 3, "TND": 3,
        "BIF": 0, "CLP": 0, "DJF": 0, "GNF": 0, "ISK": 0, "JPY": 0, "KMF": 0,
        "KRW": 0, "PYG": 0, "RWF": 0, "UGX": 0, "UYI": 0, "VND": 0, "VUV": 0,
        "XAF": 0, "XOF": 0, "XPF": 0,
        "CLF": 4, "UYW": 4
    ]

    static func isValid(_ code: String?) -> Bool {
        guard let code else { return false }
        return codes.contains(code.uppercased())
    }

    static func minorUnits(for code: String?) -> Int {
        guard let code else { return 2 }
        return minorUnitExceptions[code.uppercased()] ?? 2
    }

    /// Currencies where `1.500` is far more likely to mean one and a half
    /// than fifteen hundred. Relevant across the GCC.
    static func usesThreeDecimals(_ code: String?) -> Bool {
        minorUnits(for: code) == 3
    }
}
