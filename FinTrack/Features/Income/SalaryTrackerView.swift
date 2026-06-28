import SwiftUI
import SwiftData
import Charts

// MARK: - SalaryTrackerView

struct SalaryTrackerView: View {

    // MARK: Environment
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context

    // MARK: Queries
    @Query(filter: #Predicate<SalaryRecord> { $0.isActive }) private var salaryRecords: [SalaryRecord]
    @Query private var transactions: [Transaction]

    // MARK: Sheet State
    @State private var editingRecord: SalaryRecord? = nil
    @State private var recordingPaymentFor: SalaryRecord? = nil
    @State private var showingHistory: SalaryRecord? = nil

    // MARK: Computed
    private var baseCurrency: String { appState.baseCurrency }

    private var totalExpectedMonthly: Double {
        salaryRecords.reduce(0) { sum, record in
            let monthly: Double
            switch record.paymentFrequency {
            case .weekly:      monthly = record.expectedAmount * 52 / 12
            case .biweekly:    monthly = record.expectedAmount * 26 / 12
            case .semiMonthly: monthly = record.expectedAmount * 2
            case .monthly:     monthly = record.expectedAmount
            case .quarterly:   monthly = record.expectedAmount / 3
            case .annual:      monthly = record.expectedAmount / 12
            }
            return sum + currencyService.convert(monthly, from: record.currency, to: baseCurrency)
        }
    }

    private var totalReceivedYTD: Double {
        let yearStart = Date().startOfYear
        return transactions
            .filter { $0.type == .income && $0.category == .salary && $0.date >= yearStart }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    private var averageOnTimeRate: Double {
        guard !salaryRecords.isEmpty else { return 0 }
        return salaryRecords.reduce(0) { $0 + $1.onTimeRate } / Double(salaryRecords.count)
    }

    // Chart data: last 6 months received vs expected
    private struct MonthBarData: Identifiable {
        var id: String { "\(month)-\(type)" }
        let month: String
        let date: Date
        let amount: Double
        let type: String // "Received" or "Expected"
    }

    private var chartData: [MonthBarData] {
        let cal = Calendar.current
        let now = Date()
        var result: [MonthBarData] = []

        for monthOffset in stride(from: -5, through: 0, by: 1) {
            guard let monthDate = cal.date(byAdding: .month, value: monthOffset, to: now) else { continue }
            let label = monthDate.shortMonthName

            // Expected: sum of monthly equivalents for that month
            let expected = totalExpectedMonthly

            // Received: income transactions in that month
            let received = transactions
                .filter { tx in
                    tx.type == .income && tx.category == .salary &&
                    cal.isDate(tx.date, equalTo: monthDate, toGranularity: .month)
                }
                .reduce(0) { $0 + $1.amountInBaseCurrency }

            result.append(MonthBarData(month: label, date: monthDate, amount: expected, type: "Expected"))
            result.append(MonthBarData(month: label, date: monthDate, amount: received, type: "Received"))
        }
        return result
    }

    private var allPayments: [SalaryPayment] {
        salaryRecords.flatMap { $0.payments }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                if salaryRecords.isEmpty {
                    emptyState
                } else {
                    summaryHeroCard
                    salaryRecordsList
                    if !allPayments.isEmpty {
                        paymentHistoryChart
                    }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.lg)
            .padding(.bottom, 40)
        }
        .sheet(item: $editingRecord) { record in
            AddSalaryRecordView(editingRecord: record)
        }
        .sheet(item: $recordingPaymentFor) { record in
            RecordSalaryPaymentSheet(record: record)
        }
        .sheet(item: $showingHistory) { record in
            SalaryPaymentHistoryView(record: record)
        }
    }

    // MARK: - Summary Hero Card

    private var summaryHeroCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                FTIconTile(symbol: "banknote.fill", tint: FTColor.income, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Salary Overview")
                        .font(.ftHeadline)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("\(salaryRecords.count) active record\(salaryRecords.count == 1 ? "" : "s")")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                MetricCell(
                    label: "Expected/mo",
                    value: totalExpectedMonthly.formatted(as: baseCurrency),
                    valueColor: FTColor.textPrimary
                )
                metricDivider
                MetricCell(
                    label: "Received YTD",
                    value: totalReceivedYTD.formatted(as: baseCurrency),
                    valueColor: FTColor.income
                )
                metricDivider
                MetricCell(
                    label: "Avg On-Time",
                    value: String(format: "%.0f%%", averageOnTimeRate),
                    valueColor: averageOnTimeRate >= 90 ? FTColor.income
                              : averageOnTimeRate >= 70 ? FTColor.gold
                              : FTColor.expense
                )
            }
            .padding(.vertical, FTSpacing.sm)
            .ftGlass(FTRadius.md)
        }
        .padding(FTSpacing.xl)
        .ftGlass(FTRadius.xl)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.08))
            .frame(width: 0.5)
            .padding(.vertical, FTSpacing.sm)
    }

    // MARK: - Records List

    private var salaryRecordsList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            sectionHeader(title: "Salary Records", symbol: "list.bullet.clipboard.fill")

            ForEach(salaryRecords) { record in
                SalaryRecordCard(
                    record: record,
                    baseCurrency: baseCurrency,
                    currencyService: currencyService,
                    onEdit: { editingRecord = record },
                    onRecordPayment: { recordingPaymentFor = record },
                    onShowHistory: { showingHistory = record },
                    onDelete: { deleteRecord(record) }
                )
            }
        }
    }

    // MARK: - Payment History Chart

    private var paymentHistoryChart: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            sectionHeader(title: "Payment History", symbol: "chart.bar.fill")

            VStack(alignment: .leading, spacing: FTSpacing.lg) {
                // Legend
                HStack(spacing: FTSpacing.lg) {
                    legendDot(color: FTColor.income, label: "Received")
                    legendDot(color: FTColor.income.opacity(0.3), label: "Expected")
                    Spacer()
                }

                Chart(chartData) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(
                        item.type == "Received"
                            ? AnyShapeStyle(FTColor.income)
                            : AnyShapeStyle(FTColor.income.opacity(0.3))
                    )
                    .position(by: .value("Type", item.type))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(FTColor.textPrimary.opacity(0.07))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v.asCompact(currency: baseCurrency))
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textMuted)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
            .padding(FTSpacing.xl)
            .ftGlass(FTRadius.xl)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: FTSpacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.xl) {
            Spacer(minLength: 60)
            FTIconTile(symbol: "banknote", tint: FTColor.income, size: 64)
            VStack(spacing: FTSpacing.sm) {
                Text("No Salary Records")
                    .font(.ftTitle)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Add your first salary to track payments and on-time rates.")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FTSpacing.xl)
            }
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, symbol: String) -> some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: symbol)
                .font(.ftCallout)
                .foregroundStyle(FTColor.accent)
            Text(title.uppercased())
                .font(.ftLabel)
                .tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
        }
    }

    private func deleteRecord(_ record: SalaryRecord) {
        context.delete(record)
        try? context.save()
    }
}

