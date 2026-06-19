import Foundation
import UserNotifications

// MARK: - BillWasteAnalysis

struct BillWasteAnalysis {
    let bill: Bill
    let daysSinceLastMatch: Int
    let confidence: Double   // 0–1
    let isLikelyUnused: Bool

    /// Human-readable suggestion shown in the UI.
    var suggestion: String {
        if daysSinceLastMatch == 0 {
            return "You haven't used \(bill.name) (\(bill.amount.formatted(as: bill.currency))) recently."
        }
        return "You haven't used \(bill.name) (\(bill.amount.formatted(as: bill.currency))) in \(daysSinceLastMatch) days. Consider cancelling to save money."
    }
}

// MARK: - BillService

final class BillService {

    static let shared = BillService()
    private init() {}

    // MARK: - Payment Recording

    /// Records a payment for a bill, advancing the due date and rescheduling reminders.
    func recordPayment(bill: Bill, amount: Double, date: Date = Date()) {
        // Capture old amount into price history if it changed meaningfully
        if abs(amount - bill.amount) > 0.01 {
            let entry = PriceHistoryEntry(
                amount: bill.amount,
                date: date,
                note: "Previous amount before payment on \(date.formatted)"
            )
            bill.priceHistory.append(entry)
            bill.amount = amount
        }

        // Update payment tracking fields
        bill.lastPaidDate = date
        bill.lastPaidAmount = amount

        // Reset alert state
        bill.notifiedAutoPayMissed = false
        bill.notifiedOverdueDateRaw = nil

        // Advance next due date by one billing cycle
        if let advanced = Calendar.current.date(
            byAdding: bill.billingCycle.interval,
            to: bill.nextDueDate
        ) {
            bill.nextDueDate = advanced
        }

        // Reschedule reminders for the new due date
        cancelReminders(for: bill)
        scheduleReminders(for: bill)
    }

    // MARK: - Reminder Scheduling

    /// Schedules a reminder notification for each entry in `bill.reminderDaysBefore`.
    func scheduleReminders(for bill: Bill) {
        cancelReminders(for: bill)
        for days in bill.reminderDaysBefore {
            NotificationService.shared.scheduleBillReminder(
                name: bill.name,
                amount: bill.amount,
                currency: bill.currency,
                dueDate: bill.nextDueDate,
                daysBefore: days,
                id: "\(bill.id.uuidString)_\(days)"
            )
        }
    }

