// FinTrackWidget.swift
// Widget Extension — Balance, Budget, Bills, Lock Screen & Live Activity widgets.
//
// Setup in Xcode:
//   1. Add Widget Extension target "FinTrackWidget" (product bundle: com.mohd.fintrackpro.FinTrackWidget)
//   2. Add App Group "group.com.fintrack.shared" to both the app and widget targets
//   3. Add NSSupportsLiveActivities = YES in the extension's Info.plist
//   4. Delete generated widget file and use this one
//
// All data is read from the shared App Group UserDefaults written by WidgetDataService.

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: – Shared data models (mirror WidgetDataService types)

struct WidgetTransaction: Codable, Identifiable {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var type: String
    var date: Date
    var categoryIcon: String
}

struct WidgetBudget: Codable, Identifiable {
    var id: UUID
    var name: String
    var spent: Double
    var total: Double
    var currency: String
    var color: String
    var icon: String

    var progress: Double { total > 0 ? min(spent / total, 1.0) : 0 }
    var remaining: Double { max(total - spent, 0) }
    var isOverBudget: Bool { spent > total }
}

struct WidgetBill: Codable, Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var currency: String
    var dueDate: Date
    var icon: String
    var isPaid: Bool

    var daysUntilDue: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: dueDate)
        ).day ?? 0
    }
}

// MARK: – App Group reader

private let appGroupID = "group.com.fintrack.shared"

private func loadDefaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupID)
}

private func netWorth() -> Double { loadDefaults()?.double(forKey: "widget_net_worth") ?? 0 }
private func currency() -> String { loadDefaults()?.string(forKey: "widget_currency") ?? "AED" }

private func transactions() -> [WidgetTransaction] {
    guard let data = loadDefaults()?.data(forKey: "widget_recent_transactions"),
          let items = try? JSONDecoder().decode([WidgetTransaction].self, from: data)
    else { return [] }
    return items
}

private func budgets() -> [WidgetBudget] {
    guard let data = loadDefaults()?.data(forKey: "widget_budgets"),
          let items = try? JSONDecoder().decode([WidgetBudget].self, from: data)
    else { return [] }
    return items
}

private func bills() -> [WidgetBill] {
    guard let data = loadDefaults()?.data(forKey: "widget_bills"),
          let items = try? JSONDecoder().decode([WidgetBill].self, from: data)
    else { return [] }
    return items.filter { !$0.isPaid }.sorted { $0.dueDate < $1.dueDate }
}

// MARK: – Sample data

private func sampleTransactions() -> [WidgetTransaction] {
    [
        WidgetTransaction(id: UUID(), title: "Salary", amount: 15_000, currency: "AED", type: "income", date: Date(), categoryIcon: "briefcase.fill"),
        WidgetTransaction(id: UUID(), title: "Groceries", amount: 250, currency: "AED", type: "expense", date: Date().addingTimeInterval(-3600), categoryIcon: "cart.fill"),
        WidgetTransaction(id: UUID(), title: "Netflix", amount: 45, currency: "AED", type: "expense", date: Date().addingTimeInterval(-7200), categoryIcon: "play.tv.fill"),
        WidgetTransaction(id: UUID(), title: "Gym", amount: 120, currency: "AED", type: "expense", date: Date().addingTimeInterval(-10800), categoryIcon: "figure.run"),
        WidgetTransaction(id: UUID(), title: "Freelance", amount: 3000, currency: "AED", type: "income", date: Date().addingTimeInterval(-14400), categoryIcon: "laptopcomputer"),
    ]
}

private func sampleBudgets() -> [WidgetBudget] {
    [
        WidgetBudget(id: UUID(), name: "Groceries", spent: 1200, total: 2000, currency: "AED", color: "#0E9C8A", icon: "cart.fill"),
        WidgetBudget(id: UUID(), name: "Dining", spent: 850, total: 800, currency: "AED", color: "#E85D5D", icon: "fork.knife"),
        WidgetBudget(id: UUID(), name: "Transport", spent: 300, total: 600, currency: "AED", color: "#6B6BF8", icon: "car.fill"),
    ]
}

