import Foundation
import SwiftData

// MARK: - PaymentFrequency

enum PaymentFrequency: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case semiMonthly = "Semi-monthly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case annual = "Annual"

    var interval: DateComponents {
        switch self {
        case .weekly:
            return DateComponents(day: 7)
        case .biweekly:
            return DateComponents(day: 14)
        case .semiMonthly:
            return DateComponents(day: 15)
        case .monthly:
            return DateComponents(month: 1)
        case .quarterly:
            return DateComponents(month: 3)
        case .annual:
            return DateComponents(year: 1)
        }
    }

    var shortLabel: String {
        switch self {
        case .weekly: return "Wkly"
        case .biweekly: return "Bi-wk"
        case .semiMonthly: return "Semi"
        case .monthly: return "Mthly"
        case .quarterly: return "Qtrly"
        case .annual: return "Annu"
        }
    }

    var icon: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .biweekly: return "calendar.badge.plus"
        case .semiMonthly: return "calendar"
        case .monthly: return "calendar.circle"
        case .quarterly: return "calendar.circle.fill"
        case .annual: return "star.circle"
        }
    }
}

// MARK: - SalaryPaymentStatus

enum SalaryPaymentStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case received = "Received"
    case late = "Late"
    case partial = "Partial"
    case missed = "Missed"

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .received: return "checkmark.circle.fill"
        case .late: return "exclamationmark.triangle.fill"
        case .partial: return "minus.circle.fill"
        case .missed: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .received: return "green"
        case .late: return "red"
        case .partial: return "yellow"
        case .missed: return "gray"
        }
    }
}

// MARK: - ProjectStatus

enum ProjectStatus: String, Codable, CaseIterable {
    case active = "Active"
    case completed = "Completed"
    case onHold = "On Hold"
    case cancelled = "Cancelled"

    var icon: String {
        switch self {
        case .active: return "play.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .onHold: return "pause.circle.fill"
        case .cancelled: return "xmark.seal.fill"
        }
    }

    var color: String {
        switch self {
        case .active: return "green"
        case .completed: return "blue"
        case .onHold: return "orange"
        case .cancelled: return "gray"
        }
    }
}

// MARK: - InvoiceStatus

enum InvoiceStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case sent = "Sent"
    case pending = "Pending"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"

    var icon: String {
        switch self {
        case .draft: return "doc"
        case .sent: return "paperplane.fill"
        case .pending: return "clock"
        case .paid: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .draft: return "gray"
        case .sent: return "blue"
        case .pending: return "orange"
        case .paid: return "green"
        case .overdue: return "red"
        case .cancelled: return "gray"
        }
    }

    var isPaid: Bool {
        return self == .paid
    }
}

// MARK: - RentalPropertyType

enum RentalPropertyType: String, Codable, CaseIterable {
    case apartment = "Apartment"
    case villa = "Villa"
    case officeSpace = "Office Space"
    case retail = "Retail"
    case warehouse = "Warehouse"
    case land = "Land"
    case other = "Other"

    var icon: String {
        switch self {
        case .apartment: return "building"
        case .villa: return "house.fill"
        case .officeSpace: return "building.2"
        case .retail: return "storefront"
        case .warehouse: return "shippingbox"
        case .land: return "map"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - SalaryPayment

struct SalaryPayment: Codable, Identifiable {
    var id: UUID = UUID()
    var expectedDate: Date
    var expectedAmount: Double
    var receivedDate: Date? = nil
    var receivedAmount: Double? = nil
    var statusRaw: String = SalaryPaymentStatus.pending.rawValue
    var notes: String? = nil

    var status: SalaryPaymentStatus {
        SalaryPaymentStatus(rawValue: statusRaw) ?? .pending
    }

    var isLate: Bool {
        if let received = receivedDate {
            return received > expectedDate
        }
        return Date() > expectedDate
    }

    var variance: Double {
        (receivedAmount ?? 0) - expectedAmount
    }

    var variancePercent: Double {
        guard expectedAmount > 0 else { return 0 }
        return (variance / expectedAmount) * 100
    }
}

// MARK: - FreelanceInvoice

struct FreelanceInvoice: Codable, Identifiable {
    var id: UUID = UUID()
    var invoiceNumber: String
    var description: String
    var amount: Double
    var currency: String = "AED"
    var issueDate: Date = Date()
    var dueDate: Date
    var paidDate: Date? = nil
    var paidAmount: Double? = nil
    var statusRaw: String = InvoiceStatus.pending.rawValue
    var notes: String? = nil

    var status: InvoiceStatus {
        if paidDate != nil {
            return .paid
        }
        if dueDate < Date() && paidDate == nil {
            return .overdue
        }
        return InvoiceStatus(rawValue: statusRaw) ?? .pending
    }

    var isPaid: Bool {
        paidDate != nil
    }

    var isOverdue: Bool {
        dueDate < Date() && !isPaid
    }

    var variance: Double {
        (paidAmount ?? 0) - amount
    }

    var daysUntilDue: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: dueDate)
        return Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
    }
}

// MARK: - OccupancyPeriod

struct OccupancyPeriod: Codable, Identifiable {
    var id: UUID = UUID()
    var tenantName: String
    var leaseStartDate: Date
    var leaseEndDate: Date
    var monthlyRent: Double
    var depositAmount: Double = 0
    var notes: String? = nil

