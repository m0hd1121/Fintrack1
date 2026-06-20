import SwiftUI

/// A TextField that automatically formats numeric input with thousands separators.
/// Bind to a `String` state var — the string stores digits + optional decimal,
/// commas are inserted/removed automatically as the user types.
///
/// Usage:
///   @State private var amount = ""
///   AmountTextField("0.00", text: $amount)
///
/// To read the double value:
///   Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0
struct AmountTextField: View {
    let placeholder: String
    @Binding var text: String
    var alignment: TextAlignment = .trailing
    var font: Font = .body

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(alignment)
            .font(font)
            .onChange(of: text) { _, newValue in
                let formatted = Self.format(newValue)
                if formatted != newValue { text = formatted }
            }
    }

    // MARK: – Formatting

    static func format(_ input: String) -> String {
        // Only keep digits, one dot, and strip everything else
        var cleaned = ""
        var hasDot = false
        for ch in input {
            if ch.isNumber {
                cleaned.append(ch)
            } else if ch == "." && !hasDot {
                hasDot = true
                cleaned.append(ch)
            } else if ch == "," {
                // ignore — will re-insert
            }
        }

        // Split into integer and decimal parts
        let parts = cleaned.components(separatedBy: ".")
        let integerPart = parts[0]
        let decimalPart = parts.count > 1 ? parts[1] : nil

        // Apply grouping to integer part
        let grouped = groupDigits(integerPart)

        // Reassemble
        if let dec = decimalPart {
            return grouped + "." + dec
        }
        return grouped
    }

    private static func groupDigits(_ digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        // Insert commas every 3 digits from the right
        var result = ""
        var count = 0
        for ch in digits.reversed() {
            if count > 0 && count % 3 == 0 { result.insert(",", at: result.startIndex) }
            result.insert(ch, at: result.startIndex)
            count += 1
        }
        return result
    }

    /// Parse the formatted string back to Double
    static func double(from text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    /// Produce a formatted display string from a Double (for pre-filling)
    static func string(from value: Double) -> String {
        if value == 0 { return "" }
        // Show up to 2 decimal places, strip trailing zeros
        let raw = String(format: "%g", value)
        return format(raw)
    }
}

// MARK: – Convenience init with label

extension AmountTextField {
    init(_ placeholder: String, text: Binding<String>, alignment: TextAlignment = .trailing) {
        self.placeholder = placeholder
        self._text = text
        self.alignment = alignment
    }
}
