import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

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
                                    currency: String, daysBefore: Int = 7, id: String) {
        schedule(
            identifier: "cc_\(id)",
            title: "Credit Card Payment Due",
            body: "\(cardName) minimum payment of \(minimumPayment.formatted(as: currency)) is due on \(dueDate.formatted)",
            dueDate: dueDate,
            daysBefore: daysBefore
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

    // MARK: – Budget alert (immediate)
    func scheduleBudgetAlert(categoryName: String, spent: Double, budget: Double, currency: String) {
        let content = UNMutableNotificationContent()
        let pct = Int((spent / budget) * 100)
        content.title = "Budget Alert — \(categoryName)"
        content.body = "You've used \(pct)% of your \(categoryName) budget (\(spent.formatted(as: currency)) of \(budget.formatted(as: currency)))"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "budget_\(categoryName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
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
        UNUserNotificationCenter.current().add(request)
    }
}
