import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum BusinessInvoiceStatus: String, Codable, CaseIterable {
    case draft          = "Draft"
    case sent           = "Sent"
    case viewed         = "Viewed"
    case partiallyPaid  = "Partially Paid"
    case paid           = "Paid"
    case overdue        = "Overdue"
    case cancelled      = "Cancelled"

    var icon: String {
        switch self {
        case .draft:         return "doc"
        case .sent:          return "paperplane.fill"
        case .viewed:        return "eye.fill"
        case .partiallyPaid: return "minus.circle.fill"
        case .paid:          return "checkmark.circle.fill"
        case .overdue:       return "exclamationmark.triangle.fill"
        case .cancelled:     return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .draft:         return FTColor.textMuted
        case .sent:          return FTColor.catBlue
        case .viewed:        return FTColor.catPurple
        case .partiallyPaid: return FTColor.gold
        case .paid:          return FTColor.income
        case .overdue:       return FTColor.expense
        case .cancelled:     return FTColor.textMuted
        }
    }

    var isSettled: Bool { self == .paid }
    var isOpen: Bool { self == .sent || self == .viewed || self == .partiallyPaid }
}

enum ClientStatus: String, Codable, CaseIterable {
    case active   = "Active"
    case inactive = "Inactive"
    case prospect = "Prospect"
    case archived = "Archived"

    var icon: String {
        switch self {
        case .active:   return "checkmark.circle.fill"
        case .inactive: return "pause.circle.fill"
        case .prospect: return "star.fill"
        case .archived: return "archivebox.fill"
        }
    }

    var color: Color {
        switch self {
        case .active:   return FTColor.income
        case .inactive: return FTColor.textMuted
        case .prospect: return FTColor.gold
        case .archived: return FTColor.textSecondary
        }
    }
}

enum MileageVehicleType: String, Codable, CaseIterable {
    case car        = "Car"
    case motorcycle = "Motorcycle"
    case van        = "Van"
    case truck      = "Truck"

    var icon: String {
        switch self {
        case .car:        return "car.fill"
        case .motorcycle: return "bicycle"
        case .van:        return "bus.fill"
        case .truck:      return "shippingbox.fill"
        }
    }
}

enum MileagePurpose: String, Codable, CaseIterable {
    case clientVisit = "Client Visit"
    case delivery    = "Delivery"
    case meeting     = "Meeting"
    case conference  = "Conference"
    case siteVisit   = "Site Visit"
    case other       = "Other"

