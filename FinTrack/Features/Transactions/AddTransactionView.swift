import SwiftUI
import SwiftData
import PhotosUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @State private var scanner = ReceiptScannerService.shared

    var editingTransaction: Transaction? = nil

    @Query private var accounts: [Account]
    @Query private var budgets: [Budget]

    @State private var title = ""
    @State private var amount = ""
    @State private var type: TransactionType = .expense
    @State private var category: TransactionCategory = .food
    @State private var date = Date()
    @State private var currency = "AED"
    @State private var selectedAccount: Account? = nil
    @State private var toAccount: Account? = nil
    @State private var notes = ""
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var chequeNumber = ""
    @State private var chequeDate = Date()
    @State private var isRecurring = false
    @State private var recurringFrequency: RecurringFrequency = .monthly
    @State private var merchant = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var receiptImage: UIImage? = nil
    @State private var isSaving = false
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @FocusState private var amountFocused: Bool

    // #23 – balance validation
    @State private var showingInsufficientFunds = false

    private var isEditing: Bool { editingTransaction != nil }

    private let typeOrder: [TransactionType] = [.expense, .income, .transfer]

    private var typeBinding: Binding<Int> {
        Binding(
            get: { typeOrder.firstIndex(of: type) ?? 0 },
            set: { newIndex in
                type = typeOrder[newIndex]
                updateDefaultCategory(for: type)
            }
        )
    }

    // #23 – computed available balance in selected account's currency
    private var availableBalance: Double? {
        guard type == .expense, let acc = selectedAccount else { return nil }
        return acc.balance
    }

    private var amountDouble: Double? {
        let v = AmountTextField.double(from: amount)
        return v > 0 ? v : nil
    }

    // #23 – convert entered amount to account currency for comparison
    private var enteredAmountInAccountCurrency: Double? {
        guard let amt = amountDouble, let acc = selectedAccount else { return amountDouble }
        return currencyService.convert(amt, from: currency, to: acc.currency)
    }

    private var isBalanceInsufficient: Bool {
        guard type == .expense,
              !isEditing,
              let balance = availableBalance,
              let entered = enteredAmountInAccountCurrency
        else { return false }
        return entered > balance
    }

    private var canSave: Bool {
        guard !title.isEmpty, amountDouble != nil, !isBalanceInsufficient else { return false }
        if type == .transfer {
            guard let from = selectedAccount, let to = toAccount, from.id != to.id else { return false }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        FTSegmentedControl(options: ["Expense", "Income", "Transfer"], selection: typeBinding)

                        amountCard
                        if type == .transfer {
                            transferCard
                        } else {
                            categorySection
                        }
                        detailsCard
                        recurringCard
                        notesReceiptCard

                        if let scan = scanner.scanResult {
                            scanResultsCard(scan)
                        }

                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                    .padding(.bottom, FTSpacing.lg)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                // Pinned CTA
                Button {
                    saveTransaction()
                } label: {
                    Text(isEditing ? "Update Transaction" : "Add Transaction")
                }
                .buttonStyle(.ftPrimary)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.55)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle(isEditing ? "Edit Transaction" : "New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(FTColor.textSecondary)
                            .frame(width: 30, height: 30)
                            .ftGlass(FTRadius.sm)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onAppear(perform: loadEditingData)
            .dismissKeyboardOnTap()  // #8
        }
    }

    // MARK: - Amount card

    private var amountCard: some View {
        VStack(spacing: FTSpacing.md) {
            Menu {
                Picker("Currency", selection: $currency) {
                    ForEach(currencyService.supportedCurrencies.prefix(12)) { info in
                        Text("\(info.flag) \(info.code)").tag(info.code)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currency).font(.ftCallout)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(FTColor.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
            }

            TextField("0.00", text: $amount)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.ftDisplay)
                .foregroundStyle(FTColor.textPrimary)
                .focused($amountFocused)
                .onChange(of: amount) { _, newValue in
                    let formatted = AmountTextField.format(newValue)
                    if formatted != newValue { amount = formatted }
                }

            if isBalanceInsufficient, let acc = selectedAccount {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Insufficient funds — \(acc.name) has \(acc.balance.formatted(as: acc.currency))")
                }
                .font(.ftCaption)
                .foregroundStyle(FTColor.expense)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.xxl)
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Transfer card

    private var transferCard: some View {
        VStack(spacing: 0) {
            // From account
            detailMenuRow(
                label: "From Account",
                value: selectedAccount?.name ?? "Select Account"
            ) {
                Picker("From Account", selection: $selectedAccount) {
                    Text("Select").tag(Optional<Account>.none)
                    ForEach(accounts.filter { !$0.isArchived }) { acc in
                        HStack {
                            Text(acc.name)
                            Spacer()
                            Text(acc.balance.formatted(as: acc.currency))
                                .foregroundStyle(.secondary)
                        }
                        .tag(Optional<Account>.some(acc))
                    }
                }
            }

            if let from = selectedAccount {
                HStack {
                    Spacer()
                    Text("Balance: \(from.balance.formatted(as: from.currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                .padding(.bottom, FTSpacing.sm)
            }

            Divider().opacity(0.4)

            // Arrow indicator
            HStack {
                Spacer()
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(FTColor.accent)
                Spacer()
            }
            .padding(.vertical, FTSpacing.sm)

            Divider().opacity(0.4)

            // To account
            detailMenuRow(
                label: "To Account",
                value: toAccount?.name ?? "Select Account"
            ) {
                Picker("To Account", selection: $toAccount) {
                    Text("Select").tag(Optional<Account>.none)
                    ForEach(accounts.filter { !$0.isArchived && $0.id != selectedAccount?.id }) { acc in
                        Text(acc.name).tag(Optional<Account>.some(acc))
                    }
                }
            }

            if let to = toAccount {
                HStack {
                    Spacer()
                    Text("Balance: \(to.balance.formatted(as: to.currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                .padding(.bottom, FTSpacing.sm)
            }

            // Same-account warning
            if let from = selectedAccount, let to = toAccount, from.id == to.id {
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(FTColor.expense)
                    Text("Source and destination must be different accounts")
                        .font(.ftCaption).foregroundStyle(FTColor.expense)
                }
                .padding(.vertical, FTSpacing.sm)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("Category")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(FTColor.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    ForEach(relevantCategories, id: \.self) { cat in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { category = cat }
                        } label: {
                            FTChip(symbol: cat.icon, title: cat.rawValue, selected: category == cat)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Details card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: FTSpacing.md) {
                Text("Title").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                TextField("Description", text: $title)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
            }
            .padding(.vertical, 13)

            Divider().opacity(0.4)

            HStack(spacing: FTSpacing.md) {
                Text("Merchant").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                TextField("Optional", text: $merchant)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
            }
            .padding(.vertical, 13)

            if !accounts.isEmpty && type != .transfer {
                Divider().opacity(0.4)
                detailMenuRow(label: "Account", value: selectedAccount?.name ?? "None") {
                    Picker("Account", selection: $selectedAccount) {
                        Text("None").tag(Optional<Account>.none)
                        ForEach(accounts.filter { !$0.isArchived }) { acc in
                            Text(acc.name).tag(Optional<Account>.some(acc))
                        }
                    }
                }
                if let balance = availableBalance, let acc = selectedAccount {
                    HStack {
                        Spacer()
                        Text("Available: \(balance.formatted(as: acc.currency))")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    .padding(.bottom, FTSpacing.sm)
                }
            }

            Divider().opacity(0.4)
            detailMenuRow(label: "Payment", value: paymentMethod.rawValue) {
                Picker("Payment Method", selection: $paymentMethod) {
                    ForEach(PaymentMethod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }

            if paymentMethod == .cheque {
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.md) {
                    Text("Cheque No.").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    TextField("Enter cheque number", text: $chequeNumber)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        .frame(maxWidth: 160)
                }
                .padding(.vertical, 13)

                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.md) {
                    Text("Cheque Date").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    DatePicker("", selection: $chequeDate, displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(.vertical, 9)
            }

            Divider().opacity(0.4)
            HStack(spacing: FTSpacing.md) {
                Text("Date").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            .padding(.vertical, 9)
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private func detailMenuRow<P: View>(label: String, value: String, @ViewBuilder picker: () -> P) -> some View {
        Menu {
            picker()
        } label: {
            HStack(spacing: FTSpacing.md) {
                Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FTColor.textMuted)
            }
            .padding(.vertical, 13)
        }
    }

    // MARK: - Recurring card

    private var recurringCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isRecurring) {
                Text("Make Recurring").font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
            .tint(FTColor.accent)
            .padding(.vertical, 13)

            if isRecurring {
                Divider().opacity(0.4)
                detailMenuRow(label: "Frequency", value: recurringFrequency.rawValue) {
                    Picker("Frequency", selection: $recurringFrequency) {
                        ForEach(RecurringFrequency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Notes & Receipt card

    private var notesReceiptCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Notes & Receipt")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(FTColor.textSecondary)

            TextField("Add a note...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .font(.ftBody)
                .foregroundStyle(FTColor.textPrimary)

            // Tags
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.xs) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag)").font(.ftCaption).foregroundStyle(FTColor.accent)
                                Button { tags.removeAll { $0 == tag } } label: {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(FTColor.textMuted)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.regularMaterial, in: Capsule())
                        }
                    }
                }
            }
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "tag").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                TextField("Add tag...", text: $tagInput)
                    .font(.ftCaption)
                    .submitLabel(.done)
                    .onSubmit {
                        let t = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if !t.isEmpty && !tags.contains(t) { tags.append(t) }
                        tagInput = ""
                    }
            }

            // Dashed receipt-attach row
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "camera.viewfinder")
                    Text(receiptImage == nil ? "Attach Receipt" : "Replace Receipt")
                    Spacer()
                }
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.accent)
                .padding(FTSpacing.md)
                .frame(maxWidth: .infinity)
                .background(FTColor.accent.opacity(0.08), in: .rect(cornerRadius: FTRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: FTRadius.sm)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundStyle(FTColor.accent.opacity(0.4))
                )
            }
            .onChange(of: selectedPhoto) { _, item in loadReceiptImage(from: item) }

            if let image = receiptImage {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))

                Button {
                    Task {
                        await scanner.scanReceipt(image: image)
                        if let result = scanner.scanResult { applyScanResult(result) }
                    }
                } label: {
                    HStack {
                        Image(systemName: "text.viewfinder")
                        Text(scanner.isScanning ? "Scanning…" : "Scan Receipt")
                        Spacer()
                    }
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                }
                .buttonStyle(.glass)
                .disabled(scanner.isScanning)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }

    private func scanResultsCard(_ scan: ScannedReceiptData) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            // Header
            HStack(spacing: FTSpacing.sm) {
                Label(
                    scan.merchantNeedsReview || scan.totalNeedsReview || scan.dateNeedsReview
                        ? "Scan Complete — Review Flagged Fields"
                        : "Scan Results Applied",
                    systemImage: scan.merchantNeedsReview || scan.totalNeedsReview || scan.dateNeedsReview
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.seal.fill"
                )
                .font(.ftBodySemibold)
                .foregroundStyle(
                    scan.merchantNeedsReview || scan.totalNeedsReview || scan.dateNeedsReview
                        ? FTColor.expense : FTColor.income
                )
            }

            Divider().opacity(0.3)

            // Merchant
            if let m = scan.merchant {
                scanRow(
                    icon: "storefront",
                    label: "Merchant",
                    value: m,
                    confidence: scan.merchantConfidence,
                    needsReview: scan.merchantNeedsReview
                )
            }

            // Amount
            if let a = scan.totalAmount {
                scanRow(
                    icon: "banknote",
                    label: "Amount",
                    value: a.formatted(as: scan.currency),
                    confidence: scan.totalConfidence,
                    needsReview: scan.totalNeedsReview
                )
            }

            // Date
            if let d = scan.date {
                scanRow(
                    icon: "calendar",
                    label: "Date",
                    value: d.formatted(date: .abbreviated, time: .omitted),
                    confidence: scan.dateConfidence,
                    needsReview: scan.dateNeedsReview
                )
            }

            if !scan.wasReceiptDetected {
                Label("Receipt edges not detected — verify values", systemImage: "viewfinder.trianglebadge.exclamationmark")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }

    @ViewBuilder
    private func scanRow(icon: String, label: String, value: String, confidence: Float, needsReview: Bool) -> some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: icon)
                .font(.ftCaption)
                .foregroundStyle(needsReview ? FTColor.expense : FTColor.textSecondary)
                .frame(width: 16)
            Text("\(label): \(value)")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            if needsReview {
                Text("Review")
                    .font(.ftLabel)
                    .foregroundStyle(FTColor.expense)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(FTColor.expense.opacity(0.12), in: .capsule)
            } else {
                Text("\(Int(confidence * 100))%")
                    .font(.ftLabel)
                    .foregroundStyle(FTColor.textMuted)
            }
        }
    }

    // MARK: – Helpers

    private var relevantCategories: [TransactionCategory] {
        switch type {
        case .income:
            return [.salary, .bonus, .freelance, .business, .investmentIncome, .rental, .dividends,
                    .interestIncome, .personalLentRepayment, .other]
        case .expense:
            return [.food, .shopping, .transportation, .fuel, .utilities, .rent, .mortgage, .education,
                    .medical, .entertainment, .travel, .insurance, .investments, .subscriptions, .gifts,
                    .personalCare, .childcare, .pets, .charity, .loanRepayment, .creditCard, .personalLent, .other]
        case .transfer: return [.transfer]
        }
    }

    private func updateDefaultCategory(for type: TransactionType) {
        switch type {
        case .income:   category = .salary
        case .expense:  category = .food
        case .transfer: category = .transfer
        }
    }

    /// Downsamples an image so its longest side is at most `maxDimension`,
    /// preserving aspect ratio. Keeps memory use bounded while leaving enough
    /// resolution for OCR receipt scanning.
    private func downsampled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension, longestSide > 0 else { return image }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func loadReceiptImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                if case .success(let data) = result, let data {
                    receiptImage = UIImage(data: data).map { downsampled($0, maxDimension: 1500) }
                    // #20 – auto-scan as soon as image is loaded
                    if let img = receiptImage {
                        Task {
                            await scanner.scanReceipt(image: img)
                            if let result = scanner.scanResult {
                                applyScanResult(result)
                            }
                        }
                    }
                }
            }
        }
    }

    private func applyScanResult(_ scan: ScannedReceiptData) {
        if let m = scan.merchant, title.isEmpty  { title = m }
        if let m = scan.merchant, merchant.isEmpty { merchant = m }
        if let a = scan.totalAmount              { amount = AmountTextField.string(from: a) }
        if let d = scan.date                     { date = d }
        currency = scan.currency
        paymentMethod = scan.paymentMethod
        category = scan.suggestedCategory
    }

    private func loadEditingData() {
        guard let tx = editingTransaction else { return }
        title = tx.title; amount = AmountTextField.string(from: tx.amount); type = tx.type; category = tx.category
        date = tx.date; currency = tx.currency; notes = tx.notes ?? ""
        paymentMethod = tx.paymentMethod; isRecurring = tx.isRecurring
        merchant = tx.merchant ?? ""; selectedAccount = tx.account
        chequeNumber = tx.chequeNumber ?? ""
        if let cd = tx.chequeDate { chequeDate = cd }
        toAccount = tx.toAccount
        tags = tx.tags
        if let data = tx.receiptImageData { receiptImage = UIImage(data: data) }
    }

    private func saveTransaction() {
        guard let amountValue = amountDouble, !title.isEmpty else { return }

        // #23 – Final guard before saving
        if isBalanceInsufficient { showingInsufficientFunds = true; return }

        isSaving = true
        let baseCurrency = appState.baseCurrency
        let convertedAmount = currencyService.convert(amountValue, from: currency, to: baseCurrency)

        if let tx = editingTransaction {
            // Reverse the previous account-balance effect before applying new values
            if let oldAccount = tx.account {
                let oldDelta = currencyService.convert(tx.amount, from: tx.currency, to: oldAccount.currency)
                switch tx.type {
                case .income:   oldAccount.balance -= oldDelta
                case .expense:  oldAccount.balance += oldDelta
                case .transfer: break
                }
            }

            tx.title = title; tx.amount = amountValue; tx.currency = currency
            tx.amountInBaseCurrency = convertedAmount; tx.type = type; tx.category = category
            tx.date = date; tx.notes = notes.isEmpty ? nil : notes
            tx.paymentMethod = paymentMethod; tx.isRecurring = isRecurring
            tx.merchant = merchant.isEmpty ? nil : merchant
            tx.chequeNumber = paymentMethod == .cheque && !chequeNumber.isEmpty ? chequeNumber : nil
            tx.chequeDate   = paymentMethod == .cheque ? chequeDate : nil
            tx.tags = tags
            tx.account = selectedAccount
            tx.toAccount = type == .transfer ? toAccount : nil
            tx.updatedAt = Date()
            if let img = receiptImage { tx.receiptImageData = img.jpegData(compressionQuality: 0.7) }

            // Apply the new account-balance effect
            if let newAccount = selectedAccount {
                let newDelta = currencyService.convert(amountValue, from: currency, to: newAccount.currency)
                switch type {
                case .income:   newAccount.balance += newDelta
                case .expense:  newAccount.balance -= newDelta
                case .transfer: break
                }
            }
        } else {
            let aiCategory = AICategorizationService.shared.suggestCategory(for: title, amount: amountValue, type: type)
            let tx = Transaction(
                title: title, amount: amountValue, currency: currency,
                amountInBaseCurrency: convertedAmount, type: type,
                category: aiCategory != .other ? aiCategory : category,
                date: date, notes: notes.isEmpty ? nil : notes,
                isRecurring: isRecurring,
                recurringRule: isRecurring ? RecurringRule(
                    frequency: recurringFrequency, interval: 1, endDate: nil, maxOccurrences: nil,
                    nextDueDate: Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
                ) : nil,
                merchant: merchant.isEmpty ? nil : merchant, paymentMethod: paymentMethod,
                chequeNumber: paymentMethod == .cheque && !chequeNumber.isEmpty ? chequeNumber : nil,
                chequeDate:   paymentMethod == .cheque ? chequeDate : nil,
                tags: tags
            )
            if let img = receiptImage { tx.receiptImageData = img.jpegData(compressionQuality: 0.7) }
            tx.account = selectedAccount
            tx.toAccount = type == .transfer ? toAccount : nil
            context.insert(tx)

            // Update account balance
            // #7 – only update running balance, not re-derive from scratch
            if type == .transfer {
                // Debit source, credit destination
                if let from = selectedAccount {
                    let delta = currencyService.convert(amountValue, from: currency, to: from.currency)
                    from.balance -= delta
                    if from.minimumBalanceEnabled && from.balance < from.minimumBalance {
                        NotificationService.shared.sendMinimumBalanceAlert(
                            accountName: from.name, balance: from.balance,
                            minimum: from.minimumBalance, currency: from.currency
                        )
                    }
                }
                if let to = toAccount {
                    let delta = currencyService.convert(amountValue, from: currency, to: to.currency)
                    to.balance += delta
                }
            } else if let account = selectedAccount {
                let delta = currencyService.convert(amountValue, from: currency, to: account.currency)
                switch type {
                case .income:   account.balance += delta
                case .expense:  account.balance -= delta
                case .transfer: break
                }
                // #22 – minimum balance check
                if account.minimumBalanceEnabled && account.balance < account.minimumBalance {
                    NotificationService.shared.sendMinimumBalanceAlert(
                        accountName: account.name, balance: account.balance,
                        minimum: account.minimumBalance, currency: account.currency
                    )
                }
            }
        }

        try? context.save()

        // Fire budget alert if expense crosses 80% threshold
        if type == .expense {
            let base = appState.baseCurrency
            let now = Date()
            let cal = Calendar.current
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            if let matchingBudget = budgets.first(where: { $0.category == category }) {
                let allTx = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
                let spent = allTx
                    .filter { $0.type == .expense && $0.category == category && $0.date >= monthStart }
                    .reduce(0.0) { $0 + $1.amountInBaseCurrency }
                let limit = currencyService.convert(matchingBudget.amount, from: matchingBudget.currency, to: base)
                if limit > 0 && spent / limit >= 0.8 {
                    NotificationService.shared.scheduleBudgetAlert(
                        categoryName: category.rawValue,
                        spent: spent, budget: limit, currency: base
                    )
                }
            }
        }

        isSaving = false
        dismiss()
    }
}