    var isActive: Bool {
        let now = Date()
        return leaseStartDate <= now && leaseEndDate >= now
    }

    var durationMonths: Int {
        Calendar.current.dateComponents([.month], from: leaseStartDate, to: leaseEndDate).month ?? 0
    }
}

// MARK: - RentPaymentRecord

struct RentPaymentRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var expectedDate: Date
    var expectedAmount: Double
    var receivedDate: Date? = nil
    var receivedAmount: Double? = nil
    var notes: String? = nil

    var isPaid: Bool {
        receivedDate != nil
    }

    var isLate: Bool {
        !isPaid && Date() > expectedDate
    }

    var variance: Double {
        (receivedAmount ?? 0) - expectedAmount
    }
}

// MARK: - SalaryRecord

@Model
final class SalaryRecord {
    var id: UUID = UUID()
    var employerName: String
    var jobTitle: String
    var currency: String = "AED"
    var expectedAmount: Double
    var expectedPaymentDay: Int
    var paymentFrequencyRaw: String = PaymentFrequency.monthly.rawValue
    var isActive: Bool = true
    var colorName: String = "green"
    var notes: String? = nil
    @Attribute(.externalStorage) var paymentsData: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var payments: [SalaryPayment] {
        get {
            (try? JSONDecoder().decode([SalaryPayment].self, from: paymentsData)) ?? []
        }
        set {
            paymentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var paymentFrequency: PaymentFrequency {
        PaymentFrequency(rawValue: paymentFrequencyRaw) ?? .monthly
    }

    var lastPayment: SalaryPayment? {
        payments.sorted { $0.expectedDate > $1.expectedDate }.first
    }

    var pendingPayments: [SalaryPayment] {
        payments.filter { $0.status == .pending || $0.status == .late }
    }

    var averageReceivedAmount: Double {
        let received = payments.compactMap { $0.receivedAmount }
        guard !received.isEmpty else { return 0 }
        return received.reduce(0, +) / Double(received.count)
    }

    var onTimeRate: Double {
        let receivedPayments = payments.filter { $0.receivedDate != nil }
        guard !receivedPayments.isEmpty else { return 0 }
        let onTime = receivedPayments.filter { !$0.isLate }
        return (Double(onTime.count) / Double(receivedPayments.count)) * 100
    }

    var nextExpectedDate: Date {
        let calendar = Calendar.current
        let now = Date()
        _ = calendar.dateComponents([.year, .month], from: now)

        // Clamp expectedPaymentDay to valid day for each month
        func nextOccurrence(from referenceDate: Date) -> Date {
            var comps = calendar.dateComponents([.year, .month], from: referenceDate)
            _ = comps.year ?? 0
            _ = comps.month ?? 1
            let range = calendar.range(of: .day, in: .month, for: referenceDate)
            let maxDay = range?.count ?? 28
            let day = min(expectedPaymentDay, maxDay)
            comps.day = day
            return calendar.date(from: comps) ?? referenceDate
        }

        let thisMonthCandidate = nextOccurrence(from: now)
        if thisMonthCandidate > now {
            return thisMonthCandidate
        }

        // Move to next month
        guard let nextMonth = calendar.date(byAdding: DateComponents(month: 1), to: now) else {
            return thisMonthCandidate
        }
        return nextOccurrence(from: nextMonth)
    }

    init(
        id: UUID = UUID(),
        employerName: String,
        jobTitle: String,
        currency: String = "AED",
        expectedAmount: Double,
        expectedPaymentDay: Int,
        paymentFrequencyRaw: String = PaymentFrequency.monthly.rawValue,
        isActive: Bool = true,
        colorName: String = "green",
        notes: String? = nil
    ) {
        self.id = id
        self.employerName = employerName
        self.jobTitle = jobTitle
        self.currency = currency
        self.expectedAmount = expectedAmount
        self.expectedPaymentDay = expectedPaymentDay
        self.paymentFrequencyRaw = paymentFrequencyRaw
        self.isActive = isActive
        self.colorName = colorName
        self.notes = notes
        self.paymentsData = Data()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - FreelanceProject

@Model
final class FreelanceProject {
    var id: UUID = UUID()
    var projectName: String
    var clientName: String
    var projectDescription: String? = nil
    var currency: String = "AED"
    var totalValue: Double
    var statusRaw: String = ProjectStatus.active.rawValue
    var startDate: Date = Date()
    var endDate: Date? = nil
    @Attribute(.externalStorage) var invoicesData: Data = Data()
    var notes: String? = nil
    var colorName: String = "teal"
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var invoices: [FreelanceInvoice] {
        get {
            (try? JSONDecoder().decode([FreelanceInvoice].self, from: invoicesData)) ?? []
        }
        set {
            invoicesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var status: ProjectStatus {
        ProjectStatus(rawValue: statusRaw) ?? .active
    }

    var totalInvoiced: Double {
        invoices.reduce(0) { $0 + $1.amount }
    }

    var totalReceived: Double {
        invoices
            .filter { $0.isPaid }
            .reduce(0) { $0 + ($1.paidAmount ?? $1.amount) }
    }

    var totalOutstanding: Double {
        invoices
            .filter { !$0.isPaid }
            .reduce(0) { $0 + $1.amount }
    }

    var completionRate: Double {
        guard totalValue > 0 else { return 0 }
        return totalReceived / totalValue
    }

    var overdueInvoices: [FreelanceInvoice] {
        invoices.filter { $0.isOverdue }
    }

    var pendingInvoices: [FreelanceInvoice] {
        invoices.filter { $0.status == .pending || $0.status == .sent }
    }

    init(
        id: UUID = UUID(),
        projectName: String,
        clientName: String,
        projectDescription: String? = nil,
        currency: String = "AED",
        totalValue: Double,
        statusRaw: String = ProjectStatus.active.rawValue,
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String? = nil,
        colorName: String = "teal"
    ) {
        self.id = id
        self.projectName = projectName
        self.clientName = clientName
        self.projectDescription = projectDescription
        self.currency = currency
        self.totalValue = totalValue
        self.statusRaw = statusRaw
        self.startDate = startDate
        self.endDate = endDate
        self.invoicesData = Data()
        self.notes = notes
        self.colorName = colorName
        self.isArchived = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - RentalProperty

@Model
final class RentalProperty {
    var id: UUID = UUID()
    var propertyName: String
    var propertyTypeRaw: String = RentalPropertyType.apartment.rawValue
    var address: String? = nil
    var currency: String = "AED"
    var monthlyRentExpected: Double
    var isOccupied: Bool = false
    @Attribute(.externalStorage) var occupancyPeriodsData: Data = Data()
    @Attribute(.externalStorage) var paymentHistoryData: Data = Data()
    var notes: String? = nil
    var colorName: String = "brown"
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var occupancyPeriods: [OccupancyPeriod] {
        get {
            (try? JSONDecoder().decode([OccupancyPeriod].self, from: occupancyPeriodsData)) ?? []
        }
        set {
            occupancyPeriodsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var paymentHistory: [RentPaymentRecord] {
        get {
            (try? JSONDecoder().decode([RentPaymentRecord].self, from: paymentHistoryData)) ?? []
        }
        set {
            paymentHistoryData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var propertyType: RentalPropertyType {
        RentalPropertyType(rawValue: propertyTypeRaw) ?? .apartment
    }

    var currentOccupancyPeriod: OccupancyPeriod? {
        occupancyPeriods.first { $0.isActive }
    }

    var currentMonthlyRent: Double {
        currentOccupancyPeriod?.monthlyRent ?? monthlyRentExpected
    }

    var totalCollected: Double {
        paymentHistory.reduce(0) { $0 + ($1.receivedAmount ?? 0) }
    }

    var totalExpected: Double {
        paymentHistory.reduce(0) { $0 + $1.expectedAmount }
    }

    var collectionRate: Double {
        guard totalExpected > 0 else { return 0 }
        return totalCollected / totalExpected
    }

    var overduePayments: [RentPaymentRecord] {
        paymentHistory.filter { $0.isLate }
    }

    var vacancyMonths: Int {
        let calendar = Calendar.current
        guard !occupancyPeriods.isEmpty else { return 0 }

        // Find the overall date range spanned by all occupancy periods
        guard
            let earliest = occupancyPeriods.map({ $0.leaseStartDate }).min(),
            let latest = occupancyPeriods.map({ $0.leaseEndDate }).max()
        else { return 0 }

        let totalMonths = calendar.dateComponents([.month], from: earliest, to: latest).month ?? 0
        let occupiedMonths = occupancyPeriods.reduce(0) {
            $0 + (calendar.dateComponents([.month], from: $1.leaseStartDate, to: $1.leaseEndDate).month ?? 0)
        }
        return max(0, totalMonths - occupiedMonths)
    }

    init(
        id: UUID = UUID(),
        propertyName: String,
        propertyTypeRaw: String = RentalPropertyType.apartment.rawValue,
        address: String? = nil,
        currency: String = "AED",
        monthlyRentExpected: Double,
        notes: String? = nil,
        colorName: String = "brown"
    ) {
        self.id = id
        self.propertyName = propertyName
        self.propertyTypeRaw = propertyTypeRaw
        self.address = address
        self.currency = currency
        self.monthlyRentExpected = monthlyRentExpected
        self.isOccupied = false
        self.occupancyPeriodsData = Data()
        self.paymentHistoryData = Data()
        self.notes = notes
        self.colorName = colorName
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
