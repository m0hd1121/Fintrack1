import Foundation

/// Parses bank statement export files (OFX / QFX / QIF) into
/// `ParsedTransactionItem`s. Pure value code with no UI or SwiftData access.
///
/// - OFX and QFX are the same SGML/XML format (QFX is Quicken's branded OFX):
///   one `<STMTTRN>` block per transaction with `TRNTYPE`, `DTPOSTED`, signed
///   `TRNAMT`, `NAME`/`MEMO`, and the statement currency in `<CURDEF>`.
/// - QIF is line based: `D` date, `T`/`U` signed amount, `P` payee, `M` memo,
///   `^` ends a record.
///
/// Amounts are returned positive; the sign decides `transactionType`.
nonisolated enum StatementFileParser {

    enum ParseError: LocalizedError {
        case unreadable
        case noTransactions

        var errorDescription: String? {
            switch self {
            case .unreadable:     return "The file couldn't be read as text."
            case .noTransactions: return "No transactions were found in this file."
            }
        }
    }

    static func parse(data: Data, fileType: ImportFileType, defaultCurrency: String) throws -> [ParsedTransactionItem] {
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else { throw ParseError.unreadable }
        let items: [ParsedTransactionItem]
        switch fileType {
        case .qif: items = parseQIF(text, currency: defaultCurrency)
        default:   items = parseOFX(text, defaultCurrency: defaultCurrency)
        }
        guard !items.isEmpty else { throw ParseError.noTransactions }
        return items
    }

    // MARK: - OFX / QFX

    static func parseOFX(_ text: String, defaultCurrency: String) -> [ParsedTransactionItem] {
        let currency = tagValue("CURDEF", in: text)?.uppercased() ?? defaultCurrency
        var items: [ParsedTransactionItem] = []
        var searchRange = text.startIndex..<text.endIndex
        while let open = text.range(of: "<STMTTRN>", options: .caseInsensitive, range: searchRange) {
            let blockEnd = text.range(of: "</STMTTRN>", options: .caseInsensitive,
                                      range: open.upperBound..<text.endIndex)
            // SGML OFX may omit closing tags; fall back to the next opening tag.
            let nextOpen = text.range(of: "<STMTTRN>", options: .caseInsensitive,
                                      range: open.upperBound..<text.endIndex)
            let end = blockEnd?.lowerBound ?? nextOpen?.lowerBound ?? text.endIndex
            let block = String(text[open.upperBound..<end])
            searchRange = (blockEnd?.upperBound ?? end)..<text.endIndex

            guard let amountText = tagValue("TRNAMT", in: block),
                  let signed = Double(amountText.replacingOccurrences(of: ",", with: ".")),
                  signed != 0,
                  let dateText = tagValue("DTPOSTED", in: block),
                  let date = ofxDate(dateText) else { continue }
            let name = tagValue("NAME", in: block) ?? tagValue("PAYEE", in: block)
            let memo = tagValue("MEMO", in: block)
            let title = (name?.isEmpty == false ? name : memo) ?? "Imported transaction"
            var item = ParsedTransactionItem(
                date: date,
                description: decodeEntities(title),
                amount: abs(signed),
                currency: currency,
                transactionType: signed < 0 ? "expense" : "income"
            )
            if let memo, memo != title { item.notes = decodeEntities(memo) }
            items.append(item)
        }
        return items
    }

    /// Value of an OFX element, for both `<TAG>value</TAG>` and SGML `<TAG>value`.
    private static func tagValue(_ tag: String, in text: String) -> String? {
        guard let open = text.range(of: "<\(tag)>", options: .caseInsensitive) else { return nil }
        let rest = text[open.upperBound...]
        let stop = rest.firstIndex(where: { $0 == "<" || $0 == "\n" || $0 == "\r" }) ?? rest.endIndex
        let value = rest[..<stop].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// OFX dates: `YYYYMMDD[HHMMSS[.XXX]][[+|-]TZ[:name]]` — only the date part matters here.
    private static func ofxDate(_ text: String) -> Date? {
        let digits = text.prefix { $0.isNumber }
        guard digits.count >= 8,
              let year = Int(digits.prefix(4)),
              let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.dropFirst(6).prefix(2)) else { return nil }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }

    private static func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    // MARK: - QIF

    static func parseQIF(_ text: String, currency: String) -> [ParsedTransactionItem] {
        var items: [ParsedTransactionItem] = []
        var date: Date?
        var amount: Double?
        var payee: String?
        var memo: String?

        func flush() {
            if let date, let amount, amount != 0 {
                let title = (payee?.isEmpty == false ? payee : memo) ?? "Imported transaction"
                var item = ParsedTransactionItem(date: date, description: title, amount: abs(amount),
                                                 currency: currency,
                                                 transactionType: amount < 0 ? "expense" : "income")
                if let memo, memo != title { item.notes = memo }
                items.append(item)
            }
            date = nil; amount = nil; payee = nil; memo = nil
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let code = line.first else { continue }
            let value = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            switch code {
            case "!": continue                       // header, e.g. "!Type:Bank"
            case "D": date = qifDate(value)
            case "T", "U": amount = Double(value.replacingOccurrences(of: ",", with: ""))
            case "P": payee = value
            case "M": memo = value
            case "^": flush()
            default: continue
            }
        }
        flush()
        return items
    }

    /// QIF dates come as `M/D/YY`, `M/D'YY`, `M/D/YYYY`, `D/M/YYYY` or `YYYY-MM-DD`.
    /// Month-first is the Quicken default; a first part above 12 means day-first.
    private static func qifDate(_ text: String) -> Date? {
        let cleaned = text.replacingOccurrences(of: "'", with: "/").replacingOccurrences(of: " ", with: "")
        let parts = cleaned.split(whereSeparator: { $0 == "/" || $0 == "-" || $0 == "." }).compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var year: Int, month: Int, day: Int
        if parts[0] > 31 {                       // YYYY-MM-DD
            (year, month, day) = (parts[0], parts[1], parts[2])
        } else if parts[0] > 12 {                // D/M/Y
            (day, month, year) = (parts[0], parts[1], parts[2])
        } else {                                 // M/D/Y
            (month, day, year) = (parts[0], parts[1], parts[2])
        }
        if year < 100 { year += year < 70 ? 2000 : 1900 }
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }
}
