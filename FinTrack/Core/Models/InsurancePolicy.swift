import Foundation
import SwiftData

enum InsurancePolicyType: String, Codable, CaseIterable {
    case health   = "Health"
    case life     = "Life"
    case car      = "Car"
    case home     = "Home"
    case travel   = "Travel"
    case disability = "Disability"
    case critical = "Critical Illness"
    case other    = "Other"

    var icon: String {
        switch self {
        case .health:     return "heart.fill"
        case .life:       return "person.fill.checkmark"
        case .car:        return "car.fill"
        case .home:       return "house.fill"
        case .travel:     return "airplane"
        case .disability: return "figure.roll"
        case .critical:   return "cross.case.fill"
        case .other:      return "shield.fill"
        }
    }

    var tint: String {
        switch self {
        case .health:     return "red"
        case .life:       return "blue"
        case .car:        return "orange"
        case .home:       return "teal"
        case .travel:     return "purple"
        case .disability: return "coral"
        case .critical:   return "pink"
        case .other:      return "gray"
        }
    }
}

enum PremiumFrequency: String, Codable, CaseIterable {
    case monthly   = "Monthly"
    case quarterly = "Quarterly"
    case annual    = "Annual"

    var multiplier: Double {
        switch self {
        case .monthly:   return 12
        case .quarterly: return 4
        case .annual:    return 1
        }
    }
}

@Model
final class InsurancePolicy {
    var id: UUID
    var typeRaw: String
    var policyName: String
    var provider: String
    var policyNumber: String?
    var startDate: Date
    var endDate: Date
    var premium: Double
    var premiumCurrency: String
    var premiumFrequencyRaw: String
    var coverageAmount: Double
    var deductible: Double
    var beneficiary: String?
    var notes: String?
    var isActive: Bool

    var type: InsurancePolicyType {
        get { InsurancePolicyType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var premiumFrequency: PremiumFrequency {
        get { PremiumFrequency(rawValue: premiumFrequencyRaw) ?? .annual }
        set { premiumFrequencyRaw = newValue.rawValue }
    }

    var annualPremium: Double { premium * premiumFrequency.multiplier }

    var daysUntilRenewal: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }

    var isExpiringSoon: Bool { daysUntilRenewal <= 30 && daysUntilRenewal >= 0 }
    var isExpired: Bool { endDate < Date() }

    init(
        id: UUID = UUID(),
        type: InsurancePolicyType = .health,
        policyName: String = "",
        provider: String = "",
        policyNumber: String? = nil,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
        premium: Double = 0,
        premiumCurrency: String = "AED",
        premiumFrequency: PremiumFrequency = .annual,
        coverageAmount: Double = 0,
        deductible: Double = 0,
        beneficiary: String? = nil,
        notes: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.policyName = policyName
        self.provider = provider
        self.policyNumber = policyNumber
        self.startDate = startDate
        self.endDate = endDate
        self.premium = premium
        self.premiumCurrency = premiumCurrency
        self.premiumFrequencyRaw = premiumFrequency.rawValue
        self.coverageAmount = coverageAmount
        self.deductible = deductible
        self.beneficiary = beneficiary
        self.notes = notes
        self.isActive = isActive
    }
}
