import Foundation
import SwiftUI

/// Cached formatters to avoid the 1-5ms cost of allocating a new
/// DateFormatter/NumberFormatter on every call (these helpers run for
/// every row in every list).
///
/// NOTE: Formatting happens during SwiftUI view rendering on the main
/// thread, so the mutable currency-formatter cache below is intentionally
/// main-thread-only and unsynchronized.
private enum CachedFormatters {
    static let monthName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let shortMonthName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    static let dayNumber: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    // Main-thread-only cache (see note above): one NumberFormatter per currency code.
    static var currency: [String: NumberFormatter] = [:]

    static func currencyFormatter(for code: String) -> NumberFormatter {
        if let cached = currency[code] { return cached }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        currency[code] = formatter
        return formatter
    }
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.dateInterval(of: .month, for: self)?.start ?? self
    }

    var endOfMonth: Date {
        let start = startOfMonth
        return Calendar.current.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? self
    }

    var startOfYear: Date {
        Calendar.current.dateInterval(of: .year, for: self)?.start ?? self
    }

    var startOfWeek: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: self)?.start ?? self
    }

    var monthName: String {
        CachedFormatters.monthName.string(from: self)
    }

    var shortMonthName: String {
        CachedFormatters.shortMonthName.string(from: self)
    }

    var dayNumber: String {
        CachedFormatters.dayNumber.string(from: self)
    }

    var formatted: String {
        CachedFormatters.mediumDate.string(from: self)
    }

    var relativeFormatted: String {
        CachedFormatters.relative.localizedString(for: self, relativeTo: Date())
    }

    func isSameMonth(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .month)
    }

    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
}

extension Double {
    func formatted(as currency: String, locale: Locale = .current) -> String {
        // Note: the `locale` parameter was never applied to the formatter in the
        // original implementation (NumberFormatter defaults to .current), so the
        // cached formatter intentionally ignores it too to keep output identical.
        let formatter = CachedFormatters.currencyFormatter(for: currency)
        return formatter.string(from: NSNumber(value: self)) ?? "\(currency) \(self)"
    }

    func asPercentage(decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", self)
    }

    func asCompact(currency: String) -> String {
        let absValue = abs(self)
        let prefix = self < 0 ? "-" : ""
        if absValue >= 1_000_000 {
            return "\(prefix)\(currency) \(String(format: "%.1fM", absValue / 1_000_000))"
        } else if absValue >= 1_000 {
            return "\(prefix)\(currency) \(String(format: "%.1fK", absValue / 1_000))"
        }
        return self.formatted(as: currency)
    }
}

extension Color {
    static func fromString(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray": return .gray
        default: return .blue
        }
    }

    var hex: String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 0]
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// cardStyle() and glassBackground() are defined in UI/Theme/AppTheme.swift

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// dismissKeyboardOnTap() and Color(hex:) are defined in UI/Theme/AppTheme.swift