    /// Removes all pending reminders that were scheduled for the given bill.
    func cancelReminders(for bill: Bill) {
        var identifiers = bill.reminderDaysBefore.map { days in
            "bill_\(bill.id.uuidString)_\(days)"
        }
        identifiers.append("bill_overdue_\(bill.id.uuidString)")
        identifiers.append("bill_autopay_\(bill.id.uuidString)")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Reschedules reminders for every active bill in the provided list.
    func scheduleAllReminders(for bills: [Bill]) {
        for bill in bills where bill.isActive {
            scheduleReminders(for: bill)
        }
    }

    // MARK: - AutoPay Missed Detection

    /// Returns `true` when an auto-pay bill is overdue and no matching transaction was found
    /// inside the expected auto-pay window.
    func isAutoPayMissed(bill: Bill, transactions: [Transaction]) -> Bool {
        guard bill.isAutoPay && bill.isOverdue else { return false }

        guard let windowEnd = Calendar.current.date(
            byAdding: .day,
            value: bill.autoPayWindowDays,
            to: bill.nextDueDate
        ) else { return false }

        guard Date() > windowEnd else { return false }

        guard let windowStart = Calendar.current.date(
            byAdding: .day,
            value: -2,
            to: bill.nextDueDate
        ) else { return false }

        let billNameLower     = bill.name.lowercased()
        let providerLower     = bill.provider?.lowercased()

        let matched = transactions.contains { tx in
            guard tx.type == .expense else { return false }
            guard tx.date >= windowStart && tx.date <= windowEnd else { return false }

            let txTitleLower    = tx.title.lowercased()
            let txMerchantLower = tx.merchant?.lowercased()

            let nameMatch =
                txTitleLower.contains(billNameLower) ||
                billNameLower.contains(txTitleLower)

            let providerMatch: Bool = {
                guard let prov = providerLower else { return false }
                return txMerchantLower?.contains(prov) ?? false
            }()

            return nameMatch || providerMatch
        }

        return !matched
    }

    // MARK: - Waste Analysis

    /// Analyses whether a subscription appears to be unused by looking for matching
    /// transactions in recent history.
    func analyzeWaste(bill: Bill, transactions: [Transaction]) -> BillWasteAnalysis {
        guard bill.isSubscription else {
            return BillWasteAnalysis(
                bill: bill,
                daysSinceLastMatch: 0,
                confidence: 0.0,
                isLikelyUnused: false
            )
        }

        // Look back at least 30 days, or double the billing-cycle length
        let cycleApproxDays: Int = {
            let comps = bill.billingCycle.interval
            if let d = comps.day   { return d }
            if let m = comps.month { return m * 30 }
            if let y = comps.year  { return y * 365 }
            return 30
        }()
        let lookbackDays = max(30, cycleApproxDays * 2)

        guard let windowStart = Calendar.current.date(
            byAdding: .day,
            value: -lookbackDays,
            to: Date()
        ) else {
            return BillWasteAnalysis(
                bill: bill,
                daysSinceLastMatch: lookbackDays,
                confidence: 0.85,
                isLikelyUnused: true
            )
        }

        let billNameLower  = bill.name.lowercased()
        let providerLower  = bill.provider?.lowercased()

        let recentTransactions = transactions.filter { $0.date >= windowStart }

        // Find the most-recent matching transaction
        let latestMatch: Transaction? = recentTransactions
            .filter { tx in
                let txTitleLower    = tx.title.lowercased()
                let txMerchantLower = tx.merchant?.lowercased()

                let nameMatch =
                    txTitleLower.contains(billNameLower) ||
                    billNameLower.contains(txTitleLower)

                let providerMatch: Bool = {
                    guard let prov = providerLower else { return false }
                    return txMerchantLower?.contains(prov) ?? false
                }()

                return nameMatch || providerMatch
            }
            .max(by: { $0.date < $1.date })

        let referenceDate: Date = latestMatch?.date ?? bill.createdAt
        let daysSince = max(0, Calendar.current.dateComponents([.day], from: referenceDate, to: Date()).day ?? 0)

        let confidence: Double
        if latestMatch == nil && daysSince > 60 {
            confidence = 0.85
        } else if daysSince > 30 {
            confidence = 0.65
        } else if daysSince > 0 {
            confidence = 0.35
        } else {
            confidence = 0.0
        }

        return BillWasteAnalysis(
            bill: bill,
            daysSinceLastMatch: daysSince,
            confidence: confidence,
            isLikelyUnused: confidence >= 0.6
        )
    }

    // MARK: - Unified Alert Check

    /// Runs all alert checks for the active bills and fires notifications as needed.
    func checkAllAlerts(bills: [Bill], transactions: [Transaction], currency: String) {
        let active = bills.filter { $0.isActive }
        checkLatePayments(bills: active, currency: currency)
        checkAutoPayMissed(bills: active, transactions: transactions)
        checkPriceChanges(bills: active)
    }

    // MARK: - Individual Alert Checks (private)

    private func checkLatePayments(bills: [Bill], currency: String) {
        let calendar = Calendar.current
        for bill in bills where bill.isOverdue {
            let dueDayStart = calendar.startOfDay(for: bill.nextDueDate)
            // Fire once per due-date day
            if let notified = bill.notifiedOverdueDateRaw,
               calendar.startOfDay(for: notified) == dueDayStart {
                continue
            }
            sendLatePaymentAlert(bill: bill, currency: currency)
            bill.notifiedOverdueDateRaw = dueDayStart
        }
    }

    private func checkAutoPayMissed(bills: [Bill], transactions: [Transaction]) {
        for bill in bills where bill.isAutoPay && !bill.notifiedAutoPayMissed {
            guard isAutoPayMissed(bill: bill, transactions: transactions) else { continue }
            sendAutoPayMissedAlert(bill: bill)
            bill.notifiedAutoPayMissed = true
        }
    }

    private func checkPriceChanges(bills: [Bill]) {
        for bill in bills {
            let result = detectPriceChange(for: bill)
            guard result.changed, let pct = result.changePercent as Double?, pct > 0 else { continue }
            sendPriceChangeAlert(bill: bill, previousAmount: result.previousAmount, changePercent: pct)
        }
    }

    // MARK: - Price Change Detection

    /// Detects whether the bill's current amount differs from the most recent price-history entry.
    func detectPriceChange(for bill: Bill) -> (changed: Bool, previousAmount: Double?, changePercent: Double) {
        guard let previous = bill.priceHistory.last?.amount else {
            return (false, nil, 0)
        }
        let delta = bill.amount - previous
        guard abs(delta) > 0.001 else {
            return (false, previous, 0)
        }
        let changePercent = previous > 0 ? (delta / previous) * 100.0 : 0
        return (true, previous, changePercent)
    }

    // MARK: - Notification Senders (private)

    private func sendLatePaymentAlert(bill: Bill, currency: String) {
        let content = UNMutableNotificationContent()
        content.title = "Bill Overdue"
        content.body = "\(bill.name) (\(bill.amount.formatted(as: bill.currency))) was due on \(bill.nextDueDate.formatted). Please make a payment."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "bill_overdue_\(bill.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func sendAutoPayMissedAlert(bill: Bill) {
        let content = UNMutableNotificationContent()
        content.title = "Auto-Pay May Have Failed"
        content.body = "\(bill.name) (\(bill.amount.formatted(as: bill.currency))) was due on \(bill.nextDueDate.formatted) but no matching payment was detected."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "bill_autopay_\(bill.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func sendPriceChangeAlert(bill: Bill, previousAmount: Double?, changePercent: Double) {
        let content = UNMutableNotificationContent()
        let prevText = previousAmount.map { $0.formatted(as: bill.currency) } ?? "previous amount"
        let direction = changePercent > 0 ? "increased" : "decreased"
        let pctText = String(format: "%.1f%%", abs(changePercent))
        content.title = "Bill Price Changed — \(bill.name)"
        content.body = "\(bill.name) has \(direction) by \(pctText): \(prevText) → \(bill.amount.formatted(as: bill.currency))."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "bill_pricechange_\(bill.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