// MARK: - MetricCell

private struct MetricCell: View {
    let label: String
    let value: String
    var valueColor: Color = FTColor.textPrimary

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - SalaryRecordCard

private struct SalaryRecordCard: View {

    let record: SalaryRecord
    let baseCurrency: String
    let currencyService: CurrencyService
    let onEdit: () -> Void
    let onRecordPayment: () -> Void
    let onShowHistory: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onEdit) {
                HStack(alignment: .top, spacing: FTSpacing.md) {
                    FTIconTile(
                        symbol: "banknote.fill",
                        tint: Color.fromString(record.colorName),
                        size: 46
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.employerName)
                            .font(.ftHeadline)
                            .foregroundStyle(FTColor.textPrimary)
                        Text(record.jobTitle)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(record.expectedAmount.formatted(as: record.currency))
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                        Text(record.paymentFrequency.shortLabel)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(FTSpacing.lg)

            // Divider
            Rectangle()
                .fill(FTColor.textPrimary.opacity(0.06))
                .frame(height: 0.5)
                .padding(.horizontal, FTSpacing.lg)

            // Details grid
            VStack(spacing: FTSpacing.md) {
                // Next payment row
                HStack(spacing: FTSpacing.md) {
                    detailItem(
                        icon: "calendar",
                        label: "Next Expected",
                        value: record.nextExpectedDate.formatted
                    )
                    Spacer()
                    if let last = record.lastPayment {
                        statusChip(status: last.status)
                    }
                }

                // On-time rate progress
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("On-Time Rate")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                        Spacer()
                        Text(String(format: "%.0f%%", record.onTimeRate))
                            .font(.ftCaption)
                            .foregroundStyle(
                                record.onTimeRate >= 90 ? FTColor.income
                                : record.onTimeRate >= 70 ? FTColor.gold
                                : FTColor.expense
                            )
                    }
                    FTProgressBar(
                        value: record.onTimeRate / 100,
                        color: record.onTimeRate >= 90 ? FTColor.income
                             : record.onTimeRate >= 70 ? FTColor.gold
                             : FTColor.expense
                    )
                }

                // Pending badge (if any)
                if !record.pendingPayments.isEmpty {
                    HStack(spacing: FTSpacing.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(record.pendingPayments.count) pending payment\(record.pendingPayments.count == 1 ? "" : "s")")
                            .font(.ftCallout)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, FTSpacing.md)
                    .padding(.vertical, FTSpacing.xs + 2)
                    .background(.orange, in: .capsule)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .padding(.vertical, FTSpacing.md)

            // Divider
            Rectangle()
                .fill(FTColor.textPrimary.opacity(0.06))
                .frame(height: 0.5)
                .padding(.horizontal, FTSpacing.lg)

            // Action buttons
            HStack(spacing: FTSpacing.sm) {
                Button {
                    onShowHistory()
                } label: {
                    HStack(spacing: FTSpacing.xs) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                        Text("History")
                            .font(.ftCallout)
                    }
                    .foregroundStyle(FTColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FTSpacing.sm + 2)
                    .background(.regularMaterial, in: .capsule)
                    .overlay(Capsule().strokeBorder(FTColor.textPrimary.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                Button {
                    onRecordPayment()
                } label: {
                    HStack(spacing: FTSpacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Record Payment")
                            .font(.ftCallout)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FTSpacing.sm + 2)
                    .background(FTColor.accentGradient, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FTSpacing.lg)
            .padding(.vertical, FTSpacing.md)
        }
        .ftGlass(FTRadius.xl)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                onShowHistory()
            } label: {
                Label("Payment History", systemImage: "clock.arrow.circlepath")
            }
            Divider()
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete \"\(record.employerName)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the salary record and all payment history.")
        }
    }

    private func detailItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: FTSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FTColor.textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                Text(value)
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.textPrimary)
            }
        }
    }

    private func statusChip(status: SalaryPaymentStatus) -> some View {
        HStack(spacing: FTSpacing.xs) {
            Image(systemName: status.icon)
                .font(.system(size: 12, weight: .semibold))
            Text(status.rawValue)
                .font(.ftCallout)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, FTSpacing.md)
        .padding(.vertical, FTSpacing.xs + 1)
        .background(Color.fromString(status.color), in: .capsule)
    }
}

