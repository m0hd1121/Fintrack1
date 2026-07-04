import Foundation

// MARK: - ParsedBankEmail

/// Result of running one email through the parser. Field-level provenance is
/// captured in `explanationLines` so the review UI can show *why* a
/// transaction was detected — the audit requirement.
struct ParsedBankEmail {
    var amount: Double
    var currency: String
    var merchant: String
    var date: Date
    var cardLast4: String?
    var direction: ParsedDirection
    var availableBalance: Double?
    var referenceNumber: String?
    var bankName: String
    var confidence: Double          // 0...1
    var explanationLines: [String]
    var isSuspicious: Bool
    var suspiciousReason: String?

    var explanation: String { explanationLines.joined(separator: "\n") }
}

// MARK: - UAE Bank Registry

struct UAEBankProfile {
    let name: String
    let senderDomains: [String]
}

// MARK: - BankEmailParser

/// Regex-based extraction engine for UAE bank notification emails.
/// Runs fully on-device; no email content ever leaves the phone.
final class BankEmailParser {
    static let shared = BankEmailParser()
    private init() {}

    // MARK: Sender whitelist

    static let uaeBanks: [UAEBankProfile] = [
        UAEBankProfile(name: "Emirates NBD",       senderDomains: ["emiratesnbd.com", "enbd.com"]),
        UAEBankProfile(name: "FAB",                senderDomains: ["bankfab.com", "fab.ae", "nbad.com", "fgb.ae"]),
        UAEBankProfile(name: "ADCB",               senderDomains: ["adcb.com", "adcb.ae"]),
        UAEBankProfile(name: "Mashreq",            senderDomains: ["mashreq.com", "mashreqbank.com"]),
        UAEBankProfile(name: "DIB",                senderDomains: ["dib.ae"]),
        UAEBankProfile(name: "RAKBANK",            senderDomains: ["rakbank.ae"]),
        UAEBankProfile(name: "CBD",                senderDomains: ["cbd.ae"]),
        UAEBankProfile(name: "Emirates Islamic",   senderDomains: ["emiratesislamic.ae", "eibank.ae"]),
        UAEBankProfile(name: "HSBC",               senderDomains: ["hsbc.ae", "hsbc.com"]),
        UAEBankProfile(name: "Standard Chartered", senderDomains: ["sc.com"]),
        UAEBankProfile(name: "Citibank",           senderDomains: ["citibank.ae", "citi.com", "citibank.com"]),
        UAEBankProfile(name: "Ajman Bank",         senderDomains: ["ajmanbank.ae"]),
        UAEBankProfile(name: "NBF",                senderDomains: ["nbf.ae"]),
        UAEBankProfile(name: "Sharjah Islamic",    senderDomains: ["sib.ae"]),
        UAEBankProfile(name: "ADIB",               senderDomains: ["adib.ae", "adib.com"]),
        UAEBankProfile(name: "Wio Bank",           senderDomains: ["wio.io", "wiobank.ae"]),
        UAEBankProfile(name: "Liv",                senderDomains: ["liv.me"]),
        UAEBankProfile(name: "Mbank",              senderDomains: ["mbank.ae"]),
    ]

    /// Subject keywords that mark a transaction notification (vs. marketing).
    private static let transactionSubjectKeywords = [
        "transaction", "purchase", "debit", "credit", "payment", "transfer",
        "withdrawal", "spent", "alert", "card", "atm", "salary", "refund",
        "outward", "inward", "remittance",
    ]

    /// Marketing / non-transaction subject markers to skip early.
    private static let marketingSubjectKeywords = [
        "offer", "reward yourself", "win ", "sale", "discount", "newsletter",
        "statement is ready", "e-statement", "otp", "one time password", "one-time password",
    ]

    // MARK: Classification

    func bankName(forSender sender: String) -> String? {
        let lower = sender.lowercased()
        for bank in Self.uaeBanks where bank.senderDomains.contains(where: { lower.contains($0) }) {
            return bank.name
        }
        return nil
    }

    /// Cheap pre-filter: is this email worth parsing at all?
    func isLikelyBankTransactionEmail(sender: String, subject: String) -> Bool {
        let subjectLower = subject.lowercased()
        guard !Self.marketingSubjectKeywords.contains(where: { subjectLower.contains($0) }) else {
            return false
        }
        let fromKnownBank = bankName(forSender: sender) != nil
        let subjectMatches = Self.transactionSubjectKeywords.contains { subjectLower.contains($0) }
        // Known bank + transaction-looking subject, or a very explicit subject
        // from an unknown sender (user may bank somewhere not in the registry).
        return (fromKnownBank && subjectMatches)
            || subjectLower.contains("transaction alert")
            || subjectLower.contains("debit alert")
            || subjectLower.contains("credit alert")
    }

