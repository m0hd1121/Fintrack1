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

    // Other scheduled payments, so the Calendar shows the same sources as the
    // Upcoming view (filters match `UpcomingPaymentsView`).
    @Query(filter: #Predicate<Loan> { $0.isActive }) private var loans: [Loan]
    @Query(filter: #Predicate<CreditCard> { $0.isActive }) private var creditCards: [CreditCard]
    @Query(filter: #Predicate<BNPLPlan> { $0.isCompleted == false }) private var bnplPlans: [BNPLPlan]
    @Query(filter: #Predicate<Transaction> { $0.isRecurring }) private var recurringTransactions: [Transaction]
    @Query private var moneyBorrowed: [MoneyBorrowed]

    @State private var tab: Int = 0
    @State private var showingAddBill = false
    @State private var selectedBill: Bill? = nil

    // Calendar tab state
    @State private var displayedMonth: Date = Date()
    @State private var selectedCalendarDay: Date? = nil

    private var baseCurrency: String { appState.baseCurrency }

    /// False when pushed onto an existing stack (see `OptionalNavigationStack`).
    var embedInNavigationStack = true

    init(embedInNavigationStack: Bool = true) {
        self.embedInNavigationStack = embedInNavigationStack
    }

    var body: some View {
        OptionalNavigationStack(embed: embedInNavigationStack) {
            ZStack {

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {

                        // Segmented Control
                        // Upcoming merges the old Upcoming Payments screen:
                        // everything due, not only bills (EMIs, cards, BNPL…).
                        FTSegmentedControl(options: ["Upcoming", "Calendar", "Subscriptions"], selection: $tab)
                            .padding(.horizontal, FTSpacing.screen)
                            .padding(.top, FTSpacing.sm)

                        if tab == 0 {
                            UpcomingPaymentsView(embedInNavigationStack: false, showsChrome: false)
                        } else if tab == 1 {
                            CalendarTabContent(
                                activeBills: activeBills,
                                sources: CalendarPaymentSources(
                                    loans: loans, creditCards: creditCards, bnplPlans: bnplPlans,
                                    recurring: recurringTransactions, borrowed: moneyBorrowed),
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { FTBackdrop() }
            .navigationTitle("Bills & Payments")
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
                    .accessibilityLabel("Add")
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

/// The non-bill payment sources the calendar projects into each month.
private struct CalendarPaymentSources {
    let loans: [Loan]
    let creditCards: [CreditCard]
    let bnplPlans: [BNPLPlan]
    let recurring: [Transaction]
    let borrowed: [MoneyBorrowed]
}

/// One dated payment on the calendar: a bill occurrence, or a loan EMI, card
/// payment, BNPL instalment, recurring expense or money borrowed — the same
/// sources as the Upcoming view. Amounts are in the base currency.
private struct CalendarPayment: Identifiable {
    enum Kind: String {
        case bill = "Bill", loan = "Loan EMI", creditCard = "Card payment"
        case bnpl = "BNPL instalment", recurring = "Recurring expense", borrowed = "Money borrowed"

        /// Legend / dot colour per kind (bills use their own colour).
        var tint: Color {
            switch self {
            case .bill:       return FTColor.accent
            case .loan:       return FTColor.catBlue
            case .creditCard: return FTColor.catPurple
            case .bnpl:       return FTColor.gold
            case .recurring:  return FTColor.catTeal
            case .borrowed:   return FTColor.catCoral
            }
        }
        var symbol: String {
            switch self {
            case .bill:       return "calendar.badge.clock"
            case .loan:       return "banknote"
            case .creditCard: return "creditcard.fill"
            case .bnpl:       return "cart"
            case .recurring:  return "repeat"
            case .borrowed:   return "person.badge.minus"
            }
        }
    }

    let id: String
    let kind: Kind
    let name: String
    let subtitle: String
    let amount: Double
    let date: Date
    let isOverdue: Bool
    let tint: Color
    let symbol: String
    /// Set for bill occurrences: tapping opens the bill.
    let bill: Bill?
}

private struct CalendarTabContent: View {
    let activeBills: [Bill]
    let sources: CalendarPaymentSources
    @Binding var displayedMonth: Date
    @Binding var selectedCalendarDay: Date?
    @Binding var selectedBill: Bill?
    let baseCurrency: String

    @Environment(CurrencyService.self) private var currencyService

    private var calendar: Calendar { .current }

    // Every payment that falls in the displayed month, sorted by date
    private var monthProjections: [CalendarPayment] {
        guard let month = Calendar.current.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let bills = projectedBillsForMonth(bills: activeBills, month: displayedMonth).map { pair in
            CalendarPayment(
                id: "bill-\(pair.bill.id)-\(pair.date.timeIntervalSince1970)",
                kind: .bill, name: pair.bill.name,
                subtitle: pair.bill.provider ?? pair.bill.billCategory.rawValue,
                amount: currencyService.convert(pair.bill.amount, from: pair.bill.currency, to: baseCurrency),
                date: pair.date,
                // Only the unpaid occurrence is overdue (not later projections).
                isOverdue: pair.bill.isOverdue && pair.date.isSameDay(as: pair.bill.nextDueDate),
                tint: Color.fromString(pair.bill.colorName), symbol: pair.bill.icon, bill: pair.bill)
        }
        return (bills + otherPayments(in: month)).sorted { $0.date < $1.date }
    }

    /// Kinds present this month, for the legend under the grid.
    private func kindsPresent(in payments: [CalendarPayment]) -> [CalendarPayment.Kind] {
        let present = Set(payments.map(\.kind))
        return [.bill, .loan, .creditCard, .bnpl, .recurring, .borrowed].filter { present.contains($0) }
    }

    // Nil-padded array: leading nils for offset, then Date objects per day
    private var calendarDays: [Date?] {
        let cal = Calendar.app
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
        // Computed once per render (projection walks every payment source).
        let payments = monthProjections
        let paymentsByDay = Dictionary(grouping: payments) { Calendar.current.component(.day, from: $0.date) }
        let filtered = selectedCalendarDay.map { day in payments.filter { $0.date.isSameDay(as: day) } } ?? payments
        let overduePayments = filtered.filter(\.isOverdue)
        let upcomingPayments = filtered.filter { !$0.isOverdue }
        let kindsThisMonth = kindsPresent(in: payments)

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
                .accessibilityLabel("Previous month")

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
                .accessibilityLabel("Next month")
            }
            .padding(.horizontal, FTSpacing.screen)

            // Calendar grid
            VStack(spacing: FTSpacing.xs) {
                // Weekday headers
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                    spacing: 4
                ) {
                    // Same week start as `calendarDays`' leading offset.
                    ForEach(Calendar.app.orderedShortWeekdaySymbols, id: \.self) { day in
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
                                hasBills: paymentsByDay[Calendar.current.component(.day, from: date)] != nil,
                                isSelected: selectedCalendarDay?.isSameDay(as: date) ?? false,
                                isToday: Calendar.current.isDateInToday(date),
                                paymentsForDay: paymentsByDay[Calendar.current.component(.day, from: date)] ?? [],
                                baseCurrency: baseCurrency
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

            // Legend: what each dot colour means (the list below also names
            // the kind on every row, so colour isn't the only cue).
            if kindsThisMonth.count > 1 {
                FlowLayout(spacing: FTSpacing.sm) {
                    ForEach(kindsThisMonth, id: \.self) { kind in
                        HStack(spacing: FTSpacing.xs) {
                            Circle().fill(kind.tint).frame(width: 8, height: 8)
                            Text(kind == .bill ? "Bills" : kind.rawValue)
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .accessibilityHidden(true)
            }

            // Payment list for selected month/day
            if payments.isEmpty {
                EmptyBillsView(title: "No Payments This Month",
                               message: "Bills, subscriptions, loan EMIs, card payments, BNPL instalments and other payments due this month appear here.")
                    .padding(.horizontal, FTSpacing.screen)
            } else {
                VStack(spacing: FTSpacing.md) {
                    // Section header
                    HStack {
                        Text(selectedCalendarDay != nil ? selectedCalendarDay!.formatted : "All Payments This Month")
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

                    if filtered.isEmpty {
                        Text("No payments due on this day")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FTSpacing.xl)
                            .ftGlass(FTRadius.lg)
                            .padding(.horizontal, FTSpacing.screen)
                    } else {
                        // Overdue section
                        if !overduePayments.isEmpty {
                            CalendarBillSection(
                                title: "Overdue",
                                titleColor: FTColor.expense,
                                projections: overduePayments,
                                baseCurrency: baseCurrency,
                                selectedBill: $selectedBill
                            )
                        }

                        // Upcoming section
                        if !upcomingPayments.isEmpty {
                            CalendarBillSection(
                                title: "Upcoming",
                                titleColor: FTColor.textSecondary,
                                projections: upcomingPayments,
                                baseCurrency: baseCurrency,
                                selectedBill: $selectedBill
                            )
                        }
                    }
                }
            }
        }
    }

    /// Loan EMIs, card payments, BNPL instalments, recurring expenses and money
    /// borrowed that fall in `month`. Repeating ones are projected forward from
    /// their next due date (loans and BNPL only for their remaining
    /// instalments); only that next date can be overdue.
    private func otherPayments(in month: DateInterval) -> [CalendarPayment] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let monthly: (Date) -> Date = { cal.date(byAdding: .month, value: 1, to: $0) ?? $0 }
        var result: [CalendarPayment] = []

        func add(_ kind: CalendarPayment.Kind, source: UUID, name: String, subtitle: String,
                 amount: Double, dates: [(index: Int, date: Date)]) {
            for (index, date) in dates {
                result.append(CalendarPayment(
                    id: "\(kind.rawValue)-\(source)-\(date.timeIntervalSince1970)",
                    kind: kind, name: name, subtitle: subtitle, amount: amount, date: date,
                    isOverdue: index == 0 && date < today,
                    tint: kind.tint, symbol: kind.symbol, bill: nil))
            }
        }

        for loan in sources.loans {
            let remaining = max(loan.totalInstallments - loan.paidInstallments, 1)
            add(.loan, source: loan.id, name: loan.name, subtitle: "\(loan.loanType.rawValue) · EMI",
                amount: currencyService.convert(loan.emiAmount, from: loan.currency, to: baseCurrency),
                dates: occurrences(from: loan.nextPaymentDate, in: month, maxCount: remaining,
                                   until: loan.endDate, next: monthly))
        }
        for card in sources.creditCards where card.outstandingBalance > 0 {
            add(.creditCard, source: card.id, name: card.name, subtitle: "Minimum payment",
                amount: currencyService.convert(card.minimumPayment, from: card.currency, to: baseCurrency),
                dates: occurrences(from: card.dueDate, in: month, maxCount: nil, until: nil, next: monthly))
        }
        for plan in sources.bnplPlans {
            let remaining = plan.totalInstallments - plan.paidInstallments
            guard remaining > 0 else { continue }
            let dates = occurrences(from: plan.nextPaymentDate, in: month, maxCount: remaining,
                                    until: nil, next: monthly)
            for occurrence in dates {
                add(.bnpl, source: plan.id, name: plan.name,
                    subtitle: "Instalment \(plan.paidInstallments + 1 + occurrence.index) of \(plan.totalInstallments)",
                    amount: currencyService.convert(plan.installmentAmount, from: plan.currency, to: baseCurrency),
                    dates: [occurrence])
            }
        }
        for tx in sources.recurring where tx.type == .expense {
            guard let rule = tx.recurringRule else { continue }
            add(.recurring, source: tx.id, name: tx.title, subtitle: rule.frequency.rawValue,
                amount: tx.amountInBaseCurrency,
                dates: occurrences(from: rule.nextDueDate, in: month, maxCount: nil,
                                   until: rule.endDate, next: { rule.occurrence(after: $0) }))
        }
        for item in sources.borrowed {
            guard item.status != .writtenOff, !item.isFullyRepaid, let due = item.dueDate,
                  due >= month.start, due < month.end else { continue }
            add(.borrowed, source: item.id, name: item.lenderName, subtitle: "Personal debt",
                amount: currencyService.convert(item.remainingBalance, from: item.currency, to: baseCurrency),
                dates: [(0, due)])
        }
        return result
    }

    /// Dates from `first` stepping with `next`, kept when inside `month`.
    /// `index` counts from the first (next-due) occurrence, so index 0 is the
    /// only one that can be overdue. Bounded so a bad rule can't loop forever.
    private func occurrences(from first: Date, in month: DateInterval, maxCount: Int?, until end: Date?,
                             next: (Date) -> Date) -> [(index: Int, date: Date)] {
        var found: [(index: Int, date: Date)] = []
        var date = first
        var index = 0
        let limit = min(maxCount ?? 500, 500)
        while date < month.end && index < limit {
            if let end, date > end { break }
            if date >= month.start { found.append((index, date)) }
            let following = next(date)
            guard following > date else { break }
            date = following
            index += 1
        }
        return found
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
    let paymentsForDay: [CalendarPayment]
    let baseCurrency: String

    /// e.g. "Monday 14 October, today, 2 payments: DEWA, Car loan — ENBD, total AED 2,790.30"
    private var accessibilityText: String {
        var parts = [DateFormatter.localizedString(from: date, dateStyle: .full, timeStyle: .none)]
        if isToday { parts.append("today") }
        if paymentsForDay.isEmpty {
            parts.append("no payments")
        } else {
            let total = paymentsForDay.reduce(0) { $0 + $1.amount }
            parts.append("\(paymentsForDay.count) payment\(paymentsForDay.count == 1 ? "" : "s"): "
                         + paymentsForDay.map(\.name).joined(separator: ", ")
                         + ", total \(total.formatted(as: baseCurrency))")
        }
        return parts.joined(separator: ", ")
    }

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

            // Payment dots row (colour per bill / payment kind)
            if hasBills {
                HStack(spacing: 2) {
                    ForEach(paymentsForDay.prefix(3)) { payment in
                        Circle()
                            .fill(payment.tint)
                            .frame(width: 5, height: 5)
                    }
                    if paymentsForDay.count > 3 {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint(isSelected ? "Shows the whole month" : "Shows this day's payments")
    }
}

// MARK: - Calendar Payment Section

private struct CalendarBillSection: View {
    let title: String
    let titleColor: Color
    let projections: [CalendarPayment]
    let baseCurrency: String
    @Binding var selectedBill: Bill?

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text(title.uppercased())
                .font(.ftLabel)
                .tracking(1.4).fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(titleColor)
                .padding(.horizontal, FTSpacing.screen)

            VStack(spacing: 1) {
                ForEach(projections) { payment in
                    Group {
                        if let bill = payment.bill {
                            // Bills open their detail (record payment, history…).
                            Button {
                                selectedBill = bill
                            } label: {
                                BillRow(bill: bill, baseCurrency: baseCurrency)
                            }
                            .buttonStyle(.plain)
                        } else {
                            CalendarPaymentRow(payment: payment, baseCurrency: baseCurrency)
                        }
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.vertical, FTSpacing.sm)

                    if payment.id != projections.last?.id {
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

/// A non-bill payment on the calendar (loan EMI, card payment, BNPL
/// instalment, recurring expense, money borrowed). Same layout as `BillRow`;
/// the kind is written out so it isn't conveyed by colour alone.
private struct CalendarPaymentRow: View {
    let payment: CalendarPayment
    let baseCurrency: String

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: payment.symbol, tint: payment.tint, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.name)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                    .lineLimit(1)
                Text("\(payment.kind.rawValue) · \(payment.subtitle)")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: FTSpacing.sm)
            VStack(alignment: .trailing, spacing: 2) {
                Text(payment.amount.formatted(as: baseCurrency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(payment.isOverdue ? FTColor.expense : FTColor.textPrimary)
                Text(payment.isOverdue ? "Overdue" : payment.date.formatted)
                    .font(.ftCaption)
                    .foregroundStyle(payment.isOverdue ? FTColor.expense : FTColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Subscriptions Tab

struct SubscriptionsTabContent: View {
    let activeBills: [Bill]
    let transactions: [Transaction]
    @Binding var selectedBill: Bill?
    let baseCurrency: String
    let context: ModelContext

    // Summary metrics
    // Each bill is in its own currency; the totals are shown in the base one.
    private var totalMonthly: Double {
        activeBills.reduce(0) { $0 + CurrencyService.shared.convert($1.monthlyEquivalent, from: $1.currency, to: baseCurrency) }
    }

    private var totalAnnual: Double {
        activeBills.reduce(0) { $0 + CurrencyService.shared.convert($1.annualEquivalent, from: $1.currency, to: baseCurrency) }
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
                    BillSectionHeader(title: "Auto-Pay Alerts", symbol: "exclamationmark.triangle.fill", tint: FTColor.gold)
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
                .tracking(1.4).fixedSize(horizontal: true, vertical: false)
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
                    .fill(FTColor.gold.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FTColor.gold)
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
                    .tracking(1.2).fixedSize(horizontal: true, vertical: false)
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
                    .accessibilityLabel("Next month")
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
    var title = "No Bills This Month"
    var message = "Add your recurring bills and subscriptions to track them here."

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
                Text(title)
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text(message)
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
        BillsView()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { FTBackdrop() }
    .environment(AppState())
    .modelContainer(for: [Bill.self, Transaction.self], inMemory: true)
}
