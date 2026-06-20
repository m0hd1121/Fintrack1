import Foundation
import SwiftData
import SwiftUI

// MARK: - Permission & Role Enums

enum FamilyPermissionLevel: String, Codable, CaseIterable {
    case viewOnly = "View Only"
    case edit     = "Edit"
    case admin    = "Admin"

    var icon: String {
        switch self {
        case .viewOnly: return "eye.fill"
        case .edit:     return "pencil.circle.fill"
        case .admin:    return "shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .viewOnly: return FTColor.textMuted
        case .edit:     return FTColor.catBlue
        case .admin:    return FTColor.gold
        }
    }

    var canEdit:  Bool { self != .viewOnly }
    var isAdmin:  Bool { self == .admin }

    var description: String {
        switch self {
        case .viewOnly: return "Can only view data, cannot make changes"
        case .edit:     return "Can view and modify data, cannot manage members"
        case .admin:    return "Full access including member management"
        }
    }
}

enum FamilyMemberRole: String, Codable, CaseIterable {
    case partner = "Partner"
    case parent  = "Parent"
    case child   = "Child"
    case other   = "Other"

    var icon: String {
        switch self {
        case .partner: return "heart.fill"
        case .parent:  return "person.fill"
        case .child:   return "person.crop.circle.fill"
        case .other:   return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .partner: return FTColor.expense
        case .parent:  return FTColor.accent
        case .child:   return FTColor.gold
        case .other:   return FTColor.textSecondary
        }
    }

    var defaultPermission: FamilyPermissionLevel {
        switch self {
        case .partner, .parent: return .admin
        case .child:            return .viewOnly
        case .other:            return .viewOnly
        }
    }
}

enum AllowanceFrequency: String, Codable, CaseIterable {
    case weekly    = "Weekly"
    case biweekly  = "Biweekly"
    case monthly   = "Monthly"

    var daysInterval: Int {
        switch self {
        case .weekly:   return 7
        case .biweekly: return 14
        case .monthly:  return 30
        }
    }
}

// MARK: - Embedded Structs (Codable)

struct FamilyPermissionRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var resourceType: String       // "all", "accounts", "budget", "goals", "reports", "transactions"
    var resourceId: String? = nil  // nil = applies to all of that type
    var level: FamilyPermissionLevel
}

struct FamilyMemberData: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var email: String?
    var role: FamilyMemberRole = .partner
    var defaultPermission: FamilyPermissionLevel = .edit
    var permissions: [FamilyPermissionRecord] = []
    var avatarColorHex: String = "#0E9C8A"
    var isCurrentUser: Bool = false
    var joinedAt: Date = Date()

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    func permissionFor(resourceType: String, resourceId: String? = nil) -> FamilyPermissionLevel {
        if let specific = permissions.first(where: {
            $0.resourceType == resourceType && $0.resourceId == resourceId
        }) { return specific.level }
        if let typeLevel = permissions.first(where: {
            $0.resourceType == resourceType && $0.resourceId == nil
        }) { return typeLevel.level }
        if let allLevel = permissions.first(where: { $0.resourceType == "all" }) {
            return allLevel.level
        }
        return defaultPermission
    }
}

struct AllowancePayment: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var amount: Double
    var notes: String?
    var isConfirmed: Bool = true
}

struct SharedGoalContribution: Codable, Identifiable {
    var id: UUID = UUID()
    var memberId: String
    var memberName: String
    var amount: Double
    var date: Date
    var notes: String?
}

// MARK: - FamilyGroup @Model

@Model
final class FamilyGroup {
    var id: UUID = UUID()
    var name: String = "My Family"
    var adminName: String = ""
    var currency: String = "AED"
    var isActive: Bool = true
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var membersData: Data = Data()

    init(
        name: String = "My Family",
        adminName: String = "",
        currency: String = "AED"
    ) {
        self.name = name
        self.adminName = adminName
        self.currency = currency
    }