    /// Gmail search query restricting the scan to whitelisted senders only —
    /// the minimum-scope principle: we never list or read the rest of the mailbox.
    /// User-configured bank rules extend the whitelist.
    static func gmailSenderQuery(extraSenders: [String] = []) -> String {
        let senders = uaeBanks.flatMap(\.senderDomains) + extraSenders.filter { !$0.isEmpty }
        let froms = Set(senders).map { "from:\($0)" }.joined(separator: " OR ")
        return "(\(froms)) newer_than:60d"
    }

    // MARK: Main parse

    func parse(sender: String, subject: String, body: String, receivedAt: Date) -> ParsedBankEmail? {
        let text = Self.normalize(body: body)
        var lines: [String] = []
        var score = 0.0

        // Bank identification
        let bank = bankName(forSender: sender)
        if let bank {
            lines.append("Sender \(sender) matched \(bank) whitelist")
            score += 0.15
        } else {
            lines.append("Sender \(sender) is not in the UAE bank whitelist")
        }

        // Amount + currency (required)
        guard let (amount, currency, amountMatch) = Self.extractAmount(from: text) else { return nil }
        lines.append("Amount \(currency) \(amount) found in “\(amountMatch)”")
        score += 0.35

        // Direction
        let (direction, directionKeyword) = Self.extractDirection(from: text, subject: subject)
        if let directionKeyword {
            lines.append("Detected \(direction.rawValue.lowercased()) from keyword “\(directionKeyword)”")
            score += 0.15
        } else {
            lines.append("No debit/credit keyword — assumed \(direction.rawValue.lowercased())")
        }

        // Merchant
        let (merchantOpt, merchantPattern) = Self.extractMerchant(from: text)
        let merchant = merchantOpt ?? bank ?? "Unknown Merchant"
        if let merchantPattern, merchantOpt != nil {
            lines.append("Merchant “\(merchant)” captured after “\(merchantPattern)”")
            score += 0.15
        } else {
            lines.append("No merchant phrase found — using “\(merchant)”")
        }

        // Date
        let (date, dateSource) = Self.extractDate(from: text) ?? (receivedAt, "email received time")
        lines.append("Date from \(dateSource)")
        if dateSource != "email received time" { score += 0.08 }

        // Card digits
        let cardLast4 = Self.extractCardLast4(from: text)
        if let cardLast4 {
            lines.append("Card ending \(cardLast4)")
            score += 0.07
        }

        // Available balance
        let balance = Self.extractBalance(from: text)
        if balance != nil { lines.append("Available balance captured"); score += 0.03 }

        // Reference number
        let reference = Self.extractReference(from: text)
        if let reference { lines.append("Reference \(reference)"); score += 0.02 }

        // Suspicion heuristics
        var suspicious = false
        var suspiciousReason: String?
        if amount > 100_000 {
            suspicious = true
            suspiciousReason = "Unusually large amount — please verify against the original email"
        } else if merchantOpt == nil && directionKeyword == nil {
            suspicious = true
            suspiciousReason = "Neither merchant nor debit/credit keyword found — parse may be unreliable"
        }
        if suspicious { score = min(score, 0.55) }

        return ParsedBankEmail(
            amount: amount,
            currency: currency,
            merchant: merchant,
            date: date,
            cardLast4: cardLast4,
            direction: direction,
            availableBalance: balance,
            referenceNumber: reference,
            bankName: bank ?? "Unknown Bank",
            confidence: min(0.99, score),
            explanationLines: lines,
            isSuspicious: suspicious,
            suspiciousReason: suspiciousReason
        )
    }

    // MARK: - Field extractors

    private static let knownCurrencies = ["AED", "USD", "EUR", "GBP", "SAR", "QAR", "KWD",
                                          "BHD", "OMR", "INR", "PKR", "EGP", "IRR"]

