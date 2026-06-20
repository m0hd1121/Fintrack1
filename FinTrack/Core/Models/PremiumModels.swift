import Foundation
import SwiftData

// MARK: - Retirement Plan

@Model
final class RetirementPlan {
    var id: UUID
    var currentAge: Int
    var targetRetirementAge: Int
    var currentSavings: Double
    var monthlyContribution: Double
    var expectedReturnRate: Double
    var expectedInflationRate: Double
    var targetMonthlyIncome: Double
    var currency: String
    var yearsOfServiceUAE: Int
    var monthlyBasicSalary: Double
    var lastUpdated: Date

    var yearsToRetirement: Int { max(0, targetRetirementAge - currentAge) }

    var projectedGratuity: Double {
        let dailyRate = monthlyBasicSalary / 30.0
        if yearsOfServiceUAE <= 5 {
            return dailyRate * 21 * Double(yearsOfServiceUAE)
        } else {
            return dailyRate * 21 * 5 + dailyRate * 30 * Double(yearsOfServiceUAE - 5)
        }
    }

    var projectedFutureValue: Double {
        let n = Double(yearsToRetirement) * 12
        let r = expectedReturnRate / 100.0 / 12.0
        if r == 0 { return currentSavings + monthlyContribution * n + projectedGratuity }
        let fvSavings = currentSavings * pow(1 + r, n)
        let fvContributions = monthlyContribution * ((pow(1 + r, n) - 1) / r)
        return fvSavings + fvContributions + projectedGratuity
    }

    var requiredNestEgg: Double {
        let realRate = (1 + expectedReturnRate / 100) / (1 + expectedInflationRate / 100) - 1
        let n = 25.0
        if realRate <= 0 { return targetMonthlyIncome * 12 * n }
        return targetMonthlyIncome * 12 * ((1 - pow(1 + realRate, -n)) / realRate)
    }

    var readinessScore: Double { min(1.0, projectedFutureValue / max(1, requiredNestEgg)) }

    var inflationAdjustedIncome: Double {
        let years = Double(yearsToRetirement)
        return targetMonthlyIncome * pow(1 + expectedInflationRate / 100, years)
    }

    init(
        id: UUID = UUID(),
        currentAge: Int = 30,
        targetRetirementAge: Int = 60,
        currentSavings: Double = 0,
        monthlyContribution: Double = 0,
        expectedReturnRate: Double = 7.0,
        expectedInflationRate: Double = 3.0,
        targetMonthlyIncome: Double = 0,
        currency: String = "AED",
        yearsOfServiceUAE: Int = 0,
        monthlyBasicSalary: Double = 0
    ) {
        self.id = id
        self.currentAge = currentAge
        self.targetRetirementAge = targetRetirementAge
        self.currentSavings = currentSavings
        self.monthlyContribution = monthlyContribution
        self.expectedReturnRate = expectedReturnRate
        self.expectedInflationRate = expectedInflationRate
        self.targetMonthlyIncome = targetMonthlyIncome
        self.currency = currency
        self.yearsOfServiceUAE = yearsOfServiceUAE
        self.monthlyBasicSalary = monthlyBasicSalary
        self.lastUpdated = Date()
    }
}

// MARK: - Life Event Planning

enum LifeEventType: String, Codable, CaseIterable {
    case marriage   = "Marriage"
    case baby       = "New Baby"
    case homeBuying = "Home Purchase"
    case jobChange  = "Job Change"
    case emigration = "Relocation"
    case education  = "Education"
    case retirement = "Retirement"
    case other      = "Other"

    var icon: String {
        switch self {
        case .marriage:   return "heart.fill"
        case .baby:       return "figure.2.and.child.holdinghands"
        case .homeBuying: return "house.fill"
        case .jobChange:  return "briefcase.fill"
        case .emigration: return "airplane"
        case .education:  return "graduationcap.fill"
        case .retirement: return "sun.max.fill"
        case .other:      return "star.fill"
        }
    }

    var defaultBudget: Double {
        switch self {
        case .marriage:   return 50000
        case .baby:       return 30000
        case .homeBuying: return 200000
        case .jobChange:  return 10000
        case .emigration: return 25000
        case .education:  return 80000
        case .retirement: return 500000
        case .other:      return 0
        }
    }

