import Foundation
import UserNotifications

/// Mirror of the notification toggles in `AppSettings`. Services that post
/// alerts have no model context, so `NotificationSettingsView` and `RootView`
/// copy the settings here (UserDefaults.standard) and every request goes
/// through `deliver(_:)`, which drops the ones the user turned off.
struct NotificationPreferences: Codable, Equatable {
    var notificationsEnabled = true
    var billReminders = true
    var reminderDaysBefore = 3
    var budgetAlerts = true
    var budgetAt75 = true
    var budgetAt90 = true
    var budgetAt100 = true
    var salaryReminders = true
    var lowBalance = true
    var lowBalanceThreshold = 100.0
    var largeTransaction = true
    var largeTransactionThreshold = 1000.0
    var goalMilestones = true
    var weeklyDigest = false
    var monthlyDigest = false
    var digestDayOfWeek = 2
    var digestDayOfMonth = 1
    var digestHour = 9

    init() {}

    init(_ s: AppSettings) {
        notificationsEnabled = s.notificationsEnabled
        billReminders = s.billRemindersEnabled
        reminderDaysBefore = s.reminderDaysBefore
        budgetAlerts = s.budgetAlertsEnabled
        budgetAt75 = s.budgetAlertAt75
        budgetAt90 = s.budgetAlertAt90
        budgetAt100 = s.budgetAlertAt100
        salaryReminders = s.salaryReminderEnabled
        lowBalance = s.lowBalanceAlertEnabled
        lowBalanceThreshold = s.lowBalanceThreshold
        largeTransaction = s.largeTransactionAlertEnabled
        largeTransactionThreshold = s.largeTransactionThreshold
        goalMilestones = s.goalMilestoneAlertEnabled
        weeklyDigest = s.weeklyDigestEnabled
        monthlyDigest = s.monthlyDigestEnabled
        digestDayOfWeek = s.digestDayOfWeek
        digestDayOfMonth = s.digestDayOfMonth
        digestHour = s.digestHour
    }
}

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private static let preferencesKey = "ft_notification_preferences"

    var preferences: NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: Self.preferencesKey),
              let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return NotificationPreferences() }
        return prefs
    }

    /// Copies the user's notification settings and re-applies them: digests
    /// are (re)scheduled for the chosen day/hour, and turning a category off
    /// removes its pending reminders.
    func apply(settings: AppSettings) {
        let prefs = NotificationPreferences(settings)
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: Self.preferencesKey)
        }
        rescheduleDigests(prefs)
        var disabledPrefixes: [String] = []
        if !prefs.notificationsEnabled {
            disabledPrefixes = [""]
        } else {
            if !prefs.billReminders { disabledPrefixes += ["bill_", "cc_", "loan_", "bnpl_", "cheque_"] }
            if !prefs.salaryReminders { disabledPrefixes += ["salary_"] }
            if !prefs.goalMilestones { disabledPrefixes += ["goal_"] }
        }
        guard !disabledPrefixes.isEmpty else { return }
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { id in
                disabledPrefixes.contains { id.hasPrefix($0) }
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Used by Clear All Data.
    func resetPreferences() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.preferencesKey)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("ft_budget_alert_") {
            defaults.removeObject(forKey: key)
        }
    }

    /// Whether a request with this identifier is allowed by the user's settings.
    private func isAllowed(_ identifier: String) -> Bool {
        let p = preferences
        guard p.notificationsEnabled else { return false }
        let id = identifier
        if ["bill_", "cc_", "loan_", "bnpl_", "cheque_"].contains(where: id.hasPrefix) { return p.billReminders }
        if id.hasPrefix("budget_") { return p.budgetAlerts }
        if id.hasPrefix("salary_") { return p.salaryReminders }
        if id.hasPrefix("minbal_") || id.hasPrefix("lowbal_") { return p.lowBalance }
        if id.hasPrefix("large_tx_") { return p.largeTransaction }
        if id.hasPrefix("goal_milestone_") || id.hasPrefix("goal_completed_") { return p.goalMilestones }
        return true
    }

    private func deliver(_ request: UNNotificationRequest) {
        guard isAllowed(request.identifier) else { return }
        UNUserNotificationCenter.current().add(request)
    }

    private func rescheduleDigests(_ p: NotificationPreferences) {
        cancelNotification(id: "weekly_digest")
        cancelNotification(id: "monthly_digest")
        guard p.notificationsEnabled else { return }
        if p.weeklyDigest {
            let content = UNMutableNotificationContent()
            content.title = "Your Weekly FinTrack Digest"
            content.body = "Review your spending summary and financial highlights from the past week."
            content.sound = .default
            var comps = DateComponents()
            comps.weekday = p.digestDayOfWeek
            comps.hour = p.digestHour
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            deliver(UNNotificationRequest(identifier: "weekly_digest", content: content, trigger: trigger))
        }
        if p.monthlyDigest {
            let content = UNMutableNotificationContent()
            content.title = "Your Monthly FinTrack Report"
            content.body = "Your financial month in review — income, spending, savings, and more."
            content.sound = .default
            var comps = DateComponents()
            comps.day = p.digestDayOfMonth
            comps.hour = p.digestHour
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            deliver(UNNotificationRequest(identifier: "monthly_digest", content: content, trigger: trigger))
        }
    }

    /// Large-transaction and low-balance alerts for a just-saved transaction.
    /// Thresholds are entered in the base currency: pass the amount converted
    /// to it; the account balance is converted before comparing.
    func checkTransactionAlerts(title: String, amount: Double, currency: String, account: Account?) {
        let p = preferences
        if p.largeTransaction, amount >= p.largeTransactionThreshold {
            sendLargeTransactionAlert(title: title, amount: amount, currency: currency,
                                      accountName: account?.name ?? "No account")
        }
        if let account, p.lowBalance,
           CurrencyService.shared.convert(account.balance, from: account.currency, to: currency) < p.lowBalanceThreshold,
           !(account.minimumBalanceEnabled && account.balance < account.minimumBalance) {
            sendLowBalanceAlert(accountName: account.name,
                                balance: CurrencyService.shared.convert(account.balance, from: account.currency, to: currency),
                                threshold: p.lowBalanceThreshold, currency: currency)
        }
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: – Bill reminder
    func scheduleBillReminder(name: String, amount: Double, currency: String,
                              dueDate: Date, daysBefore: Int = 3, id: String) {
        schedule(
            identifier: "bill_\(id)",
            title: "Bill Due Soon",
            body: "\(name) — \(amount.formatted(as: currency)) is due on \(dueDate.formatted)",
            dueDate: dueDate,
            daysBefore: daysBefore
        )
    }

    // MARK: – Loan reminder (#21 configurable days)
    func scheduleLoanReminder(loanName: String, emiAmount: Double, currency: String,
                              dueDate: Date, daysBefore: Int = 3, id: String) {
        schedule(
            identifier: "loan_\(id)",
            title: "Loan Payment Due",
            body: "\(loanName) EMI of \(emiAmount.formatted(as: currency)) is due on \(dueDate.formatted)",
            dueDate: dueDate,
            daysBefore: daysBefore
        )
    }

    // MARK: – Credit card reminder
    func scheduleCreditCardReminder(cardName: String, dueDate: Date, minimumPayment: Double,
                                    currency: String, daysBefore: Int? = nil, id: String) {
        schedule(
            identifier: "cc_\(id)",
            title: "Credit Card Payment Due",
            body: "\(cardName) minimum payment of \(minimumPayment.formatted(as: currency)) is due on \(dueDate.formatted)",
            dueDate: dueDate,
            daysBefore: daysBefore ?? preferences.reminderDaysBefore
        )
    }

    // MARK: – BNPL reminder
    func scheduleBNPLReminder(planName: String, amount: Double, currency: String,
                               dueDate: Date, daysBefore: Int = 2, id: String) {
        schedule(
            identifier: "bnpl_\(id)",
            title: "BNPL Payment Due",
            body: "\(planName) installment of \(amount.formatted(as: currency)) is due on \(dueDate.formatted)",
            dueDate: dueDate,
            daysBefore: daysBefore
        )
    }

    // MARK: – Cheque reminder
    func scheduleChequeReminder(chequeNumber: String?, amount: Double, currency: String,
                                 chequeDate: Date, daysBefore: Int = 3, id: String) {
        let label = (chequeNumber?.isEmpty == false) ? "Cheque #\(chequeNumber!)" : "Cheque"
        schedule(
            identifier: "cheque_\(id)",
            title: "Cheque Due Soon",
            body: "\(label) for \(amount.formatted(as: currency)) is due on \(chequeDate.formatted)",
            dueDate: chequeDate,
            daysBefore: daysBefore
        )
    }

    // MARK: – Budget alert (immediate)
    func scheduleBudgetAlert(categoryName: String, spent: Double, budget: Double, currency: String) {
        guard budget > 0 else { return }
        let ratio = spent / budget
        let p = preferences
        let level: Int
        if ratio >= 1.0, p.budgetAt100 { level = 100 }
        else if ratio >= 0.9, p.budgetAt90 { level = 90 }
        else if ratio >= 0.75, p.budgetAt75 { level = 75 }
        else { return }
        // One alert per budget, level and month — not one per transaction.
        let month = Calendar.current.dateComponents([.year, .month], from: Date())
        let sentKey = "ft_budget_alert_\(categoryName)_\(month.year ?? 0)_\(month.month ?? 0)"
        guard UserDefaults.standard.integer(forKey: sentKey) < level else { return }
        UserDefaults.standard.set(level, forKey: sentKey)
        let content = UNMutableNotificationContent()
        let pct = Int(ratio * 100)
        content.title = "Budget Alert — \(categoryName)"
        content.body = "You've used \(pct)% of your \(categoryName) budget (\(spent.formatted(as: currency)) of \(budget.formatted(as: currency)))"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "budget_\(categoryName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Gift card expiry reminder
    func scheduleGiftCardExpiry(merchant: String, balance: Double, currency: String,
                                expiryDate: Date, id: String) {
        schedule(
            identifier: "giftcard_\(id)",
            title: "Gift Card Expiring Soon",
            body: "\(merchant) gift card (\(balance.formatted(as: currency)) remaining) expires on \(expiryDate.formatted).",
            dueDate: expiryDate,
            daysBefore: 14
        )
    }

    // MARK: – Loyalty program expiry reminder
    func scheduleLoyaltyExpiry(programName: String, points: Double, pointsLabel: String,
                               expiryDate: Date, id: String) {
        schedule(
            identifier: "loyalty_\(id)",
            title: "Loyalty Points Expiring",
            body: "\(programName): \(Int(points)) \(pointsLabel) expire on \(expiryDate.formatted). Use them before they're gone!",
            dueDate: expiryDate,
            daysBefore: 30
        )
    }

    // MARK: – #22 Minimum balance alert
    func sendMinimumBalanceAlert(accountName: String, balance: Double, minimum: Double, currency: String) {
        let content = UNMutableNotificationContent()
        content.title = "Low Balance Warning ⚠️"
        content.body = "\(accountName) balance \(balance.formatted(as: currency)) is below minimum \(minimum.formatted(as: currency)). Top up to avoid bank fees."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "minbal_\(accountName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Salary reminder
    func scheduleSalaryReminder(recordId: String, employerName: String, expectedAmount: Double,
                                currency: String, paymentDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Salary Expected Tomorrow"
        content.body = "\(employerName) salary of \(expectedAmount.formatted(as: currency)) expected tomorrow."
        content.sound = .default
        guard let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: paymentDate),
              triggerDate > Date() else { return }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "salary_\(recordId)", content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Salary not received alert
    func sendSalaryNotReceivedAlert(employerName: String, expectedAmount: Double, currency: String, daysLate: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Salary Not Received ⚠️"
        content.body = "\(employerName) salary of \(expectedAmount.formatted(as: currency)) is \(daysLate) day\(daysLate == 1 ? "" : "s") late. Check with your employer."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "salary_late_\(employerName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Freelance invoice overdue
    func sendInvoiceOverdueAlert(clientName: String, invoiceNumber: String, amount: Double, currency: String) {
        let content = UNMutableNotificationContent()
        content.title = "Invoice Overdue"
        content.body = "Invoice #\(invoiceNumber) from \(clientName) for \(amount.formatted(as: currency)) is overdue."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "invoice_overdue_\(invoiceNumber.replacingOccurrences(of: "#", with: ""))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Rent late alert
    func sendRentLateAlert(propertyName: String, tenantName: String, amount: Double, currency: String) {
        let content = UNMutableNotificationContent()
        content.title = "Rent Payment Overdue"
        content.body = "\(propertyName): Rent of \(amount.formatted(as: currency)) from \(tenantName) is overdue."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "rent_late_\(propertyName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Money lent reminder
    func scheduleLentReminder(id: String, borrowerName: String, amount: Double,
                              currency: String, dueDate: Date, daysBefore: Int = 3) {
        schedule(
            identifier: "lent_\(id)",
            title: "Repayment Due Soon",
            body: "\(borrowerName) owes you \(amount.formatted(as: currency)) — due on \(dueDate.formatted).",
            dueDate: dueDate,
            daysBefore: daysBefore
        )
    }

    // MARK: – Money borrowed reminder
    func scheduleBorrowedReminder(id: String, lenderName: String, amount: Double,
                                  currency: String, dueDate: Date, daysBefore: Int = 3) {
        schedule(
            identifier: "borrowed_\(id)",
            title: "Debt Repayment Due",
            body: "You owe \(lenderName) \(amount.formatted(as: currency)) — due on \(dueDate.formatted).",
            dueDate: dueDate,
            daysBefore: daysBefore
        )
    }

    // MARK: – Credit utilization alert (immediate)
    func sendHighUtilizationAlert(cardName: String, utilization: Double) {
        let content = UNMutableNotificationContent()
        content.title = "High Credit Utilization ⚠️"
        content.body = "\(cardName) is at \(Int(utilization * 100))% utilization. Consider paying down the balance to protect your credit score."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "utilization_\(cardName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Savings Goal Milestone

    func scheduleSavingsGoalMilestone(goal: SavingsGoal, milestone: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Savings Milestone!"
        content.body = "'\(goal.name)' is now \(Int(milestone * 100))% funded. Keep going!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "goal_milestone_\(goal.id.uuidString)_\(Int(milestone * 100))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Savings Goal Completed

    func sendGoalCompletedAlert(goalName: String, amount: Double, currency: String) {
        let content = UNMutableNotificationContent()
        content.title = "Goal Reached! \u{1F389}"
        content.body = "Congratulations! You've reached your '\(goalName)' goal of \(amount.formatted(as: currency))."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "goal_completed_\(goalName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Auto-Contribution Reminder

    func scheduleSavingsGoalContributionReminder(
        goal: SavingsGoal,
        frequency: GoalContributionFrequency,
        dayOfMonth: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Savings Contribution Due"
        content.body = "Time to contribute \(goal.autoContributionAmount.formatted(as: goal.currency)) to '\(goal.name)'."
        content.sound = .default

        var components = DateComponents()
        switch frequency {
        case .monthly:
            components.day = dayOfMonth
            components.hour = 9
        case .weekly:
            components.weekday = 2  // Monday
            components.hour = 9
        case .biWeekly:
            components.weekday = 2
            components.hour = 9
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let id = "goal_contribution_\(goal.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Large Transaction Alert

    func sendLargeTransactionAlert(title: String, amount: Double, currency: String, accountName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Large Transaction Detected"
        content.body = "\(title): \(amount.formatted(as: currency)) charged to \(accountName)"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "large_tx_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Low Balance Alert (threshold-based)

    func sendLowBalanceAlert(accountName: String, balance: Double, threshold: Double, currency: String) {
        let content = UNMutableNotificationContent()
        content.title = "Low Balance: \(accountName)"
        content.body = "Balance \(balance.formatted(as: currency)) has fallen below your alert threshold of \(threshold.formatted(as: currency))."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "lowbal_threshold_\(accountName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – Email Import Alert

    func sendEmailImportAlert(merchant: String, amount: Double, currency: String,
                              category: String, autoApproved: Bool, pendingReviewCount: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = autoApproved ? "Transaction Imported" : "Transaction Needs Review"
        content.body = autoApproved
            ? "\(merchant): \(amount.formatted(as: currency)) · \(category) — added automatically"
            : "\(merchant): \(amount.formatted(as: currency)) · \(category) — waiting in your review queue"
        content.sound = .default
        if pendingReviewCount > 0 {
            content.badge = NSNumber(value: pendingReviewCount)
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "email_import_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        deliver(request)
    }

    // MARK: – App icon badge

    /// Keeps the app-icon badge honest. `sendEmailImportAlert` stamps a badge
    /// number onto its notification, and iOS leaves that number on the icon
    /// forever unless someone resets it — so the app syncs the badge to the
    /// number of transactions actually waiting in the review queue (0 clears
    /// it) whenever it becomes active or that queue changes.
    func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(max(0, count))
    }

    // MARK: – Helpers
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func schedule(identifier: String, title: String, body: String,
                          dueDate: Date, daysBefore: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        guard let triggerDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: dueDate),
              triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        deliver(request)
    }
}
