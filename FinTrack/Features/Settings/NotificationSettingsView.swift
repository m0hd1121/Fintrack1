import SwiftUI
import SwiftData
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]
    @Query private var accounts: [Account]
    @Query private var budgets: [Budget]

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingLargeThresholdEditor = false
    @State private var showingLowBalanceEditor = false

    private var settings: AppSettings? { allSettings.first }

    private func bind<T>(_ kp: WritableKeyPath<AppSettings, T>, default def: T) -> Binding<T> {
        Binding(
            get: { settings?[keyPath: kp] ?? def },
            set: { v in allSettings.first?[keyPath: kp] = v; try? context.save() }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                permissionCard
                if authStatus != .denied {
                    masterToggleCard
                    if settings?.notificationsEnabled != false {
                        billRemindersCard
                        budgetAlertsCard
                        balanceAlertsCard
                        incomeAlertsCard
                        goalMilestonesCard
                        digestCard
                    }
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .task { await refreshAuthStatus() }
    }

    // MARK: - Permission Card

    private var permissionCard: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(statusColor.opacity(0.1)).frame(width: 52, height: 52)
                Image(systemName: statusIcon).font(.ftTitle).foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(statusSubtitle).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            if authStatus == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.ftCaption)
                .foregroundStyle(FTColor.accent)
                .padding(.horizontal, FTSpacing.sm).padding(.vertical, 4)
                .background(FTColor.accent.opacity(0.1), in: Capsule())
            } else if authStatus == .notDetermined {
                Button("Enable") {
                    Task {
                        _ = await NotificationService.shared.requestPermission()
                        await refreshAuthStatus()
                    }
                }
                .font(.ftCaption)
                .foregroundStyle(.white)
                .padding(.horizontal, FTSpacing.sm).padding(.vertical, 4)
                .background(FTColor.accent, in: Capsule())
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var statusIcon: String {
        switch authStatus {
        case .authorized:      return "bell.badge.fill"
        case .denied:          return "bell.slash.fill"
        case .notDetermined:   return "bell.fill"
        default:               return "bell.fill"
        }
    }

    private var statusColor: Color {
        switch authStatus {
        case .authorized:    return FTColor.income
        case .denied:        return FTColor.expense
        default:             return FTColor.gold
        }
    }

    private var statusTitle: String {
        switch authStatus {
        case .authorized:    return "Notifications Enabled"
        case .denied:        return "Notifications Blocked"
        default:             return "Notifications Pending"
        }
    }

    private var statusSubtitle: String {
        switch authStatus {
        case .authorized:    return "FinTrack can send you timely alerts"
        case .denied:        return "Enable in iOS Settings to receive alerts"
        default:             return "Tap Enable to allow notifications"
        }
    }

    // MARK: - Master Toggle

    private var masterToggleCard: some View {
        FTToggleRow(symbol: "bell.fill", tint: FTColor.accent,
                    title: "All Notifications",
                    isOn: bind(\.notificationsEnabled, default: true))
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Bill Reminders

    private var billRemindersCard: some View {
        settingsCard("BILL & PAYMENT REMINDERS", icon: "calendar.badge.clock", color: FTColor.catCoral) {
            FTToggleRow(symbol: "calendar.badge.clock", tint: FTColor.catCoral,
                        title: "Bill Due Reminders",
                        isOn: bind(\.billRemindersEnabled, default: true))
            if settings?.billRemindersEnabled != false {
                noteDivider
                Menu {
                    Picker("Lead Time", selection: bind(\.reminderDaysBefore, default: 3)) {
                        Text("1 day before").tag(1)
                        Text("3 days before").tag(3)
                        Text("5 days before").tag(5)
                        Text("7 days before").tag(7)
                    }
                } label: {
                    noteRow(icon: "timer", tint: FTColor.catCoral, title: "Lead Time",
                            value: leadTimeLabel)
                }
                noteDivider
                FTToggleRow(symbol: "creditcard.fill", tint: FTColor.catPurple,
                            title: "Credit Card Payment Reminders",
                            isOn: bind(\.billRemindersEnabled, default: true))
            }
        }
    }

    private var leadTimeLabel: String {
        let days = settings?.reminderDaysBefore ?? 3
        return days == 1 ? "1 day before" : "\(days) days before"
    }

    // MARK: - Budget Alerts

    private var budgetAlertsCard: some View {
        settingsCard("BUDGET ALERTS", icon: "chart.pie.fill", color: FTColor.catBlue) {
            FTToggleRow(symbol: "chart.pie.fill", tint: FTColor.catBlue,
                        title: "Budget Threshold Alerts",
                        isOn: bind(\.budgetAlertsEnabled, default: true))
            if settings?.budgetAlertsEnabled != false {
                noteDivider
                Text("Notify when spending reaches:")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    .padding(.leading, FTSpacing.md)
                noteDivider
                FTToggleRow(symbol: "exclamationmark.triangle", tint: FTColor.gold,
                            title: "75% of budget used",
                            isOn: bind(\.budgetAlertAt75, default: true))
                noteDivider
                FTToggleRow(symbol: "exclamationmark.triangle.fill", tint: FTColor.catCoral,
                            title: "90% of budget used",
                            isOn: bind(\.budgetAlertAt90, default: true))
                noteDivider
                FTToggleRow(symbol: "xmark.circle.fill", tint: FTColor.expense,
                            title: "100% — budget exceeded",
                            isOn: bind(\.budgetAlertAt100, default: true))
            }
        }
    }

    // MARK: - Balance Alerts

    private var balanceAlertsCard: some View {
        settingsCard("BALANCE ALERTS", icon: "building.columns.fill", color: FTColor.catTeal) {
            FTToggleRow(symbol: "exclamationmark.circle.fill", tint: FTColor.catTeal,
                        title: "Low Balance Alert",
                        isOn: bind(\.lowBalanceAlertEnabled, default: true))
            if settings?.lowBalanceAlertEnabled != false {
                noteDivider
                HStack {
                    noteRowIcon(icon: "arrow.down.circle.fill", tint: FTColor.catTeal)
                    Text("Alert when balance falls below").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Button {
                        showingLowBalanceEditor = true
                    } label: {
                        Text((settings?.lowBalanceThreshold ?? 100).formatted(.currency(code: "AED").precision(.fractionLength(0))))
                            .font(.ftCallout).foregroundStyle(FTColor.accent)
                            .padding(.horizontal, FTSpacing.sm).padding(.vertical, 4)
                            .background(FTColor.accent.opacity(0.1), in: Capsule())
                    }
                }
            }
            noteDivider
            FTToggleRow(symbol: "bolt.fill", tint: FTColor.gold,
                        title: "Large Transaction Alert",
                        isOn: bind(\.largeTransactionAlertEnabled, default: true))
            if settings?.largeTransactionAlertEnabled != false {
                noteDivider
                HStack {
                    noteRowIcon(icon: "arrow.up.circle.fill", tint: FTColor.gold)
                    Text("Alert for transactions above").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Button {
                        showingLargeThresholdEditor = true
                    } label: {
                        Text((settings?.largeTransactionThreshold ?? 1000).formatted(.currency(code: "AED").precision(.fractionLength(0))))
                            .font(.ftCallout).foregroundStyle(FTColor.accent)
                            .padding(.horizontal, FTSpacing.sm).padding(.vertical, 4)
                            .background(FTColor.accent.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .sheet(isPresented: $showingLowBalanceEditor) {
            ThresholdEditorSheet(
                title: "Low Balance Threshold",
                value: bind(\.lowBalanceThreshold, default: 100),
                currency: "AED"
            )
        }
        .sheet(isPresented: $showingLargeThresholdEditor) {
            ThresholdEditorSheet(
                title: "Large Transaction Threshold",
                value: bind(\.largeTransactionThreshold, default: 1000),
                currency: "AED"
            )
        }
    }

    // MARK: - Income Alerts

    private var incomeAlertsCard: some View {
        settingsCard("INCOME ALERTS", icon: "banknote.fill", color: FTColor.income) {
            FTToggleRow(symbol: "banknote.fill", tint: FTColor.income,
                        title: "Salary Credit Detected",
                        isOn: bind(\.salaryReminderEnabled, default: true))
            noteDivider
            FTToggleRow(symbol: "clock.badge.exclamationmark.fill", tint: FTColor.gold,
                        title: "Salary Delayed Alert",
                        isOn: bind(\.salaryReminderEnabled, default: true))
        }
    }

    // MARK: - Goal Milestones

    private var goalMilestonesCard: some View {
        settingsCard("GOAL MILESTONES", icon: "target", color: FTColor.catPurple) {
            FTToggleRow(symbol: "target", tint: FTColor.catPurple,
                        title: "Goal Progress Milestones",
                        isOn: bind(\.goalMilestoneAlertEnabled, default: true))
            if settings?.goalMilestoneAlertEnabled != false {
                noteDivider
                milestoneInfo
            }
        }
    }

    private var milestoneInfo: some View {
        HStack(spacing: FTSpacing.md) {
            noteRowIcon(icon: "flag.fill", tint: FTColor.catPurple)
            VStack(alignment: .leading, spacing: 4) {
                Text("Notify at milestones").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                HStack(spacing: FTSpacing.sm) {
                    ForEach(["25%", "50%", "75%", "100%"], id: \.self) { pct in
                        Text(pct)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.catPurple)
                            .padding(.horizontal, FTSpacing.sm).padding(.vertical, 2)
                            .background(FTColor.catPurple.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Digest

    private var digestCard: some View {
        settingsCard("SPENDING DIGEST", icon: "chart.bar.doc.horizontal.fill", color: FTColor.catBlue) {
            FTToggleRow(symbol: "calendar.circle.fill", tint: FTColor.catBlue,
                        title: "Weekly Digest",
                        isOn: bind(\.weeklyDigestEnabled, default: false))
            if settings?.weeklyDigestEnabled == true {
                noteDivider
                Menu {
                    Picker("Day of Week", selection: bind(\.digestDayOfWeek, default: 2)) {
                        Text("Monday").tag(2)
                        Text("Tuesday").tag(3)
                        Text("Wednesday").tag(4)
                        Text("Thursday").tag(5)
                        Text("Friday").tag(6)
                        Text("Saturday").tag(7)
                        Text("Sunday").tag(1)
                    }
                } label: {
                    noteRow(icon: "calendar", tint: FTColor.catBlue, title: "Send on",
                            value: weekdayName(settings?.digestDayOfWeek ?? 2))
                }
            }
            noteDivider
            FTToggleRow(symbol: "chart.bar.doc.horizontal.fill", tint: FTColor.catPurple,
                        title: "Monthly Digest",
                        isOn: bind(\.monthlyDigestEnabled, default: false))
            if settings?.monthlyDigestEnabled == true {
                noteDivider
                Menu {
                    Picker("Day of Month", selection: bind(\.digestDayOfMonth, default: 1)) {
                        ForEach(1...28, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                    }
                } label: {
                    noteRow(icon: "calendar", tint: FTColor.catPurple, title: "Send on",
                            value: "Day \(settings?.digestDayOfMonth ?? 1)")
                }
                noteDivider
                Menu {
                    Picker("Hour", selection: bind(\.digestHour, default: 9)) {
                        ForEach([6, 7, 8, 9, 10, 12, 18, 20], id: \.self) { h in
                            Text(hourLabel(h)).tag(h)
                        }
                    }
                } label: {
                    noteRow(icon: "clock", tint: FTColor.catPurple, title: "At",
                            value: hourLabel(settings?.digestHour ?? 9))
                }
            }
        }
        .onChange(of: settings?.weeklyDigestEnabled) { _, enabled in
            if enabled == true { scheduleWeeklyDigest() }
            else { NotificationService.shared.cancelNotification(id: "weekly_digest") }
        }
        .onChange(of: settings?.monthlyDigestEnabled) { _, enabled in
            if enabled == true { scheduleMonthlyDigest() }
            else { NotificationService.shared.cancelNotification(id: "monthly_digest") }
        }
    }

    // MARK: - Card Builder

    @ViewBuilder
    private func settingsCard<Content: View>(_ title: String, icon: String, color: Color,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: icon).font(.ftCaption).foregroundStyle(color)
                Text(title).font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
            }
            VStack(spacing: 0) {
                content()
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    @ViewBuilder
    private func noteRow(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: FTSpacing.md) {
            noteRowIcon(icon: icon, tint: tint)
            Text(title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
            Spacer()
            Text(value).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
    }

    private func noteRowIcon(icon: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.15)).frame(width: 32, height: 32)
            Image(systemName: icon).font(.ftCaption).foregroundStyle(tint)
        }
    }

    private var noteDivider: some View {
        Divider().background(FTColor.textMuted.opacity(0.3))
    }

    // MARK: - Helpers

    private func weekdayName(_ weekday: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let idx = max(0, min(weekday - 1, 6))
        return names[idx]
    }

    private func hourLabel(_ h: Int) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h a"
        var comps = DateComponents()
        comps.hour = h
        comps.minute = 0
        return Calendar.current.date(from: comps).map { fmt.string(from: $0) } ?? "\(h):00"
    }

    private func scheduleWeeklyDigest() {
        let content = UNMutableNotificationContent()
        content.title = "Your Weekly FinTrack Digest"
        content.body = "Review your spending summary and financial highlights from the past week."
        content.sound = .default
        var comps = DateComponents()
        comps.weekday = settings?.digestDayOfWeek ?? 2
        comps.hour = settings?.digestHour ?? 9
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_digest", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleMonthlyDigest() {
        let content = UNMutableNotificationContent()
        content.title = "Your Monthly FinTrack Report"
        content.body = "Your financial month in review — income, spending, savings, and more."
        content.sound = .default
        var comps = DateComponents()
        comps.day = settings?.digestDayOfMonth ?? 1
        comps.hour = settings?.digestHour ?? 9
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "monthly_digest", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    @MainActor
    private func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
    }
}

// MARK: - Threshold Editor Sheet

struct ThresholdEditorSheet: View {
    let title: String
    @Binding var value: Double
    let currency: String

    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: FTSpacing.xxl) {
                VStack(spacing: FTSpacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40)).foregroundStyle(FTColor.accent)
                    Text(title).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text("Enter the threshold amount in \(currency)")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                }
                .padding(.top, FTSpacing.xxl)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currency).font(.ftTitle).foregroundStyle(FTColor.textMuted)
                    TextField("0", text: $inputText)
                        .font(.ftAmount)
                        .foregroundStyle(FTColor.textPrimary)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 200)
                }

                if showError {
                    Text("Please enter a valid amount greater than 0.")
                        .font(.ftCaption).foregroundStyle(FTColor.expense)
                }

                let presets: [Double] = [50, 100, 200, 500, 1000, 2000, 5000]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.sm) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            inputText = String(Int(preset))
                            showError = false
                        } label: {
                            Text("\(Int(preset))")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, FTSpacing.sm)
                                .background(FTColor.accent.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: FTRadius.sm))
                        }
                    }
                }

                Spacer()
            }
            .padding(FTSpacing.screen)
            .background { FTBackdrop() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = Double(inputText), amount > 0 else {
                            showError = true; return
                        }
                        value = amount
                        dismiss()
                    }
                    .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                }
            }
            .onAppear {
                inputText = value == 0 ? "" : String(Int(value))
            }
        }
    }
}
