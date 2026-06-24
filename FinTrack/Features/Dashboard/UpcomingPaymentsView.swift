import SwiftUI
import SwiftData

struct UpcomingPaymentsView: View {
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Loan> { $0.isActive }) private var loans: [Loan]
    @Query(filter: #Predicate<CreditCard> { $0.isActive }) private var creditCards: [CreditCard]
    @Query(filter: #Predicate<BNPLPlan> { $0.isCompleted == false }) private var bnplPlans: [BNPLPlan]
    @Query(filter: #Predicate<Transaction> { $0.isRecurring }) private var recurringExpenses: [Transaction]
    @Query(filter: #Predicate<Bill> { $0.isActive }) private var bills: [Bill]

    @State private var selectedRange: DateRangeFilter = .month
    @State private var customStart = Date()
    @State private var customEnd = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var showingCustomPicker = false

    private var baseCurrency: String { appState.baseCurrency }

    // MARK: - Date Range

    enum DateRangeFilter: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case threeMonths = "3 Months"
        case custom = "Custom"

        var endDate: Date {
            let cal = Calendar.current
            switch self {
            case .week: return cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            case .month: return cal.date(byAdding: .month, value: 1, to: Date()) ?? Date()
            case .threeMonths: return cal.date(byAdding: .month, value: 3, to: Date()) ?? Date()
            case .custom: return Date()
            }
        }
    }

    private var rangeStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var rangeEnd: Date {
        selectedRange == .custom ? customEnd : selectedRange.endDate
    }

    // MARK: - Payment Model

    struct UpcomingPayment: Identifiable {
        let id = UUID()
        let name: String
        let subtitle: String
        let amount: Double
        let currency: String
        let date: Date
        let sourceType: SourceType
        let isOverdue: Bool

        enum SourceType {
            case loan, creditCard, bnpl, recurring, bill
            var label: String {
                switch self {
                case .loan: return "Loan"
                case .creditCard: return "Credit Card"
                case .bnpl: return "BNPL"
                case .recurring: return "Recurring"
                case .bill: return "Bill"
                }
            }
            var icon: String {
                switch self {
                case .loan: return "banknote"
                case .creditCard: return "creditcard.fill"
                case .bnpl: return "cart"
                case .recurring: return "repeat"
                case .bill: return "calendar.badge.exclamationmark"
                }
            }
            var color: Color {
                switch self {
                case .loan: return .blue
                case .creditCard: return .purple
                case .bnpl: return .orange
                case .recurring: return .teal
                case .bill: return Color.fromString("teal")
                }
            }
        }
    }

    // MARK: - Computed Payments

    private var allPayments: [UpcomingPayment] {
        var result: [UpcomingPayment] = []
        let today = Calendar.current.startOfDay(for: Date())

        // Loans
        for loan in loans {
            let overdue = loan.nextPaymentDate < today
            if loan.nextPaymentDate <= rangeEnd || overdue {
                result.append(UpcomingPayment(
                    name: loan.name,
                    subtitle: loan.loanType.rawValue,
                    amount: currencyService.convert(loan.emiAmount, from: loan.currency, to: baseCurrency),
                    currency: baseCurrency,
                    date: loan.nextPaymentDate,
                    sourceType: .loan,
                    isOverdue: overdue
                ))
            }
        }

        // Credit Cards
        for card in creditCards.filter({ $0.outstandingBalance > 0 }) {
            let overdue = card.dueDate < today
            if card.dueDate <= rangeEnd || overdue {
                result.append(UpcomingPayment(
                    name: card.name,
                    subtitle: "Min. \(card.minimumPayment.formatted(as: card.currency))",
                    amount: currencyService.convert(card.minimumPayment, from: card.currency, to: baseCurrency),
                    currency: baseCurrency,
                    date: card.dueDate,
                    sourceType: .creditCard,
                    isOverdue: overdue
                ))
            }
        }

        // BNPL
        for plan in bnplPlans {
            let overdue = plan.nextPaymentDate < today
            if plan.nextPaymentDate <= rangeEnd || overdue {
                result.append(UpcomingPayment(
                    name: plan.name,
                    subtitle: "\(plan.paidInstallments + 1) of \(plan.totalInstallments)",
                    amount: currencyService.convert(plan.installmentAmount, from: plan.currency, to: baseCurrency),
                    currency: baseCurrency,
                    date: plan.nextPaymentDate,
                    sourceType: .bnpl,
                    isOverdue: overdue
                ))
            }
        }

        // Recurring transactions
        for tx in recurringExpenses.filter({ $0.type == .expense }) {
            guard let rule = tx.recurringRule else { continue }
            let overdue = rule.nextDueDate < today
            if rule.nextDueDate <= rangeEnd || overdue {
                result.append(UpcomingPayment(
                    name: tx.title,
                    subtitle: rule.frequency.rawValue,
                    amount: tx.amountInBaseCurrency,
                    currency: baseCurrency,
                    date: rule.nextDueDate,
                    sourceType: .recurring,
                    isOverdue: overdue
                ))
            }
        }

        // Bills & Subscriptions
        for bill in bills {
            let overdue = bill.nextDueDate < today
            if bill.nextDueDate <= rangeEnd || overdue {
                result.append(UpcomingPayment(
                    name: bill.name,
                    subtitle: bill.provider ?? bill.billCategory.rawValue,
                    amount: currencyService.convert(bill.amount, from: bill.currency, to: baseCurrency),
                    currency: baseCurrency,
                    date: bill.nextDueDate,
                    sourceType: .bill,
                    isOverdue: overdue
                ))
            }
        }

        return result.sorted {
            if $0.isOverdue != $1.isOverdue { return $0.isOverdue }
            return $0.date < $1.date
        }
    }

    private var groupedPayments: [(label: String, payments: [UpcomingPayment])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let endOfToday = cal.date(byAdding: .day, value: 1, to: today)!
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: today)!
        let endOfMonth = cal.date(byAdding: .month, value: 1, to: today)!

        var overdue: [UpcomingPayment] = []
        var todayPayments: [UpcomingPayment] = []
        var thisWeek: [UpcomingPayment] = []
        var thisMonth: [UpcomingPayment] = []
        var later: [UpcomingPayment] = []

        for p in allPayments {
            if p.isOverdue {
                overdue.append(p)
            } else if p.date < endOfToday {
                todayPayments.append(p)
            } else if p.date < endOfWeek {
                thisWeek.append(p)
            } else if p.date < endOfMonth {
                thisMonth.append(p)
            } else {
                later.append(p)
            }
        }

        var groups: [(label: String, payments: [UpcomingPayment])] = []
        if !overdue.isEmpty { groups.append(("Overdue", overdue)) }
        if !todayPayments.isEmpty { groups.append(("Today", todayPayments)) }
        if !thisWeek.isEmpty { groups.append(("This Week", thisWeek)) }
        if !thisMonth.isEmpty { groups.append(("This Month", thisMonth)) }
        if !later.isEmpty { groups.append(("Later", later)) }
        return groups
    }

    private var totalDue: Double {
        allPayments.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    filterBar
                        .padding(.horizontal, FTSpacing.lg)
                        .padding(.top, 8)

                    if selectedRange == .custom {
                        customDatePickers
                            .padding(.horizontal, FTSpacing.lg)
                    }

                    if !allPayments.isEmpty {
                        summaryCard
                            .padding(.horizontal, FTSpacing.lg)
                    }

                    if groupedPayments.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else {
                        ForEach(groupedPayments, id: \.label) { group in
                            groupSection(group)
                                .padding(.horizontal, FTSpacing.lg)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .background { FTBackdrop() }
            .navigationTitle("Upcoming Payments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateRangeFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedRange = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(.ftCallout)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedRange == filter ? FTColor.accent : FTColor.bgElevated)
                            .foregroundStyle(selectedRange == filter ? .white : .primary)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
    }

    // MARK: - Custom Date Pickers

    private var customDatePickers: some View {
        VStack(spacing: 12) {
            DatePicker("From", selection: $customStart, in: ...Date.distantFuture, displayedComponents: .date)
            DatePicker("To", selection: $customEnd, in: customStart..., displayedComponents: .date)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(label: "Total Due", value: totalDue.formatted(as: baseCurrency), color: .primary)
            Divider().frame(height: 36)
            summaryItem(label: "Payments", value: "\(allPayments.count)", color: .secondary)
            Divider().frame(height: 36)
            let overdueCount = allPayments.filter { $0.isOverdue }.count
            summaryItem(label: "Overdue", value: "\(overdueCount)", color: overdueCount > 0 ? .red : .secondary)
        }
        .padding(.vertical, FTSpacing.lg)
        .ftGlass(FTRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.ftHeadline)
                .foregroundStyle(color)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Group Section

    private func groupSection(_ group: (label: String, payments: [UpcomingPayment])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group.label)
                    .font(.ftCallout)
                    .foregroundStyle(group.label == "Overdue" ? .red : .secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                let groupTotal = group.payments.reduce(0) { $0 + $1.amount }
                Text(groupTotal.formatted(as: baseCurrency))
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(group.payments.enumerated()), id: \.element.id) { index, payment in
                    paymentRow(payment)
                    if index < group.payments.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Payment Row

    private func paymentRow(_ payment: UpcomingPayment) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(payment.isOverdue ? FTColor.expense.opacity(0.12) : payment.sourceType.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: payment.sourceType.icon)
                    .foregroundStyle(payment.isOverdue ? .red : payment.sourceType.color)
                    .font(.ftHeadline)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(payment.name)
                    .font(.ftBody)
                Text(payment.subtitle)
                    .font(.caption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(payment.amount.formatted(as: payment.currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(payment.isOverdue ? .red : .primary)
                Text(dueLabelFor(payment.date, overdue: payment.isOverdue))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(urgencyColor(for: payment.date, overdue: payment.isOverdue))
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.ftDisplay)
                .foregroundStyle(FTColor.income)
            Text("All Clear!")
                .font(.ftHeadline)
            Text("No upcoming payments in this period")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
        }
    }

    // MARK: - Helpers

    private func dueLabelFor(_ date: Date, overdue: Bool) -> String {
        if overdue {
            let days = Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: date),
                to: Calendar.current.startOfDay(for: Date())).day ?? 0
            return days == 0 ? "Today" : "\(days)d overdue"
        }
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days)d"
    }

    private func urgencyColor(for date: Date, overdue: Bool) -> Color {
        if overdue { return .red }
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)).day ?? 0
        return days <= 3 ? .red : days <= 7 ? .orange : .secondary
    }
}
