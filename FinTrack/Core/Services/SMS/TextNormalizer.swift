import Foundation

/// Result of normalising an incoming message.
///
/// `original` is preserved byte-for-byte. `normalized` is what gets sent to
/// the on-device model and what evidence spans are checked against.
struct NormalizedText {
    let original: String
    let normalized: String
    let wasTruncated: Bool
}

enum TextNormalizer {

    /// Characters that carry no meaning but routinely break span matching:
    /// bidi controls, zero-width joiners, BOM, soft hyphen.
    private static let invisibles: Set<Unicode.Scalar> = [
        "\u{200B}", "\u{200C}", "\u{200D}", "\u{200E}", "\u{200F}",
        "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}",
        "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}",
        "\u{FEFF}", "\u{00AD}"
    ]

    /// Space-like characters folded to U+0020.
    private static let spaceLike: Set<Unicode.Scalar> = [
        "\u{00A0}", "\u{2000}", "\u{2001}", "\u{2002}", "\u{2003}", "\u{2004}",
        "\u{2005}", "\u{2006}", "\u{2007}", "\u{2008}", "\u{2009}", "\u{200A}",
        "\u{202F}", "\u{205F}", "\u{3000}", "\u{2028}", "\u{2029}", "\u{0009}"
    ]

    /// Separators that mean "decimal point" or "thousands mark" in some scripts.
    /// Folding these early means the amount parser only ever sees `.` and `,`.
    private static let separatorMap: [Unicode.Scalar: Character] = [
        "\u{066B}": ".",   // Arabic decimal separator
        "\u{066C}": ",",   // Arabic thousands separator
        "\u{2396}": ".",   // decimal separator key symbol
        "\u{2019}": ",",   // apostrophe used as Swiss grouping mark
        "\u{02BC}": ","
    ]

    /// Keeps the message intact but removes anything that only adds noise.
    /// Newlines survive — they are the main structural signal for multi-line
    /// messages.
    static func normalize(_ input: String, maxCharacters: Int = 4_000) -> NormalizedText {
        // NFKC folds fullwidth forms, ligatures, and compatibility variants.
        let composed = input.precomposedStringWithCompatibilityMapping

        var out = String()
        out.reserveCapacity(composed.count)

        for scalar in composed.unicodeScalars {
            if invisibles.contains(scalar) { continue }
            if spaceLike.contains(scalar) { out.append(" "); continue }
            if let mapped = separatorMap[scalar] { out.append(mapped); continue }
            if let digit = asciiDigit(for: scalar) { out.append(digit); continue }
            out.unicodeScalars.append(scalar)
        }

        out = collapseHorizontalWhitespace(out)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var truncated = false
        if out.count > maxCharacters {
            out = headAndTail(out, budget: maxCharacters)
            truncated = true
        }

        return NormalizedText(original: input, normalized: out, wasTruncated: truncated)
    }

    /// Maps any Unicode decimal digit to its ASCII equivalent, using Unicode's
    /// own numeric properties rather than a hardcoded list of scripts. Eastern
    /// Arabic, Persian, Devanagari, Bengali, Thai, and every other decimal
    /// digit system is covered automatically.
    private static func asciiDigit(for scalar: Unicode.Scalar) -> Character? {
        guard scalar.properties.numericType == .decimal,
              let value = scalar.properties.numericValue,
              let digit = Int(exactly: value), (0...9).contains(digit)
        else { return nil }
        return Character(String(digit))
    }

    private static func collapseHorizontalWhitespace(_ s: String) -> String {
        var out = String()
        out.reserveCapacity(s.count)
        var lastWasSpace = false
        for ch in s {
            if ch == " " {
                if !lastWasSpace { out.append(ch) }
                lastWasSpace = true
            } else {
                lastWasSpace = false
                out.append(ch)
            }
        }
        return out
    }

    /// Very long inputs (forwarded threads) keep their head and tail — the
    /// transaction is almost always in one of the two.
    private static func headAndTail(_ s: String, budget: Int) -> String {
        let headCount = Int(Double(budget) * 0.7)
        let tailCount = budget - headCount
        let head = String(s.prefix(headCount))
        let tail = String(s.suffix(tailCount))
        return head + "\n[…]\n" + tail
    }

    // MARK: - Grounding comparison

    /// Aggressive fold used only to test whether an evidence span really came
    /// from the message. Removes everything a model might legitimately render
    /// differently — case, spacing, mask characters, sign glyphs — while
    /// keeping digits and letters.
    static func foldForComparison(_ s: String) -> String {
        let normalized = normalize(s, maxCharacters: .max).normalized
        var out = String()
        out.reserveCapacity(normalized.count)
        for ch in normalized.lowercased() where ch.isLetter || ch.isNumber {
            out.append(ch)
        }
        return out
    }

    /// True when `evidence` plausibly appears inside `haystack`.
    static func isGrounded(_ evidence: String?, in haystack: String) -> Bool {
        guard let evidence, !evidence.isEmpty else { return false }
        let needle = foldForComparison(evidence)
        guard !needle.isEmpty else { return false }
        return foldForComparison(haystack).contains(needle)
    }
}
