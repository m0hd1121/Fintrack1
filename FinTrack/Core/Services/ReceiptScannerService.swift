import Foundation
import Vision
import UIKit
import Observation

// MARK: – Observable service

@Observable
@MainActor
final class ReceiptScannerService {
    static let shared = ReceiptScannerService()
    private init() {}

    var isScanning = false
    var scanResult: ScannedReceiptData?
    var errorMessage: String?

    private let detector = ReceiptDocumentDetector()

    // MARK: – Public API (unchanged call-site)

    func scanReceipt(image: UIImage) async {
        isScanning = true
        defer { isScanning = false }
        scanResult = nil
        errorMessage = nil

        // Step 1–2: Detect receipt quad, warp + preprocess
        let detected = await detector.detect(in: image)
        let workingImage = detected.image

        guard let cgImage = workingImage.cgImage else {
            errorMessage = "Invalid image"
            return
        }

        // Step 3: OCR — collect every observation with its per-line confidence
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        // Arabic, Persian, English — the order is the priority hint for the engine
        textRequest.recognitionLanguages = ["ar-SA", "fa-IR", "en-US"]
        textRequest.minimumTextHeight = 0.008   // ignore tiny noise marks
        textRequest.customWords = customDictionaryWords()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([textRequest])
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            return
        }

        guard let observations = textRequest.results, !observations.isEmpty else {
            errorMessage = "No text found in the image"
            return
        }

        // Build a parallel list of (text, ocrConfidence) preserving reading order
        let annotated: [(text: String, confidence: Float)] = observations.compactMap { obs in
            guard let top = obs.topCandidates(1).first else { return nil }
            return (top.string, top.confidence)
        }

        let fullText = annotated.map { $0.text }.joined(separator: "\n")

        // Steps 4–6: Extract structured data
        var result = extractStructuredData(from: annotated, fullText: fullText)
        result.ocrText = fullText
        result.wasReceiptDetected = detected.wasReceiptDetected
        result.success = result.totalAmount != nil || result.merchant != nil

        // AI-assisted category suggestion
        if let merchant = result.merchant {
            result.suggestedCategory = AICategorizationService.shared.suggestCategory(
                for: merchant, amount: result.totalAmount ?? 0, type: .expense
            )
        }