    var checklistItems: [String] {
        switch self {
        case .marriage:
            return ["Set wedding budget", "Book venue", "Arrange mahr/dowry", "Plan honeymoon", "Update legal documents", "Joint bank account"]
        case .baby:
            return ["Maternity/paternity leave plan", "Health insurance update", "Baby gear budget", "Childcare costs", "Education fund", "Will update"]
        case .homeBuying:
            return ["Down payment saved", "Mortgage pre-approval", "DLD fees budgeted (4%)", "Oqood registration", "Home inspection", "Moving costs"]
        case .jobChange:
            return ["Emergency fund (6 months)", "EOSG calculation", "Benefits comparison", "Visa/NOC arrangement", "Income gap plan", "Tax implications"]
        case .emigration:
            return ["Visa & residency fees", "Shipping costs", "School fees", "Currency transfer plan", "Health insurance abroad", "UAE bank account manage"]
        case .education:
            return ["Tuition fees budgeted", "Living expenses planned", "Scholarship research", "Student loan if needed", "Part-time income plan", "Return ROI analysis"]
        case .retirement:
            return ["EOSG claim", "Pension arrangement", "Healthcare plan", "Relocation decision", "Investment withdrawal strategy", "Estate planning update"]
        case .other:
            return ["Define goal", "Set budget", "Create timeline", "Track progress"]
        }
    }
}

struct LifeEventChecklistItem: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
}

@Model
final class LifeEventPlan {
    var id: UUID
    var eventTypeRaw: String
    var title: String
    var targetDate: Date
    var estimatedCost: Double
    var currency: String
    var savedAmount: Double
    var notes: String?
    var isCompleted: Bool
    var checklistData: Data

    var eventType: LifeEventType {
        get { LifeEventType(rawValue: eventTypeRaw) ?? .other }
        set { eventTypeRaw = newValue.rawValue }
    }

    var checklist: [LifeEventChecklistItem] {
        get { (try? JSONDecoder().decode([LifeEventChecklistItem].self, from: checklistData)) ?? [] }
        set { checklistData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var progress: Double { min(1.0, savedAmount / max(1, estimatedCost)) }
    var remaining: Double { max(0, estimatedCost - savedAmount) }

    var monthsUntilEvent: Int {
        max(0, Calendar.current.dateComponents([.month], from: Date(), to: targetDate).month ?? 0)
    }

    var requiredMonthlySaving: Double {
        let months = Double(max(1, monthsUntilEvent))
        return remaining / months
    }

    var completedChecklistCount: Int { checklist.filter(\.isCompleted).count }

    init(
        id: UUID = UUID(),
        eventType: LifeEventType = .other,
        title: String = "",
        targetDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
        estimatedCost: Double = 0,
        currency: String = "AED",
        savedAmount: Double = 0,
        notes: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.eventTypeRaw = eventType.rawValue
        self.title = title
        self.targetDate = targetDate
        self.estimatedCost = estimatedCost
        self.currency = currency
        self.savedAmount = savedAmount
        self.notes = notes
        self.isCompleted = isCompleted
        self.checklistData = Data()
    }
}

// MARK: - Advisor Access (Collaborative Planner)

enum AdvisorRole: String, Codable, CaseIterable {
    case readOnly  = "Read-Only"
    case advisor   = "Advisor"

    var icon: String {
        switch self {
        case .readOnly: return "eye"
        case .advisor:  return "person.badge.shield.checkmark"
        }
    }

    var description: String {
        switch self {
        case .readOnly: return "View financial summary only"
        case .advisor:  return "View all data and add notes"
        }
    }
}

@Model
final class AdvisorAccess {
    var id: UUID
    var advisorName: String
    var advisorEmail: String
    var roleRaw: String
    var invitedDate: Date
    var lastAccessDate: Date?
    var isActive: Bool
    var accessCode: String
    var canViewTransactions: Bool
    var canViewAccounts: Bool
    var canViewGoals: Bool
    var canViewDebts: Bool
    var canAddNotes: Bool
    var notesData: Data

    var role: AdvisorRole {
        get { AdvisorRole(rawValue: roleRaw) ?? .readOnly }
        set { roleRaw = newValue.rawValue }
    }

    var notes: [AdvisorNote] {
        get { (try? JSONDecoder().decode([AdvisorNote].self, from: notesData)) ?? [] }
        set { notesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(
        id: UUID = UUID(),
        advisorName: String = "",
        advisorEmail: String = "",
        role: AdvisorRole = .readOnly,
        isActive: Bool = true,
        canViewTransactions: Bool = true,
        canViewAccounts: Bool = true,
        canViewGoals: Bool = true,
        canViewDebts: Bool = false,
        canAddNotes: Bool = false
    ) {
        self.id = id
        self.advisorName = advisorName
        self.advisorEmail = advisorEmail
        self.roleRaw = role.rawValue
        self.invitedDate = Date()
        self.lastAccessDate = nil
        self.isActive = isActive
        self.accessCode = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
        self.canViewTransactions = canViewTransactions
        self.canViewAccounts = canViewAccounts
        self.canViewGoals = canViewGoals
        self.canViewDebts = canViewDebts
        self.canAddNotes = canAddNotes
        self.notesData = Data()
    }
}

struct AdvisorNote: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var content: String
    var advisorName: String
}
