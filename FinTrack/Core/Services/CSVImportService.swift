import Foundation

// MARK: - Column Mapping

struct CSVColumnMapping {
    var dateColumn:     String?
    var titleColumn:    String?
    var amountColumn:   String?
    var categoryColumn: String?
    var merchantColumn: String?
    var notesColumn:    String?
    var currencyColumn: String?
    var typeColumn:     String?
    var tagsColumn:     String?

    var dateFormat:      String = "yyyy-MM-dd"
    var currencyDefault: String = "AED"
    var typeDefault:     TransactionType = .expense

    /// Returns true when the minimum required columns are mapped.
    var isValid: Bool {
        titleColumn != nil && amountColumn != nil && dateColumn != nil
    }
}

// MARK: - Import Result

struct CSVImportRow: Identifiable {
    let id = UUID()
    var title:    String
    var amount:   Double
    var date:     Date
    var category: TransactionCategory
    var merchant: String?
    var notes:    String?
    var currency: String
    var type:     TransactionType
    var tags:     [String]
    var isDuplicate: Bool = false
    var parseWarning: String? = nil
}

struct CSVImportResult {
    var rows:         [CSVImportRow]
    var skippedCount: Int
    var headers:      [String]

    var validRows:    [CSVImportRow] { rows.filter { !$0.isDuplicate } }
    var duplicates:   [CSVImportRow] { rows.filter { $0.isDuplicate } }
}

// MARK: - Service

final class CSVImportService {
    static let shared = CSVImportService()
    private init() {}

    // MARK: Parsing

    /// Parses raw CSV data into a header row and value rows.
    func parseCSV(data: Data, delimiter: Character? = nil) -> (headers: [String], rows: [[String: String]]) {
        guard let text = String(data: data, encoding: .utf8) ??
                         String(data: data, encoding: .isoLatin1) else {
            return ([], [])
        }

        let sep = delimiter ?? detectDelimiter(in: text)
        let lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else { return ([], []) }

        let headers = parseCSVLine(lines[0], separator: sep)
        var rows: [[String: String]] = []

        for line in lines.dropFirst() {
            let values = parseCSVLine(line, separator: sep)
            var row: [String: String] = [:]
            for (i, header) in headers.enumerated() {
                row[header] = i < values.count ? values[i] : ""
            }
            rows.append(row)
        }

        return (headers, rows)
    }

    /// Auto-detects the delimiter by counting occurrences in the first line.
    func detectDelimiter(in text: String) -> Character {
        let firstLine = text.components(separatedBy: "\n").first ?? ""
        let candidates: [(Character, Int)] = [
            (",", firstLine.filter { $0 == "," }.count),
            (";", firstLine.filter { $0 == ";" }.count),
            ("\t", firstLine.filter { $0 == "\t" }.count),
            ("|", firstLine.filter { $0 == "|" }.count),
        ]
        return candidates.max(by: { $0.1 < $1.1 })?.0 ?? ","
    }