private func sampleBills() -> [WidgetBill] {
    let cal = Calendar.current
    return [
        WidgetBill(id: UUID(), name: "DEWA", amount: 450, currency: "AED", dueDate: cal.date(byAdding: .day, value: 3, to: Date())!, icon: "bolt.fill", isPaid: false),
        WidgetBill(id: UUID(), name: "Etisalat", amount: 250, currency: "AED", dueDate: cal.date(byAdding: .day, value: 7, to: Date())!, icon: "wifi", isPaid: false),
        WidgetBill(id: UUID(), name: "Netflix", amount: 45, currency: "AED", dueDate: cal.date(byAdding: .day, value: 14, to: Date())!, icon: "play.tv.fill", isPaid: false),
    ]
}

// MARK: – Timeline Entry

struct FinTrackEntry: TimelineEntry {
    var date: Date
    var netWorth: Double
    var currency: String
    var transactions: [WidgetTransaction]
    var budgets: [WidgetBudget]
    var bills: [WidgetBill]

    static var placeholder: FinTrackEntry {
        FinTrackEntry(date: Date(), netWorth: 85_000, currency: "AED",
                      transactions: sampleTransactions(), budgets: sampleBudgets(), bills: sampleBills())
    }
}

// MARK: – Provider

struct FinTrackProvider: TimelineProvider {
    func placeholder(in context: Context) -> FinTrackEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (FinTrackEntry) -> Void) {
        completion(context.isPreview ? .placeholder : live())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FinTrackEntry>) -> Void) {
        let entry = live()
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func live() -> FinTrackEntry {
        FinTrackEntry(
            date: Date(),
            netWorth: netWorth(),
            currency: currency(),
            transactions: transactions(),
            budgets: budgets(),
            bills: bills()
        )
    }
}

// MARK: – Color helpers (widget-local)

private extension Color {
    init(hexStr: String) {
        let hex = hexStr.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }

    static var ftAccent: Color { Color(hexStr: "#0E9C8A") }
    static var ftIncome: Color { Color(hexStr: "#34C759") }
    static var ftExpense: Color { Color(hexStr: "#E85D5D") }
    static var ftGold: Color { Color(hexStr: "#F0B429") }
    static var ftBg: Color { Color(hexStr: "#0D1117") }
    static var ftSurface: Color { Color(white: 1, opacity: 0.08) }
}

private extension Double {
    func asCompact(currency: String) -> String {
        let abs = Swift.abs(self)
        let prefix = self < 0 ? "-" : ""
        if abs >= 1_000_000 { return "\(prefix)\(currency) \(String(format: "%.1fM", abs / 1_000_000))" }
        if abs >= 1_000    { return "\(prefix)\(currency) \(String(format: "%.1fK", abs / 1_000))" }
        return "\(currency) \(String(format: "%.0f", self))"
    }

    func formatted2dp(currency: String) -> String {
        "\(currency) \(String(format: "%.2f", self))"
    }
}

// MARK: – Balance Widget Views

