import Foundation
import SwiftData

// MARK: - BillingCycle

enum BillingCycle: String, Codable, CaseIterable {
    case weekly     = "Weekly"
    case monthly    = "Monthly"
    case quarterly  = "Quarterly"
    case semiAnnual = "Semi-Annual"
    case annual     = "Annual"

    /// DateComponents to add to advance a due date by one billing cycle.
    var interval: DateComponents {
        switch self {
        case .weekly:     return DateComponents(day: 7)
        case .monthly:    return DateComponents(month: 1)
        case .quarterly:  return DateComponents(month: 3)
        case .semiAnnual: return DateComponents(month: 6)
        case .annual:     return DateComponents(year: 1)
        }
    }

    /// Multiplier to convert the billed amount into a monthly-equivalent cost.
    var monthlyFactor: Double {
        switch self {
        case .weekly:     return 52.0 / 12.0
        case .monthly:    return 1.0
        case .quarterly:  return 1.0 / 3.0
        case .semiAnnual: return 1.0 / 6.0
        case .annual:     return 1.0 / 12.0
        }
    }

    /// Multiplier to convert the billed amount into an annual-equivalent cost.
    var annualFactor: Double { monthlyFactor * 12.0 }

    /// SF Symbol representing the cycle.
    var icon: String {
        switch self {
        case .weekly:     return "calendar"
        case .monthly:    return "calendar.circle"
        case .quarterly:  return "calendar.badge.clock"
        case .semiAnnual: return "calendar.badge.plus"
        case .annual:     return "calendar.circle.fill"
        }
    }

    /// Short display label appended after a formatted amount.
    var shortLabel: String {
        switch self {
        case .weekly:     return "/wk"
        case .monthly:    return "/mo"
        case .quarterly:  return "/qtr"
        case .semiAnnual: return "/6mo"
        case .annual:     return "/yr"
        }
    }
}

// MARK: - BillCategory

enum BillCategory: String, Codable, CaseIterable {
    case utilities     = "Utilities"
    case housing       = "Housing"
    case entertainment = "Entertainment"
    case communication = "Communication"
    case insurance     = "Insurance"
    case education     = "Education"
    case subscriptions = "Subscriptions"
    case healthcare    = "Healthcare"
    case financial     = "Financial"
    case other         = "Other"

    var icon: String {
        switch self {
        case .utilities:     return "bolt.fill"
        case .housing:       return "house.fill"
        case .entertainment: return "tv.fill"
        case .communication: return "antenna.radiowaves.left.and.right"
        case .insurance:     return "shield.fill"
        case .education:     return "graduationcap.fill"
        case .subscriptions: return "repeat"
        case .healthcare:    return "cross.circle.fill"
        case .financial:     return "building.columns.fill"
        case .other:         return "ellipsis.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .utilities:     return "yellow"
        case .housing:       return "brown"
        case .entertainment: return "purple"
        case .communication: return "blue"
        case .insurance:     return "gray"
        case .education:     return "indigo"
        case .subscriptions: return "teal"
        case .healthcare:    return "red"
        case .financial:     return "green"
        case .other:         return "gray"
        }
    }
}

// MARK: - PriceHistoryEntry

struct PriceHistoryEntry: Codable, Identifiable {
    var id: UUID
    var amount: Double
    var date: Date
    var note: String?

    init(id: UUID = UUID(), amount: Double, date: Date = Date(), note: String? = nil) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
    }
}

// MARK: - Bill

@Model
final class Bill {

    // MARK: Identity & display
    var id: UUID
    var name: String
    var provider: String?
    var billCategoryRaw: String
    var colorName: String
    var icon: String

    // MARK: Financials
    var amount: Double
    var currency: String
    var billingCycleRaw: String

    // MARK: Due date & autopay
    var nextDueDate: Date
    var isAutoPay: Bool
    var autoPayWindowDays: Int

    // MARK: Payment
    var paymentMethodRaw: String

    // MARK: Notes & flags
    var notes: String?
    var isActive: Bool
    var isSubscription: Bool

    // MARK: Reminders
    var reminderDaysBefore: [Int]

    // MARK: Price history
    var priceHistory: [PriceHistoryEntry]

    // MARK: Last payment tracking
    var lastPaidDate: Date?
    var lastPaidAmount: Double?

    // MARK: Alert state
    var isDismissedWasteAlert: Bool
    var notifiedOverdueDateRaw: Date?
    var notifiedAutoPayMissed: Bool

    // MARK: Audit
    var createdAt: Date

    // MARK: - Computed: typed enums

    var billCategory: BillCategory {
        get { BillCategory(rawValue: billCategoryRaw) ?? .other }
        set { billCategoryRaw = newValue.rawValue }
    }

    var billingCycle: BillingCycle {
        get { BillingCycle(rawValue: billingCycleRaw) ?? .monthly }
        set { billingCycleRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw) ?? .other }
        set { paymentMethodRaw = newValue.rawValue }
    }

    // MARK: - Computed: financial equivalents

    var monthlyEquivalent: Double { amount * billingCycle.monthlyFactor }
    var annualEquivalent: Double  { amount * billingCycle.annualFactor }

    // MARK: - Computed: due-date helpers

    var isOverdue: Bool { nextDueDate < Date() }

    var daysUntilDue: Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextDueDate).day ?? 0
        return days
    }

    // MARK: - Computed: price change tracking

    var previousAmount: Double? { priceHistory.last?.amount }

    var hasPriceIncreased: Bool {
        guard let prev = previousAmount else { return false }
        return amount > prev + 0.001
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        provider: String? = nil,
        billCategory: BillCategory = .subscriptions,
        amount: Double,
        currency: String = "AED",
        billingCycle: BillingCycle = .monthly,
        nextDueDate: Date = Date(),
        isAutoPay: Bool = false,
        autoPayWindowDays: Int = 3,
        paymentMethod: PaymentMethod = .bankTransfer,
        notes: String? = nil,
        colorName: String = "teal",
        icon: String = "repeat",
        isActive: Bool = true,
        isSubscription: Bool = true,
        reminderDaysBefore: [Int] = [3],
        priceHistory: [PriceHistoryEntry] = [],
        lastPaidDate: Date? = nil,
        lastPaidAmount: Double? = nil,
        isDismissedWasteAlert: Bool = false,
        notifiedOverdueDateRaw: Date? = nil,
        notifiedAutoPayMissed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.billCategoryRaw = billCategory.rawValue
        self.amount = amount
        self.currency = currency
        self.billingCycleRaw = billingCycle.rawValue
        self.nextDueDate = nextDueDate
        self.isAutoPay = isAutoPay
        self.autoPayWindowDays = autoPayWindowDays
        self.paymentMethodRaw = paymentMethod.rawValue
        self.notes = notes
        self.colorName = colorName
        self.icon = icon
        self.isActive = isActive
        self.isSubscription = isSubscription
        self.reminderDaysBefore = reminderDaysBefore
        self.priceHistory = priceHistory
        self.lastPaidDate = lastPaidDate
        self.lastPaidAmount = lastPaidAmount
        self.isDismissedWasteAlert = isDismissedWasteAlert
        self.notifiedOverdueDateRaw = notifiedOverdueDateRaw
        self.notifiedAutoPayMissed = notifiedAutoPayMissed
        self.createdAt = Date()
    }
}
