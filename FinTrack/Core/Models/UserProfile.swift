import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var email: String?
    var baseCurrency: String
    var language: AppLanguage
    var monthlyIncomeGoal: Double
    var monthlySavingsGoal: Double
    var avatarData: Data?
    var joinDate: Date
    var isPremium: Bool
    var hasCompletedOnboarding: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        email: String? = nil,
        baseCurrency: String = "AED",
        language: AppLanguage = .english,
        monthlyIncomeGoal: Double = 0,
        monthlySavingsGoal: Double = 0,
        isPremium: Bool = false,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.baseCurrency = baseCurrency
        self.language = language
        self.monthlyIncomeGoal = monthlyIncomeGoal
        self.monthlySavingsGoal = monthlySavingsGoal
        self.isPremium = isPremium
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.joinDate = Date()
    }
}

enum AppLanguage: String, Codable, CaseIterable {
    case english = "English"
    case arabic = "Arabic"

    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en")
        case .arabic: return Locale(identifier: "ar")
        }
    }

    var isRTL: Bool { self == .arabic }
}

@Model
final class AppSettings {
    var id: UUID
    var useBiometrics: Bool
    var usePIN: Bool
    var pinHash: String?
    var autoLockMinutes: Int
    var showBalanceOnDashboard: Bool
    var defaultCurrency: String
    var notificationsEnabled: Bool
    var budgetAlertsEnabled: Bool
    var billRemindersEnabled: Bool
    var salaryReminderEnabled: Bool
    var reminderDaysBefore: Int
    var cloudSyncEnabled: Bool
    var theme: AppTheme
    var accentColor: String

    init(
        id: UUID = UUID(),
        useBiometrics: Bool = true,
        usePIN: Bool = false,
        pinHash: String? = nil,
        autoLockMinutes: Int = 5,
        showBalanceOnDashboard: Bool = true,
        defaultCurrency: String = "AED",
        notificationsEnabled: Bool = true,
        budgetAlertsEnabled: Bool = true,
        billRemindersEnabled: Bool = true,
        salaryReminderEnabled: Bool = true,
        reminderDaysBefore: Int = 3,
        cloudSyncEnabled: Bool = false,
        theme: AppTheme = .system,
        accentColor: String = "blue"
    ) {
        self.id = id
        self.useBiometrics = useBiometrics
        self.usePIN = usePIN
        self.pinHash = pinHash
        self.autoLockMinutes = autoLockMinutes
        self.showBalanceOnDashboard = showBalanceOnDashboard
        self.defaultCurrency = defaultCurrency
        self.notificationsEnabled = notificationsEnabled
        self.budgetAlertsEnabled = budgetAlertsEnabled
        self.billRemindersEnabled = billRemindersEnabled
        self.salaryReminderEnabled = salaryReminderEnabled
        self.reminderDaysBefore = reminderDaysBefore
        self.cloudSyncEnabled = cloudSyncEnabled
        self.theme = theme
        self.accentColor = accentColor
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}
