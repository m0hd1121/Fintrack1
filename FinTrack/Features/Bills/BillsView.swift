import SwiftUI
import SwiftData

// MARK: - BillsView

struct BillsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Bill> { $0.isActive }, sort: \Bill.nextDueDate)
    private var activeBills: [Bill]

    @Query(sort: \Bill.nextDueDate)
    private var allBills: [Bill]

    @Query private var transactions: [Transaction]

    @State private var tab: Int = 0
    @State private var showingAddBill = false
    @State private var selectedBill: Bill? = nil

    // Calendar tab state
    @State private var displayedMonth: Date = Date()
    @State private var selectedCalendarDay: Date? = nil

    private var baseCurrency: String { appState.baseCurrency }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {

                        // Segmented Control
                        FTSegmentedControl(options: ["Calendar", "Subscriptions"], selection: $tab)
                            .padding(.horizontal, FTSpacing.screen)
                            .padding(.top, FTSpacing.sm)

                        if tab == 0 {
                            CalendarTabContent(
                                activeBills: activeBills,
                                displayedMonth: $displayedMonth,
                                selectedCalendarDay: $selectedCalendarDay,
                                selectedBill: $selectedBill,
                                baseCurrency: baseCurrency
                            )
                        } else {
                            SubscriptionsTabContent(
                                activeBills: activeBills,
                                transactions: transactions,
                                selectedBill: $selectedBill,
                                baseCurrency: baseCurrency,
                                context: context
                            )
                        }
                    }
                    .padding(.bottom, FTSpacing.xxl)
                }
            }
            .navigationTitle("Bills & Subscriptions")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddBill = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FTColor.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAddBill) {
                AddBillView()
            }
            .sheet(item: $selectedBill) { bill in
                BillDetailView(bill: bill, transactions: transactions)
            }
        }
        .onAppear {
            BillService.shared.checkAllAlerts(
                bills: allBills,
                transactions: transactions,
                currency: baseCurrency
            )
            BillService.shared.scheduleAllReminders(for: allBills)
        }
    }
}

// MARK: - Calendar Tab

private struct CalendarTabContent: View {
    let activeBills: [Bill]
    @Binding var displayedMonth: Date
    @Binding var selectedCalendarDay: Date?
    @Binding var selectedBill: Bill?
    let baseCurrency: String

    private var calendar: Calendar { .current }

    // All bill/date pairs that fall in the displayed month
    private var monthProjections: [(bill: Bill, date: Date)] {
        projectedBillsForMonth(bills: activeBills, month: displayedMonth)
    }

    // Days in the displayed month that have at least one bill due
    private var dueDays: Set<Int> {
        let cal = Calendar.current
        var days = Set<Int>()
        for pair in monthProjections {
            days.insert(cal.component(.day, from: pair.date))
        }
        return days
    }

    // Bill/date pairs filtered to selected day (or all month if none selected)
    private var filteredProjections: [(bill: Bill, date: Date)] {
        guard let selected = selectedCalendarDay else { return monthProjections }
        return monthProjections.filter { $0.date.isSameDay(as: selected) }
    }

    private var overdueProjections: [(bill: Bill, date: Date)] {
        filteredProjections.filter { $0.bill.isOverdue }
    }

    private var upcomingProjections: [(bill: Bill, date: Date)] {
        filteredProjections.filter { !$0.bill.isOverdue }
    }

