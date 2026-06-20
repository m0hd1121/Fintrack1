import SwiftUI
import SwiftData
import Charts

struct AccountDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let account: Account
    @State private var showingEdit = false     // #1

    // Cached per-presentation derived data (recomputed on appear and when balance changes via Edit)
    @State private var sortedTransactions: [Transaction] = []
    @State private var sparklineData: [(day: Date, balance: Double)] = []
    @State private var monthlyData: [(month: String, amount: Double)] = []

    private func computeSortedTransactions() -> [Transaction] {
        account.transactions.sorted { $0.date > $1.date }
    }

    private func computeSparklineData() -> [(day: Date, balance: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -29, to: today) else { return [] }

        // Start from current balance and walk backwards subtracting net deltas,
        // so we know the balance at the start of each day in the window.
        let recent = account.transactions
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }

        var dailyDelta: [Date: Double] = [:]
        for tx in recent {
            let day = calendar.startOfDay(for: tx.date)
            let delta: Double
            switch tx.type {
            case .income:   delta = tx.amount
            case .expense:  delta = -tx.amount
            case .transfer: delta = 0
            }
            dailyDelta[day, default: 0] += delta
        }

        // Compute running balance forward from balance30DaysAgo to today.
        let totalDelta = dailyDelta.values.reduce(0, +)
        var running = account.balance - totalDelta
        var points: [(Date, Double)] = []
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: cutoff) else { continue }
            running += dailyDelta[day, default: 0]
            points.append((day, running))
        }
        return points
    }

    private func computeMonthlyData() -> [(month: String, amount: Double)] {
        let calendar = Calendar.current
        var result: [(String, Double)] = []
        for i in (0..<6).reversed() {
            let date = calendar.date(byAdding: .month, value: -i, to: Date()) ?? Date()
            let net = account.transactions
                .filter { $0.date.isSameMonth(as: date) }
                .reduce(0.0) { acc, tx in
                    switch tx.type {
                    case .income:   return acc + tx.amount
                    case .expense:  return acc - tx.amount
                    case .transfer: return acc
                    }
                }
            result.append((date.shortMonthName, net))
        }
        return result
    }

    private var accountColor: Color { Color.fromString(account.color) }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    VStack(spacing: FTSpacing.md) {
                        FTIconTile(symbol: account.icon, tint: accountColor, size: 72)
                        Text(account.name).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                        Text(account.balance.formatted(as: account.currency))
                            .font(.ftAmount)
                            .foregroundStyle(accountColor)
                            .lineLimit(1).minimumScaleFactor(0.5)

                        HStack(spacing: FTSpacing.md) {
                            BadgeView(text: account.type.rawValue, color: accountColor)
                            if !account.effectiveBankName.isEmpty {
                                BadgeView(text: account.effectiveBankName, color: FTColor.textMuted)
                            }
                        }

                        // #22 – minimum balance indicator
                        if account.minimumBalanceEnabled {
                            let below = account.balance < account.minimumBalance
                            HStack(spacing: 6) {
                                Image(systemName: below ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(below ? FTColor.expense : FTColor.income)
                                Text(below
                                     ? "Below minimum \(account.minimumBalance.formatted(as: account.currency))"
                                     : "Above minimum balance")
                                    .font(.ftCaption)
                                    .foregroundStyle(below ? FTColor.expense : FTColor.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FTSpacing.sm)
                }
                .listRowBackground(Color.clear)

                // 30-day balance sparkline
                if sparklineData.count >= 2 {
                    Section {
                        Chart(sparklineData, id: \.day) { point in
                            AreaMark(
                                x: .value("Day", point.day),
                                y: .value("Balance", point.balance)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [FTColor.accent.opacity(0.25), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Day", point.day),
                                y: .value("Balance", point.balance)
                            )
                            .foregroundStyle(FTColor.accent)
                            .interpolationMethod(.monotone)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartPlotStyle { plot in
                            plot.background(Color.clear)
                        }
                        .frame(height: 60)
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.md)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: FTSpacing.sm, leading: FTSpacing.lg, bottom: FTSpacing.sm, trailing: FTSpacing.lg))
                }

                // 6-month chart
                if !monthlyData.isEmpty {
                    Section("6-Month Activity") {
                        Chart(monthlyData, id: \.month) { data in
                            BarMark(x: .value("Month", data.month), y: .value("Amount", data.amount))
                                .foregroundStyle(data.amount >= 0 ? FTColor.income : FTColor.expense)
                                .cornerRadius(4)
                        }
                        .frame(height: 140)
                        .padding(.vertical, 8)
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisValueLabel().foregroundStyle(FTColor.textMuted)
                                AxisGridLine().foregroundStyle(FTColor.textMuted.opacity(0.2))
                            }
                        }
                        .chartYAxis {
                            AxisMarks { _ in
                                AxisValueLabel().foregroundStyle(FTColor.textMuted)
                                AxisGridLine().foregroundStyle(FTColor.textMuted.opacity(0.2))
                            }
                        }
                    }
                }

                // Transactions
                Section("Transactions") {
                    if sortedTransactions.isEmpty {
                        EmptyStateView(
                            icon: "arrow.left.arrow.right.circle",
                            title: "No Transactions",
                            message: "No transactions recorded for this account yet."
                        )
                    } else {
                        ForEach(sortedTransactions.prefix(20)) { tx in
                            TransactionRowView(transaction: tx, baseCurrency: account.currency)
                        }
                    }
                }
            }
            .contentMargins(.bottom, 100, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showingEdit = true }   // #1
                }
            }
            // #1 – Edit sheet
            .sheet(isPresented: $showingEdit) {
                AddAccountView(editingAccount: account)
            }
            .onAppear { refreshDerivedData() }
            .onChange(of: account.balance) { refreshDerivedData() }
        }
    }

    private func refreshDerivedData() {
        sortedTransactions = computeSortedTransactions()
        sparklineData = computeSparklineData()
        monthlyData = computeMonthlyData()
    }
}