    static func extractAmount(from text: String) -> (Double, String, String)? {
        let currencyAlt = knownCurrencies.joined(separator: "|")
        // "AED 1,234.56" or "1,234.56 AED"
        let patterns = [
            "(\(currencyAlt))\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)",
            "([0-9][0-9,]*(?:\\.[0-9]{1,2})?)\\s*(\(currencyAlt))",
        ]
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let fullRange = Range(match.range, in: text),
                  let g1 = Range(match.range(at: 1), in: text),
                  let g2 = Range(match.range(at: 2), in: text) else { continue }
            let first = String(text[g1]), second = String(text[g2])
            let currency = (index == 0 ? first : second).uppercased()
            let numberText = (index == 0 ? second : first).replacingOccurrences(of: ",", with: "")
            guard let value = Double(numberText), value > 0 else { continue }
            return (value, currency, String(text[fullRange]))
        }
        return nil
    }

    private static let debitKeywords = ["debited", "purchase of", "was used for", "spent",
                                        "withdrawn", "charged", "payment of", "paid to",
                                        "purchase transaction", "pos transaction", "atm withdrawal",
                                        "outward transfer"]
    private static let creditKeywords = ["credited", "received", "deposited", "refund",
                                         "reversal", "salary", "cashback", "inward transfer",
                                         "transferred to your"]

    static func extractDirection(from text: String, subject: String) -> (ParsedDirection, String?) {
        let combined = (subject + " " + text).lowercased()
        // Credit keywords first — "refund of your purchase" should be a credit.
        for keyword in creditKeywords where combined.contains(keyword) { return (.credit, keyword) }
        for keyword in debitKeywords where combined.contains(keyword) { return (.debit, keyword) }
        return (.debit, nil)   // most bank alerts are spends; flagged as low-confidence upstream
    }

    static func extractMerchant(from text: String) -> (String?, String?) {
        // "at MERCHANT on/dated/." · "to MERCHANT on/." · "towards MERCHANT"
        let patterns: [(String, String)] = [
            ("at ",      "(?:at)\\s+([A-Z0-9][A-Za-z0-9 &*.'\\-/]{2,40}?)\\s+(?:on|dated|for|\\.|,)"),
            ("to ",      "(?:paid to|to)\\s+([A-Z0-9][A-Za-z0-9 &*.'\\-/]{2,40}?)\\s+(?:on|dated|for|\\.|,)"),
            ("towards ", "(?:towards)\\s+([A-Za-z0-9][A-Za-z0-9 &*.'\\-/]{2,40}?)\\s+(?:on|dated|\\.|,)"),
            ("from ",    "(?:received from|from)\\s+([A-Z][A-Za-z0-9 &*.'\\-/]{2,40}?)\\s+(?:on|dated|\\.|,)"),
        ]
        for (label, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let g1 = Range(match.range(at: 1), in: text) else { continue }
            let raw = String(text[g1]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip captures that are clearly not merchants
            let lower = raw.lowercased()
            if lower.contains("your account") || lower.contains("your card") { continue }
            if raw.count >= 2 { return (raw, label.trimmingCharacters(in: .whitespaces)) }
        }
        return (nil, nil)
    }

    static func extractCardLast4(from text: String) -> String? {
        let pattern = "(?:card|account|a/c)[^0-9]{0,20}?(?:ending(?: in| with)?|no\\.?|number|[Xx*•.]{2,})\\s*[Xx*•.]*([0-9]{4})\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let g1 = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[g1])
    }

    static func extractBalance(from text: String) -> Double? {
        let currencyAlt = knownCurrencies.joined(separator: "|")
        let pattern = "(?:available|avl\\.?|avail\\.?)\\s*(?:balance|limit|bal\\.?)[^0-9]{0,15}(?:\(currencyAlt))?\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let g1 = Range(match.range(at: 1), in: text) else { return nil }
        return Double(String(text[g1]).replacingOccurrences(of: ",", with: ""))
    }

    static func extractReference(from text: String) -> String? {
        let pattern = "ref(?:erence)?(?:\\s*(?:no|number|#))?\\s*[:.#]?\\s*([A-Za-z0-9\\-]{4,25})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let g1 = Range(match.range(at: 1), in: text) else { return nil }
        let value = String(text[g1])
        // Avoid capturing plain words like "reference below"
        return value.rangeOfCharacter(from: .decimalDigits) != nil ? value : nil
    }

    static func extractDate(from text: String) -> (Date, String)? {
        let formats: [(pattern: String, format: String)] = [
            ("[0-9]{2}/[0-9]{2}/[0-9]{4} [0-9]{2}:[0-9]{2}", "dd/MM/yyyy HH:mm"),
            ("[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}", "dd-MM-yyyy HH:mm"),
            ("[0-9]{2}/[0-9]{2}/[0-9]{4}",                    "dd/MM/yyyy"),
            ("[0-9]{2}-[0-9]{2}-[0-9]{4}",                    "dd-MM-yyyy"),
            ("[0-9]{1,2} [A-Za-z]{3} [0-9]{4}",               "d MMM yyyy"),
            ("[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}",              "MMM d, yyyy"),
        ]
        for (pattern, format) in formats {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text) else { continue }
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: String(text[range])) {
                return (date, "“\(text[range])” in email body")
            }
        }
        return nil
    }

    // MARK: - Fingerprint

    /// Stable identity for duplicate detection. Reference number wins when
    /// present; otherwise amount + calendar day + card + merchant token.
    static func fingerprint(
        amount: Double, currency: String, date: Date,
        cardLast4: String?, merchant: String, reference: String?
    ) -> String {
        if let reference, !reference.isEmpty {
            return "ref:\(reference.lowercased())"
        }
        let day = Int(date.timeIntervalSince1970 / 86_400)
        let merchantToken = merchant.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(2).joined()
        return "fp:\(currency):\(String(format: "%.2f", amount)):\(day):\(cardLast4 ?? "-"):\(merchantToken)"
    }

    // MARK: - Body normalization

    /// Strip HTML tags/entities and collapse whitespace so the regexes see
    /// clean prose regardless of the bank's email template.
    static func normalize(body: String) -> String {
        var text = body
        // Drop style/script blocks entirely
        for tag in ["style", "script", "head"] {
            text = text.replacingOccurrences(
                of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>",
                with: " ", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&#39;": "'", "&quot;": "\""]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{2,}", with: "\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