// MARK: - RecordSalaryPaymentSheet

struct RecordSalaryPaymentSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService

    let record: SalaryRecord

    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var amountText: String = ""
    @State private var paymentDate: Date = Date()
    @State private var notes: String = ""
    @State private var isProcessing: Bool = false
    @State private var showValidation: Bool = false
    @State private var selectedAccount: Account? = nil

    init(record: SalaryRecord) {
        self.record = record
        _amountText = State(initialValue: String(format: "%.2f", record.expectedAmount))
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.xl) {
                        // Record summary card
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(
                                symbol: "banknote.fill",
                                tint: Color.fromString(record.colorName),
                                size: 48
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.employerName)
                                    .font(.ftHeadline)
                                    .foregroundStyle(FTColor.textPrimary)
                                Text("Expected: \(record.expectedAmount.formatted(as: record.currency))")
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.lg)

                        // Amount section
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            sectionLabel("Amount Received")

                            HStack(spacing: FTSpacing.sm) {
                                Text(record.currency)
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.textSecondary)
                                    .frame(width: 40, alignment: .leading)

                                TextField("0.00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .font(.ftAmount)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(FTSpacing.lg)
                            .ftGlass(FTRadius.md)

                            if parsedAmount > 0 && parsedAmount != record.expectedAmount {
                                let diff = parsedAmount - record.expectedAmount
                                let sign = diff >= 0 ? "+" : ""
                                Label(
                                    "\(sign)\(diff.formatted(as: record.currency)) vs expected",
                                    systemImage: diff >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                                )
                                .font(.ftCaption)
                                .foregroundStyle(diff >= 0 ? FTColor.income : FTColor.expense)
                                .transition(.opacity)
                            }
                        }

                        // Date section
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            sectionLabel("Payment Date")

                            DatePicker(
                                "Payment Date",
                                selection: $paymentDate,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.graphical)
                            .tint(FTColor.accent)
                            .padding(FTSpacing.sm)
                            .ftGlass(FTRadius.md)
                        }

                        // Account picker
                        if !accounts.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                sectionLabel("Deposit to Account")

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: FTSpacing.sm) {
                                        ForEach(accounts) { account in
                                            let isSelected = selectedAccount?.id == account.id
                                            Button {
                                                selectedAccount = isSelected ? nil : account
                                            } label: {
                                                HStack(spacing: FTSpacing.xs) {
                                                    Image(systemName: account.icon)
                                                        .font(.system(size: 14, weight: .semibold))
                                                    Text(account.name)
                                                        .font(.ftCallout)
                                                }
                                                .foregroundStyle(isSelected ? .white : FTColor.textPrimary)
                                                .padding(.horizontal, FTSpacing.md)
                                                .padding(.vertical, FTSpacing.sm)
                                                .background(
                                                    isSelected ? FTColor.accent : FTColor.bgElevated.opacity(0.6),
                                                    in: Capsule()
                                                )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                        }

                        // Notes section
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            sectionLabel("Notes (Optional)")

                            TextEditor(text: $notes)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .padding(FTSpacing.md)
                                .ftGlass(FTRadius.md)
                        }

                        // Validation error
                        if showValidation {
                            Label("Please enter a valid amount.", systemImage: "exclamationmark.triangle.fill")
                                .font(.ftCallout)
                                .foregroundStyle(FTColor.expense)
                                .transition(.opacity)
                        }

                        // Record button
                        Button {
                            recordPayment()
                        } label: {
                            if isProcessing {
                                ProgressView().progressViewStyle(.circular).tint(.white)
                            } else {
                                Text("Record Payment")
                            }
                        }
                        .buttonStyle(.ftPrimary)
                        .disabled(isProcessing)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                    .padding(.bottom, FTSpacing.xl)
                }
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .animation(.snappy(duration: 0.2), value: showValidation)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.ftLabel)
            .tracking(1.4)
            .foregroundStyle(FTColor.textMuted)
            .padding(.leading, FTSpacing.xs)
    }

    private func recordPayment() {
        let amount = parsedAmount
        guard amount > 0 else {
            withAnimation { showValidation = true }
            return
        }
        showValidation = false
        isProcessing = true

        let payment = IncomeService.shared.recordSalaryPayment(
            record: record,
            amount: amount,
            date: paymentDate,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes
        )

        // Create a matching Transaction for the ledger
        let amountInBase = currencyService.convert(amount, from: record.currency, to: appState.baseCurrency)
        let tx = Transaction(
            title: "Salary — \(record.employerName)",
            amount: amount,
            currency: record.currency,
            amountInBaseCurrency: amountInBase,
            type: .income,
            category: .salary,
            date: paymentDate,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes,
            incomeSource: record.employerName
        )
        tx.account = selectedAccount
        tx.linkedSalaryRecordId = record.id
        tx.linkedSalaryPaymentId = payment.id

        // Credit the selected account balance
        if let account = selectedAccount {
            let delta = currencyService.convert(amount, from: record.currency, to: account.currency)
            account.balance += delta
        }

        context.insert(tx)
        try? context.save()
        isProcessing = false
        dismiss()
    }
}

