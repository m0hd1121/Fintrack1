import Foundation
import SwiftData
import SwiftUI

// MARK: - RepaymentRecord

struct RepaymentRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var amount: Double
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Double,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.notes = notes
    }
}

// MARK: - PersonalDebtStatus

enum PersonalDebtStatus: String, Codable, CaseIterable {
    case active          = "Active"
    case partiallyRepaid = "Partially Repaid"
    case repaid          = "Repaid"
    case overdue         = "Overdue"
    case writtenOff      = "Written Off"

    var icon: String {
        switch self {
        case .active:          return "circle.fill"
        case .partiallyRepaid: return "circle.lefthalf.filled"
        case .repaid:          return "checkmark.circle.fill"
        case .overdue:         return "exclamationmark.circle.fill"
        case .writtenOff:      return "xmark.circle.fill"
        }
    }

    var displayColor: Color {
        switch self {
        case .active:          return Color.fromString("blue")
        case .partiallyRepaid: return Color.fromString("orange")
        case .repaid:          return Color.fromString("green")
        case .overdue:         return Color.fromString("red")
        case .writtenOff:      return Color.fromString("gray")
        }
    }
}

// MARK: - MoneyLent

@Model
final class MoneyLent {
    var id: UUID
    var borrowerName: String
    var contactInfo: String?
    var amount: Double
    var currency: String
    var lendingDate: Date
    var dueDate: Date?
    var notes: String?
    var status: PersonalDebtStatus
    var reminderEnabled: Bool
    var reminderDaysBefore: Int
    var color: String
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) var repaymentsData: Data = Data()

    // MARK: Computed – repayments (backed by repaymentsData)

    var repayments: [RepaymentRecord] {
        get {
            guard !repaymentsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([RepaymentRecord].self, from: repaymentsData)) ?? []
        }
        set {
            repaymentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var totalRepaid: Double {
        repayments.reduce(0) { $0 + $1.amount }
    }

    var remainingBalance: Double {
        max(amount - totalRepaid, 0)
    }

    var isFullyRepaid: Bool {
        remainingBalance <= 0.005
    }

    var progressFraction: Double {
        amount > 0 ? min(totalRepaid / amount, 1.0) : 0
    }

    /// Derives status from repayment state; does NOT mutate `status`.
    var computedStatus: PersonalDebtStatus {
        if isFullyRepaid {
            return .repaid
        }
        if let due = dueDate, due < Date() {
            return .overdue
        }
        if totalRepaid > 0 {
            return .partiallyRepaid
        }
        return .active
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        borrowerName: String,
        contactInfo: String? = nil,
        amount: Double,
        currency: String = "AED",
        lendingDate: Date = Date(),
        dueDate: Date? = nil,
        notes: String? = nil,
        status: PersonalDebtStatus = .active,
        reminderEnabled: Bool = false,
        reminderDaysBefore: Int = 3,
        color: String = "blue"
    ) {
        self.id = id
        self.borrowerName = borrowerName
        self.contactInfo = contactInfo
        self.amount = amount
        self.currency = currency
        self.lendingDate = lendingDate
        self.dueDate = dueDate
        self.notes = notes
        self.status = status
        self.reminderEnabled = reminderEnabled
        self.reminderDaysBefore = reminderDaysBefore
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - MoneyBorrowed

@Model
final class MoneyBorrowed {
    var id: UUID
    var lenderName: String
    var contactInfo: String?
    var amount: Double
    var currency: String
    var borrowDate: Date
    var dueDate: Date?
    var notes: String?
    var status: PersonalDebtStatus
    var reminderEnabled: Bool
    var reminderDaysBefore: Int
    var color: String
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) var repaymentsData: Data = Data()

    // MARK: Computed – repayments (backed by repaymentsData)

    var repayments: [RepaymentRecord] {
        get {
            guard !repaymentsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([RepaymentRecord].self, from: repaymentsData)) ?? []
        }
        set {
            repaymentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var totalRepaid: Double {
        repayments.reduce(0) { $0 + $1.amount }
    }

    var remainingBalance: Double {
        max(amount - totalRepaid, 0)
    }

    var isFullyRepaid: Bool {
        remainingBalance <= 0.005
    }

    var progressFraction: Double {
        amount > 0 ? min(totalRepaid / amount, 1.0) : 0
    }

    /// Derives status from repayment state; does NOT mutate `status`.
    var computedStatus: PersonalDebtStatus {
        if isFullyRepaid {
            return .repaid
        }
        if let due = dueDate, due < Date() {
            return .overdue
        }
        if totalRepaid > 0 {
            return .partiallyRepaid
        }
        return .active
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        lenderName: String,
        contactInfo: String? = nil,
        amount: Double,
        currency: String = "AED",
        borrowDate: Date = Date(),
        dueDate: Date? = nil,
        notes: String? = nil,
        status: PersonalDebtStatus = .active,
        reminderEnabled: Bool = false,
        reminderDaysBefore: Int = 3,
        color: String = "red"
    ) {
        self.id = id
        self.lenderName = lenderName
        self.contactInfo = contactInfo
        self.amount = amount
        self.currency = currency
        self.borrowDate = borrowDate
        self.dueDate = dueDate
        self.notes = notes
        self.status = status
        self.reminderEnabled = reminderEnabled
        self.reminderDaysBefore = reminderDaysBefore
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
