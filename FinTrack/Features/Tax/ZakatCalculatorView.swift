import SwiftUI
import SwiftData

struct ZakatCalculatorView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var zakatRecords: [ZakatRecord]
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var investments: [Investment]
    @Query private var goldHoldings: [GoldHolding]
    @Query private var loans: [Loan]
    @Query private var moneyLent: [MoneyLent]

    let taxYear: Int

    @State private var record: ZakatRecord?
    @State private var showingPayment = false

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                if let r = record {
                    nisabStatusCard(r)
                    assetsSection(r)
                    deductionsSection(r)
                    zakatSummaryCard(r)
                    paymentSection(r)
                    zakatGuide
                } else {
                    loadingOrEmpty
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Zakat Calculator \(taxYear)")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .onAppear { loadOrCreate() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard let r = record else { return }
                    _ = TaxService.shared.prefillZakat(
                        record: r, transactions: transactions, accounts: accounts,
                        investments: investments, goldHoldings: goldHoldings,
                        moneyLent: moneyLent, loans: loans, currency: appState.baseCurrency
                    )
                    try? context.save()
                } label: {
                    Image(systemName: "arrow.clockwise").font(.ftCallout).foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingPayment) {
            if let r = record { ZakatPaymentSheet(record: r) }
        }
    }

    // MARK: - Nisab Status

    private func nisabStatusCard(_ r: ZakatRecord) -> some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NISAB THRESHOLD \(taxYear)").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(r.nisabThresholdAED.formatted(as: appState.baseCurrency))
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text(r.nisabBasis.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(r.isAboveNisab ? FTColor.income.opacity(0.12) : FTColor.textMuted.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: r.isAboveNisab ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.ftTitle)
                            .foregroundStyle(r.isAboveNisab ? FTColor.income : FTColor.textMuted)
                    }
                    Text(r.isAboveNisab ? "Zakat Due" : "Below Nisab")
                        .font(.ftCaption)
                        .foregroundStyle(r.isAboveNisab ? FTColor.income : FTColor.textMuted)
                }
            }

            Picker("Nisab Basis", selection: Binding(
                get: { r.nisabBasis },
                set: { r.nisabBasis = $0; try? context.save() }
            )) {
                ForEach(ZakatNisabBasis.allCases, id: \.rawValue) { b in
                    Text(b.rawValue).tag(b)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Assets Section

    private func assetsSection(_ r: ZakatRecord) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("ZAKATABLE ASSETS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                zakatInputRow(
                    icon: "banknote.fill", color: FTColor.income, label: "Cash & Savings",
                    value: Binding(get: { r.cashAndSavings }, set: { r.cashAndSavings = $0; try? context.save() })
                )
                zakatInputRow(
                    icon: "sparkle", color: FTColor.gold, label: "Gold Value (AED)",
                    value: Binding(get: { r.goldValueAED }, set: { r.goldValueAED = $0; try? context.save() })
                )
                zakatInputRow(
                    icon: "circle.fill", color: FTColor.textSecondary, label: "Silver Value (AED)",
                    value: Binding(get: { r.silverValueAED }, set: { r.silverValueAED = $0; try? context.save() })
                )
                zakatInputRow(
                    icon: "chart.line.uptrend.xyaxis", color: FTColor.catBlue, label: "Investments",
                    value: Binding(get: { r.investmentsValue }, set: { r.investmentsValue = $0; try? context.save() })
                )
                zakatInputRow(
                    icon: "shippingbox.fill", color: FTColor.catPurple, label: "Business Inventory",
                    value: Binding(get: { r.businessInventory }, set: { r.businessInventory = $0; try? context.save() })
                )
                zakatInputRow(
                    icon: "arrow.left.arrow.right.circle.fill", color: FTColor.catTeal, label: "Receivables (Money Owed to You)",
                    value: Binding(get: { r.receivablesValue }, set: { r.receivablesValue = $0; try? context.save() })
                )

                HStack {
                    Text("Total Assets").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Text(r.totalZakatableAssets.formatted(as: appState.baseCurrency))
                        .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                }
                .padding()
                .background(FTColor.income.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    // MARK: - Deductions Section

    private func deductionsSection(_ r: ZakatRecord) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("DEDUCTIONS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                zakatInputRow(
                    icon: "arrow.up.circle.fill", color: FTColor.expense, label: "Debts Due Within Year",
                    value: Binding(get: { r.immediateDebts }, set: { r.immediateDebts = $0; try? context.save() })
                )
                zakatInputRow(
                    icon: "house.fill", color: FTColor.catCoral, label: "Essential Expenses Due",
                    value: Binding(get: { r.basicExpenses }, set: { r.basicExpenses = $0; try? context.save() })
                )

                HStack {
                    Text("Net Zakatable Wealth").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Text(r.netZakatableWealth.formatted(as: appState.baseCurrency))
                        .font(.ftBodySemibold).foregroundStyle(r.isAboveNisab ? FTColor.gold : FTColor.textMuted)
                }
                .padding()
                .background((r.isAboveNisab ? FTColor.gold : FTColor.textMuted).opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    // MARK: - Zakat Summary

    private func zakatSummaryCard(_ r: ZakatRecord) -> some View {
        VStack(spacing: FTSpacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ZAKAT DUE \(taxYear)").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(r.zakatDue.formatted(as: appState.baseCurrency))
                        .font(.ftAmount)
                        .foregroundStyle(r.isAboveNisab ? FTColor.gold : FTColor.textMuted)
                    Text("2.5% of net zakatable wealth")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
            }

            if r.isPaid {
                FTProgressBar(value: r.progress, color: FTColor.income, height: 8)
                HStack {
                    Text("Paid: \(r.paidAmount.formatted(as: appState.baseCurrency))")
                        .font(.ftBody).foregroundStyle(FTColor.income)
                    Spacer()
                    Text("Remaining: \(r.remainingZakat.formatted(as: appState.baseCurrency))")
                        .font(.ftBody).foregroundStyle(r.remainingZakat > 0 ? FTColor.gold : FTColor.income)
                }
            }

            Toggle(isOn: Binding(
                get: { r.useManualOverride },
                set: { r.useManualOverride = $0; try? context.save() }
            )) {
                Text("Use manual override amount").font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
            .tint(FTColor.accent)

            if r.useManualOverride {
                HStack {
                    Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    TextField("Manual zakat amount", text: Binding(
                        get: { r.manualZakatAmount > 0 ? String(r.manualZakatAmount) : "" },
                        set: { r.manualZakatAmount = Double($0) ?? 0; try? context.save() }
                    ))
                    .keyboardType(.decimalPad)
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                }
            }
        }
        .padding()
        .background(FTColor.gold.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: FTRadius.xl).stroke(FTColor.gold.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Payment Section

    private func paymentSection(_ r: ZakatRecord) -> some View {
        VStack(spacing: FTSpacing.md) {
            if !r.isPaid && r.zakatDue > 0 {
                Button { showingPayment = true } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Record Zakat Payment")
                    }
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                    .background(FTColor.gold, in: .rect(cornerRadius: FTRadius.pill))
                }
                .buttonStyle(.plain)
            } else if r.isPaid {
                HStack(spacing: FTSpacing.md) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(FTColor.income).font(.ftHeadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zakat Paid ✓").font(.ftBodySemibold).foregroundStyle(FTColor.income)
                        if let pd = r.paidDate {
                            Text("Paid on \(pd.formatted)").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(FTColor.income.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg))
            }

            TextEditor(text: Binding(
                get: { r.notes ?? "" },
                set: { r.notes = $0.isEmpty ? nil : $0; try? context.save() }
            ))
            .font(.ftBody)
            .frame(height: 80)
            .padding()
            .ftGlass(FTRadius.lg)
            .overlay(alignment: .topLeading) {
                if r.notes == nil || r.notes!.isEmpty {
                    Text("Notes (optional)").font(.ftBody).foregroundStyle(FTColor.textMuted)
                        .padding(.horizontal, 20).padding(.top, 16).allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Zakat Guide

    private var zakatGuide: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("ABOUT ZAKAT").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                guideRow("Zakat is 2.5% of net zakatable wealth held for one lunar year.")
                guideRow("Nisab (gold): Equivalent of 87.48 grams of gold.")
                guideRow("Nisab (silver): Equivalent of 612.36 grams of silver.")
                guideRow("Silver nisab is typically lower — use gold for safety if uncertain.")
                guideRow("Gold & jewelry intended for sale = zakatable. Personal jewelry = scholarly disagreement.")
                guideRow("Receivables: only include amounts you are confident of receiving.")
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func guideRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Image(systemName: "moon.stars.fill").foregroundStyle(FTColor.gold).font(.ftCaption).frame(width: 18)
            Text(text).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Input Row

    @ViewBuilder
    private func zakatInputRow(icon: String, color: Color, label: String, value: Binding<Double>) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).font(.ftCallout).frame(width: 24)
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                .frame(width: 100)
        }
        .padding(.vertical, 10)
        Divider().opacity(0.2)
    }

    // MARK: - Empty / Loading

    private var loadingOrEmpty: some View {
        VStack(spacing: FTSpacing.lg) {
            Image(systemName: "moon.stars.fill").font(.system(size: 44)).foregroundStyle(FTColor.gold)
            Text("Preparing Calculator…").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            ProgressView().scaleEffect(1.2)
        }
        .padding(.top, 80)
    }

    // MARK: - Load/Create

    private func loadOrCreate() {
        if let existing = zakatRecords.first(where: { $0.taxYear == taxYear }) {
            record = existing
        } else {
            let r = ZakatRecord(taxYear: taxYear)
            context.insert(r)
            _ = TaxService.shared.prefillZakat(
                record: r, transactions: transactions, accounts: accounts,
                investments: investments, goldHoldings: goldHoldings,
                moneyLent: moneyLent, loans: loans, currency: appState.baseCurrency
            )
            try? context.save()
            record = r
        }
    }
}

// MARK: - Zakat Payment Sheet

struct ZakatPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let record: ZakatRecord

    @State private var amount = ""
    @State private var paymentDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    VStack(spacing: 8) {
                        Text("Record Zakat Payment")
                            .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        Text("Remaining: \(record.remainingZakat.formatted(as: "AED"))")
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(FTColor.gold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg))

                    VStack(spacing: FTSpacing.sm) {
                        HStack {
                            Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            TextField("Amount paid", text: $amount).keyboardType(.decimalPad)
                                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                            Button("Full") {
                                amount = String(format: "%.2f", record.remainingZakat)
                            }
                            .font(.ftCallout).foregroundStyle(FTColor.accent)
                        }
                        .padding().ftGlass(FTRadius.lg)

                        DatePicker("Payment Date", selection: $paymentDate, displayedComponents: .date)
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            .padding().ftGlass(FTRadius.lg)
                    }

                    Button(action: save) {
                        Text("Record Payment")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(FTColor.gold, in: .rect(cornerRadius: FTRadius.pill))
                    }
                    .buttonStyle(.plain).disabled(amount.isEmpty)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Zakat Payment")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() {
        guard let amt = Double(amount.replacingOccurrences(of: ",", with: "")) else { return }
        record.paidAmount += amt
        record.paidDate = paymentDate
        record.isPaid = record.paidAmount >= record.zakatDue
        record.updatedAt = Date()
        try? context.save()
        dismiss()
    }
}