    /// Parses a single CSV line respecting quoted fields.
    private func parseCSVLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == separator && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }

    // MARK: Date Format Detection

    /// Attempts to auto-detect the date format from a sample of date strings.
    func detectDateFormat(samples: [String]) -> String {
        let candidates = [
            "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy",
            "dd-MM-yyyy", "MM-dd-yyyy", "d MMM yyyy",
            "dd MMM yyyy", "yyyy/MM/dd", "d/M/yyyy",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in candidates {
            formatter.dateFormat = format
            let successes = samples.prefix(5).filter { formatter.date(from: $0) != nil }
            if successes.count >= min(3, samples.count) { return format }
        }
        return "yyyy-MM-dd"
    }

    // MARK: Row Mapping

    /// Converts raw CSV rows into typed ImportRows using the column mapping.
    func mapRows(
        _ rows: [[String: String]],
        mapping: CSVColumnMapping,
        existingTransactions: [Transaction] = [],
        rules: [CategorizationRule] = []
    ) -> [CSVImportRow] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = mapping.dateFormat

        var result: [CSVImportRow] = []

        for row in rows {
            guard let titleCol = mapping.titleColumn,
                  let amountCol = mapping.amountColumn,
                  let dateCol = mapping.dateColumn else { continue }

            let title = row[titleCol]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { continue }

            let amountStr = row[amountCol]?
                .replacingOccurrences(of: "[^0-9.\\-]", with: "", options: .regularExpression)
                ?? ""
            guard let amount = Double(amountStr), amount != 0 else { continue }

            let dateStr = row[dateCol]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let date = dateFormatter.date(from: dateStr) else { continue }

            let currency = mapping.currencyColumn.flatMap { row[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? mapping.currencyDefault

            let typeStr = mapping.typeColumn.flatMap { row[$0] }?.lowercased() ?? ""
            var txType = mapping.typeDefault
            if typeStr.contains("income") || typeStr.contains("credit") || typeStr.contains("deposit") {
                txType = .income
            } else if typeStr.contains("expense") || typeStr.contains("debit") || typeStr.contains("withdrawal") {
                txType = .expense
            }
            // Negative amounts typically imply expenses when type column is absent
            if mapping.typeColumn == nil && amount < 0 { txType = .expense }
            let finalAmount = abs(amount)

            let merchant = mapping.merchantColumn.flatMap { row[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes    = mapping.notesColumn.flatMap { row[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)

            let category = AICategorizationService.shared.predictCategory(
                for: merchant ?? title, merchant: merchant,
                amount: finalAmount, type: txType, rules: rules
            ).category

            let tagsStr = mapping.tagsColumn.flatMap { row[$0] } ?? ""
            let tags = tagsStr.components(separatedBy: CharacterSet(charactersIn: ";,|"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            // Duplicate detection against existing transactions
            let key = "\(title.lowercased())_\(Int(finalAmount))_\(Calendar.current.startOfDay(for: date))"
            let isDuplicate = existingTransactions.contains { tx in
                let txKey = "\(tx.title.lowercased())_\(Int(tx.amount))_\(Calendar.current.startOfDay(for: tx.date))"
                return txKey == key
            }

            var importRow = CSVImportRow(
                title: title, amount: finalAmount, date: date,
                category: category, merchant: merchant.nilIfEmpty,
                notes: notes.nilIfEmpty, currency: currency,
                type: txType, tags: tags
            )
            importRow.isDuplicate = isDuplicate
            result.append(importRow)
        }
        return result
    }

    // MARK: Suggested Column Mapping

    /// Suggests a column mapping based on common header names.
    func suggestMapping(for headers: [String]) -> CSVColumnMapping {
        var m = CSVColumnMapping()
        let lower = headers.map { $0.lowercased() }

        let dateKeywords:     [String] = ["date", "transaction date", "posting date", "value date"]
        let titleKeywords:    [String] = ["title", "description", "narrative", "detail", "memo", "particulars"]
        let amountKeywords:   [String] = ["amount", "debit", "credit", "value", "sum", "transaction amount"]
        let categoryKeywords: [String] = ["category", "type", "expense type"]
        let merchantKeywords: [String] = ["merchant", "payee", "vendor", "counterparty", "beneficiary"]
        let notesKeywords:    [String] = ["notes", "note", "remarks", "comment"]
        let currencyKeywords: [String] = ["currency", "ccy", "cur"]
        let typeKeywords:     [String] = ["type", "transaction type", "dr/cr"]
        let tagsKeywords:     [String] = ["tags", "labels"]

        m.dateColumn     = bestMatch(from: dateKeywords,     in: lower, headers: headers)
        m.titleColumn    = bestMatch(from: titleKeywords,    in: lower, headers: headers)
        m.amountColumn   = bestMatch(from: amountKeywords,   in: lower, headers: headers)
        m.categoryColumn = bestMatch(from: categoryKeywords, in: lower, headers: headers)
        m.merchantColumn = bestMatch(from: merchantKeywords, in: lower, headers: headers)
        m.notesColumn    = bestMatch(from: notesKeywords,    in: lower, headers: headers)
        m.currencyColumn = bestMatch(from: currencyKeywords, in: lower, headers: headers)
        m.typeColumn     = bestMatch(from: typeKeywords,     in: lower, headers: headers)
        m.tagsColumn     = bestMatch(from: tagsKeywords,     in: lower, headers: headers)
        return m
    }

    private func bestMatch(from keywords: [String], in lower: [String], headers: [String]) -> String? {
        for kw in keywords {
            if let idx = lower.firstIndex(where: { $0.contains(kw) }) {
                return headers[idx]
            }
        }
        return nil
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