    // Nil-padded array: leading nils for offset, then Date objects per day
    private var calendarDays: [Date?] {
        let cal = Calendar.current
        guard let monthInterval = cal.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let startOfMonth = monthInterval.start
        let weekdayOffset = (cal.component(.weekday, from: startOfMonth) - cal.firstWeekday + 7) % 7
        let daysInMonth = cal.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: weekdayOffset)
        for day in 0..<daysInMonth {
            if let date = cal.date(byAdding: .day, value: day, to: startOfMonth) {
                days.append(date)
            }
        }
        return days
    }

    var body: some View {
        VStack(spacing: FTSpacing.lg) {

            // Month navigation
            HStack(spacing: FTSpacing.xl) {
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
                            displayedMonth = prev
                            selectedCalendarDay = nil
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                        .frame(width: 36, height: 36)
                        .ftGlassInteractive(FTRadius.sm)
                }

                Spacer()

                Text(displayedMonth.monthName)
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        if let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
                            displayedMonth = next
                            selectedCalendarDay = nil
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                        .frame(width: 36, height: 36)
                        .ftGlassInteractive(FTRadius.sm)
                }
            }
            .padding(.horizontal, FTSpacing.screen)

            // Calendar grid
            VStack(spacing: FTSpacing.xs) {
                // Weekday headers
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                    spacing: 4
                ) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        Text(day)
                            .font(.ftLabel)
                            .tracking(0.8)
                            .foregroundStyle(FTColor.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FTSpacing.xs)
                    }
                }

                // Day cells
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                    spacing: 4
                ) {
                    ForEach(calendarDays.indices, id: \.self) { index in
                        if let date = calendarDays[index] {
                            CalendarDayCell(
                                date: date,
                                hasBills: dueDays.contains(Calendar.current.component(.day, from: date)),
                                isSelected: selectedCalendarDay?.isSameDay(as: date) ?? false,
                                isToday: Calendar.current.isDateInToday(date),
                                billsForDay: monthProjections.filter { $0.date.isSameDay(as: date) }
                            )
                            .onTapGesture {
                                withAnimation(.snappy(duration: 0.2)) {
                                    if selectedCalendarDay?.isSameDay(as: date) ?? false {
                                        selectedCalendarDay = nil
                                    } else {
                                        selectedCalendarDay = date
                                    }
                                }
                            }
                        } else {
                            Color.clear
                                .frame(height: 52)
                        }
                    }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.md)
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)

            // Bill list for selected month/day
            if monthProjections.isEmpty {
                EmptyBillsView()
                    .padding(.horizontal, FTSpacing.screen)
            } else {
                VStack(spacing: FTSpacing.md) {
                    // Section header
                    HStack {
                        Text(selectedCalendarDay != nil ? selectedCalendarDay!.formatted : "All Bills This Month")
                            .font(.ftCallout)
                            .foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        if selectedCalendarDay != nil {
                            Button {
                                withAnimation { selectedCalendarDay = nil }
                            } label: {
                                Text("Clear")
                                    .font(.ftCallout)
                                    .foregroundStyle(FTColor.accent)
                            }
                        }
                    }
                    .padding(.horizontal, FTSpacing.screen)

                    if filteredProjections.isEmpty {
                        Text("No bills due on this day")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FTSpacing.xl)
                            .ftGlass(FTRadius.lg)
                            .padding(.horizontal, FTSpacing.screen)
                    } else {
                        // Overdue section
                        if !overdueProjections.isEmpty {
                            CalendarBillSection(
                                title: "Overdue",
                                titleColor: FTColor.expense,
                                projections: overdueProjections,
                                baseCurrency: baseCurrency,
                                selectedBill: $selectedBill
                            )
                        }

                        // Upcoming section
                        if !upcomingProjections.isEmpty {
                            CalendarBillSection(
                                title: "Upcoming",
                                titleColor: FTColor.textSecondary,
                                projections: upcomingProjections,
                                baseCurrency: baseCurrency,
                                selectedBill: $selectedBill
                            )
                        }
                    }
                }
            }
        }
    }

    // Project each active bill to the date it falls on within the given month (if any)
    private func projectedBillsForMonth(bills: [Bill], month: Date) -> [(bill: Bill, date: Date)] {
        let cal = Calendar.current
        guard let monthInterval = cal.dateInterval(of: .month, for: month) else { return [] }
        let monthStart = monthInterval.start
        let monthEnd   = monthInterval.end

        var result: [(bill: Bill, date: Date)] = []

        for bill in bills {
            // Project forward from nextDueDate until we pass the month's end
            var candidate = bill.nextDueDate

            // If nextDueDate is already past the month, try projecting backward
            if candidate >= monthEnd {
                var back = candidate
                while back >= monthEnd {
                    guard let prev = cal.date(byAdding: inverseInterval(bill.billingCycle.interval), to: back) else { break }
                    back = prev
                }
                candidate = back
            }

            // Now advance forward from candidate until we land in or past the month
            var iterations = 0
            while candidate < monthStart && iterations < 60 {
                guard let next = cal.date(byAdding: bill.billingCycle.interval, to: candidate) else { break }
                candidate = next
                iterations += 1
            }

            // Check if candidate falls within the month
            if candidate >= monthStart && candidate < monthEnd {
                result.append((bill: bill, date: candidate))
            }
        }

        return result.sorted { $0.date < $1.date }
    }

    // Return a DateComponents that is the inverse of the given interval (for backward projection)
    private func inverseInterval(_ comps: DateComponents) -> DateComponents {
        var inv = DateComponents()
        if let d = comps.day   { inv.day = -d }
        if let m = comps.month { inv.month = -m }
        if let y = comps.year  { inv.year = -y }
        return inv
    }
}

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let date: Date
    let hasBills: Bool
    let isSelected: Bool
    let isToday: Bool
    let billsForDay: [(bill: Bill, date: Date)]

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(FTColor.accentGradient)
                        .frame(width: 34, height: 34)
                } else if isToday {
                    Circle()
                        .strokeBorder(FTColor.accent, lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                }

                Text(date.dayNumber)
                    .font(.system(size: 14, weight: isToday || isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : (isToday ? FTColor.accent : FTColor.textPrimary))
            }

            // Bill dots row
            if hasBills {
                HStack(spacing: 2) {
                    ForEach(billsForDay.prefix(3), id: \.bill.id) { pair in
                        Circle()
                            .fill(Color.fromString(pair.bill.colorName))
                            .frame(width: 5, height: 5)
                    }
                    if billsForDay.count > 3 {
                        Circle()
                            .fill(FTColor.textMuted)
                            .frame(width: 5, height: 5)
                    }
                }
            } else {
                // Spacer to maintain height consistency
                Color.clear.frame(height: 5)
            }
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }
}

