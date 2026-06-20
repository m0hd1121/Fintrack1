import SwiftUI
import SwiftData

// MARK: - AddInvestmentView

struct AddInvestmentView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // MARK: Editing target
    var editingItem: Investment? = nil

    // MARK: - Form state

    // Section 1 — Basic Info
    @State private var name: String = ""
    @State private var symbol: String = ""
    @State private var exchange: String = ""
    @State private var investmentType: InvestmentType = .stock

    // Section 2 — Purchase Details
    @State private var quantityText: String = ""
    @State private var averageCostText: String = ""
    @State private var currentPriceText: String = ""
    @State private var currency: String = "USD"
    @State private var purchaseDate: Date = Date()

    // Section 3 — Fund Details (ETF / Mutual Fund only)
    @State private var expenseRatioText: String = ""
    @State private var dividendYieldText: String = ""

    // Section 4 — Purchase Lots
    @State private var trackLots: Bool = false
    @State private var lots: [PurchaseLot] = []
    @State private var showingAddLot: Bool = false

    // Inline lot mini-form
    @State private var lotDate: Date = Date()
    @State private var lotQtyText: String = ""
    @State private var lotCostText: String = ""
    @State private var lotNotes: String = ""

    // Section 5 — Notes
    @State private var notes: String = ""

    // MARK: - Constants

    private let currencies = ["USD", "AED", "EUR", "GBP", "SAR", "INR", "JPY", "CNY", "CHF", "CAD", "AUD", "SGD"]

    // MARK: - Computed

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var showFundDetails: Bool {
        investmentType == .etf || investmentType == .mutualFund
    }

    // MARK: - Init

    init(editingItem: Investment? = nil) {
        self.editingItem = editingItem
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        basicInfoSection
                        purchaseDetailsSection
                        if showFundDetails {
                            fundDetailsSection
                        }
                        purchaseLotsSection
                        notesSection
                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                    .animation(.snappy(duration: 0.25), value: showFundDetails)
                    .animation(.snappy(duration: 0.25), value: trackLots)
                    .animation(.snappy(duration: 0.25), value: showingAddLot)
                }

                saveButtonArea
            }
            .navigationTitle(editingItem == nil ? "Add Investment" : "Edit Investment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Section 1: Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Basic Info")

            VStack(spacing: 0) {
                // Name
                fieldRow(label: "Security Name") {
                    TextField("e.g. Apple Inc.", text: $name)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }

                divider

                // Symbol
                fieldRow(label: "Symbol / Ticker") {
                    TextField("e.g. AAPL", text: $symbol)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }

                divider

                // Exchange
                fieldRow(label: "Exchange") {
                    TextField("e.g. NASDAQ (optional)", text: $exchange)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                }

                divider

                // Type picker
                fieldRow(label: "Type") {
                    Menu {
                        ForEach(InvestmentType.allCases, id: \.self) { type in
                            Button {
                                investmentType = type
                            } label: {
                                Label(type.rawValue, systemImage: type.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Image(systemName: investmentType.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.fromString(investmentType.color))
                            Text(investmentType.rawValue)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Section 2: Purchase Details

    private var purchaseDetailsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Purchase Details")

            VStack(spacing: 0) {
                // Quantity
                fieldRow(label: "Quantity") {
                    TextField("0.00", text: $quantityText)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }

                divider

                // Average Cost
                fieldRow(label: "Avg Cost per Unit") {
                    TextField("0.00", text: $averageCostText)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }

                divider

                // Current Price
                fieldRow(label: "Current Price") {
                    TextField("0.00", text: $currentPriceText)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }

                divider

                // Currency
                fieldRow(label: "Currency") {
                    Menu {
                        ForEach(currencies, id: \.self) { code in
                            Button(code) { currency = code }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Text(currency)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }

                divider

                // Purchase Date
                HStack(spacing: FTSpacing.md) {
                    Text("Purchase Date")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.sm)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Section 3: Fund Details

    private var fundDetailsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Fund Details")

            VStack(spacing: 0) {
                fieldRow(label: "Expense Ratio %") {
                    TextField("0.00", text: $expenseRatioText)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }

                divider

                fieldRow(label: "Dividend Yield %") {
                    TextField("0.00", text: $dividendYieldText)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Section 4: Purchase Lots

    private var purchaseLotsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Purchase Lots")

            VStack(spacing: 0) {
                // Toggle
                FTToggleRow(
                    symbol: "list.number",
                    tint: FTColor.catBlue,
                    title: "Track Purchase Lots (FIFO/LIFO)",
                    isOn: $trackLots
                )

                if trackLots {
                    divider

                    // Existing lots
                    if !lots.isEmpty {
                        ForEach(lots) { lot in
                            lotRow(lot: lot)
                            if lot.id != lots.last?.id {
                                divider
                            }
                        }
                        divider
                    }

                    // Add lot button
                    if !showingAddLot {
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                showingAddLot = true
                                lotDate = Date()
                                lotQtyText = ""
                                lotCostText = ""
                                lotNotes = ""
                            }
                        } label: {
                            HStack(spacing: FTSpacing.sm) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(FTColor.accent)
                                Text("Add Lot")
                                    .font(.ftBodySemibold)
                                    .foregroundStyle(FTColor.accent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, FTSpacing.md)
                        }
                        .buttonStyle(.plain)
                    } else {
                        addLotForm
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    private func lotRow(lot: PurchaseLot) -> some View {
        HStack(spacing: FTSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(lot.quantity.formatted(.number.precision(.fractionLength(0...4)))) units @ \(lot.costPerUnit.formatted(.number.precision(.fractionLength(2))))")
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text(lot.purchaseDate, style: .date)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                if let n = lot.notes, !n.isEmpty {
                    Text(n)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }
            }
            Spacer()
            Button {
                withAnimation { lots.removeAll { $0.id == lot.id } }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FTColor.expense)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, FTSpacing.md)
    }

    private var addLotForm: some View {
        VStack(spacing: 0) {
            Text("New Lot")
                .font(.ftHeadline)
                .foregroundStyle(FTColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, FTSpacing.md)

            divider

            HStack(spacing: FTSpacing.md) {
                Text("Date")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                Spacer()
                DatePicker("", selection: $lotDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(FTColor.accent)
            }
            .padding(.vertical, FTSpacing.sm)

            divider

            fieldRow(label: "Quantity") {
                TextField("0.00", text: $lotQtyText)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }

            divider

            fieldRow(label: "Cost per Unit") {
                TextField("0.00", text: $lotCostText)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }

            divider

            fieldRow(label: "Notes") {
                TextField("Optional", text: $lotNotes)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                    .multilineTextAlignment(.trailing)
            }

            divider

            HStack(spacing: FTSpacing.md) {
                Button("Cancel") {
                    withAnimation(.snappy(duration: 0.25)) { showingAddLot = false }
                }
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FTSpacing.md)
                .ftGlassInteractive(FTRadius.md)

                Button("Add") {
                    commitLot()
                }
                .font(.ftBodySemibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FTSpacing.md)
                .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.md))
                .disabled(lotQtyText.isEmpty || lotCostText.isEmpty)
                .opacity((lotQtyText.isEmpty || lotCostText.isEmpty) ? 0.5 : 1)
            }
            .padding(.vertical, FTSpacing.md)
        }
    }

    // MARK: - Section 5: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Notes")

            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $notes)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Save Button

    private var saveButtonArea: some View {
        VStack(spacing: 0) {
            Button(editingItem == nil ? "Save Investment" : "Update Investment") {
                save()
            }
            .buttonStyle(.ftPrimary)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.5)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, FTSpacing.xl)
        .padding(.top, FTSpacing.md)
        .background {
            LinearGradient(
                colors: [FTColor.bgBase.opacity(0), FTColor.bgBase],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.ftLabel)
            .tracking(1.6)
            .foregroundStyle(FTColor.textMuted)
            .padding(.leading, FTSpacing.xs)
            .padding(.bottom, FTSpacing.xs)
    }

    @ViewBuilder
    private func fieldRow<Trailing: View>(label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize()
            Spacer()
            trailing()
        }
        .padding(.vertical, FTSpacing.md)
    }

    private var divider: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.06))
            .frame(height: 0.5)
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let item = editingItem else { return }
        name              = item.name
        symbol            = item.symbol
        exchange          = item.exchange ?? ""
        investmentType    = item.type
        quantityText      = item.quantity > 0 ? String(format: "%g", item.quantity) : ""
        averageCostText   = item.averageCost > 0 ? String(format: "%.2f", item.averageCost) : ""
        currentPriceText  = item.currentPrice > 0 ? String(format: "%.2f", item.currentPrice) : ""
        currency          = item.currency
        purchaseDate      = item.purchaseDate
        expenseRatioText  = item.expenseRatio > 0 ? String(format: "%g", item.expenseRatio) : ""
        dividendYieldText = item.dividendYield > 0 ? String(format: "%g", item.dividendYield) : ""
        notes             = item.notes ?? ""
        let existingLots  = item.lots
        if !existingLots.isEmpty {
            trackLots = true
            lots = existingLots
        }
    }

    private func commitLot() {
        let qty  = Double(lotQtyText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cost = Double(lotCostText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard qty > 0, cost > 0 else { return }
        let lot = PurchaseLot(
            quantity: qty,
            costPerUnit: cost,
            purchaseDate: lotDate,
            notes: lotNotes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : lotNotes.trimmingCharacters(in: .whitespaces)
        )
        withAnimation(.snappy(duration: 0.25)) {
            lots.append(lot)
            showingAddLot = false
        }
    }

    private func save() {
        let qty          = Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let avgCost      = Double(averageCostText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let curPrice     = Double(currentPriceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let expRatio     = Double(expenseRatioText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let divYield     = Double(dividendYieldText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let trimmedName  = name.trimmingCharacters(in: .whitespaces)
        let trimmedSym   = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        let trimmedExch  = exchange.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        if let item = editingItem {
            item.name          = trimmedName
            item.symbol        = trimmedSym
            item.exchange      = trimmedExch.isEmpty ? nil : trimmedExch
            item.type          = investmentType
            item.quantity      = qty
            item.averageCost   = avgCost
            item.currentPrice  = curPrice
            item.currency      = currency
            item.purchaseDate  = purchaseDate
            item.expenseRatio  = expRatio
            item.dividendYield = divYield
            item.notes         = trimmedNotes.isEmpty ? nil : trimmedNotes
            item.updatedAt     = Date()
            if trackLots { item.lots = lots }
        } else {
            let investment = Investment(
                name:          trimmedName,
                symbol:        trimmedSym,
                type:          investmentType,
                quantity:      qty,
                averageCost:   avgCost,
                currentPrice:  curPrice,
                currency:      currency,
                exchange:      trimmedExch.isEmpty ? nil : trimmedExch,
                notes:         trimmedNotes.isEmpty ? nil : trimmedNotes,
                purchaseDate:  purchaseDate,
                expenseRatio:  expRatio,
                dividendYield: divYield
            )
            if trackLots { investment.lots = lots }
            context.insert(investment)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Investment") {
    AddInvestmentView()
        .modelContainer(for: Investment.self, inMemory: true)
}

#Preview("Edit Investment") {
    let inv = Investment(
        name: "Apple Inc.",
        symbol: "AAPL",
        type: .stock,
        quantity: 10,
        averageCost: 172.50,
        currentPrice: 195.00,
        currency: "USD",
        exchange: "NASDAQ"
    )
    return AddInvestmentView(editingItem: inv)
        .modelContainer(for: Investment.self, inMemory: true)
}
