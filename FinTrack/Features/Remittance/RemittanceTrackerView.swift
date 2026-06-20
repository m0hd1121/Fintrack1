import SwiftUI
import SwiftData

struct RemittanceTrackerView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \RemittanceRecord.date, order: .reverse) private var records: [RemittanceRecord]

    @State private var showingAdd = false
    @State private var filterProvider: RemittanceProvider? = nil

    private var filtered: [RemittanceRecord] {
        guard let p = filterProvider else { return records }
        return records.filter { $0.provider == p }
    }

    private var totalSent: Double { records.reduce(0) { $0 + $1.sentAmount } }
    private var totalFees: Double { records.reduce(0) { $0 + $1.fee } }
    private var currency: String { appState.baseCurrency }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                summaryCard
                if records.count > 1 { rateComparisonCard }
                providerFilter
                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "arrow.up.right.circle.fill",
                        title: "Track Your Remittances",
                        message: "Log money transfers to family and friends. Compare rates across providers and track fees.",
                        actionTitle: "Log Transfer"
                    ) { showingAdd = true }
                } else {
                    recordsList
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Remittance Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddRemittanceView() }
    }

    // MARK: – Summary

    private var summaryCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Sent").font(.ftLabel).foregroundStyle(FTColor.textSecondary).tracking(1.2)
                    Text(totalSent.formatted(as: currency)).font(.ftDisplay).foregroundStyle(FTColor.textPrimary)
                }
                Spacer()
                FTIconTile(symbol: "arrow.up.right.circle.fill", tint: FTColor.accent, size: 48)
            }
            HStack(spacing: 0) {
                remStat("Transfers", "\(records.count)", FTColor.accent)
                Spacer()
                remStat("Total Fees", totalFees.formatted(as: currency), FTColor.expense)
                Spacer()
                remStat("Avg Fee %", records.isEmpty ? "—" : (totalFees / max(1, totalSent) * 100).asPercentage(), FTColor.gold)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var rateComparisonCard: some View {
        let byProvider = Dictionary(grouping: records, by: { $0.providerDisplayName })
            .mapValues { recs in
                let avgRate = recs.reduce(0.0) { $0 + $1.effectiveRate } / Double(recs.count)
                let avgFee = recs.reduce(0.0) { $0 + $1.feePercent } / Double(recs.count)
                return (avgRate: avgRate, avgFee: avgFee, count: recs.count)
            }
            .sorted { $0.value.avgFee < $1.value.avgFee }

        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Image(systemName: "chart.bar.fill").foregroundStyle(FTColor.accent)
                Text("Provider Comparison").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            }
            ForEach(byProvider.prefix(4), id: \.key) { provider, stats in
                HStack {
                    Text(provider).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Avg fee: \(String(format: "%.2f", stats.avgFee))%")
                            .font(.ftCaption).foregroundStyle(FTColor.expense)
                        Text("\(stats.count) transfer\(stats.count == 1 ? "" : "s")")
                            .font(.system(size: 9)).foregroundStyle(FTColor.textMuted)
                    }
                }
            }
            if let best = byProvider.first {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "star.fill").foregroundStyle(FTColor.gold)
                    Text("Best rate: \(best.key) (\(String(format: "%.2f", best.value.avgFee))% avg fee)")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                .padding(FTSpacing.sm)
                .background(FTColor.gold.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var providerFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FTChip(symbol: "square.grid.2x2", title: "All", selected: filterProvider == nil)
                    .onTapGesture { filterProvider = nil }
                ForEach(RemittanceProvider.allCases, id: \.self) { p in
                    if records.contains(where: { $0.provider == p }) {
                        FTChip(symbol: p.icon, title: p.rawValue, selected: filterProvider == p)
                            .onTapGesture { filterProvider = filterProvider == p ? nil : p }
                    }
                }
            }
            .padding(.horizontal, FTSpacing.xs)
        }
    }

    private var recordsList: some View {
        VStack(spacing: FTSpacing.sm) {
            ForEach(filtered) { record in
                RemittanceRow(record: record)
            }
        }
    }

    private func remStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
    }
}

struct RemittanceRow: View {
    @Environment(\.modelContext) private var context
    let record: RemittanceRecord

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: record.provider.icon, tint: FTColor.accent, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.providerDisplayName).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("To \(record.recipientName) · \(record.recipientCountry)")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(record.date.relativeFormatted).font(.system(size: 10)).foregroundStyle(FTColor.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.senderCurrency) \(String(format: "%.0f", record.sentAmount))")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("→ \(record.receiverCurrency) \(String(format: "%.0f", record.receivedAmount))")
                    .font(.ftCaption).foregroundStyle(FTColor.income)
                if record.fee > 0 {
                    Text("Fee: \(record.fee.formatted(as: record.senderCurrency))")
                        .font(.system(size: 9)).foregroundStyle(FTColor.expense)
                }
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(record)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: – Add Remittance

struct AddRemittanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var provider: RemittanceProvider = .wise
    @State private var customProvider = ""
    @State private var recipientName = ""
    @State private var recipientCountry = ""
    @State private var sentAmount = 0.0
    @State private var receivedAmount = 0.0
    @State private var exchangeRate = 0.0
    @State private var fee = 0.0
    @State private var senderCurrency: String = "AED"
    @State private var receiverCurrency: String = "INR"
    @State private var referenceNumber = ""
    @State private var date = Date()
    @State private var notes = ""

    private let commonCurrencies = ["AED", "INR", "PKR", "PHP", "BDT", "NPR", "USD", "GBP", "EUR", "EGP", "SAR"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    Picker("Provider", selection: $provider) {
                        ForEach(RemittanceProvider.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.icon).tag(p)
                        }
                    }
                    if provider == .custom {
                        TextField("Provider Name", text: $customProvider)
                    }
                }
                Section("Recipient") {
                    TextField("Recipient Name", text: $recipientName)
                    TextField("Country", text: $recipientCountry)
                }
                Section("Transfer Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("From Currency", selection: $senderCurrency) {
                        ForEach(commonCurrencies, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("To Currency", selection: $receiverCurrency) {
                        ForEach(commonCurrencies, id: \.self) { Text($0).tag($0) }
                    }
                    HStack {
                        Text("Amount Sent")
                        Spacer()
                        TextField("0", value: $sentAmount, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Amount Received")
                        Spacer()
                        TextField("0", value: $receivedAmount, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Exchange Rate")
                        Spacer()
                        TextField("0", value: $exchangeRate, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fee")
                        Spacer()
                        TextField("0", value: $fee, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    TextField("Reference Number (optional)", text: $referenceNumber)
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
            }
            .navigationTitle("Log Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(FTColor.accent)
                        .disabled(recipientName.isEmpty || sentAmount == 0)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear { senderCurrency = appState.baseCurrency }
        }
    }

    private func save() {
        let record = RemittanceRecord(
            date: date,
            provider: provider,
            customProviderName: provider == .custom ? customProvider : nil,
            senderCurrency: senderCurrency,
            receiverCurrency: receiverCurrency,
            sentAmount: sentAmount,
            receivedAmount: receivedAmount,
            exchangeRate: exchangeRate,
            fee: fee,
            recipientName: recipientName,
            recipientCountry: recipientCountry,
            referenceNumber: referenceNumber.isEmpty ? nil : referenceNumber,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(record)
        try? context.save()
        dismiss()
    }
}