// MARK: – Loan detail

struct LoanDetailView: View {
    let loan: Loan
    var body: some View { RegularLoanDetailView(loan: loan) }
}

// MARK: – Loan detail

struct RegularLoanDetailView: View {
    @Environment(\.modelContext) private var context
    let loan: Loan
    @State private var showingAmortization = false
    @State private var showingEdit = false

    var body: some View {
        List {
            Section {
                VStack(spacing: FTSpacing.lg) {
                    FTIconTile(symbol: loan.loanType.icon, tint: FTColor.gold, size: 72)
                    Text(loan.name).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                    VStack(spacing: 4) {
                        Text("Outstanding Balance").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text(loan.outstandingBalance.formatted(as: loan.currency))
                            .font(.ftAmount)
                            .foregroundStyle(FTColor.gold)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    // #4 – progress
                    if loan.totalInstallments > 0 {
                        VStack(spacing: 6) {
                            FTProgressBar(value: Double(loan.paidInstallments) / Double(loan.totalInstallments),
                                          color: FTColor.gold)
                            Text("\(loan.paidInstallments) of \(loan.totalInstallments) installments paid")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.sm)
            }
            .listRowBackground(Color.clear)

            Section("Loan Details") {
                DetailRow(label: "Loan Type", value: loan.loanType.rawValue, icon: "doc.text")
                DetailRow(label: "Principal", value: loan.principalAmount.formatted(as: loan.currency), icon: "banknote")
                DetailRow(label: "Interest Rate", value: "\(loan.interestRate)%", icon: "percent")
                DetailRow(label: "Monthly EMI", value: loan.emiAmount.formatted(as: loan.currency), icon: "calendar")
                DetailRow(label: "Start Date", value: loan.startDate.formatted, icon: "calendar.badge.plus")
                DetailRow(label: "End Date", value: loan.endDate.formatted, icon: "calendar.badge.minus")
                DetailRow(label: "Next Payment", value: loan.nextPaymentDate.formatted, icon: "clock")
                DetailRow(label: "Reminder", value: "\(loan.reminderDaysBefore) day(s) before", icon: "bell")
            }

            if let lender = loan.lenderPersonName {
                Section("Lender") {
                    DetailRow(label: "Name", value: lender, icon: "person")
                    if let contact = loan.lenderContactInfo { DetailRow(label: "Contact", value: contact, icon: "phone") }
                }
            }

            Section {
                Button { showingAmortization = true } label: {
                    Label("View Amortization Schedule", systemImage: "tablecells")
                        .foregroundStyle(FTColor.accent)
                }
            }

            LoanPaymentHistorySection(loan: loan, category: .loanRepayment)

            if let notes = loan.notes, !notes.isEmpty {
                Section("Notes") { Text(notes).font(.ftBody).foregroundStyle(FTColor.textPrimary) }
            }
        }
        .contentMargins(.bottom, 100, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Loan Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingAmortization) { AmortizationScheduleView(loan: loan) }
        .sheet(isPresented: $showingEdit) { AddLoanView(editingLoan: loan) }
    }
}


// MARK: – Loan payment history (filtered in Swift to avoid #Predicate enum crash)

struct LoanPaymentHistorySection: View {
    let loan: Loan
    let category: TransactionCategory
    var title: String = "Payment History"

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    private var payments: [Transaction] {
        allTransactions.filter { $0.linkedLoan?.id == loan.id && $0.category == category }
    }

    var body: some View {
        if !payments.isEmpty {
            Section(title) {
                ForEach(payments) { tx in
                    HStack(spacing: FTSpacing.md) {
                        FTIconTile(symbol: "arrow.down.circle.fill", tint: FTColor.income, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Text(tx.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                        Text("+" + tx.amount.formatted(as: tx.currency))
                            .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct AmortizationScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    let loan: Loan

    var body: some View {
        // Hoist: amortizationSchedule runs an O(n) loop on every access, compute once per render
        let schedule = loan.amortizationSchedule.prefix(120)
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Month").fontWeight(.semibold).frame(width: 80, alignment: .leading)
                        Text("Payment").fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Principal").fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Interest").fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Balance").fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                ForEach(schedule) { entry in
                    HStack {
                        Text(entry.date.shortMonthName + " " + entry.date.dayNumber).font(.ftCaption).frame(width: 80, alignment: .leading)
                        Text(String(format: "%.0f", entry.payment)).font(.ftCaption).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(String(format: "%.0f", entry.principal)).font(.ftCaption).foregroundStyle(FTColor.income).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(String(format: "%.0f", entry.interest)).font(.ftCaption).foregroundStyle(FTColor.expense).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(String(format: "%.0f", entry.balance)).font(.ftCaption).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .contentMargins(.bottom, 100, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Amortization Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
