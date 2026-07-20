import SwiftUI

/// Settings modules (Premium Features grid rows, standalone top-level sections,
/// or individual nested rows) that developers can hide from the app without
/// deleting any code or data.
///
/// This is **developer-controlled only** — there is intentionally no user-facing
/// screen to toggle these. To disable a feature, add its case to `disabled`
/// below and record it in `docs/DISABLED_FEATURES.md`. To re-enable, remove it
/// from both. The code, models, and data for a disabled feature always stay
/// intact so it can be switched back on later.
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
        /// The owning view checks `isEnabled` manually at its own call site
        /// rather than being auto-filtered by category.
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

    /// The single source of truth for which features are currently disabled.
    /// Keep this in sync with `docs/DISABLED_FEATURES.md`.
    static let disabled: Set<DisableableFeature> = [
        .collaborativePlanner,
        .insuranceOptimizer,
        .remittanceTracker,
        .taxManagement,
        .businessFreelancer,
        .auditLog,
        .googleDriveBackup,
    ]

    /// Whether this feature should currently be shown/active in the app.
    var isEnabled: Bool { !DisableableFeature.disabled.contains(self) }
}
