import SwiftUI
import SwiftData

// MARK: - BillDetailView

struct BillDetailView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    // MARK: - Inputs

    let bill: Bill
    let transactions: [Transaction]

    // MARK: - Sheet / Alert State

    @State private var showingEdit = false
    @State private var showingRecordPayment = false
    @State private var showingDeleteAlert = false
    @State private var showingDeactivateAlert = false

    // MARK: - Waste Analysis

    @State private var wasteAnalysis: BillWasteAnalysis? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.xl) {
                        heroCard
                        if bill.isAutoPay { autoPayCard }
                        if !bill.priceHistory.isEmpty || bill.hasPriceIncreased { priceHistorySection }
                        remindersSection
                        if bill.isSubscription { wasteSection }
                        relatedTransactionsSection
                        billDetailsSection
                        bottomActions
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle(bill.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.ftBody)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: FTSpacing.md) {
                        Button {
                            showingEdit = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.ftBody)
                        }
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.ftBody)
                                .foregroundStyle(FTColor.expense)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                AddBillView(editingBill: bill)
            }
            .sheet(isPresented: $showingRecordPayment) {
                RecordPaymentSheet(bill: bill)
            }
            .alert("Delete Bill", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) { deleteBill() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \"\(bill.name)\" and all its history. This cannot be undone.")
            }
            .onAppear {
                wasteAnalysis = BillService.shared.analyzeWaste(bill: bill, transactions: transactions)
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: FTSpacing.lg) {
            // Icon + names row
            HStack(alignment: .top, spacing: FTSpacing.lg) {
                FTIconTile(
                    symbol: bill.icon,
                    tint: Color.fromString(bill.colorName),
                    size: 60
                )
                VStack(alignment: .leading, spacing: FTSpacing.xs) {
                    Text(bill.name)
                        .font(.ftTitle)
                        .foregroundStyle(FTColor.textPrimary)
                    if let provider = bill.provider, !provider.isEmpty {
                        Text(provider)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
            }

            // Amount
            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(bill.amount.formatted(as: bill.currency))
                        .font(.ftAmount)
                        .foregroundStyle(FTColor.accentGradient)
                    Text(bill.billingCycle.shortLabel)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textSecondary)
                }

                if bill.billingCycle != .monthly {
                    Text("≈ \(bill.monthlyEquivalent.formatted(as: bill.currency))/mo")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Urgency / Due date status
            urgencyBadgeRow

            // Record Payment button
            Button("Record Payment") {
                showingRecordPayment = true
            }
            .buttonStyle(.ftPrimary)
        }
        .padding(FTSpacing.xl)
        .ftGlass(FTRadius.xl)
    }

    @ViewBuilder
    private var urgencyBadgeRow: some View {
        HStack(spacing: FTSpacing.sm) {
            if bill.isOverdue {
                Label("Overdue", systemImage: "exclamationmark.circle.fill")
                    .font(.ftCallout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, FTSpacing.md)
                    .padding(.vertical, FTSpacing.xs + 2)
                    .background(FTColor.expense, in: .capsule)
            } else if bill.daysUntilDue <= 3 {
                Label("Due in \(bill.daysUntilDue) day\(bill.daysUntilDue == 1 ? "" : "s")",
                      systemImage: "clock.fill")
                    .font(.ftCallout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, FTSpacing.md)
                    .padding(.vertical, FTSpacing.xs + 2)
                    .background(.orange, in: .capsule)
            } else {
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "calendar")
                        .font(.ftCaption)
                    Text("Due \(bill.nextDueDate.formatted)")
                        .font(.ftCallout)
                }
                .foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Auto-Pay Card

    private var autoPayCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "shield.checkered", tint: FTColor.accent, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-Pay Enabled")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("Window: \(bill.autoPayWindowDays) day\(bill.autoPayWindowDays == 1 ? "" : "s") after due date")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(FTColor.accent)
                    .font(.title3)
            }
            .padding(FTSpacing.lg)

            if bill.notifiedAutoPayMissed {
                Divider().padding(.horizontal, FTSpacing.lg)
                HStack(spacing: FTSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                        .font(.ftBody)
                    Text("Auto-payment not detected! Check your account.")
                        .font(.ftCallout)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FTSpacing.lg)
                .background(FTColor.expense.opacity(0.85), in: .rect(cornerRadius: FTRadius.md))
                .padding([.horizontal, .bottom], FTSpacing.sm)
            }
        }
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Price History Section

    @ViewBuilder
    private var priceHistorySection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            sectionHeader(title: "Price History", symbol: "chart.line.uptrend.xyaxis")

            FTCard {
                VStack(spacing: 0) {
                    let entries = bill.priceHistory
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        priceHistoryRow(
                            entry: entry,
                            nextAmount: index + 1 < entries.count ? entries[index + 1].amount : bill.amount,
                            isCurrent: false
                        )
                        if index < entries.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }

                    if !bill.priceHistory.isEmpty {
                        Divider().padding(.leading, 44)
                    }

                    // Current amount row
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(FTColor.accent)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current")
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                            Text(Date().formatted)
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: FTSpacing.xs) {
                            if bill.hasPriceIncreased {
                                let pct = bill.previousAmount.map {
                                    $0 > 0 ? ((bill.amount - $0) / $0) * 100 : 0
                                } ?? 0
                                Label(String(format: "+%.1f%%", pct), systemImage: "arrow.up")
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.expense)
                                    .padding(.horizontal, FTSpacing.sm)
                                    .padding(.vertical, 3)
                                    .background(FTColor.expense.opacity(0.12), in: .capsule)
                            }
                            Text(bill.amount.formatted(as: bill.currency))
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                        }
                    }
                    .padding(.vertical, FTSpacing.md)
                }
            }
        }
    }

    private func priceHistoryRow(entry: PriceHistoryEntry, nextAmount: Double, isCurrent: Bool) -> some View {
        let isIncrease = nextAmount > entry.amount + 0.001
        let isDecrease = nextAmount < entry.amount - 0.001

        return HStack(spacing: FTSpacing.md) {
            Image(systemName: isIncrease ? "arrow.up.circle.fill" : (isDecrease ? "arrow.down.circle.fill" : "minus.circle.fill"))
                .font(.system(size: 20))
                .foregroundStyle(isIncrease ? FTColor.expense : (isDecrease ? FTColor.income : FTColor.textMuted))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                if let note = entry.note {
                    Text(note)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(entry.amount.formatted(as: bill.currency))
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
        }
        .padding(.vertical, FTSpacing.md)
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            sectionHeader(title: "Reminders", symbol: "bell.badge.fill")

            FTCard {
                if bill.reminderDaysBefore.isEmpty {
                    Text("No reminders configured")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textMuted)
                        .padding(.vertical, FTSpacing.xs)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FTSpacing.sm) {
                            ForEach([1, 3, 7], id: \.self) { day in
                                let isActive = bill.reminderDaysBefore.contains(day)
                                reminderChip(days: day, isActive: isActive)
                            }
                            ForEach(bill.reminderDaysBefore.filter { ![1, 3, 7].contains($0) }, id: \.self) { day in
                                reminderChip(days: day, isActive: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func reminderChip(days: Int, isActive: Bool) -> some View {
        HStack(spacing: FTSpacing.xs) {
            Image(systemName: isActive ? "bell.fill" : "bell.slash")
                .font(.system(size: 13, weight: .semibold))
            Text(days == 1 ? "1 day before" : "\(days) days before")
                .font(.ftCallout)
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.vertical, FTSpacing.sm + 1)
        .foregroundStyle(isActive ? .white : FTColor.textMuted)
        .background(isActive ? FTColor.accent : FTColor.textMuted.opacity(0.15), in: .capsule)
    }

    // MARK: - Waste Analysis Section

    @ViewBuilder
    private var wasteSection: some View {
        if let waste = wasteAnalysis, waste.isLikelyUnused && !bill.isDismissedWasteAlert {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                sectionHeader(title: "Usage Insights", symbol: "waveform.path.ecg")

                VStack(spacing: FTSpacing.md) {
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(FTColor.gold)
                            .font(.title3)
                        Text("Possibly Unused Subscription")
                            .font(.ftHeadline)
                            .foregroundStyle(FTColor.textPrimary)
                        Spacer()
                    }

                    Text(waste.suggestion)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: FTSpacing.xs) {
                        HStack {
                            Text("Confidence")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(String(format: "%.0f%%", waste.confidence * 100))
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                        }
                        FTProgressBar(value: waste.confidence, color: FTColor.gold)
                    }

                    Button("Dismiss") {
                        bill.isDismissedWasteAlert = true
                        try? context.save()
                        wasteAnalysis = nil
                    }
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(FTSpacing.lg)
                .background(FTColor.gold.opacity(0.1), in: .rect(cornerRadius: FTRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: FTRadius.lg)
                        .strokeBorder(FTColor.gold.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Related Transactions Section

    private var relatedTransactionsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            sectionHeader(title: "Recent Transactions", symbol: "arrow.left.arrow.right.circle.fill")

            let matched = matchedTransactions
            if matched.isEmpty {
                FTCard {
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(FTColor.textMuted)
                            .font(.ftHeadline)
                        Text("No matching transactions found")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, FTSpacing.xs)
                }
            } else {
                FTCard {
                    VStack(spacing: 0) {
                        ForEach(Array(matched.enumerated()), id: \.element.id) { index, tx in
                            FTTransactionRow(
                                symbol: tx.category.icon,
                                tint: Color.fromString(tx.category.color),
                                title: tx.title,
                                subtitle: tx.date.formatted,
                                amount: "−\(tx.amountInBaseCurrency.formatted(as: appState.baseCurrency))",
                                amountColor: FTColor.expense
                            )
                            if index < matched.count - 1 {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                }
            }
        }
    }

    private var matchedTransactions: [Transaction] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let billNameLower = bill.name.lowercased()
        let providerLower = bill.provider?.lowercased()

        return transactions
            .filter { tx in
                guard tx.type == .expense else { return false }
                guard tx.date >= cutoff else { return false }

                let txTitle = tx.title.lowercased()
                let txMerchant = tx.merchant?.lowercased()

                let nameMatch = txTitle.contains(billNameLower) || billNameLower.contains(txTitle)
                let providerMatch = providerLower.map { prov in
                    txMerchant?.contains(prov) ?? false
                } ?? false

                return nameMatch || providerMatch
            }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Bill Details Section

    private var billDetailsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            sectionHeader(title: "Bill Details", symbol: "info.circle.fill")

            FTCard {
                VStack(spacing: 0) {
                    detailRow(
                        symbol: bill.billCategory.icon,
                        tint: Color.fromString(bill.billCategory.colorName),
                        label: "Category",
                        value: bill.billCategory.rawValue
                    )
                    Divider().padding(.leading, 48)

                    detailRow(
                        symbol: bill.billingCycle.icon,
                        tint: FTColor.accent,
                        label: "Billing Cycle",
                        value: bill.billingCycle.rawValue
                    )
                    Divider().padding(.leading, 48)

                    detailRow(
                        symbol: "creditcard.fill",
                        tint: FTColor.accentDeep,
                        label: "Payment Method",
                        value: bill.paymentMethod.rawValue
                    )
                    Divider().padding(.leading, 48)

                    detailRow(
                        symbol: "calendar",
                        tint: bill.isOverdue ? FTColor.expense : FTColor.accent,
                        label: "Next Due",
                        value: bill.nextDueDate.formatted,
                        valueColor: bill.isOverdue ? FTColor.expense : FTColor.textPrimary
                    )
                    Divider().padding(.leading, 48)

                    detailRow(
                        symbol: "checkmark.circle.fill",
                        tint: FTColor.income,
                        label: "Last Paid",
                        value: bill.lastPaidDate?.formatted ?? "Not yet recorded",
                        valueColor: bill.lastPaidDate == nil ? FTColor.textMuted : FTColor.textPrimary
                    )
                    Divider().padding(.leading, 48)

                    detailRow(
                        symbol: "calendar.badge.clock",
                        tint: FTColor.gold,
                        label: "Annual Cost",
                        value: bill.annualEquivalent.formatted(as: bill.currency)
                    )
                    Divider().padding(.leading, 48)

                    detailRow(
                        symbol: "clock.fill",
                        tint: FTColor.textMuted,
                        label: "Created",
                        value: bill.createdAt.formatted,
                        showDivider: false
                    )

                    if let notes = bill.notes, !notes.isEmpty {
                        Divider().padding(.leading, 48)
                        HStack(alignment: .top, spacing: FTSpacing.md) {
                            FTIconTile(symbol: "note.text", tint: FTColor.textSecondary, size: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Notes")
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textMuted)
                                Text(notes)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(.vertical, FTSpacing.md)
                    }
                }
            }
        }
    }

    private func detailRow(
        symbol: String,
        tint: Color,
        label: String,
        value: String,
        valueColor: Color = FTColor.textPrimary,
        showDivider: Bool = true
    ) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: symbol, tint: tint, size: 32)
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, FTSpacing.md)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: FTSpacing.md) {
            // Activate / Deactivate
            Button {
                toggleActive()
            } label: {
                HStack {
                    Image(systemName: bill.isActive ? "pause.circle.fill" : "play.circle.fill")
                    Text(bill.isActive ? "Deactivate Bill" : "Activate Bill")
                }
                .font(.ftHeadline)
                .foregroundStyle(bill.isActive ? FTColor.textSecondary : FTColor.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .ftGlass(FTRadius.md)
            }

            // Delete
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Bill")
                }
                .font(.ftHeadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(FTColor.expense, in: .rect(cornerRadius: FTRadius.md))
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, symbol: String) -> some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: symbol)
                .font(.ftCallout)
                .foregroundStyle(FTColor.accent)
            Text(title)
                .font(.ftLabel)
                .foregroundStyle(FTColor.textSecondary)
                .tracking(1.2)
                .textCase(.uppercase)
        }
    }

    // MARK: - Actions

    private func toggleActive() {
        bill.isActive.toggle()
        if bill.isActive {
            BillService.shared.scheduleReminders(for: bill)
        } else {
            BillService.shared.cancelReminders(for: bill)
        }
        try? context.save()
    }

    private func deleteBill() {
        BillService.shared.cancelReminders(for: bill)
        context.delete(bill)
        try? context.save()
        dismiss()
    }
}

// MARK: - RecordPaymentSheet

private struct RecordPaymentSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let bill: Bill

    @State private var amount: Double
    @State private var paymentDate = Date()
    @State private var isProcessing = false

    init(bill: Bill) {
        self.bill = bill
        self._amount = State(initialValue: bill.amount)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                VStack(spacing: FTSpacing.xl) {
                    // Bill summary
                    HStack(spacing: FTSpacing.md) {
                        FTIconTile(
                            symbol: bill.icon,
                            tint: Color.fromString(bill.colorName),
                            size: 48
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(bill.name)
                                .font(.ftHeadline)
                                .foregroundStyle(FTColor.textPrimary)
                            Text("Usual amount: \(bill.amount.formatted(as: bill.currency))")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.lg)

                    // Amount field
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("Amount")
                            .font(.ftLabel)
                            .foregroundStyle(FTColor.textSecondary)
                            .tracking(1.2)
                            .textCase(.uppercase)

                        HStack {
                            Text(bill.currency)
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textSecondary)
                            TextField("0.00", value: $amount, format: .number)
                                .font(.ftAmount)
                                .foregroundStyle(FTColor.textPrimary)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.md)
                    }

                    // Date picker
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("Payment Date")
                            .font(.ftLabel)
                            .foregroundStyle(FTColor.textSecondary)
                            .tracking(1.2)
                            .textCase(.uppercase)

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

                    Spacer()

                    Button {
                        recordPayment()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Record Payment")
                        }
                    }
                    .buttonStyle(.ftPrimary)
                    .disabled(amount <= 0 || isProcessing)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.lg)
                .padding(.bottom, FTSpacing.xl)
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func recordPayment() {
        isProcessing = true
        BillService.shared.recordPayment(bill: bill, amount: amount, date: paymentDate)
        try? context.save()
        isProcessing = false
        dismiss()
    }
}

