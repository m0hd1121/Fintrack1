import Foundation
import SwiftData

@Model
final class LoyaltyProgram {
    var id: UUID
    var name: String
    var programType: LoyaltyProgramType
    var customProgramName: String?      // When programType == .other
    var points: Double                  // Current points/miles balance
    var pointsValuePerUnit: Double      // e.g. 0.01 AED per point
    var currency: String                // Currency for pointsValue calculation
    var membershipNumber: String?
    var tier: String?                   // "Silver", "Gold", "Platinum", etc.
    var expiryDate: Date?               // When points expire
    var notes: String?
    var color: String
    var createdAt: Date
    var updatedAt: Date

    var estimatedValue: Double { points * pointsValuePerUnit }

    var isExpiringSoon: Bool {
        guard let expiry = expiryDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return days >= 0 && days <= 60
    }

    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }

    init(
        id: UUID = UUID(),
        name: String,
        programType: LoyaltyProgramType = .other,
        customProgramName: String? = nil,
        points: Double = 0,
        pointsValuePerUnit: Double = 0.01,
        currency: String = "AED",
        membershipNumber: String? = nil,
        tier: String? = nil,
        expiryDate: Date? = nil,
        notes: String? = nil,
        color: String = "purple"
    ) {
        self.id = id
        self.name = name
        self.programType = programType
        self.customProgramName = customProgramName
        self.points = points
        self.pointsValuePerUnit = pointsValuePerUnit
        self.currency = currency
        self.membershipNumber = membershipNumber
        self.tier = tier
        self.expiryDate = expiryDate
        self.notes = notes
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum LoyaltyProgramType: String, Codable, CaseIterable {
    // Airlines
    case emiratesSkwards    = "Emirates Skywards"
    case etihardGuest       = "Etihad Guest"
    case flyDubai           = "flydubai OPEN"
    // Retail / UAE
    case shukran            = "Shukran"
    case smiles             = "Smiles"
    case adnocAlphaPoints   = "ADNOC Rewards"
    case enoc               = "ENOC SmartMiles"
    // Hotels
    case marriottBonvoy     = "Marriott Bonvoy"
    case hiltonHonors       = "Hilton Honors"
    case worldOfHyatt       = "World of Hyatt"
    // Banks
    case adcbTouchpoints    = "ADCB Touchpoints"
    case fabRewards         = "FAB Rewards"
    case emiratesNBD        = "Emirates NBD Beyond"
    // Other
    case other              = "Other"

    var icon: String {
        switch self {
        case .emiratesSkwards, .etihardGuest, .flyDubai: return "airplane"
        case .shukran, .smiles, .adnocAlphaPoints, .enoc: return "tag.fill"
        case .marriottBonvoy, .hiltonHonors, .worldOfHyatt: return "bed.double.fill"
        case .adcbTouchpoints, .fabRewards, .emiratesNBD: return "creditcard.fill"
        case .other: return "star.fill"
        }
    }

    var pointsLabel: String {
        switch self {
        case .emiratesSkwards, .etihardGuest, .flyDubai,
             .marriottBonvoy, .hiltonHonors, .worldOfHyatt:
            return "Miles"
        default:
            return "Points"
        }
    }
}