    var members: [FamilyMemberData] {
        get { (try? JSONDecoder().decode([FamilyMemberData].self, from: membersData)) ?? [] }
        set { membersData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var activeMembers: [FamilyMemberData] { members }

    func addMember(_ member: FamilyMemberData) {
        var current = members
        current.append(member)
        members = current
    }

    func removeMember(id: UUID) {
        members = members.filter { $0.id != id }
    }

    func updateMember(_ updated: FamilyMemberData) {
        var current = members
        if let idx = current.firstIndex(where: { $0.id == updated.id }) {
            current[idx] = updated
        }
        members = current
    }
}

// MARK: - ChildProfile @Model

@Model
final class ChildProfile {
    var id: UUID = UUID()
    var name: String = ""
    var dateOfBirth: Date?
    var monthlyAllowance: Double = 0
    var currency: String = "AED"
    var allowanceFrequencyRaw: String = AllowanceFrequency.monthly.rawValue
    var savingsGoalName: String = ""
    var savingsGoalAmount: Double = 0
    var currentSavings: Double = 0
    var colorHex: String = "#0E9C8A"
    var icon: String = "star.fill"
    var paymentsData: Data = Data()
    var isActive: Bool = true
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        name: String = "",
        dateOfBirth: Date? = nil,
        monthlyAllowance: Double = 0,
        currency: String = "AED",
        allowanceFrequency: AllowanceFrequency = .monthly,
        savingsGoalName: String = "",
        savingsGoalAmount: Double = 0,
        colorHex: String = "#0E9C8A",
        icon: String = "star.fill"
    ) {
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.monthlyAllowance = monthlyAllowance
        self.currency = currency
        self.allowanceFrequencyRaw = allowanceFrequency.rawValue
        self.savingsGoalName = savingsGoalName
        self.savingsGoalAmount = savingsGoalAmount
        self.colorHex = colorHex
        self.icon = icon
    }

    var allowanceFrequency: AllowanceFrequency {
        get { AllowanceFrequency(rawValue: allowanceFrequencyRaw) ?? .monthly }
        set { allowanceFrequencyRaw = newValue.rawValue }
    }

    var payments: [AllowancePayment] {
        get { (try? JSONDecoder().decode([AllowancePayment].self, from: paymentsData)) ?? [] }
        set { paymentsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var sortedPayments: [AllowancePayment] { payments.sorted { $0.date > $1.date } }

    var age: Int {
        guard let dob = dateOfBirth else { return 0 }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
    }

    var totalPaid: Double { payments.reduce(0) { $0 + $1.amount } }

    var savingsProgress: Double {
        guard savingsGoalAmount > 0 else { return 0 }
        return min(1.0, currentSavings / savingsGoalAmount)
    }

    var lastPaymentDate: Date? { payments.sorted { $0.date > $1.date }.first?.date }

    var isAllowanceDue: Bool {
        guard let last = lastPaymentDate else { return true }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return days >= allowanceFrequency.daysInterval
    }

    var nextDueDate: Date? {
        guard let last = lastPaymentDate else { return Date() }
        return Calendar.current.date(byAdding: .day, value: allowanceFrequency.daysInterval, to: last)
    }

    func addPayment(amount: Double, notes: String? = nil, isConfirmed: Bool = true) {
        var p = payments
        p.append(AllowancePayment(id: UUID(), date: Date(), amount: amount, notes: notes, isConfirmed: isConfirmed))
        payments = p
        if isConfirmed { currentSavings += amount * 0.1 }
    }
}

// MARK: - SharedFamilyGoal @Model

@Model
final class SharedFamilyGoal {
    var id: UUID = UUID()
    var name: String = ""
    var goalDescription: String = ""
    var targetAmount: Double = 0
    var currency: String = "AED"
    var targetDate: Date?
    var icon: String = "house.fill"
    var colorHex: String = "#0E9C8A"
    var isCompleted: Bool = false
    var isArchived: Bool = false
    var contributionsData: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        name: String = "",
        goalDescription: String = "",
        targetAmount: Double = 0,
        currency: String = "AED",
        targetDate: Date? = nil,
        icon: String = "house.fill",
        colorHex: String = "#0E9C8A"
    ) {
        self.name = name
        self.goalDescription = goalDescription
        self.targetAmount = targetAmount
        self.currency = currency
        self.targetDate = targetDate
        self.icon = icon
        self.colorHex = colorHex
    }

    var contributions: [SharedGoalContribution] {
        get { (try? JSONDecoder().decode([SharedGoalContribution].self, from: contributionsData)) ?? [] }
        set { contributionsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var totalContributed: Double { contributions.reduce(0) { $0 + $1.amount } }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1.0, totalContributed / targetAmount)
    }

    var remaining: Double { max(0, targetAmount - totalContributed) }

    var contributionsByMember: [String: Double] {
        var result: [String: Double] = [:]
        for c in contributions {
            result[c.memberName, default: 0] += c.amount
        }
        return result
    }

    var daysRemaining: Int? {
        guard let t = targetDate else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: t).day ?? 0)
    }

    var projectedCompletionDate: Date? {
        guard totalContributed > 0 else { return nil }
        let rem = targetAmount - totalContributed
        if rem <= 0 { return Date() }
        let months = max(1.0, Double(Calendar.current.dateComponents([.month], from: createdAt, to: Date()).month ?? 1))
        let monthly = totalContributed / months
        guard monthly > 0 else { return nil }
        return Calendar.current.date(byAdding: .month, value: Int(ceil(rem / monthly)), to: Date())
    }

    func addContribution(amount: Double, memberId: String, memberName: String, notes: String? = nil) {
        var cs = contributions
        cs.append(SharedGoalContribution(
            id: UUID(), memberId: memberId, memberName: memberName,
            amount: amount, date: Date(), notes: notes
        ))
        contributions = cs
        if totalContributed >= targetAmount { isCompleted = true }
        updatedAt = Date()
    }

    static let presets: [(name: String, icon: String, colorHex: String, targetAmount: Double)] = [
        ("Family Vacation", "airplane.departure", "#4A90D9", 10_000),
        ("New Home", "house.fill", "#1B8B4B", 100_000),
        ("Emergency Fund", "umbrella.fill", "#E8963C", 20_000),
        ("Car Purchase", "car.fill", "#9B59B6", 50_000),
        ("Education Fund", "graduationcap.fill", "#0E9C8A", 30_000),
        ("Wedding", "heart.fill", "#E74C3C", 25_000),
    ]
}
