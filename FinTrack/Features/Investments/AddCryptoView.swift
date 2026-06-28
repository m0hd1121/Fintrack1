import SwiftUI
import SwiftData

// MARK: - AddCryptoView

struct AddCryptoView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(CryptoPriceService.self) private var cryptoPriceService
    @Environment(CurrencyService.self) private var currencyService

    // MARK: Editing target
    var editingItem: CryptoHolding? = nil

    // MARK: - Form state

    // Coin search
    @State private var coinSearch: String = ""

    // Section 1 — Asset
    @State private var cryptoName: String = ""
    @State private var cryptoSymbol: String = ""
    @State private var exchangeLabel: String = ""
    @State private var walletAddress: String = ""
    @State private var showWalletAddress: Bool = false

    // Section 2 — Purchase
    @State private var quantityText: String = ""
    @State private var averageCostText: String = ""
    @State private var currency: String = "USD"
    @State private var purchaseDate: Date = Date()

    // Section 3 — Purchase Lots
    @State private var trackLots: Bool = false
    @State private var lots: [PurchaseLot] = []
    @State private var showingAddLot: Bool = false

    // Inline lot mini-form
    @State private var lotDate: Date = Date()
    @State private var lotQtyText: String = ""
    @State private var lotCostText: String = ""
    @State private var lotNotes: String = ""

    // Section 4 — Notes
    @State private var notes: String = ""

    // MARK: - Constants

    private let currencies = ["USD", "AED", "EUR", "USDT"]

    // MARK: - Computed

    private var canSave: Bool {
        !cryptoName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Live price in the selected currency, sourced from CryptoPriceService (USD) and converted.
    private var livePrice: Double? {
        let sym = cryptoSymbol.trimmingCharacters(in: .whitespaces).uppercased()
        guard !sym.isEmpty, let usd = cryptoPriceService.usdPrice(for: sym) else { return nil }
        return currencyService.convert(usd, from: "USD", to: currency)
    }

    private var livePriceLabel: String {
        guard let p = livePrice else { return "—" }
        if p >= 1 { return String(format: "%.2f %@", p, currency) }
        return String(format: "%.6f %@", p, currency)
    }

    // MARK: - Init

    init(editingItem: CryptoHolding? = nil) {
        self.editingItem = editingItem
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        coinPickerSection
                        assetSection
                        purchaseSection
                        purchaseLotsSection
                        notesSection
                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                    .animation(.snappy(duration: 0.25), value: trackLots)
                    .animation(.snappy(duration: 0.25), value: showingAddLot)
                    .animation(.snappy(duration: 0.2), value: showWalletAddress)
                }

                saveButtonArea
            }
            .navigationTitle(editingItem == nil ? "Add Crypto" : "Edit Crypto")
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

    // MARK: - Coin Picker

    private var coinPickerSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Choose Coin")

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                    TextField("Search Bitcoin, ETH, SOL…", text: $coinSearch)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !coinSearch.isEmpty {
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { coinSearch = "" }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(FTColor.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, FTSpacing.lg)
                .padding(.vertical, FTSpacing.md)

                divider

                let coins = cryptoPriceService.searchCoins(query: coinSearch)
                if coins.isEmpty {
                    Text("No coins found")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, FTSpacing.xxl)
                } else {
                    let visible = Array(coins.prefix(80))
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(visible.enumerated()), id: \.element.symbol) { idx, coin in
                                coinPickerRow(coin)
                                if idx < visible.count - 1 {
                                    divider
                                        .padding(.leading, FTSpacing.lg + 38 + FTSpacing.md)
                                }
                            }
                        }
                    }
                    .frame(height: 240)
                }
            }
            .ftGlass(FTRadius.lg)
        }
    }

    private func coinPickerRow(_ coin: (symbol: String, name: String)) -> some View {
        let isSelected = cryptoSymbol.uppercased() == coin.symbol
        let usdPrice = cryptoPriceService.usdPrice(for: coin.symbol)

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                cryptoSymbol = coin.symbol
                cryptoName = coin.name
            }
        } label: {
            HStack(spacing: FTSpacing.md) {
                // Symbol badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(FTColor.accentGradient) : AnyShapeStyle(FTColor.accent.opacity(0.12)))
                        .frame(width: 38, height: 38)
                    Text(String(coin.symbol.prefix(4)))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(isSelected ? .white : FTColor.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.name)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                    Text(coin.symbol)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }

                Spacer(minLength: 0)

                if let p = usdPrice {
                    Text(p >= 1 ? String(format: "$%.2f", p) : String(format: "$%.5f", p))
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(isSelected ? FTColor.accent : Color.clear)
            }
            .padding(.horizontal, FTSpacing.lg)
            .padding(.vertical, FTSpacing.sm + 2)
            .background(isSelected ? FTColor.accent.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 1: Asset

    private var assetSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Asset")

            VStack(spacing: 0) {
                // Name
                fieldRow(label: "Name") {
                    TextField("e.g. Bitcoin", text: $cryptoName)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }

                divider

                // Symbol
                fieldRow(label: "Symbol") {
                    TextField("e.g. BTC", text: $cryptoSymbol)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }

                divider

                // Exchange / Wallet Label
                fieldRow(label: "Exchange / Wallet") {
                    TextField("e.g. Binance (optional)", text: $exchangeLabel)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }

                divider

                // Wallet Address with eye toggle
                HStack(spacing: FTSpacing.md) {
                    Text("Wallet Address")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    if showWalletAddress {
                        TextField("0x... (optional)", text: $walletAddress)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        if walletAddress.isEmpty {
                            Text("0x... (optional)")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                        } else {
                            Text(String(repeating: "•", count: min(walletAddress.count, 12)))
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            showWalletAddress.toggle()
                        }
                    } label: {
                        Image(systemName: showWalletAddress ? "eye.slash" : "eye")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FTColor.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.lg)
        }
    }

    // MARK: - Section 2: Purchase

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Purchase")

            VStack(spacing: 0) {
                fieldRow(label: "Quantity (tokens)") {
                    TextField("0.00", text: $quantityText)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }

                divider

                fieldRow(label: "Avg Cost per Token") {
                    TextField("0.00", text: $averageCostText)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }

                divider

                // Live price — read-only, auto-populated from API
                HStack(spacing: FTSpacing.md) {
                    Text("Current Price")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    if cryptoPriceService.isRefreshing && livePrice == nil {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.65).tint(FTColor.accent)
                            Text("Fetching…")
                                .font(.ftBody).foregroundStyle(FTColor.textMuted)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(livePrice != nil ? Color.green : FTColor.textMuted)
                                .frame(width: 7, height: 7)
                            Text(livePriceLabel)
                                .font(.ftBody)
                                .foregroundStyle(livePrice != nil ? FTColor.textPrimary : FTColor.textMuted)
                        }
                    }
                }
                .padding(.vertical, FTSpacing.md)

                divider

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

    // MARK: - Section 3: Purchase Lots

    private var purchaseLotsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            sectionLabel("Purchase Lots")

            VStack(spacing: 0) {
                FTToggleRow(
                    symbol: "list.number",
                    tint: FTColor.catPurple,
                    title: "Track Purchase Lots (FIFO/LIFO)",
                    isOn: $trackLots
                )

                if trackLots {
                    divider

                    if !lots.isEmpty {
                        ForEach(lots) { lot in
                            lotRow(lot: lot)
                            if lot.id != lots.last?.id {
                                divider
                            }
                        }
                        divider
                    }

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
                Text("\(lot.quantity.formatted(.number.precision(.fractionLength(0...8)))) tokens @ \(lot.costPerUnit.formatted(.number.precision(.fractionLength(2))))")
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

            fieldRow(label: "Cost per Token") {
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

    // MARK: - Section 4: Notes

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
            Button(editingItem == nil ? "Save Crypto" : "Update Crypto") {
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
        cryptoName      = item.name
        cryptoSymbol    = item.symbol
        exchangeLabel   = item.exchange ?? ""
        walletAddress   = item.walletAddress ?? ""
        quantityText    = item.quantity > 0 ? String(format: "%g", item.quantity) : ""
        averageCostText = item.averageCost > 0 ? String(format: "%.2f", item.averageCost) : ""
        currency        = item.currency
        purchaseDate    = item.purchaseDate
        notes           = item.notes ?? ""
        let existingLots = item.lots
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
        let curPrice     = livePrice ?? 0
        let trimmedName  = cryptoName.trimmingCharacters(in: .whitespaces)
        let trimmedSym   = cryptoSymbol.trimmingCharacters(in: .whitespaces).uppercased()
        let trimmedExch  = exchangeLabel.trimmingCharacters(in: .whitespaces)
        let trimmedWallet = walletAddress.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        if let item = editingItem {
            item.name          = trimmedName
            item.symbol        = trimmedSym
            item.exchange      = trimmedExch.isEmpty ? nil : trimmedExch
            item.walletAddress = trimmedWallet.isEmpty ? nil : trimmedWallet
            item.quantity      = qty
            item.averageCost   = avgCost
            item.currentPrice  = curPrice
            item.currency      = currency
            item.purchaseDate  = purchaseDate
            item.notes         = trimmedNotes.isEmpty ? nil : trimmedNotes
            item.updatedAt     = Date()
            if trackLots { item.lots = lots }
        } else {
            let holding = CryptoHolding(
                name:          trimmedName,
                symbol:        trimmedSym,
                quantity:      qty,
                averageCost:   avgCost,
                currentPrice:  curPrice,
                currency:      currency,
                walletAddress: trimmedWallet.isEmpty ? nil : trimmedWallet,
                exchange:      trimmedExch.isEmpty ? nil : trimmedExch,
                notes:         trimmedNotes.isEmpty ? nil : trimmedNotes,
                purchaseDate:  purchaseDate
            )
            if trackLots { holding.lots = lots }
            context.insert(holding)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Crypto") {
    AddCryptoView()
        .modelContainer(for: CryptoHolding.self, inMemory: true)
}

#Preview("Edit Crypto") {
    let holding = CryptoHolding(
        name: "Bitcoin",
        symbol: "BTC",
        quantity: 0.5,
        averageCost: 58000,
        currentPrice: 67000,
        currency: "USD",
        exchange: "Binance"
    )
    return AddCryptoView(editingItem: holding)
        .modelContainer(for: CryptoHolding.self, inMemory: true)
}