// MARK: - AddBillView Stub (forward declaration for Edit sheet)
// AddBillView should be defined in its own file; this ensures the module resolves.
// If AddBillView does not yet exist, uncomment the stub below:

// struct AddBillView: View {
//     var editingBill: Bill? = nil
//     @Environment(\.dismiss) private var dismiss
//     var body: some View {
//         Text("Add / Edit Bill — Coming Soon")
//             .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
//     }
// }

// MARK: - Preview

#Preview("Bill Detail") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Bill.self, Transaction.self, configurations: config)

    let bill = Bill(
        name: "Netflix",
        provider: "Netflix Inc.",
        billCategory: .entertainment,
        amount: 49.99,
        currency: "AED",
        billingCycle: .monthly,
        nextDueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
        isAutoPay: true,
        autoPayWindowDays: 3,
        paymentMethod: .creditCard,
        notes: "Family plan — shared with household.",
        colorName: "purple",
        icon: "play.rectangle.fill",
        isActive: true,
        isSubscription: true,
        reminderDaysBefore: [1, 3],
        priceHistory: [
            PriceHistoryEntry(amount: 39.99, date: Calendar.current.date(byAdding: .month, value: -6, to: Date())!),
            PriceHistoryEntry(amount: 45.00, date: Calendar.current.date(byAdding: .month, value: -3, to: Date())!)
        ]
    )
    container.mainContext.insert(bill)

    return BillDetailView(bill: bill, transactions: [])
        .modelContainer(container)
        .environment(AppState())
}
