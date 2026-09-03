import Foundation

/// Extracts transactions from a single SMS message. Two tiers:
///
/// 1. **Template match** — identify the bank from the sender id / message
///    content (`BankSMSTemplateStore`), then run the same generic, proven
///    extraction grammar `BankEmailParser` already uses for bank emails
///    (amount, direction, merchant, card digits, date). Deterministic,
///    instant, and — because every field is read straight out of the
///    message by construction — inherently grounded.
/// 2. **On-device model fallback** — when the template pass can't find a
///    confident amount, hand the message to `FoundationModelsSMSExtractor`
///    (Apple Intelligence, on-device only). Its evidence spans are checked
///    back against the message with `TextNormalizer.isGrounded` before
///    anything from it is trusted.
enum BankSMSParser {

    /// Marketing/OTP/reminder phrases that mean "not a transaction" even if
    /// an amount happens to appear nearby (e.g. "your bill of AED 200 is due").
    private static let skipKeywords = [
        "otp", "one time password", "one-time password", "verification code",
        "is your code", "do not share", "reward", "cashback offer", "win ",
        "% off", "discount code", "statement is ready", "e-statement",
        "payment due", "is due on", "reminder:", "declined", "transaction failed",
        "insufficient funds", "was not successful", "unsuccessful",
    ]

    struct Outcome {
        var results: [ParsedBankEmail]
        /// "template" or "on-device model" — read by `SMSIngestService` to
        /// decide auto-approve eligibility and shown in the explanation trail.
        var source: String
    }

    /// `userTemplates` — sender IDs configured per bank in `SMSImportView` —
    /// are consulted ahead of the bundled/remote list; see
    /// `BankSMSTemplateStore.identify`.
    static func parse(rawText: String, senderId: String?, userTemplates: [BankSMSTemplate] = []) async -> Outcome {
        let normalized = TextNormalizer.normalize(rawText).normalized
        let lower = normalized.lowercased()

        guard !skipKeywords.contains(where: { lower.contains($0) }) else {
            return Outcome(results: [], source: "template")
        }

        if let templateResult = parseWithTemplate(normalized, senderId: senderId, userTemplates: userTemplates) {
            return Outcome(results: [templateResult], source: "template")
        }

        guard FoundationModelsSMSExtractor.isAvailable,
              let extraction = try? await FoundationModelsSMSExtractor.extract(normalized)
        else {
            return Outcome(results: [], source: "on-device model")
        }
        let grounded = extraction.transactions.compactMap {
            groundedResult(from: $0, rawText: normalized)
        }
        return Outcome(results: grounded, source: "on-device model")
    }

    // MARK: - Template path (deterministic, reuses BankEmailParser's grammar)

    private static func parseWithTemplate(_ text: String, senderId: String?, userTemplates: [BankSMSTemplate]) -> ParsedBankEmail? {
        guard let (amount, currency, amountMatch) = BankEmailParser.extractAmount(from: text) else { return nil }

        let bank = BankSMSTemplateStore.identify(senderId: senderId, text: text, extraTemplates: userTemplates)
        var lines: [String] = ["Parsed via on-device SMS template"]
        var score = 0.35
        lines.append("Amount \(currency) \(amount) found in “\(amountMatch)”")

        if let bank {
            lines.append("Identified \(bank.bankName) from \(senderId != nil && !senderId!.isEmpty ? "sender id" : "message text")")
            score += 0.2
        } else {
            lines.append("Bank not identified from sender or message text")
        }

        let (direction, directionKeyword) = BankEmailParser.extractDirection(from: text, subject: "")
        if let directionKeyword {
            lines.append("Detected \(direction.rawValue.lowercased()) from “\(directionKeyword)”")
            score += 0.2
        } else {
            lines.append("No debit/credit keyword — assumed \(direction.rawValue.lowercased())")
        }

        let (merchantOpt, merchantPattern) = BankEmailParser.extractMerchant(from: text)
        let merchant = merchantOpt ?? bank?.bankName ?? "Unknown Merchant"
        if let merchantPattern, merchantOpt != nil {
            lines.append("Merchant “\(merchant)” captured after “\(merchantPattern)”")
            score += 0.15
        } else {
            lines.append("No merchant phrase found — using “\(merchant)”")
        }

        let cardLast4 = BankEmailParser.extractCardLast4(from: text)
        if let cardLast4 { lines.append("Card ending \(cardLast4)"); score += 0.1 }

        let (date, dateSource) = BankEmailParser.extractDate(from: text) ?? (Date(), "SMS received time")
        lines.append("Date from \(dateSource)")

        let balance = BankEmailParser.extractBalance(from: text)
        let reference = BankEmailParser.extractReference(from: text)

        var suspicious = false
        var suspiciousReason: String?
        if amount > 100_000 {
            suspicious = true
            suspiciousReason = "Unusually large amount — please verify against the original message"
        } else if merchantOpt == nil && directionKeyword == nil {
            suspicious = true
            suspiciousReason = "Neither merchant nor debit/credit keyword found — parse may be unreliable"
        }
        if suspicious { score = min(score, 0.55) }

        return ParsedBankEmail(
            amount: amount, currency: currency, merchant: merchant, date: date,
            cardLast4: cardLast4, direction: direction, availableBalance: balance,
            referenceNumber: reference, bankName: bank?.bankName ?? "Unknown Bank",
            confidence: min(0.99, score), explanationLines: lines,
            isSuspicious: suspicious, suspiciousReason: suspiciousReason
        )
    }

