import SwiftUI

/// Settings modules (Premium Features grid rows, or standalone top-level sections)
/// that the user can hide from the app without deleting any code or data.
/// Persisted as a comma-separated list of raw values in `AppSettings.disabledFeatures`.
enum DisableableFeature: String, CaseIterable, Identifiable, Codable {
    case aiCFOMode = "AI CFO Mode"
    case retirementSimulation = "Retirement Simulation"
    case lifeEventPlanning = "Life Event Planning"
    case estatePlanning = "Estate Planning"
    case insuranceOptimizer = "Insurance Optimizer"
    case smartCashAllocation = "Smart Cash Allocation"
    case collaborativePlanner = "Collaborative Planner"
    case financialEducation = "Financial Education"
    case remittanceTracker = "Remittance Tracker"
    case taxManagement = "Tax Management"
    case businessFreelancer = "Business & Freelancer"
    case auditLog = "Audit Log"
    case googleDriveBackup = "Google Drive Backup"

    var id: String { rawValue }

    var title: String { rawValue }

    enum Category {
        /// Rendered as one of the rows inside Settings' "Premium Features" card.
        case premium
        /// Rendered as its own standalone `sectionCard` in Settings.
        case topLevelSection
        /// Rendered as one row among others in a shared card (a sibling row inside
        /// some other `sectionCard`), or nested inside another screen entirely.
        /// The owning view checks `isFeatureEnabled`/`isFeatureVisible` manually at
        /// its own call site rather than being auto-filtered by category.
        case nested
    }

    var category: Category {
        switch self {
        case .taxManagement, .businessFreelancer: return .topLevelSection
        case .auditLog, .googleDriveBackup:        return .nested
        default:                                   return .premium
        }
    }

    var symbol: String {
        switch self {
        case .aiCFOMode:            return "brain.head.profile"
        case .retirementSimulation: return "sun.max.fill"
        case .lifeEventPlanning:    return "star.fill"
        case .estatePlanning:       return "scroll.fill"
        case .insuranceOptimizer:   return "shield.fill"
        case .smartCashAllocation:  return "lightbulb.fill"
        case .collaborativePlanner: return "person.3.fill"
        case .financialEducation:   return "book.fill"
        case .remittanceTracker:    return "arrow.up.right.circle.fill"
        case .taxManagement:        return "doc.text.fill"
        case .businessFreelancer:   return "briefcase.fill"
        case .auditLog:             return "list.bullet.clipboard.fill"
        case .googleDriveBackup:    return "doc.badge.gearshape.fill"
        }
    }

    var tint: Color {
        switch self {
        case .aiCFOMode:            return FTColor.accent
        case .retirementSimulation: return FTColor.gold
        case .lifeEventPlanning:    return FTColor.catPurple
        case .estatePlanning:       return FTColor.catCoral
        case .insuranceOptimizer:   return FTColor.catTeal
        case .smartCashAllocation:  return FTColor.income
        case .collaborativePlanner: return FTColor.catBlue
        case .financialEducation:   return FTColor.catPurple
        case .remittanceTracker:    return FTColor.accent
        case .taxManagement:        return FTColor.catPurple
        case .businessFreelancer:   return FTColor.catBlue
        case .auditLog:             return FTColor.gold
        case .googleDriveBackup:    return FTColor.income
        }
    }

    /// Features that are hidden out of the box, before the user ever opens the
    /// Disabled Features screen (i.e. while `AppSettings.disabledFeatures == nil`).
    static let disabledByDefault: Set<DisableableFeature> = [
        .collaborativePlanner, .insuranceOptimizer, .remittanceTracker, .taxManagement, .businessFreelancer,
        .auditLog, .googleDriveBackup
    ]
}

extension AppSettings {
    /// The set of currently-disabled features, decoded from `disabledFeatures`.
    /// `nil` storage falls back to `DisableableFeature.disabledByDefault`.
    var disabledFeatureSet: Set<DisableableFeature> {
        get {
            guard let disabledFeatures else { return DisableableFeature.disabledByDefault }
            let rawValues = disabledFeatures.split(separator: ",").map(String.init)
            return Set(rawValues.compactMap(DisableableFeature.init(rawValue:)))
        }
        set {
            disabledFeatures = newValue.map(\.rawValue).joined(separator: ",")
        }
    }

    func isFeatureEnabled(_ feature: DisableableFeature) -> Bool {
        !disabledFeatureSet.contains(feature)
    }
}