        scanResult = result
    }

    // MARK: – Step 4: Structured extraction with confidence

    private func extractStructuredData(
        from annotated: [(text: String, confidence: Float)],
        fullText: String
    ) -> ScannedReceiptData {
        var data = ScannedReceiptData()

        let lines = annotated.map { $0.text }

        // --- Total amount ---
        let (total, totalConf) = extractTotal(from: annotated)
        data.totalAmount     = total
        data.totalConfidence = totalConf

        // --- VAT ---
        data.vatAmount = extractVAT(from: annotated)

        // --- Date ---
        let (date, dateConf) = extractDate(from: annotated, fullText: fullText)
        data.date           = date
        data.dateConfidence = dateConf

        // --- Currency ---
        data.currency = detectCurrency(in: fullText)

        // --- Payment method ---
        data.paymentMethod = detectPaymentMethod(in: fullText)

        // --- Merchant ---
        let (merchant, merchantConf) = extractMerchant(from: annotated)
        data.merchant           = merchant
        data.merchantConfidence = merchantConf

        _ = lines   // suppress unused warning
        return data
    }

    // MARK: – Total extraction (Steps 4 + 6)

    private struct TotalCandidate {
        let amount: Double
        let priority: Int       // 3 = grand total, 2 = net/payable, 1 = total
        let ocrConfidence: Float
        var score: Double { Double(priority) * Double(ocrConfidence) * (amount > 0 ? 1 : 0) }
    }

    private func extractTotal(
        from annotated: [(text: String, confidence: Float)]
    ) -> (Double?, Float) {

        // Ranked keyword table — higher priority wins over plain "total"
        let keywords: [(pattern: String, priority: Int)] = [
            ("grand total",      3), ("المجموع الكلي",  3),
            ("amount due",       3), ("balance due",    3),
            ("net total",        3), ("total due",      3),
            ("amount payable",   3), ("total payable",  3),
            ("net payable",      2), ("net amount",     2),
            ("المجموع",          2), ("الإجمالي",       2),
            ("total",            1), ("amount",         1),
        ]

        // Lines to skip — they look like totals but are not the final payment
        let exclusions = [
            "subtotal", "sub total", "sub-total",
            "discount", "saving", "coupon", "offer",
            "vat", "tax", "service charge", "tip", "gratuity",
            "cashback", "cash back", "refund",
        ]

        var candidates: [TotalCandidate] = []

        for (line, confidence) in annotated {
            let lower = line.lowercased()
            if exclusions.contains(where: { lower.contains($0) }) { continue }

            for (kw, priority) in keywords {
                if lower.contains(kw) {
                    if let amount = extractRightmostAmount(from: line), amount > 0 {
                        candidates.append(TotalCandidate(
                            amount: amount, priority: priority, ocrConfidence: confidence
                        ))
                    }
                    break   // one keyword match per line is enough
                }
            }
        }

        // Pick the highest-scoring candidate
        if let best = candidates.max(by: { $0.score < $1.score }) {
            return (best.amount, best.ocrConfidence * Float(best.priority) / 3.0)
        }

        // Fallback: scan bottom 30 % of receipt for the largest decimal amount
        // This handles minimalist receipts with no explicit "total" label.
        let bottomSlice = Array(annotated.suffix(max(annotated.count / 3, 6)))
        var fallbackCandidates: [(amount: Double, conf: Float)] = []
        for (line, conf) in bottomSlice {
            if let amount = extractDecimalAmount(from: line), amount > 0 {
                fallbackCandidates.append((amount, conf))
            }
        }

        if let best = fallbackCandidates.max(by: { $0.amount < $1.amount }) {
            // Fallback confidence is capped at 0.70 — we're guessing
            return (best.amount, min(best.conf * 0.70, 0.70))
        }

        return (nil, 0)
    }

    // MARK: – VAT extraction

    private func extractVAT(from annotated: [(text: String, confidence: Float)]) -> Double? {
        let vatKeywords = ["vat", "tax", "ضريبة", "vat 5%", "vat amount", "tax amount"]
        for (line, _) in annotated {
            let lower = line.lowercased()
            if vatKeywords.contains(where: { lower.contains($0) }) {
                return extractRightmostAmount(from: line)
            }
        }
        return nil
    }

    // MARK: – Date extraction (Step 4)

    private func extractDate(
        from annotated: [(text: String, confidence: Float)],
        fullText: String
    ) -> (Date?, Float) {

        // Ordered by specificity — try unambiguous formats first
        let strategies: [(pattern: String, formats: [String])] = [
            // ISO
            (#"\b\d{4}[-/]\d{2}[-/]\d{2}\b"#,             ["yyyy-MM-dd", "yyyy/MM/dd"]),
            // Day Month Year (European)
            (#"\b\d{1,2}[./-]\d{1,2}[./-]\d{4}\b"#,       ["dd/MM/yyyy", "dd.MM.yyyy", "dd-MM-yyyy",
                                                              "MM/dd/yyyy", "MM.dd.yyyy", "MM-dd-yyyy"]),
            // Named month — "14 Jun 2025" or "Jun 14 2025"
            (#"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b"#,     ["dd MMM yyyy", "dd MMMM yyyy"]),
            (#"\b[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}\b"#,   ["MMM dd yyyy", "MMM dd, yyyy",
                                                              "MMMM dd yyyy", "MMMM dd, yyyy"]),
            // Persian / Hijri numeric — basic detection, treated as approximate
            (#"\b\d{4}[/]\d{1,2}[/]\d{1,2}\b"#,            ["yyyy/MM/dd"]),
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for (line, confidence) in annotated {
            for (pattern, formats) in strategies {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                      let range = Range(match.range, in: line) else { continue }

                let candidate = String(line[range])
                    .replacingOccurrences(of: "/", with: "/")   // normalise separators
                    .trimmingCharacters(in: .whitespaces)

                for fmt in formats {
                    formatter.dateFormat = fmt
                    if let date = formatter.date(from: candidate) {
                        // Sanity check — reject obviously wrong years
                        let year = Calendar.current.component(.year, from: date)
                        if year < 2000 || year > 2100 { continue }
                        return (date, confidence * 0.95)
                    }
                }
            }
        }

        return (nil, 0)
    }

    // MARK: – Merchant extraction (Step 4)

    private func extractMerchant(
        from annotated: [(text: String, confidence: Float)]
    ) -> (String?, Float) {

        // Strategy 1: explicit label
        let explicitLabels = [
            "merchant:", "store:", "shop:", "outlet:", "sold by:",
            "retailer:", "vendor:", "المتجر:", "التاجر:"
        ]
        for (line, conf) in annotated {
            let lower = line.lowercased()
            for label in explicitLabels {
                if lower.hasPrefix(label) {
                    let name = String(line.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { return (name, min(conf, 0.99)) }
                }
            }
        }

        // Strategy 2: scan the top 12 lines for the most prominent non-metadata line
        // These are patterns that appear on receipts but are NOT the merchant name
        let skipPatterns: Set<String> = [
            "receipt", "invoice", "tax invoice", "vat invoice", "fiscal receipt",
            "payment receipt", "customer copy", "duplicate", "copy",
            "vat", "tel", "phone", "mobile", "mob", "fax",
            "www.", "http", ".com", ".ae", ".co",
            "p.o. box", "po box", "email", "e-mail",
            "ref:", "reference", "date:", "time:", "order",
            "transaction", "no.", "#", "reg no", "cr no",
            "thank you", "thanks for", "welcome", "please come again",
            "cash", "card", "debit", "credit", "visa", "mastercard", "amex",
            "change:", "subtotal", "total", "amount", "paid", "price",
            "qty", "item", "quantity", "unit", "discount", "vat no",
            "trn:", "trnno", "terminal", "pos id", "batch",
        ]
        let addressIndicators: Set<String> = [
            "road", "street", "st.", "avenue", "ave", "blvd", "boulevard",
            "building", "tower", "floor", "suite", "shop no",
            "dubai", "abu dhabi", "sharjah", "ajman", "uae",
            "riyadh", "jeddah", "saudi", "doha", "qatar",
            "p.o", "near", "behind", "opposite",
        ]

        let topLines = Array(annotated.prefix(12))
        var bestLine: (text: String, confidence: Float)? = nil

        for (line, conf) in topLines {
            guard line.count >= 3 else { continue }
            let lower = line.lowercased()

            if skipPatterns.contains(where: { lower.contains($0) }) { continue }
            if addressIndicators.contains(where: { lower.contains($0) }) { continue }

            // Skip pure-number lines (dates, transaction IDs)
            let letterCount = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            if letterCount < 2 { continue }

            // Skip lines that look like phone numbers (7+ consecutive digits)
            let digitCount = line.filter { $0.isNumber }.count
            if digitCount > 7 && letterCount < 3 { continue }

            // Skip lines that look like a lone amount
            if extractDecimalAmount(from: line) != nil && letterCount < 3 { continue }

            // Accept the first qualifying line — it's almost always the merchant header
            if bestLine == nil {
                bestLine = (line.trimmingCharacters(in: .whitespacesAndNewlines), conf)
            }
        }

        if let found = bestLine {
            return (found.text, found.confidence * 0.92)
        }

        return (nil, 0)
    }

    // MARK: – Currency detection

    private func detectCurrency(in text: String) -> String {
        let lower = text.lowercased()
        // Ranked by specificity — more specific patterns first
        if lower.contains("aed") || lower.contains("د.إ") || lower.contains("درهم") { return "AED" }
        if lower.contains("sar") || lower.contains("ريال") { return "SAR" }
        if lower.contains("qar") { return "QAR" }
        if lower.contains("usd") || lower.contains("dollar") { return "USD" }
        if lower.contains("eur") || lower.contains("euro")   { return "EUR" }
        if lower.contains("gbp") || lower.contains("pound")  { return "GBP" }
        if lower.contains("irr") || lower.contains("تومان")  { return "IRR" }
        return "AED"    // UAE default
    }

    // MARK: – Payment method detection

    private func detectPaymentMethod(in text: String) -> PaymentMethod {
        let lower = text.lowercased()
        if lower.contains("apple pay")                                     { return .applePay }
        if lower.contains("visa") || lower.contains("mastercard") ||
           lower.contains("amex") || lower.contains("credit card")         { return .creditCard }
        if lower.contains("debit")                                         { return .debitCard }
        if lower.contains("mada") || lower.contains("tap to pay")          { return .debitCard }
        return .cash
    }

    // MARK: – Amount helpers

    /// Returns the rightmost monetary value on a line.
    /// Handles: 1,234.56 · 1234.56 · 1234 · ١٢٣٤.٥٦ (Arabic-Indic digits)
    private func extractRightmostAmount(from text: String) -> Double? {
        let normalised = normaliseDigits(stripCurrencySymbols(from: text))
        let pattern = #"\d{1,3}(?:,\d{3})*(?:\.\d{1,3})?|\d+(?:\.\d{1,3})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = normalised as NSString
        let matches = regex.matches(in: normalised, range: NSRange(location: 0, length: ns.length))
        guard let last = matches.last, let range = Range(last.range, in: normalised) else { return nil }
        let raw = normalised[range].replacingOccurrences(of: ",", with: "")
        return Double(raw)
    }

    /// Like extractRightmostAmount but requires a decimal point — avoids
    /// mistaking item counts (qty "3") for monetary amounts.
    private func extractDecimalAmount(from text: String) -> Double? {
        let normalised = normaliseDigits(stripCurrencySymbols(from: text))
        let pattern = #"\d{1,3}(?:,\d{3})*\.\d{1,3}|\d+\.\d{1,3}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = normalised as NSString
        let matches = regex.matches(in: normalised, range: NSRange(location: 0, length: ns.length))
        guard let last = matches.last, let range = Range(last.range, in: normalised) else { return nil }
        let raw = normalised[range].replacingOccurrences(of: ",", with: "")
        return Double(raw)
    }

    /// Replace Arabic-Indic / Persian digits (٠١٢٣٤٥٦٧٨٩ / ۰۱۲۳۴۵۶۷۸۹)
    /// with their ASCII equivalents so standard regex can parse them.
    private func normaliseDigits(_ s: String) -> String {
        var out = s
        let arabicIndic: [Character: Character] = [
            "٠":"0","١":"1","٢":"2","٣":"3","٤":"4","٥":"5","٦":"6","٧":"7","٨":"8","٩":"9",
            "۰":"0","۱":"1","۲":"2","۳":"3","۴":"4","۵":"5","۶":"6","۷":"7","۸":"8","۹":"9",
        ]
        out = String(out.map { arabicIndic[$0] ?? $0 })
        return out
    }

    private func stripCurrencySymbols(from text: String) -> String {
        text
            .replacingOccurrences(of: "AED", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "USD", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "SAR", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "EUR", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "GBP", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "QAR", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "IRR", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "$",   with: " ")
            .replacingOccurrences(of: "د.إ", with: " ")
            .replacingOccurrences(of: "﷼",   with: " ")
            .replacingOccurrences(of: "€",   with: " ")
            .replacingOccurrences(of: "£",   with: " ")
    }

    // MARK: – Custom vocabulary

    /// Domain words that the language-correction model may otherwise mangle.
    private func customDictionaryWords() -> [String] {
        [
            "VAT", "AED", "SAR", "QAR", "TRN", "IBAN",
            "Carrefour", "Lulu", "Spinneys", "Waitrose", "Choithrams",
            "Emirates", "Etisalat", "Du", "ADNOC", "DEWA", "SEWA",
            "Talabat", "Noon", "Amazon", "Namshi",
            "Grand Total", "Net Total", "Sub Total", "Amount Due",
            "Tabby", "Tamara", "Postpay",
        ]
    }
}

// MARK: – Data model (Steps 5 + 9)

/// Confidence threshold below which a field should be flagged for user review.
let receiptConfidenceThreshold: Float = 0.85

struct ScannedReceiptData {
    // Extracted fields
    var merchant: String?
    var merchantConfidence: Float = 0

    var totalAmount: Double?
    var totalConfidence: Float = 0

    var vatAmount: Double?

    var currency: String = "AED"

    var date: Date?
    var dateConfidence: Float = 0

    // Pipeline metadata
    var ocrText: String = ""
    var wasReceiptDetected: Bool = false
    var success: Bool = false

    // App integration
    var paymentMethod: PaymentMethod = .cash
    var suggestedCategory: TransactionCategory = .other

    // MARK: – Confidence helpers

    var merchantNeedsReview: Bool { merchant != nil && merchantConfidence < receiptConfidenceThreshold }
    var totalNeedsReview: Bool    { totalAmount != nil && totalConfidence < receiptConfidenceThreshold }
    var dateNeedsReview: Bool     { date != nil && dateConfidence < receiptConfidenceThreshold }
}