// MARK: - SalaryPaymentHistoryView

struct SalaryPaymentHistoryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService
    @Environment(AppState.self) private var appState

    let record: SalaryRecord

    @Query private var allTransactions: [Transaction]
    @State private var editingPayment: SalaryPayment? = nil

    private var baseCurrency: String { appState.baseCurrency }

    private var sortedPayments: [SalaryPayment] {
        record.payments.sorted { $0.expectedDate > $1.expectedDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                Group {
                    if sortedPayments.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            VStack(spacing: FTSpacing.md) {
                                // Header summary
                                headerSummary

                                // Payment rows
                                VStack(spacing: 0) {
                                    ForEach(Array(sortedPayments.enumerated()), id: \.element.id) { index, payment in
                                        paymentRow(payment)
                                        if index < sortedPayments.count - 1 {
                                            Rectangle()
                                                .fill(FTColor.textPrimary.opacity(0.06))
                                                .frame(height: 0.5)
                                                .padding(.leading, FTSpacing.xxl + FTSpacing.md)
                                        }
                                    }
                                }
                                .ftGlass(FTRadius.xl)
                            }
                            .padding(.horizontal, FTSpacing.screen)
                            .padding(.top, FTSpacing.lg)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("Payment History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.ftBodySemibold)
                }
            }
            .sheet(item: $editingPayment) { payment in
                EditSalaryPaymentSheet(payment: payment, currency: record.currency) { amount, date, notes in
                    updatePayment(payment, amount: amount, date: date, notes: notes)
                }
            }
        }
    }

    // MARK: Header summary

    private var headerSummary: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(
                symbol: "banknote.fill",
                tint: Color.fromString(record.colorName),
                size: 46
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(record.employerName)
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text(record.jobTitle)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.0f%%", record.onTimeRate))
                    .font(.ftBodySemibold)
                    .foregroundStyle(record.onTimeRate >= 90 ? FTColor.income : FTColor.gold)
                Text("On-time")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    // MARK: Payment row

    @ViewBuilder
    private func paymentRow(_ payment: SalaryPayment) -> some View {
        HStack(spacing: FTSpacing.md) {
            // Status icon
            Image(systemName: payment.status.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.fromString(payment.status.color))
                .frame(width: 28, height: 28)

            // Dates and notes
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.expectedDate.formatted)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                HStack(spacing: FTSpacing.xs) {
                    if let receivedDate = payment.receivedDate {
                        Text("Received \(receivedDate.formatted)")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    } else {
                        Text("Expected \(payment.expectedDate.formatted)")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                    if payment.isLate {
                        Text("· Late")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.expense)
                    }
                }
                if let notes = payment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amounts + variance
            VStack(alignment: .trailing, spacing: 4) {
                Text((payment.receivedAmount ?? payment.expectedAmount).formatted(as: record.currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)

                if let received = payment.receivedAmount {
                    let diff = received - payment.expectedAmount
                    if abs(diff) > 0.01 {
                        let sign = diff >= 0 ? "+" : ""
                        Text("\(sign)\(String(format: "%.0f%%", payment.variancePercent))")
                            .font(.ftCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, FTSpacing.sm)
                            .padding(.vertical, 2)
                            .background(diff >= 0 ? FTColor.income : FTColor.expense, in: .capsule)
                    }
                }
            }

            HStack(spacing: FTSpacing.xs) {
                Button { editingPayment = payment } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                        .frame(width: 28, height: 28)
                        .background(.regularMaterial, in: .circle)
                }
                .buttonStyle(.plain)
                Button { deletePayment(payment) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FTColor.expense)
                        .frame(width: 28, height: 28)
                        .background(.regularMaterial, in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: FTSpacing.xl) {
            Spacer()
            FTIconTile(symbol: "clock.arrow.circlepath", tint: FTColor.textMuted, size: 56)
            VStack(spacing: FTSpacing.sm) {
                Text("No Payment History")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Payments recorded for \(record.employerName) will appear here.")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FTSpacing.xl)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private func deletePayment(_ payment: SalaryPayment) {
        if let tx = allTransactions.first(where: { $0.linkedSalaryPaymentId == payment.id }) {
            if let account = tx.account {
                let delta = currencyService.convert(tx.amount, from: tx.currency, to: account.currency)
                account.balance -= delta  // reverse the income credit
            }
            context.delete(tx)
        }
        record.payments.removeAll { $0.id == payment.id }
        record.updatedAt = Date()
        try? context.save()
    }

    private func updatePayment(_ old: SalaryPayment, amount: Double, date: Date, notes: String?) {
        if let tx = allTransactions.first(where: { $0.linkedSalaryPaymentId == old.id }) {
            let oldAmount = old.receivedAmount ?? old.expectedAmount
            if let account = tx.account, amount != oldAmount {
                let oldDelta = currencyService.convert(oldAmount, from: record.currency, to: account.currency)
                let newDelta = currencyService.convert(amount, from: record.currency, to: account.currency)
                account.balance -= oldDelta  // reverse old income
                account.balance += newDelta  // apply new income
            }
            tx.amount = amount
            tx.amountInBaseCurrency = currencyService.convert(amount, from: record.currency, to: baseCurrency)
            tx.date = date
            tx.notes = notes
            tx.updatedAt = Date()
        }
        var payments = record.payments
        if let idx = payments.firstIndex(where: { $0.id == old.id }) {
            payments[idx].receivedAmount = amount
            payments[idx].receivedDate = date
            payments[idx].notes = notes
            payments[idx].statusRaw = SalaryPaymentStatus.received.rawValue
        }
        record.payments = payments
        record.updatedAt = Date()
        try? context.save()
    }
}

// MARK: - EditSalaryPaymentSheet

private struct EditSalaryPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let payment: SalaryPayment
    let currency: String
    let onSave: (Double, Date, String?) -> Void

    @State private var amount: String = ""
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            formRow(label: "Amount (\(currency))") {
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Received Date") {
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(FTColor.accent)
                            }
                            Divider().padding(.leading, FTSpacing.screen)
                            formRow(label: "Notes") {
                                TextField("Optional notes", text: $notes)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .ftGlass(FTRadius.lg)
                        .padding(.horizontal, FTSpacing.screen)

                        Button("Save Changes") {
                            guard let amountValue = Double(amount), amountValue > 0 else { return }
                            onSave(amountValue, date, notes.isEmpty ? nil : notes)
                            dismiss()
                        }
                        .buttonStyle(.ftPrimary)
                        .padding(.horizontal, FTSpacing.screen)
                        .disabled(Double(amount) == nil || (Double(amount) ?? 0) <= 0)
                    }
                    .padding(.top, FTSpacing.lg)
                }
            }
            .navigationTitle("Edit Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.accent)
                }
            }
            .onAppear {
                amount = String(format: "%.2f", payment.receivedAmount ?? payment.expectedAmount)
                date = payment.receivedDate ?? Date()
                notes = payment.notes ?? ""
            }
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            content()
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.md)
    }
}

// IncomeService is defined in FinTrack/Core/Services/IncomeService.swift

// MARK: - Preview

#Preview("Salary Tracker") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SalaryRecord.self, Transaction.self, configurations: config)

    let record = SalaryRecord(
        employerName: "Acme Corp",
        jobTitle: "Senior Engineer",
        currency: "AED",
        expectedAmount: 25_000,
        expectedPaymentDay: 28,
        paymentFrequencyRaw: PaymentFrequency.monthly.rawValue,
        colorName: "teal"
    )
    container.mainContext.insert(record)

    return SalaryTrackerView()
        .modelContainer(container)
        .environment(AppState())
        .environment(CurrencyService.shared)
}
