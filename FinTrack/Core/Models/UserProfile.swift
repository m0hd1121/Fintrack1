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
    // Existing security
    var useBiometrics: Bool
    var usePIN: Bool
    var pinHash: String?
    var autoLockMinutes: Int
    var showBalanceOnDashboard: Bool
    var defaultCurrency: String
    // Advanced security
    var decoyPINHash: String?
    var hiddenModeEnabled: Bool
    var twoFactorEnabled: Bool
    var twoFactorSecret: String?
    var auditLogEnabled: Bool
    var encryptionEnabled: Bool
    // Existing notifications
    var notificationsEnabled: Bool
    var budgetAlertsEnabled: Bool
    var billRemindersEnabled: Bool
    var salaryReminderEnabled: Bool
    var reminderDaysBefore: Int
    // Extended notifications
    var lowBalanceAlertEnabled: Bool
    var lowBalanceThreshold: Double
    var largeTransactionAlertEnabled: Bool
    var largeTransactionThreshold: Double
    var goalMilestoneAlertEnabled: Bool
    var budgetAlertAt75: Bool
    var budgetAlertAt90: Bool
    var budgetAlertAt100: Bool
    var weeklyDigestEnabled: Bool
    var monthlyDigestEnabled: Bool
    var digestDayOfWeek: Int
    var digestDayOfMonth: Int
    var digestHour: Int
    // Appearance / sync
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
        decoyPINHash: String? = nil,
        hiddenModeEnabled: Bool = false,
        twoFactorEnabled: Bool = false,
        twoFactorSecret: String? = nil,
        auditLogEnabled: Bool = true,
        encryptionEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        budgetAlertsEnabled: Bool = true,
        billRemindersEnabled: Bool = true,
        salaryReminderEnabled: Bool = true,
        reminderDaysBefore: Int = 3,
        lowBalanceAlertEnabled: Bool = true,
        lowBalanceThreshold: Double = 100.0,
        largeTransactionAlertEnabled: Bool = true,
        largeTransactionThreshold: Double = 1000.0,
        goalMilestoneAlertEnabled: Bool = true,
        budgetAlertAt75: Bool = true,
        budgetAlertAt90: Bool = true,
        budgetAlertAt100: Bool = true,
        weeklyDigestEnabled: Bool = false,
        monthlyDigestEnabled: Bool = false,
        digestDayOfWeek: Int = 2,
        digestDayOfMonth: Int = 1,
        digestHour: Int = 9,
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
        self.decoyPINHash = decoyPINHash
        self.hiddenModeEnabled = hiddenModeEnabled
        self.twoFactorEnabled = twoFactorEnabled
        self.twoFactorSecret = twoFactorSecret
        self.auditLogEnabled = auditLogEnabled
        self.encryptionEnabled = encryptionEnabled
        self.notificationsEnabled = notificationsEnabled
        self.budgetAlertsEnabled = budgetAlertsEnabled
        self.billRemindersEnabled = billRemindersEnabled
        self.salaryReminderEnabled = salaryReminderEnabled
        self.reminderDaysBefore = reminderDaysBefore
        self.lowBalanceAlertEnabled = lowBalanceAlertEnabled
        self.lowBalanceThreshold = lowBalanceThreshold
        self.largeTransactionAlertEnabled = largeTransactionAlertEnabled
        self.largeTransactionThreshold = largeTransactionThreshold
        self.goalMilestoneAlertEnabled = goalMilestoneAlertEnabled
        self.budgetAlertAt75 = budgetAlertAt75
        self.budgetAlertAt90 = budgetAlertAt90
        self.budgetAlertAt100 = budgetAlertAt100
        self.weeklyDigestEnabled = weeklyDigestEnabled
        self.monthlyDigestEnabled = monthlyDigestEnabled
        self.digestDayOfWeek = digestDayOfWeek
        self.digestDayOfMonth = digestDayOfMonth
        self.digestHour = digestHour
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
