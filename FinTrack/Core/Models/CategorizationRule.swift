import Foundation
import SwiftData

// MARK: - Rule Condition Type

enum RuleConditionType: String, Codable, CaseIterable {
    case merchantEquals   = "Merchant equals"
    case merchantContains = "Merchant contains"
    case titleContains    = "Title contains"
    case titleRegex       = "Title matches regex"
    case amountRange      = "Amount in range"
    case currency         = "Currency is"

    var icon: String {
        switch self {
        case .merchantEquals:   return "equal.circle"
        case .merchantContains: return "text.magnifyingglass"
        case .titleContains:    return "doc.text.magnifyingglass"
        case .titleRegex:       return "curlybraces"
        case .amountRange:      return "dollarsign.circle"
        case .currency:         return "globe"
        }
    }

    var placeholder: String {
        switch self {
        case .merchantEquals:   return "Exact merchant name"
        case .merchantContains: return "Keyword in merchant name"
        case .titleContains:    return "Keyword in title"
        case .titleRegex:       return "Regular expression pattern"
        case .amountRange:      return "(use the amount fields below)"
        case .currency:         return "Currency code, e.g. USD"
        }
    }

    var requiresAmountRange: Bool { self == .amountRange }
    var requiresTextValue:   Bool { self != .amountRange }
}

// MARK: - Categorization Rule Model

@Model
final class CategorizationRule {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var priority: Int          // lower number = applied first
    var conditionTypeRaw: String
    var conditionValue: String
    var amountMin: Double?
    var amountMax: Double?
    var targetCategoryRaw: String
    var targetCustomCategoryID: UUID?
    var autoTags: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        priority: Int = 100,
        conditionType: RuleConditionType = .merchantContains,
        conditionValue: String = "",
        amountMin: Double? = nil,
        amountMax: Double? = nil,
        targetCategory: TransactionCategory = .other,
        targetCustomCategoryID: UUID? = nil,
        autoTags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.priority = priority
        self.conditionTypeRaw = conditionType.rawValue
        self.conditionValue = conditionValue
        self.amountMin = amountMin
        self.amountMax = amountMax
        self.targetCategoryRaw = targetCategory.rawValue
        self.targetCustomCategoryID = targetCustomCategoryID
        self.autoTags = autoTags
        self.createdAt = Date()
    }
}

// MARK: - Extensions

extension CategorizationRule {
    var conditionType: RuleConditionType {
        get { RuleConditionType(rawValue: conditionTypeRaw) ?? .merchantContains }
        set { conditionTypeRaw = newValue.rawValue }
    }

    var targetCategory: TransactionCategory {
        get { TransactionCategory(rawValue: targetCategoryRaw) ?? .other }
        set { targetCategoryRaw = newValue.rawValue }
    }

    var conditionSummary: String {
        switch conditionType {
        case .merchantEquals:   return "Merchant = \"\(conditionValue)\""
        case .merchantContains: return "Merchant ∋ \"\(conditionValue)\""
        case .titleContains:    return "Title ∋ \"\(conditionValue)\""
        case .titleRegex:       return "Title ~ /\(conditionValue)/"
        case .amountRange:
            let lo = amountMin.map { String(format: "%.0f", $0) } ?? "0"
            let hi = amountMax.map { String(format: "%.0f", $0) } ?? "∞"
            return "Amount \(lo)–\(hi)"
        case .currency:         return "Currency = \(conditionValue)"
        }
    }

    func matches(title: String, merchant: String?, amount: Double, currency: String) -> Bool {
        let lv = conditionValue.trimmingCharacters(in: .whitespaces)
        guard !lv.isEmpty || conditionType.requiresAmountRange else { return false }

        let lowerTitle    = title.lowercased()
        let lowerMerchant = (merchant ?? "").lowercased()
        let lowerValue    = lv.lowercased()

        switch conditionType {
        case .merchantEquals:
            return !lowerMerchant.isEmpty && lowerMerchant == lowerValue
        case .merchantContains:
            return !lowerMerchant.isEmpty && lowerMerchant.contains(lowerValue)
        case .titleContains:
            return lowerTitle.contains(lowerValue)
        case .titleRegex:
            guard let regex = try? NSRegularExpression(pattern: lv, options: .caseInsensitive) else { return false }
            return regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) != nil
        case .amountRange:
            let lo = amountMin ?? 0
            let hi = amountMax ?? Double.infinity
            return amount >= lo && amount <= hi
        case .currency:
            return currency.uppercased() == lv.uppercased()
        }
    }
}