    // MARK: - On-device model path

    private static func groundedResult(from raw: SMSExtractedTransaction, rawText: String) -> ParsedBankEmail? {
        // Amount and currency are required — without both there's nothing
        // safe to post, grounded or not.
        guard let amount = raw.amount, amount > 0,
              TextNormalizer.isGrounded(raw.amountEvidence, in: rawText)
        else { return nil }
        guard let currencyRaw = raw.currency, ISO4217.isValid(currencyRaw),
              TextNormalizer.isGrounded(raw.currencyEvidence, in: rawText)
        else { return nil }
        let currency = currencyRaw.uppercased()

        var lines = ["Parsed via on-device model (no matching bank template)"]

        var cardLast4 = raw.accountOrCardLast4
        if cardLast4 != nil, !TextNormalizer.isGrounded(raw.last4Evidence, in: rawText) {
            cardLast4 = nil
            lines.append("Dropped last4 — evidence didn't match the message")
        }

        let direction: ParsedDirection = raw.transactionDirection == .credit ? .credit : .debit
        var suspicious = raw.transactionDirection == .unknown
        var suspiciousReason = suspicious ? "The model couldn't tell debit from credit — please confirm" : nil

        var date = Date()
        if let dateString = raw.date, TextNormalizer.isGrounded(raw.datetimeEvidence, in: rawText) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let hasTime = raw.time != nil
            formatter.dateFormat = hasTime ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd"
            let combined = hasTime ? "\(dateString) \(raw.time!)" : dateString
            date = formatter.date(from: combined) ?? Date()
        } else {
            lines.append("No grounded date — using processing time")
        }

        if amount > 100_000 {
            suspicious = true
            suspiciousReason = suspiciousReason ?? "Unusually large amount — please verify against the original message"
        }

        lines.append("Amount \(currency) \(amount)")
        lines.append("Merchant “\(raw.merchant ?? "Unknown")”")
        if let description = raw.transactionDescription { lines.append(description) }

        // Never let a model guess look as trustworthy as a deterministic
        // template match — caps it below the auto-approve/bulk-approve bar
        // regardless of the model's own self-reported confidence.
        let confidence = suspicious ? min(raw.confidence, 0.5) : min(raw.confidence, 0.85)

        return ParsedBankEmail(
            amount: amount, currency: currency,
            merchant: raw.merchant ?? raw.bankName ?? "Unknown Merchant",
            date: date, cardLast4: cardLast4, direction: direction,
            availableBalance: nil, referenceNumber: nil,
            bankName: raw.bankName ?? "Unknown Bank",
            confidence: max(0.05, confidence),
            explanationLines: lines, isSuspicious: suspicious, suspiciousReason: suspiciousReason
        )
    }
}