    var icon: String {
        switch self {
        case .clientVisit: return "person.fill.badge.plus"
        case .delivery:    return "shippingbox.fill"
        case .meeting:     return "person.2.fill"
        case .conference:  return "building.2.fill"
        case .siteVisit:   return "map.fill"
        case .other:       return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Embedded Structs

struct InvoiceLineItem: Codable, Identifiable {
    var id: UUID = UUID()
    var description: String = ""
    var quantity: Double = 1
    var unitPrice: Double = 0
    var vatRate: Double = 0.05

    var subtotal: Double  { quantity * unitPrice }
    var vatAmount: Double { subtotal * vatRate }
    var total: Double     { subtotal + vatAmount }
}

struct InvoicePaymentRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var amount: Double = 0
    var method: String = "Bank Transfer"
    var notes: String?
}

// MARK: - ClientProfile @Model

@Model
final class ClientProfile {
    var id: UUID = UUID()
    var name: String = ""
    var company: String?
    var email: String?
    var phone: String?
    var address: String?
    var currency: String = "AED"
    var statusRaw: String = ClientStatus.active.rawValue
    var vatNumber: String?
    var notes: String?
    var colorHex: String = "#0E9C8A"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        name: String = "",
        company: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        currency: String = "AED",
        vatNumber: String? = nil,
        notes: String? = nil,
        colorHex: String = "#0E9C8A"
    ) {
        self.name = name
        self.company = company
        self.email = email
        self.phone = phone
        self.address = address
        self.currency = currency
        self.vatNumber = vatNumber
        self.notes = notes
        self.colorHex = colorHex
    }

    var status: ClientStatus {
        get { ClientStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue; updatedAt = Date() }
    }

    var displayName: String {
        if let c = company, !c.isEmpty { return "\(name) · \(c)" }
        return name
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - BusinessInvoice @Model

@Model
final class BusinessInvoice {
    var id: UUID = UUID()
    var invoiceNumber: String = ""
    var clientId: String = ""
    var clientName: String = ""
    var clientEmail: String?
    var currency: String = "AED"
    var statusRaw: String = BusinessInvoiceStatus.draft.rawValue
    var issueDate: Date = Date()
    var dueDate: Date = Date()
    var notes: String?
    var vatIncluded: Bool = true
    var projectName: String?
    var lineItemsData: Data = Data()
    var paymentsData: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        invoiceNumber: String = "",
        clientId: String = "",
        clientName: String = "",
        clientEmail: String? = nil,
        currency: String = "AED",
        dueDate: Date = Date().addingTimeInterval(30 * 86400),
        notes: String? = nil,
        vatIncluded: Bool = true,
        projectName: String? = nil
    ) {
        self.invoiceNumber = invoiceNumber
        self.clientId = clientId
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.currency = currency
        self.dueDate = dueDate
        self.notes = notes
        self.vatIncluded = vatIncluded
        self.projectName = projectName
    }

    var status: BusinessInvoiceStatus {
        get { BusinessInvoiceStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue; updatedAt = Date() }
    }

    var lineItems: [InvoiceLineItem] {
        get { (try? JSONDecoder().decode([InvoiceLineItem].self, from: lineItemsData)) ?? [] }
        set { lineItemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var invoicePayments: [InvoicePaymentRecord] {
        get { (try? JSONDecoder().decode([InvoicePaymentRecord].self, from: paymentsData)) ?? [] }
        set { paymentsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var subtotal: Double     { lineItems.reduce(0) { $0 + $1.subtotal } }
    var totalVAT: Double     { lineItems.reduce(0) { $0 + $1.vatAmount } }
    var totalAmount: Double  { lineItems.reduce(0) { $0 + $1.total } }
    var totalPaid: Double    { invoicePayments.reduce(0) { $0 + $1.amount } }
    var balanceDue: Double   { max(0, totalAmount - totalPaid) }

    var isOverdue: Bool {
        dueDate < Date() && status != .paid && status != .cancelled
    }

    var daysOverdue: Int {
        guard isOverdue else { return 0 }
        return Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
    }

    var daysUntilDue: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0)
    }

    func recordPayment(amount: Double, method: String = "Bank Transfer", notes: String? = nil) {
        var p = invoicePayments
        p.append(InvoicePaymentRecord(date: Date(), amount: amount, method: method, notes: notes))
        invoicePayments = p
        if totalPaid >= totalAmount {
            status = .paid
        } else if totalPaid > 0 {
            status = .partiallyPaid
        }
        updatedAt = Date()
    }
}

// MARK: - MileageTrip @Model

@Model
final class MileageTrip {
    var id: UUID = UUID()
    var date: Date = Date()
    var fromLocation: String = ""
    var toLocation: String = ""
    var distanceKm: Double = 0
    var ratePerKm: Double = 0.29
    var vehicleTypeRaw: String = MileageVehicleType.car.rawValue
    var purposeRaw: String = MileagePurpose.clientVisit.rawValue
    var clientName: String?
    var projectName: String?
    var notes: String?
    var isReimbursable: Bool = true
    var isReimbursed: Bool = false
    var currency: String = "AED"
    var createdAt: Date = Date()

    init(
        date: Date = Date(),
        fromLocation: String = "",
        toLocation: String = "",
        distanceKm: Double = 0,
        ratePerKm: Double = 0.29,
        vehicleType: MileageVehicleType = .car,
        purpose: MileagePurpose = .clientVisit,
        clientName: String? = nil,
        projectName: String? = nil,
        notes: String? = nil,
        isReimbursable: Bool = true,
        currency: String = "AED"
    ) {
        self.date = date
        self.fromLocation = fromLocation
        self.toLocation = toLocation
        self.distanceKm = distanceKm
        self.ratePerKm = ratePerKm
        self.vehicleTypeRaw = vehicleType.rawValue
        self.purposeRaw = purpose.rawValue
        self.clientName = clientName
        self.projectName = projectName
        self.notes = notes
        self.isReimbursable = isReimbursable
        self.currency = currency
    }

    var vehicleType: MileageVehicleType {
        MileageVehicleType(rawValue: vehicleTypeRaw) ?? .car
    }

    var purpose: MileagePurpose {
        MileagePurpose(rawValue: purposeRaw) ?? .clientVisit
    }

    var reimbursementAmount: Double { distanceKm * ratePerKm }
}

// MARK: - BusinessProject @Model

@Model
final class BusinessProject {
    var id: UUID = UUID()
    var name: String = ""
    var clientId: String?
    var clientName: String?
    var projectDescription: String?
    var currency: String = "AED"
    var budget: Double = 0
    var statusRaw: String = ProjectStatus.active.rawValue
    var startDate: Date = Date()
    var endDate: Date?
    var colorHex: String = "#4A90D9"
    var notes: String?
    var tagKey: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        name: String = "",
        clientId: String? = nil,
        clientName: String? = nil,
        projectDescription: String? = nil,
        currency: String = "AED",
        budget: Double = 0,
        status: ProjectStatus = .active,
        startDate: Date = Date(),
        endDate: Date? = nil,
        colorHex: String = "#4A90D9",
        notes: String? = nil
    ) {
        self.name = name
        self.clientId = clientId
        self.clientName = clientName
        self.projectDescription = projectDescription
        self.currency = currency
        self.budget = budget
        self.statusRaw = status.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.colorHex = colorHex
        self.notes = notes
        self.tagKey = name.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
}