// MARK: - Calendar Bill Section

private struct CalendarBillSection: View {
    let title: String
    let titleColor: Color
    let projections: [(bill: Bill, date: Date)]
    let baseCurrency: String
    @Binding var selectedBill: Bill?

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text(title.uppercased())
                .font(.ftLabel)
                .tracking(1.4)
                .foregroundStyle(titleColor)
                .padding(.horizontal, FTSpacing.screen)

            VStack(spacing: 1) {
                ForEach(projections, id: \.bill.id) { pair in
                    Button {
                        selectedBill = pair.bill
                    } label: {
                        BillRow(bill: pair.bill, baseCurrency: baseCurrency)
                            .padding(.horizontal, FTSpacing.screen)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .buttonStyle(.plain)

                    if pair.bill.id != projections.last?.bill.id {
                        Divider()
                            .padding(.leading, FTSpacing.screen + 42 + FTSpacing.md)
                    }
                }
            }
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)
        }
    }
}

// MARK: - Subscriptions Tab

private struct SubscriptionsTabContent: View {
    let activeBills: [Bill]
    let transactions: [Transaction]
    @Binding var selectedBill: Bill?
    let baseCurrency: String
    let context: ModelContext

    // Summary metrics
    private var totalMonthly: Double {
        activeBills.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    private var totalAnnual: Double {
        activeBills.reduce(0) { $0 + $1.annualEquivalent }
    }

    private var autoPayCount: Int {
        activeBills.filter { $0.isAutoPay }.count
    }

    // Waste analyses
    private var wasteAnalyses: [BillWasteAnalysis] {
        activeBills
            .filter { $0.isSubscription }
            .map { BillService.shared.analyzeWaste(bill: $0, transactions: transactions) }
            .filter { $0.isLikelyUnused && !$0.bill.isDismissedWasteAlert }
    }

    // Auto-pay missed bills
    private var autoPayMissedBills: [Bill] {
        activeBills.filter { $0.isAutoPay && $0.notifiedAutoPayMissed }
    }

    // Price-increased bills
    private var priceChangedBills: [Bill] {
        activeBills.filter { $0.hasPriceIncreased }
    }

    // Bills grouped by category (only categories with active bills)
    private var groupedBills: [(category: BillCategory, bills: [Bill])] {
        let categories = BillCategory.allCases
        return categories.compactMap { cat in
            let bills = activeBills.filter { $0.billCategory == cat }
            guard !bills.isEmpty else { return nil }
            return (category: cat, bills: bills)
        }
    }

    var body: some View {
        VStack(spacing: FTSpacing.lg) {

            // Summary hero card
            SummaryHeroCard(
                totalMonthly: totalMonthly,
                totalAnnual: totalAnnual,
                activeBillsCount: activeBills.count,
                autoPayCount: autoPayCount,
                baseCurrency: baseCurrency
            )
            .padding(.horizontal, FTSpacing.screen)

            // AI Insights
            if !wasteAnalyses.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    BillSectionHeader(title: "AI Insights", symbol: "sparkles", tint: FTColor.gold)
                        .padding(.horizontal, FTSpacing.screen)

                    VStack(spacing: FTSpacing.sm) {
                        ForEach(wasteAnalyses, id: \.bill.id) { analysis in
                            WasteAlertCard(
                                analysis: analysis,
                                selectedBill: $selectedBill,
                                context: context
                            )
                            .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            }

            // Auto-Pay Missed alerts
            if !autoPayMissedBills.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    BillSectionHeader(title: "Auto-Pay Alerts", symbol: "exclamationmark.triangle.fill", tint: .orange)
                        .padding(.horizontal, FTSpacing.screen)

                    VStack(spacing: FTSpacing.sm) {
                        ForEach(autoPayMissedBills, id: \.id) { bill in
                            AutoPayWarningCard(bill: bill, selectedBill: $selectedBill)
                                .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            }

            // Price Changes
            if !priceChangedBills.isEmpty {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    BillSectionHeader(title: "Price Changes", symbol: "arrow.up.right.circle.fill", tint: FTColor.expense)
                        .padding(.horizontal, FTSpacing.screen)

                    VStack(spacing: FTSpacing.sm) {
                        ForEach(priceChangedBills, id: \.id) { bill in
                            PriceChangeCard(bill: bill, selectedBill: $selectedBill)
                                .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            }

            // Bills grouped by category
            if activeBills.isEmpty {
                EmptyBillsView()
                    .padding(.horizontal, FTSpacing.screen)
            } else {
                VStack(spacing: FTSpacing.lg) {
                    ForEach(groupedBills, id: \.category) { group in
                        CategoryBillsSection(
                            category: group.category,
                            bills: group.bills,
                            baseCurrency: baseCurrency,
                            selectedBill: $selectedBill
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Summary Hero Card

private struct SummaryHeroCard: View {
    let totalMonthly: Double
    let totalAnnual: Double
    let activeBillsCount: Int
    let autoPayCount: Int
    let baseCurrency: String

    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            // Title row with gradient icon
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FTColor.accentGradient)
                        .frame(width: 42, height: 42)
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bills Overview")
                        .font(.ftHeadline)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("Active subscriptions & bills")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }

                Spacer()
            }

            // 2x2 metric grid
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: FTSpacing.md
            ) {
                MetricCell(
                    label: "Monthly Cost",
                    value: totalMonthly.formatted(as: baseCurrency),
                    symbol: "calendar",
                    tint: FTColor.accent
                )
                MetricCell(
                    label: "Annual Cost",
                    value: totalAnnual.asCompact(currency: baseCurrency),
                    symbol: "calendar.circle.fill",
                    tint: FTColor.accentDeep
                )
                MetricCell(
                    label: "Active Bills",
                    value: "\(activeBillsCount)",
                    symbol: "list.bullet.rectangle",
                    tint: FTColor.catBlue
                )
                MetricCell(
                    label: "Auto-Pay",
                    value: "\(autoPayCount)",
                    symbol: "arrow.clockwise.circle.fill",
                    tint: FTColor.income
                )
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }
}

private struct MetricCell: View {
    let label: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.ftLabel)
                    .tracking(0.5)
                    .foregroundStyle(FTColor.textSecondary)
            }
            Text(value)
                .font(.ftTitle)
                .foregroundStyle(FTColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpacing.md)
        .background(FTColor.textPrimary.opacity(0.04), in: .rect(cornerRadius: FTRadius.sm))
    }
}

// MARK: - Section Header

private struct BillSectionHeader: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: FTSpacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(title.uppercased())
                .font(.ftLabel)
                .tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
        }
    }
}

// MARK: - Waste Alert Card

private struct WasteAlertCard: View {
    let analysis: BillWasteAnalysis
    @Binding var selectedBill: Bill?
    let context: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(alignment: .top, spacing: FTSpacing.md) {
                ZStack {
                    Circle()
                        .fill(FTColor.gold.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FTColor.gold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.bill.name)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text(analysis.suggestion)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: FTSpacing.sm) {
                Button("Dismiss") {
                    analysis.bill.isDismissedWasteAlert = true
                }
                .font(.ftCallout)
                .foregroundStyle(FTColor.textSecondary)
                .padding(.horizontal, FTSpacing.lg)
                .padding(.vertical, FTSpacing.sm)
                .background(.regularMaterial, in: .capsule)
                .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))

                Button("Review") {
                    selectedBill = analysis.bill
                }
                .font(.ftCallout)
                .foregroundStyle(.white)
                .padding(.horizontal, FTSpacing.lg)
                .padding(.vertical, FTSpacing.sm)
                .background(FTColor.accentGradient, in: .capsule)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - Auto-Pay Warning Card

private struct AutoPayWarningCard: View {
    let bill: Bill
    @Binding var selectedBill: Bill?

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(bill.name) auto-pay not detected")
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Expected on \(bill.nextDueDate.formatted) — no matching payment found.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            Button {
                selectedBill = bill
            } label: {
                Text("Review")
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.accent)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - Price Change Card

private struct PriceChangeCard: View {
    let bill: Bill
    @Binding var selectedBill: Bill?

    private var changeInfo: (previous: Double, percent: Double) {
        let result = BillService.shared.detectPriceChange(for: bill)
        return (result.previousAmount ?? 0, result.changePercent)
    }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle()
                    .fill(FTColor.expense.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FTColor.expense)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(bill.name) price increased")
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                let info = changeInfo
                if info.previous > 0 {
                    Text(
                        "\(info.previous.formatted(as: bill.currency)) → \(bill.amount.formatted(as: bill.currency)) (+\(String(format: "%.1f%%", info.percent)))"
                    )
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                }
            }

            Spacer()

            Button {
                selectedBill = bill
            } label: {
                Text("Review")
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.accent)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - Category Bills Section

private struct CategoryBillsSection: View {
    let category: BillCategory
    let bills: [Bill]
    let baseCurrency: String
    @Binding var selectedBill: Bill?

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            // Category header
            HStack(spacing: FTSpacing.sm) {
                FTIconTile(symbol: category.icon, tint: Color.fromString(category.colorName), size: 28)
                Text(category.rawValue.uppercased())
                    .font(.ftLabel)
                    .tracking(1.2)
                    .foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text("\(bills.count)")
                    .font(.ftLabel)
                    .tracking(0.5)
                    .foregroundStyle(FTColor.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(FTColor.textPrimary.opacity(0.07), in: .capsule)
            }
            .padding(.horizontal, FTSpacing.screen)

            // Bill rows
            VStack(spacing: 1) {
                ForEach(bills, id: \.id) { bill in
                    Button {
                        selectedBill = bill
                    } label: {
                        HStack(spacing: 0) {
                            BillRow(bill: bill, baseCurrency: baseCurrency)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FTColor.textMuted)
                                .padding(.trailing, FTSpacing.lg)
                        }
                        .padding(.leading, FTSpacing.screen)
                        .padding(.vertical, FTSpacing.sm)
                    }
                    .buttonStyle(.plain)

                    if bill.id != bills.last?.id {
                        Divider()
                            .padding(.leading, FTSpacing.screen + 42 + FTSpacing.md)
                    }
                }
            }
            .ftGlass(FTRadius.lg)
            .padding(.horizontal, FTSpacing.screen)
        }
    }
}

// MARK: - BillRow

private struct BillRow: View {
    let bill: Bill
    let baseCurrency: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: bill.icon, tint: Color.fromString(bill.colorName), size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(bill.name)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)

                HStack(spacing: FTSpacing.xs) {
                    if let provider = bill.provider, !provider.isEmpty {
                        Text(provider)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                        Text("·")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                    Text(bill.billingCycle.shortLabel)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(bill.amount.formatted(as: bill.currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)

                HStack(spacing: FTSpacing.xs) {
                    if bill.isOverdue {
                        Text("Overdue")
                            .font(.ftLabel)
                            .tracking(0.5)
                            .foregroundStyle(FTColor.expense)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(FTColor.expense.opacity(0.12), in: .capsule)
                    } else {
                        Text(dueDateLabel)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }

                    if bill.isAutoPay {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FTColor.income)
                    }
                }
            }
        }
    }

    private var dueDateLabel: String {
        let days = bill.daysUntilDue
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 0  { return "Overdue" }
        return "Due in \(days)d"
    }
}

// MARK: - Empty State

private struct EmptyBillsView: View {
    var body: some View {
        VStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FTColor.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(FTColor.accent)
            }

            VStack(spacing: FTSpacing.xs) {
                Text("No Bills This Month")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Add your recurring bills and subscriptions to track them here.")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.xxl)
        .padding(.horizontal, FTSpacing.xxl)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        FTBackdrop()
        BillsView()
    }
    .environment(AppState())
    .modelContainer(for: [Bill.self, Transaction.self], inMemory: true)
}
