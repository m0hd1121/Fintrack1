import SwiftUI
import SwiftData
import Charts

struct VATTrackerView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var taxRecords: [TaxRecord]

    let taxYear: Int

    @State private var selectedTab = 0
    @State private var showingAdd = false
    @State private var selectedRecord: TaxRecord?
    @State private var filterType: VATRecordType? = nil

    private var tabs = ["Overview", "Records", "FTA Report"]

    init(taxYear: Int) {
        self.taxYear = taxYear
    }

    private var summary: VATSummary {
        TaxService.shared.vatSummary(records: taxRecords, taxYear: taxYear)
    }

    private var filteredRecords: [TaxRecord] {
        var base = taxRecords.filter { $0.taxYear == taxYear }
        if let f = filterType { base = base.filter { $0.vatType == f } }
        return base.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                FTSegmentedControl(options: tabs, selection: $selectedTab)
                    .padding(.horizontal, FTSpacing.screen)

                switch selectedTab {
                case 0:  overviewTab
                case 1:  recordsTab
                default: ftaTab
                }
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("UAE VAT Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus").font(.ftCallout).foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddVATRecordView(taxYear: taxYear)
        }
        .sheet(item: $selectedRecord) { record in
            VATRecordDetailSheet(record: record)
        }
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: FTSpacing.lg) {
            vatPositionCard
            quarterlyChart
            vatRateInfo
        }
        .padding(.horizontal, FTSpacing.screen)
    }

    private var vatPositionCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NET VAT POSITION \(taxYear)")
                        .font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    let net = summary.netVATPosition
                    Text(net.formatted(as: appState.baseCurrency))
                        .font(.ftAmount)
                        .foregroundStyle(net >= 0 ? FTColor.expense : FTColor.income)
                    Text(net >= 0 ? "Payable to FTA" : "Refund from FTA")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(summary.netVATPosition >= 0 ? FTColor.expense.opacity(0.1) : FTColor.income.opacity(0.1))
                        .frame(width: 60, height: 60)
                    Image(systemName: summary.netVATPosition >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.ftTitle)
                        .foregroundStyle(summary.netVATPosition >= 0 ? FTColor.expense : FTColor.income)
                }
            }

            HStack(spacing: FTSpacing.md) {
                vatStat(label: "Output VAT\n(Collected)", value: summary.totalVATCollected, color: FTColor.income)
                Divider().frame(height: 40)
                vatStat(label: "Input VAT\n(Paid)", value: summary.totalVATPaid, color: FTColor.expense)
                Divider().frame(height: 40)
                vatStat(label: "Reclaimable", value: summary.totalReclaimable, color: FTColor.catBlue)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func vatStat(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value.asCompact(currency: appState.baseCurrency))
                .font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                .multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var quarterlyChart: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("QUARTERLY BREAKDOWN")
                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            Chart {
                ForEach(summary.quarterlyBreakdown) { q in
                    BarMark(x: .value("Quarter", q.label), y: .value("VAT Paid", q.vatPaid))
                        .foregroundStyle(FTColor.expense.opacity(0.8))
                        .position(by: .value("Type", "Paid"))

                    BarMark(x: .value("Quarter", q.label), y: .value("VAT Collected", q.vatCollected))
                        .foregroundStyle(FTColor.income.opacity(0.8))
                        .position(by: .value("Type", "Collected"))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(FTColor.textSecondary)
                    AxisGridLine().foregroundStyle(FTColor.textMuted.opacity(0.2))
                }
            }
            .frame(height: 160)

            HStack(spacing: FTSpacing.lg) {
                legend(color: FTColor.expense, label: "Paid (Input)")
                legend(color: FTColor.income, label: "Collected (Output)")
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
    }

    private var vatRateInfo: some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: "info.circle.fill").foregroundStyle(FTColor.accent).font(.ftCallout)
            VStack(alignment: .leading, spacing: 2) {
                Text("UAE VAT Rate: 5%").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("Federal Tax Authority (FTA) requires quarterly VAT returns for registered businesses.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding()
        .background(FTColor.accent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
    }

    // MARK: - Records Tab

    private var recordsTab: some View {
        VStack(spacing: FTSpacing.md) {
            filterChips
                .padding(.horizontal, FTSpacing.screen)

            if filteredRecords.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: FTSpacing.sm) {
                    ForEach(filteredRecords) { record in
                        vatRecordRow(record)
                            .onTapGesture { selectedRecord = record }
                            .padding(.horizontal, FTSpacing.screen)
                    }
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FilterChip(title: "All", isSelected: filterType == nil) {
                    withAnimation { filterType = nil }
                }
                ForEach(VATRecordType.allCases, id: \.rawValue) { type in
                    FilterChip(title: type.rawValue, isSelected: filterType == type) {
                        withAnimation { filterType = filterType == type ? nil : type }
                    }
                }
            }
        }
    }

    private func vatRecordRow(_ record: TaxRecord) -> some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FTRadius.sm).fill(record.vatType.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: record.vatType.icon).foregroundStyle(record.vatType.color).font(.ftCallout)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(record.vendorOrCustomer).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(record.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(record.vatAmount.formatted(as: appState.baseCurrency))
                    .font(.ftBodySemibold).foregroundStyle(record.vatType.color)
                Text("VAT \(Int(record.vatRate))%").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(record)
                try? context.save()
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            Image(systemName: "percent").font(.system(size: 44)).foregroundStyle(FTColor.textMuted)
            Text("No VAT Records").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("Add VAT records for purchases and sales to track your UAE VAT position.")
                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, FTSpacing.xxl)
            Button { showingAdd = true } label: {
                Label("Add VAT Record", systemImage: "plus")
                    .font(.ftCallout).foregroundStyle(.white)
                    .padding().frame(maxWidth: 200)
                    .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 60)
    }

    // MARK: - FTA Report Tab

    private var ftaTab: some View {
        VStack(spacing: FTSpacing.md) {
            ForEach(1...4, id: \.self) { q in
                ftaQuarterCard(quarter: q)
            }
            .padding(.horizontal, FTSpacing.screen)

            ftaInfoCard
                .padding(.horizontal, FTSpacing.screen)
        }
    }

    private func ftaQuarterCard(quarter: Int) -> some View {
        let report = TaxService.shared.ftaReport(records: taxRecords, year: taxYear, quarter: quarter)
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Text("Q\(quarter) \(taxYear)").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Text(report.ftaNote)
                    .font(.ftCaption)
                    .foregroundStyle(report.isPayable ? FTColor.expense : FTColor.income)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background((report.isPayable ? FTColor.expense : FTColor.income).opacity(0.1))
                    .clipShape(Capsule())
            }
            HStack {
                ftaStatItem(label: "Output VAT", value: report.outputVAT, color: FTColor.income)
                Spacer()
                ftaStatItem(label: "Input VAT", value: report.inputVAT, color: FTColor.expense)
                Spacer()
                ftaStatItem(label: "Net", value: abs(report.netVAT),
                            color: report.isPayable ? FTColor.expense : FTColor.income)
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private func ftaStatItem(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            Text(value.formatted(as: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
        }
    }

    private var ftaInfoCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("FTA FILING GUIDE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ftaGuideRow("Register with FTA if annual taxable supplies exceed AED 375,000.")
                ftaGuideRow("Voluntary registration threshold: AED 187,500.")
                ftaGuideRow("File quarterly VAT returns within 28 days of each quarter end.")
                ftaGuideRow("Maintain VAT records for 5 years (real estate: 15 years).")
                ftaGuideRow("Late filing penalty: AED 1,000 for first offence, AED 2,000 for repeat.")
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private func ftaGuideRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(FTColor.income).font(.ftCaption)
            Text(text).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Add VAT Record

struct AddVATRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let taxYear: Int

    @State private var title = ""
    @State private var vendor = ""
    @State private var baseAmount = ""
    @State private var vatType: VATRecordType = .paid
    @State private var vatRate = 5.0
    @State private var date = Date()
    @State private var invoiceNumber = ""
    @State private var notes = ""

    private var vatAmount: Double {
        let base = Double(baseAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        return base * vatRate / 100
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("VAT TYPE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        Picker("VAT Type", selection: $vatType) {
                            ForEach(VATRecordType.allCases, id: \.rawValue) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .ftGlass(FTRadius.lg)

                    VStack(spacing: FTSpacing.sm) {
                        formField("Description", text: $title, placeholder: "e.g. Office supplies")
                        formField("Vendor / Customer", text: $vendor, placeholder: "Business name")
                        formField("Base Amount (\(appState.baseCurrency))", text: $baseAmount, placeholder: "0.00", keyboard: .decimalPad)
                        formField("Invoice Number", text: $invoiceNumber, placeholder: "Optional")
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            .padding()
                            .ftGlass(FTRadius.lg)
                        formField("Notes", text: $notes, placeholder: "Optional")
                    }

                    // VAT Preview
                    if vatAmount > 0 {
                        HStack {
                            Text("VAT Amount")
                                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(vatAmount.formatted(as: appState.baseCurrency))
                                .font(.ftBodySemibold).foregroundStyle(vatType.color)
                        }
                        .padding()
                        .background(vatType.color.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                    }

                    Button(action: save) {
                        Text("Save VAT Record")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
                    }
                    .buttonStyle(.plain)
                    .disabled(title.isEmpty || baseAmount.isEmpty)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Add VAT Record")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func formField(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private func save() {
        let base = Double(baseAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        let record = TaxRecord(
            title: title.isEmpty ? vendor : title,
            vendorOrCustomer: vendor,
            amount: base,
            vatAmount: vatAmount,
            vatRate: vatRate,
            vatType: vatType,
            date: date,
            invoiceNumber: invoiceNumber.isEmpty ? nil : invoiceNumber,
            currency: appState.baseCurrency,
            taxYear: taxYear,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(record)
        try? context.save()
        dismiss()
    }
}

// MARK: - VAT Record Detail Sheet

struct VATRecordDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let record: TaxRecord

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    // Header
                    VStack(spacing: FTSpacing.sm) {
                        ZStack {
                            Circle().fill(record.vatType.color.opacity(0.12)).frame(width: 64, height: 64)
                            Image(systemName: record.vatType.icon).font(.ftTitle).foregroundStyle(record.vatType.color)
                        }
                        Text(record.vatAmount.formatted(as: record.currency))
                            .font(.ftAmount).foregroundStyle(record.vatType.color)
                        Text(record.vatType.rawValue).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: FTSpacing.sm) {
                        detailRow("Description", record.title)
                        detailRow("Vendor / Customer", record.vendorOrCustomer)
                        detailRow("Base Amount", record.amount.formatted(as: record.currency))
                        detailRow("VAT Rate", "\(Int(record.vatRate))%")
                        detailRow("Total Amount", record.totalAmount.formatted(as: record.currency))
                        detailRow("Date", record.date.formatted)
                        detailRow("Tax Year", String(record.taxYear))
                        if let inv = record.invoiceNumber, !inv.isEmpty {
                            detailRow("Invoice #", inv)
                        }
                        if let notes = record.notes, !notes.isEmpty {
                            detailRow("Notes", notes)
                        }
                    }
                    .padding()
                    .ftGlass(FTRadius.xl)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("VAT Record")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
        }
    }
}