struct BalanceSmallView: View {
    var entry: FinTrackEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.ftAccent)
                Text("Net Worth")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.netWorth.asCompact(currency: entry.currency))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Divider().opacity(0.3)

            let incomeTotal = entry.transactions.filter { $0.type == "income" }.reduce(0) { $0 + $1.amount }
            let expenseTotal = entry.transactions.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }

            HStack {
                Label(incomeTotal.asCompact(currency: entry.currency), systemImage: "arrow.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.ftIncome)
                    .lineLimit(1)
                Spacer()
                Label(expenseTotal.asCompact(currency: entry.currency), systemImage: "arrow.up")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.ftExpense)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct BalanceMediumView: View {
    var entry: FinTrackEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: net worth
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(Color.ftAccent)
                        .font(.system(size: 11, weight: .semibold))
                    Text("Net Worth")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(entry.netWorth.asCompact(currency: entry.currency))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Spacer()

                Text(entry.date, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Rectangle().fill(.white.opacity(0.1)).frame(width: 1)

            // Right: last 3 transactions
            VStack(alignment: .leading, spacing: 5) {
                Text("Recent")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                ForEach(entry.transactions.prefix(3)) { tx in
                    HStack(spacing: 6) {
                        Image(systemName: tx.categoryIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(tx.type == "income" ? Color.ftIncome : Color.ftExpense)
                            .frame(width: 16)
                        Text(tx.title)
                            .font(.system(size: 10))
                            .lineLimit(1)
                        Spacer()
                        Text((tx.type == "expense" ? "-" : "+") + tx.amount.asCompact(currency: tx.currency))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(tx.type == "income" ? Color.ftIncome : Color.ftExpense)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct BalanceLargeView: View {
    var entry: FinTrackEntry

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(Color.ftAccent)
                    Text("Net Worth").font(.caption).foregroundStyle(.secondary)
                }

                Text(entry.netWorth.asCompact(currency: entry.currency))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Spacer()

                if !entry.budgets.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Budget")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        let b = entry.budgets[0]
                        Text(b.name).font(.system(size: 11, weight: .medium))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.15)).frame(height: 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(b.isOverBudget ? Color.ftExpense : Color.ftAccent)
                                    .frame(width: geo.size.width * b.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                        Text("\(b.spent.asCompact(currency: b.currency)) / \(b.total.asCompact(currency: b.currency))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Text("Updated").font(.caption2).foregroundStyle(.secondary)
                Text(entry.date, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Rectangle().fill(.white.opacity(0.1)).frame(width: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text("Recent")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    .padding(.top, 12).padding(.horizontal, 12)

                ForEach(entry.transactions.prefix(6)) { tx in
                    HStack(spacing: 8) {
                        Image(systemName: tx.categoryIcon)
                            .font(.system(size: 11))
                            .foregroundStyle(tx.type == "income" ? Color.ftIncome : Color.ftExpense)
                            .frame(width: 18)
                        Text(tx.title)
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer()
                        Text((tx.type == "expense" ? "-" : "+") + tx.amount.asCompact(currency: tx.currency))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(tx.type == "income" ? Color.ftIncome : Color.ftExpense)
                    }
                    .padding(.horizontal, 12)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: – Budget Widget Views

struct BudgetSmallView: View {
    var entry: FinTrackEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ftAccent)
                Text("Budget")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let top = entry.budgets.first {
                Spacer()
                Text(top.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: top.progress)
                        .stroke(top.isOverBudget ? Color.ftExpense : Color.ftAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(Int(top.progress * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("used").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 70, height: 70)
                .frame(maxWidth: .infinity, alignment: .center)

                Text("\(top.remaining.asCompact(currency: top.currency)) left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(top.isOverBudget ? Color.ftExpense : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Spacer()
                Text("No budgets set").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct BudgetMediumView: View {
    var entry: FinTrackEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.pie.fill").foregroundStyle(Color.ftAccent)
                Text("Budget Overview").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(entry.date, style: .date).font(.system(size: 9)).foregroundStyle(.secondary)
            }

            ForEach(entry.budgets.prefix(3)) { b in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: b.icon).font(.system(size: 10))
                            .foregroundStyle(Color(hexStr: b.color))
                        Text(b.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Spacer()
                        Text("\(b.spent.asCompact(currency: b.currency)) / \(b.total.asCompact(currency: b.currency))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text("\(Int(b.progress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(b.isOverBudget ? Color.ftExpense : Color.ftAccent)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.1)).frame(height: 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(b.isOverBudget ? Color.ftExpense : Color(hexStr: b.color))
                                .frame(width: geo.size.width * b.progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }

            if entry.budgets.isEmpty {
                Spacer()
                Text("No budgets set").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct BudgetLargeView: View {
    var entry: FinTrackEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.pie.fill").foregroundStyle(Color.ftAccent)
                Text("Budget Overview").font(.system(size: 13, weight: .semibold))
                Spacer()
                let overCount = entry.budgets.filter { $0.isOverBudget }.count
                if overCount > 0 {
                    Label("\(overCount) over", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.ftExpense)
                }
            }

            ForEach(entry.budgets.prefix(5)) { b in
                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.1), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: b.progress)
                            .stroke(b.isOverBudget ? Color.ftExpense : Color(hexStr: b.color),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text("\(b.spent.asCompact(currency: b.currency)) of \(b.total.asCompact(currency: b.currency))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(b.progress * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(b.isOverBudget ? Color.ftExpense : .primary)
                        Text(b.isOverBudget ? "over" : "\(b.remaining.asCompact(currency: b.currency)) left")
                            .font(.system(size: 9))
                            .foregroundStyle(b.isOverBudget ? Color.ftExpense : .secondary)
                    }
                }
            }

            if entry.budgets.isEmpty {
                Spacer()
                Text("No budgets set").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: – Bills Widget Views

struct BillsMediumView: View {
    var entry: FinTrackEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(Color.ftGold)
                Text("Upcoming Bills").font(.system(size: 12, weight: .semibold))
                Spacer()
            }

            if entry.bills.isEmpty {
                Spacer()
                Text("No upcoming bills").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(entry.bills.prefix(3)) { bill in
                    HStack(spacing: 8) {
                        Image(systemName: bill.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(dueColor(bill.daysUntilDue))
                            .frame(width: 20)
                        Text(bill.name).font(.system(size: 11)).lineLimit(1)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(bill.amount.asCompact(currency: bill.currency))
                                .font(.system(size: 11, weight: .semibold))
                            Text(dueLabel(bill.daysUntilDue))
                                .font(.system(size: 9))
                                .foregroundStyle(dueColor(bill.daysUntilDue))
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct BillsLargeView: View {
    var entry: FinTrackEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(Color.ftGold)
                Text("Upcoming Bills").font(.system(size: 13, weight: .semibold))
                Spacer()
                if !entry.bills.isEmpty {
                    let totalDue = entry.bills.filter { $0.daysUntilDue <= 7 }.reduce(0) { $0 + $1.amount }
                    if totalDue > 0 {
                        Text("Due soon: \(totalDue.asCompact(currency: entry.currency))")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.ftExpense)
                    }
                }
            }

            if entry.bills.isEmpty {
                Spacer()
                Text("No upcoming bills").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(entry.bills.prefix(6)) { bill in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(dueColor(bill.daysUntilDue).opacity(0.15)).frame(width: 32, height: 32)
                            Image(systemName: bill.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(dueColor(bill.daysUntilDue))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bill.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            Text(bill.dueDate, style: .date).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(bill.amount.asCompact(currency: bill.currency))
                                .font(.system(size: 12, weight: .semibold))
                            Text(dueLabel(bill.daysUntilDue))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(dueColor(bill.daysUntilDue))
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private func dueColor(_ days: Int) -> Color {
    if days < 0 { return Color.ftExpense }
    if days <= 3 { return Color.ftExpense }
    if days <= 7 { return Color.ftGold }
    return Color.ftIncome
}

private func dueLabel(_ days: Int) -> String {
    if days < 0 { return "\(abs(days))d overdue" }
    if days == 0 { return "Due today" }
    if days == 1 { return "Due tomorrow" }
    return "In \(days) days"
}

// MARK: – Lock Screen Widget Views

struct LockScreenCircularView: View {
    var entry: FinTrackEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .semibold))
                Text(entry.netWorth.asCompact(currency: entry.currency))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }
}

struct LockScreenRectangularView: View {
    var entry: FinTrackEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 1) {
                Text("Net Worth")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(entry.netWorth.asCompact(currency: entry.currency))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            if let top = entry.budgets.first {
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(top.name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(Int(top.progress * 100))% used")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(top.isOverBudget ? Color.ftExpense : Color.ftAccent)
                }
            }
        }
    }
}

struct LockScreenInlineView: View {
    var entry: FinTrackEntry

    var body: some View {
        Label(entry.netWorth.asCompact(currency: entry.currency), systemImage: "chart.line.uptrend.xyaxis")
    }
}

struct LockScreenCornerView: View {
    var entry: FinTrackEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 11))
                if let top = entry.budgets.first {
                    Text("\(Int(top.progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
            }
        }
    }
}

// MARK: – Composite Widget view router

struct FinTrackWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: FinTrackEntry

    var body: some View {
        switch family {
        case .systemSmall:               BalanceSmallView(entry: entry)
        case .systemMedium:              BalanceMediumView(entry: entry)
        case .systemLarge:               BalanceLargeView(entry: entry)
        case .accessoryCircular:         LockScreenCircularView(entry: entry)
        case .accessoryRectangular:      LockScreenRectangularView(entry: entry)
        case .accessoryInline:           LockScreenInlineView(entry: entry)
        case .accessoryCorner:           LockScreenCornerView(entry: entry)
        default:                         BalanceSmallView(entry: entry)
        }
    }
}

struct BudgetWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: FinTrackEntry

    var body: some View {
        switch family {
        case .systemSmall:  BudgetSmallView(entry: entry)
        case .systemMedium: BudgetMediumView(entry: entry)
        case .systemLarge:  BudgetLargeView(entry: entry)
        default:            BudgetSmallView(entry: entry)
        }
    }
}

struct BillsWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: FinTrackEntry

    var body: some View {
        switch family {
        case .systemMedium: BillsMediumView(entry: entry)
        case .systemLarge:  BillsLargeView(entry: entry)
        default:            BillsMediumView(entry: entry)
        }
    }
}

// MARK: – Widget declarations

struct FinTrackBalanceWidget: Widget {
    let kind = "FinTrackBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinTrackProvider()) { entry in
            FinTrackWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hexStr: "#0D1117"), Color(hexStr: "#161B22")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Balance")
        .description("Net worth, income, expenses and recent transactions.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

struct FinTrackBudgetWidget: Widget {
    let kind = "FinTrackBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinTrackProvider()) { entry in
            BudgetWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hexStr: "#0D1117"), Color(hexStr: "#161B22")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Budget")
        .description("Track your monthly budget progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct FinTrackBillsWidget: Widget {
    let kind = "FinTrackBillsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinTrackProvider()) { entry in
            BillsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hexStr: "#0D1117"), Color(hexStr: "#161B22")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Upcoming Bills")
        .description("See upcoming bills and due dates.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: – Live Activity Views

struct BudgetLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var spent: Double
        var total: Double
        var currency: String
        var lastTransaction: String
    }

    var budgetName: String
    var budgetIcon: String
}

@available(iOS 16.1, *)
struct BudgetLiveActivityView: View {
    let context: ActivityViewContext<BudgetLiveActivityAttributes>

    var progress: Double {
        context.state.total > 0
            ? min(context.state.spent / context.state.total, 1.0)
            : 0
    }

    var remaining: Double {
        max(context.state.total - context.state.spent, 0)
    }

    var isOverBudget: Bool { context.state.spent > context.state.total }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(.white.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(isOverBudget ? Color.ftExpense : Color.ftAccent,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.budgetName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(isOverBudget
                     ? "Over by \(abs(remaining).asCompact(currency: context.state.currency))"
                     : "\(remaining.asCompact(currency: context.state.currency)) remaining")
                    .font(.system(size: 11))
                    .foregroundStyle(isOverBudget ? Color.ftExpense : .secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(context.state.spent.asCompact(currency: context.state.currency))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("of \(context.state.total.asCompact(currency: context.state.currency))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

@available(iOS 16.1, *)
struct BudgetDynamicIslandExpandedView: View {
    let context: ActivityViewContext<BudgetLiveActivityAttributes>

    var progress: Double {
        context.state.total > 0 ? min(context.state.spent / context.state.total, 1.0) : 0
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: context.attributes.budgetIcon)
                    .foregroundStyle(Color.ftAccent)
                Text(context.attributes.budgetName)
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.title3.bold())
                    .foregroundStyle(progress > 1 ? Color.ftExpense : Color.ftAccent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.15)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress > 1 ? Color.ftExpense : Color.ftAccent)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Spent: \(context.state.spent.asCompact(currency: context.state.currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Budget: \(context.state.total.asCompact(currency: context.state.currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !context.state.lastTransaction.isEmpty {
                Text("Last: \(context.state.lastTransaction)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
    }
}

// MARK: – Widget Bundle

@available(iOS 16.1, *)
struct FinTrackLiveActivityConfiguration: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetLiveActivityAttributes.self) { context in
            BudgetLiveActivityView(context: context)
                .containerBackground(.black.opacity(0.85), for: .expanded)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.budgetName, systemImage: context.attributes.budgetIcon)
                        .font(.caption.bold())
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let pct = context.state.total > 0
                        ? Int(min(context.state.spent / context.state.total, 1.0) * 100)
                        : 0
                    Text("\(pct)%")
                        .font(.caption.bold())
                        .foregroundStyle(context.state.spent > context.state.total ? Color.ftExpense : Color.ftAccent)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BudgetDynamicIslandExpandedView(context: context)
                }
            } compactLeading: {
                Image(systemName: context.attributes.budgetIcon)
                    .foregroundStyle(Color.ftAccent)
            } compactTrailing: {
                let pct = context.state.total > 0
                    ? Int(min(context.state.spent / context.state.total, 1.0) * 100)
                    : 0
                Text("\(pct)%")
                    .font(.caption2.bold())
                    .foregroundStyle(context.state.spent > context.state.total ? Color.ftExpense : Color.ftAccent)
            } minimal: {
                Image(systemName: context.attributes.budgetIcon)
                    .foregroundStyle(Color.ftAccent)
            }
        }
    }
}

@main
struct FinTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        FinTrackBalanceWidget()
        FinTrackBudgetWidget()
        FinTrackBillsWidget()
        if #available(iOS 16.1, *) {
            FinTrackLiveActivityConfiguration()
        }
    }
}
