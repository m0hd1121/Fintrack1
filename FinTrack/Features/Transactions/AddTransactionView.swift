import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation
import UniformTypeIdentifiers
import Combine

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    private let scanner = ReceiptScannerService.shared
    private let speech  = SpeechTransactionService.shared

    var editingTransaction: Transaction? = nil

    @Query private var accounts: [Account]
    @Query private var budgets: [Budget]
    @Query(filter: #Predicate<CustomCategory> { $0.isArchived == false }, sort: \CustomCategory.sortOrder)
    private var customCategories: [CustomCategory]
    @Query(sort: \CategorizationRule.priority)
    private var categorizationRules: [CategorizationRule]
    @Query(sort: \LoyaltyProgram.name) private var loyaltyPrograms: [LoyaltyProgram]

    // — Core fields
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

    // — New: pending / scheduled
    @State private var isPending    = false
    @State private var isScheduled  = false
    @State private var scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    // — New: subtype
    @State private var selectedSubtype: TransactionSubtype? = nil

    // — New: income source
    @State private var incomeSource = ""

    // — New: split transactions
    @State private var isSplitEnabled = false
    @State private var splitItems: [SplitItem] = []

    // — New: location
    @State private var latitude: Double? = nil
    @State private var longitude: Double? = nil
    @State private var locationLabel = ""
    @State private var showingLocationPicker = false
    @StateObject private var locationHelper = LocationHelper()

    // — New: documents
    @State private var showingDocumentPicker = false
    @State private var pendingDocuments: [(data: Data, filename: String, mime: String)] = []

    // — New: voice
    @State private var showingVoiceEntry = false

    // — New: tax flags & custom category
    @State private var isTaxDeductible = false
    @State private var isVATReclaimable = false
    @State private var customCategoryID: UUID? = nil

    // — Loyalty points
    @State private var selectedLoyaltyProgram: LoyaltyProgram? = nil
    @State private var toLoyaltyProgram: LoyaltyProgram? = nil
    @State private var loyaltyPoints = ""
    @State private var isLoyaltyTransfer = false

    // — New: AI & rules
    @State private var aiPrediction: CategoryPrediction? = nil
    @State private var appliedRuleName: String? = nil

    // — New: tag suggestions
    @State private var tagSuggestions: [String] = []

    // — New: category management sheet
    @State private var showingCategoryManagement = false

    // — Category search
    @State private var categorySearch = ""

    // — Lent / Borrowed mode (extends transaction type without touching the schema)
    @State private var modeIndex: Int = 0   // 0=Expense 1=Income 2=Transfer 3=Lent 4=Borrowed
    @State private var lentBorrowerName = ""
    @State private var lentHasDueDate = false
    @State private var lentDueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var borrowedLenderName = ""
    @State private var borrowedHasDueDate = false
    @State private var borrowedDueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    // — Duplicate / balance
    @State private var showingInsufficientFunds = false
    @State private var showingDuplicateWarning = false
    @State private var potentialDuplicate: Transaction? = nil

    private var isEditing: Bool { editingTransaction != nil }
    private var isLoyaltyCategory: Bool { category == .loyaltyEarned || category == .loyaltyRedeemed }
    private var loyaltyPointsDouble: Double { Double(loyaltyPoints) ?? 0 }
    private var isLentMode: Bool { modeIndex == 3 }
    private var isBorrowedMode: Bool { modeIndex == 4 }

    private var modeBinding: Binding<Int> {
        Binding(
            get: { modeIndex },
            set: { newIndex in
                modeIndex = newIndex
                selectedSubtype = nil
                isSplitEnabled = false
                splitItems = []
                switch newIndex {
                case 1: type = .income;   updateDefaultCategory(for: .income)
                case 2: type = .transfer; category = .transfer
                case 3: type = .expense;  category = .personalLent
                case 4: type = .income;   category = .other
                default: type = .expense; updateDefaultCategory(for: .expense)
                }
            }
        )
    }

    private var availableBalance: Double? {
        guard type == .expense, let acc = selectedAccount else { return nil }
        return acc.balance
    }

    private var amountDouble: Double? {
        let v = AmountTextField.double(from: amount)
        return v > 0 ? v : nil
    }

    private var enteredAmountInAccountCurrency: Double? {
        guard let amt = amountDouble, let acc = selectedAccount else { return amountDouble }
        return currencyService.convert(amt, from: currency, to: acc.currency)
    }

    private var isBalanceInsufficient: Bool {
        guard type == .expense, !isPending, !isEditing,
              let balance = availableBalance,
              let entered = enteredAmountInAccountCurrency
        else { return false }
        return entered > balance
    }

    private var splitTotal: Double { splitItems.reduce(0) { $0 + $1.amount } }
    private var splitIsValid: Bool {
        !isSplitEnabled || (abs(splitTotal - (amountDouble ?? 0)) < 0.01 && !splitItems.isEmpty)
    }

    private var canSave: Bool {
        guard amountDouble != nil, !isBalanceInsufficient, splitIsValid else { return false }
        if isLentMode     { return !lentBorrowerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if isBorrowedMode { return !borrowedLenderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !title.isEmpty else { return false }
        if type == .transfer {
            guard let from = selectedAccount, let to = toAccount, from.id != to.id else { return false }
        }
        if isLoyaltyCategory {
            guard loyaltyPointsDouble > 0 else { return false }
            if isLoyaltyTransfer {
                guard let from = selectedLoyaltyProgram, let to = toLoyaltyProgram, from.id != to.id else { return false }
            } else {
                guard selectedLoyaltyProgram != nil else { return false }
            }
        }
        if isScheduled, let sDate = Optional(scheduledDate), sDate <= Date() { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        FTSegmentedControl(options: ["Expense", "Income", "Transfer", "Lent", "Borrowed"], selection: modeBinding)

                        amountCard

                        if isLentMode {
                            lentDetailsCard
                        } else if isBorrowedMode {
                            borrowedDetailsCard
                        } else if type == .transfer {
                            transferCard
                        } else {
                            categorySection
                            if isLoyaltyCategory { loyaltyProgramCard }
                            if type == .expense && !isLoyaltyCategory { splitSection }
                        }

                        detailsCard
                        recurringCard
                        statusCard
                        if type == .expense && !isLentMode { taxSection }
                        notesReceiptCard

                        if !pendingDocuments.isEmpty { documentsPreviewCard }

                        if let scan = scanner.scanResult { scanResultsCard(scan) }

                        if showingDuplicateWarning { duplicateWarningCard }

                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                    .padding(.bottom, FTSpacing.lg)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { saveTransaction() } label: {
                    Text(isEditing ? "Update Transaction" : isLentMode ? "Record Lent" : isBorrowedMode ? "Record Borrowed" : "Add Transaction")
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: FTSpacing.sm) {
                        // Voice entry
                        Button {
                            showingVoiceEntry = true
                        } label: {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(FTColor.accent)
                        }
                        .accessibilityLabel("Voice Entry")

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
            }
            .onAppear(perform: loadEditingData)
            .dismissKeyboardOnTap()
            .onChange(of: title)    { _, _ in runAutoCategorization() }
            .onChange(of: merchant) { _, _ in runAutoCategorization(); updateTagSuggestions() }
            .onChange(of: type)     { _, _ in runAutoCategorization() }
            .onChange(of: tags)     { _, _ in updateTagSuggestions() }
            .sheet(isPresented: $showingCategoryManagement) { CategoryManagementView() }
            .sheet(isPresented: $showingVoiceEntry) {
                VoiceTransactionView { parsed in
                    applyVoiceResult(parsed)
                }
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.pdf, .image, .data],
                allowsMultipleSelection: true
            ) { result in
                handleDocumentImport(result)
            }
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
                .accessibilityLabel("Amount")
                .accessibilityHint("Enter the transaction amount")
                .onChange(of: amount) { _, newValue in
                    let formatted = AmountTextField.format(newValue)
                    if formatted != newValue { amount = formatted }
                    // Auto-sync split total when amount changes
                    if isSplitEnabled, let total = amountDouble, splitItems.count == 1 {
                        splitItems[0].amount = total
                    }
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
            detailMenuRow(label: "From Account", value: selectedAccount?.name ?? "Select Account") {
                Picker("From Account", selection: $selectedAccount) {
                    Text("Select").tag(Optional<Account>.none)
                    ForEach(accounts.filter { !$0.isArchived }) { acc in
                        Text(acc.name).tag(Optional<Account>.some(acc))
                    }
                }
            }
            if let from = selectedAccount {
                HStack { Spacer()
                    Text("Balance: \(from.balance.formatted(as: from.currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }.padding(.bottom, FTSpacing.sm)
            }
            Divider().opacity(0.4)
            HStack { Spacer()
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(FTColor.accent)
                Spacer()
            }.padding(.vertical, FTSpacing.sm)
            Divider().opacity(0.4)
            detailMenuRow(label: "To Account", value: toAccount?.name ?? "Select Account") {
                Picker("To Account", selection: $toAccount) {
                    Text("Select").tag(Optional<Account>.none)
                    ForEach(accounts.filter { !$0.isArchived && $0.id != selectedAccount?.id }) { acc in
                        Text(acc.name).tag(Optional<Account>.some(acc))
                    }
                }
            }
            if let to = toAccount {
                HStack { Spacer()
                    Text("Balance: \(to.balance.formatted(as: to.currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }.padding(.bottom, FTSpacing.sm)
            }
            if let from = selectedAccount, let to = toAccount, from.id == to.id {
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(FTColor.expense)
                    Text("Source and destination must be different accounts")
                        .font(.ftCaption).foregroundStyle(FTColor.expense)
                }.padding(.vertical, FTSpacing.sm)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                Text("Category")
                    .font(.ftLabel).tracking(1.6)
                    .foregroundStyle(FTColor.textSecondary)
                Spacer()
                // AI / rule confidence badge
                if let pred = aiPrediction, pred.confidence >= 0.3 {
                    HStack(spacing: 4) {
                        Image(systemName: pred.source == .rule ? "text.badge.checkmark" : "brain")
                            .font(.system(size: 10, weight: .semibold))
                        Text(pred.confidenceLabel)
                            .font(.ftLabel)
                    }
                    .foregroundStyle(pred.isHighConfidence ? FTColor.income : FTColor.gold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(
                        (pred.isHighConfidence ? FTColor.income : FTColor.gold).opacity(0.12),
                        in: .capsule
                    )
                }
            }

            // Search field
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(FTColor.textMuted)
                TextField("Search categories…", text: $categorySearch)
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.textPrimary)
                    .autocorrectionDisabled()
                if !categorySearch.isEmpty {
                    Button { withAnimation(.snappy(duration: 0.15)) { categorySearch = "" } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(FTColor.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FTSpacing.md)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: FTRadius.sm))

            if categorySearch.isEmpty {
                // Normal horizontal chip scroll — built-in categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.sm) {
                        ForEach(relevantCategories, id: \.self) { cat in
                            categoryChipButton(cat)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                // Custom categories row
                let customCats = relevantCustomCategories
                if !customCats.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FTSpacing.sm) {
                            ForEach(customCats) { cat in
                                customCategoryChipButton(cat)
                            }
                            manageButton
                        }
                        .padding(.horizontal, 2)
                    }
                } else {
                    manageButton
                }
            } else {
                // Search results grid
                let builtIn = filteredBuiltinCategories
                let custom  = filteredCustomCategories
                if builtIn.isEmpty && custom.isEmpty {
                    HStack(spacing: FTSpacing.sm) {
                        Image(systemName: "magnifyingglass").foregroundStyle(FTColor.textMuted)
                        Text("No categories match \"\(categorySearch)\"")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    .padding(.vertical, FTSpacing.sm)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110, maximum: 180), spacing: FTSpacing.sm)],
                        spacing: FTSpacing.sm
                    ) {
                        ForEach(builtIn, id: \.self) { cat in
                            categoryChipButton(cat)
                        }
                        ForEach(custom) { cat in
                            customCategoryChipButton(cat)
                        }
                    }
                }
            }

            // Rule applied banner
            if let ruleName = appliedRuleName {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Categorized by rule: \(ruleName)")
                        .font(.ftCaption)
                }
                .foregroundStyle(FTColor.income)
            }
        }
    }

    @ViewBuilder
    private func categoryChipButton(_ cat: TransactionCategory) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                category = cat
                customCategoryID = nil
                categorySearch = ""
                let isLoyalty = cat == .loyaltyEarned || cat == .loyaltyRedeemed
                if isLoyalty {
                    isSplitEnabled = false; splitItems = []
                } else {
                    selectedLoyaltyProgram = nil; toLoyaltyProgram = nil
                    loyaltyPoints = ""; isLoyaltyTransfer = false
                }
            }
        } label: {
            FTChip(symbol: cat.icon, title: cat.rawValue,
                   selected: category == cat && customCategoryID == nil)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func customCategoryChipButton(_ cat: CustomCategory) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                customCategoryID = cat.id
                categorySearch = ""
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(cat.name).font(.ftCallout)
            }
            .padding(.horizontal, 13).padding(.vertical, 9)
            .foregroundStyle(customCategoryID == cat.id ? .white : FTColor.textPrimary)
            .background(
                customCategoryID == cat.id
                    ? AnyShapeStyle(cat.color)
                    : AnyShapeStyle(.regularMaterial),
                in: .capsule
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var manageButton: some View {
        Button { showingCategoryManagement = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "folder.badge.plus").font(.system(size: 12, weight: .semibold))
                Text("Manage").font(.ftCallout)
            }
            .padding(.horizontal, 13).padding(.vertical, 9)
            .foregroundStyle(FTColor.accent)
            .background(FTColor.accent.opacity(0.1), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private var relevantCustomCategories: [CustomCategory] {
        customCategories.filter { $0.isRoot && $0.matchesType(type) }
    }

    private var filteredBuiltinCategories: [TransactionCategory] {
        guard !categorySearch.isEmpty else { return relevantCategories }
        return relevantCategories.filter { $0.rawValue.localizedCaseInsensitiveContains(categorySearch) }
    }

    private var filteredCustomCategories: [CustomCategory] {
        guard !categorySearch.isEmpty else { return relevantCustomCategories }
        return relevantCustomCategories.filter { $0.name.localizedCaseInsensitiveContains(categorySearch) }
    }

    // MARK: - Lent card

    private var lentDetailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: FTSpacing.md) {
                Text("Borrower").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                TextField("Full name", text: $lentBorrowerName)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            .padding(.vertical, 13)

            Divider().opacity(0.4)

            Toggle(isOn: $lentHasDueDate) {
                Text("Set Repayment Due Date").font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
            .tint(FTColor.accent)
            .padding(.vertical, 13)

            if lentHasDueDate {
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.md) {
                    Text("Due Date").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    DatePicker("", selection: $lentDueDate, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(.vertical, 9)
            }

            Divider().opacity(0.4)
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: "info.circle").font(.system(size: 12))
                Text("Creates a record in Debt Management and debits the selected account.")
                    .font(.ftCaption)
            }
            .foregroundStyle(FTColor.textMuted)
            .padding(.vertical, 10)
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Borrowed card

    private var borrowedDetailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: FTSpacing.md) {
                Text("Lender").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                TextField("Full name", text: $borrowedLenderName)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            .padding(.vertical, 13)

            Divider().opacity(0.4)

            Toggle(isOn: $borrowedHasDueDate) {
                Text("Set Repayment Due Date").font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
            .tint(FTColor.expense)
            .padding(.vertical, 13)

            if borrowedHasDueDate {
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.md) {
                    Text("Due Date").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    DatePicker("", selection: $borrowedDueDate, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(.vertical, 9)
            }

            Divider().opacity(0.4)
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: "info.circle").font(.system(size: 12))
                Text("Creates a record in Debt Management and credits the selected account.")
                    .font(.ftCaption)
            }
            .foregroundStyle(FTColor.textMuted)
            .padding(.vertical, 10)
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Split section

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header toggle row
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "scissors", tint: FTColor.catPurple, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Split Transaction")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text("Divide across multiple categories")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $isSplitEnabled)
                    .tint(FTColor.accent)
                    .labelsHidden()
                    .onChange(of: isSplitEnabled) { _, on in
                        if on && splitItems.isEmpty {
                            let total = amountDouble ?? 0
                            splitItems = [
                                SplitItem(category: category, amount: total)
                            ]
                        }
                        if !on { splitItems = [] }
                    }
            }
            .padding(.vertical, 13)

            if isSplitEnabled {
                Divider().opacity(0.4)

                ForEach($splitItems) { $item in
                    SplitItemRow(item: $item, currency: currency, availableCategories: relevantCategories) {
                        splitItems.removeAll { $0.id == item.id }
                    }
                    Divider().opacity(0.3)
                }

                // Add split button
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        let used = splitItems.reduce(0) { $0 + $1.amount }
                        let remaining = max(0, (amountDouble ?? 0) - used)
                        splitItems.append(SplitItem(category: .other, amount: remaining))
                    }
                } label: {
                    HStack(spacing: FTSpacing.sm) {
                        Image(systemName: "plus.circle").font(.system(size: 14, weight: .semibold))
                        Text("Add Category")
                    }
                    .font(.ftCallout).foregroundStyle(FTColor.accent)
                }
                .padding(.vertical, 12)

                // Validation row
                Divider().opacity(0.3)
                HStack {
                    Text("Total split")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    let total = amountDouble ?? 0
                    Text("\(splitTotal.formatted(as: currency)) / \(total.formatted(as: currency))")
                        .font(.ftCallout)
                        .foregroundStyle(splitIsValid ? FTColor.income : FTColor.expense)
                }
                .padding(.vertical, 10)

                if !splitIsValid {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(FTColor.expense)
                        Text("Split total must equal transaction amount")
                            .font(.ftCaption).foregroundStyle(FTColor.expense)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Details card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            // Title
            HStack(spacing: FTSpacing.md) {
                Text("Title").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                TextField("Description", text: $title)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            .padding(.vertical, 13)

            Divider().opacity(0.4)

            // Merchant
            HStack(spacing: FTSpacing.md) {
                Text("Merchant").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                TextField("Optional", text: $merchant)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            .padding(.vertical, 13)

            // Income source (income only, not for borrowed)
            if type == .income && !isBorrowedMode {
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.md) {
                    Text("Source").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    TextField("Employer / client name", text: $incomeSource)
                        .multilineTextAlignment(.trailing)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                }
                .padding(.vertical, 13)
            }

            // Account
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
                    HStack { Spacer()
                        Text("Available: \(balance.formatted(as: acc.currency))")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }.padding(.bottom, FTSpacing.sm)
                }
            }

            // Subtype
            if !availableSubtypes.isEmpty {
                Divider().opacity(0.4)
                Menu {
                    Button("None") { selectedSubtype = nil }
                    ForEach(availableSubtypes, id: \.self) { sub in
                        Button {
                            selectedSubtype = sub
                        } label: {
                            Label(sub.rawValue, systemImage: sub.icon)
                        }
                    }
                } label: {
                    HStack(spacing: FTSpacing.md) {
                        Text("Subtype").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        if let sub = selectedSubtype {
                            Label(sub.rawValue, systemImage: sub.icon)
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        } else {
                            Text("None")
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textMuted)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FTColor.textMuted)
                    }
                    .padding(.vertical, 13)
                }
            }

            // Payment method
            Divider().opacity(0.4)
            detailMenuRow(label: "Payment", value: paymentMethod.rawValue) {
                Picker("Payment Method", selection: $paymentMethod) {
                    ForEach(PaymentMethod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }

            // Cheque fields
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
                    DatePicker("", selection: $chequeDate, displayedComponents: .date).labelsHidden()
                }
                .padding(.vertical, 9)
            }

            // Date
            Divider().opacity(0.4)
            HStack(spacing: FTSpacing.md) {
                Text("Date").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute]).labelsHidden()
            }
            .padding(.vertical, 9)
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
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

    // MARK: - Status card (pending / scheduled)

    private var statusCard: some View {
        VStack(spacing: 0) {
            // Pending toggle
            Toggle(isOn: $isPending) {
                HStack(spacing: FTSpacing.sm) {
                    FTIconTile(symbol: "clock.badge.questionmark", tint: FTColor.gold, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Mark as Pending")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text("Won't update account balance until cleared")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
            }
            .tint(FTColor.accent)
            .padding(.vertical, 13)
            .onChange(of: isPending) { _, on in if on { isScheduled = false } }

            Divider().opacity(0.4)

            // Scheduled toggle
            Toggle(isOn: $isScheduled) {
                HStack(spacing: FTSpacing.sm) {
                    FTIconTile(symbol: "calendar.badge.clock", tint: FTColor.catBlue, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Schedule for Future")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text("Will be posted automatically on the chosen date")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
            }
            .tint(FTColor.accent)
            .padding(.vertical, 13)
            .onChange(of: isScheduled) { _, on in if on { isPending = false } }

            if isScheduled {
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.md) {
                    Text("Post On").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    DatePicker(
                        "", selection: $scheduledDate,
                        in: (Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding(.vertical, 9)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Tax section (expense only)

    private var taxSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isTaxDeductible) {
                HStack(spacing: FTSpacing.sm) {
                    FTIconTile(symbol: "doc.text.magnifyingglass", tint: FTColor.catBlue, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tax Deductible")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text("Flag this expense for tax reporting")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
            }
            .tint(FTColor.accent)
            .padding(.vertical, 13)
            .onChange(of: isTaxDeductible) { _, on in if !on { isVATReclaimable = false } }

            if isTaxDeductible {
                Divider().opacity(0.4)
                Toggle(isOn: $isVATReclaimable) {
                    HStack(spacing: FTSpacing.sm) {
                        FTIconTile(symbol: "percent", tint: FTColor.catPurple, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("VAT Reclaimable")
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Text("Include in VAT reclaim export")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                    }
                }
                .tint(FTColor.accent)
                .padding(.vertical, 13)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Notes & Receipt card

    private var notesReceiptCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Notes & Attachments")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(FTColor.textSecondary)

            TextField("Add a note...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)

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
            // Smart tag suggestions
            if !tagSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.xs) {
                        Text("Suggested:")
                            .font(.ftLabel)
                            .foregroundStyle(FTColor.textMuted)
                        ForEach(tagSuggestions, id: \.self) { suggestion in
                            Button {
                                if !tags.contains(suggestion) { tags.append(suggestion) }
                                tagSuggestions.removeAll { $0 == suggestion }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("#\(suggestion)").font(.ftCaption)
                                }
                                .foregroundStyle(FTColor.catPurple)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(FTColor.catPurple.opacity(0.1), in: .capsule)
                            }
                            .buttonStyle(.plain)
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

            // Action buttons row
            HStack(spacing: FTSpacing.sm) {
                // Receipt attach
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(receiptImage == nil ? "Receipt" : "Replace", systemImage: "camera.viewfinder")
                        .font(.ftCallout)
                        .foregroundStyle(FTColor.accent)
                        .padding(.horizontal, FTSpacing.md)
                        .padding(.vertical, FTSpacing.sm + 2)
                        .frame(maxWidth: .infinity)
                        .background(FTColor.accent.opacity(0.08), in: .rect(cornerRadius: FTRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: FTRadius.sm)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                .foregroundStyle(FTColor.accent.opacity(0.4))
                        )
                }
                .onChange(of: selectedPhoto) { _, item in loadReceiptImage(from: item) }

                // Document attach
                Button { showingDocumentPicker = true } label: {
                    Label("Document", systemImage: "doc.badge.plus")
                        .font(.ftCallout)
                        .foregroundStyle(FTColor.catPurple)
                        .padding(.horizontal, FTSpacing.md)
                        .padding(.vertical, FTSpacing.sm + 2)
                        .frame(maxWidth: .infinity)
                        .background(FTColor.catPurple.opacity(0.08), in: .rect(cornerRadius: FTRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: FTRadius.sm)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                .foregroundStyle(FTColor.catPurple.opacity(0.4))
                        )
                }

                // Location tag
                Button { requestLocation() } label: {
                    Label(hasLocation ? "Located" : "Location", systemImage: hasLocation ? "location.fill" : "location")
                        .font(.ftCallout)
                        .foregroundStyle(hasLocation ? FTColor.income : FTColor.textSecondary)
                        .padding(.horizontal, FTSpacing.md)
                        .padding(.vertical, FTSpacing.sm + 2)
                        .frame(maxWidth: .infinity)
                        .background((hasLocation ? FTColor.income : FTColor.textSecondary).opacity(0.08),
                                    in: .rect(cornerRadius: FTRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: FTRadius.sm)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                .foregroundStyle((hasLocation ? FTColor.income : FTColor.textSecondary).opacity(0.4))
                        )
                }
            }

            // Receipt image preview
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
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                }
                .buttonStyle(.glass)
                .disabled(scanner.isScanning)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Documents preview card

    private var documentsPreviewCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("DOCUMENTS (\(pendingDocuments.count))")
                .font(.ftLabel).tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)

            ForEach(pendingDocuments.indices, id: \.self) { i in
                HStack(spacing: FTSpacing.sm) {
                    let doc = pendingDocuments[i]
                    Image(systemName: doc.mime.hasPrefix("image") ? "photo" : "doc.richtext")
                        .foregroundStyle(FTColor.catPurple)
                    Text(doc.filename)
                        .font(.ftCallout)
                        .foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    let size = Double(doc.data.count)
                    Text(size < 1024 ? "\(Int(size)) B" : size < 1_048_576 ? String(format: "%.1f KB", size/1024) : String(format: "%.1f MB", size/1_048_576))
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    Button { pendingDocuments.remove(at: i) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Scan results card

    private func scanResultsCard(_ scan: ScannedReceiptData) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: FTSpacing.sm) {
                Label(
                    scan.merchantNeedsReview || scan.totalNeedsReview || scan.dateNeedsReview
                        ? "Scan Complete — Review Flagged Fields"
                        : "Scan Results Applied",
                    systemImage: scan.merchantNeedsReview || scan.totalNeedsReview || scan.dateNeedsReview
                        ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
                )
                .font(.ftBodySemibold)
                .foregroundStyle(
                    scan.merchantNeedsReview || scan.totalNeedsReview || scan.dateNeedsReview
                        ? FTColor.expense : FTColor.income
                )
            }
            Divider().opacity(0.3)
            if let m = scan.merchant { scanRow(icon: "storefront", label: "Merchant", value: m, confidence: scan.merchantConfidence, needsReview: scan.merchantNeedsReview) }
            if let a = scan.totalAmount { scanRow(icon: "banknote", label: "Amount", value: a.formatted(as: scan.currency), confidence: scan.totalConfidence, needsReview: scan.totalNeedsReview) }
            if let d = scan.date { scanRow(icon: "calendar", label: "Date", value: d.formatted(date: .abbreviated, time: .omitted), confidence: scan.dateConfidence, needsReview: scan.dateNeedsReview) }
            if !scan.wasReceiptDetected {
                Label("Receipt edges not detected — verify values", systemImage: "viewfinder.trianglebadge.exclamationmark")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
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
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            Spacer()
            if needsReview {
                Text("Review").font(.ftLabel).foregroundStyle(FTColor.expense)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(FTColor.expense.opacity(0.12), in: .capsule)
            } else {
                Text("\(Int(confidence * 100))%").font(.ftLabel).foregroundStyle(FTColor.textMuted)
            }
        }
    }

    // MARK: - Duplicate warning card

    private var duplicateWarningCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Label("Possible Duplicate", systemImage: "exclamationmark.triangle.fill")
                .font(.ftBodySemibold).foregroundStyle(FTColor.gold)

            if let dup = potentialDuplicate {
                Text("A similar transaction exists: \"\(dup.title)\" for \(dup.amount.formatted(as: dup.currency)) on \(dup.date.formatted).")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }

            HStack(spacing: FTSpacing.sm) {
                Button("Skip (Don't Save)") {
                    showingDuplicateWarning = false
                    dismiss()
                }
                .font(.ftCallout).foregroundStyle(FTColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: .capsule)

                Button("Save Anyway") {
                    showingDuplicateWarning = false
                    commitSave()
                }
                .font(.ftCallout).foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(FTColor.expense, in: .capsule)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: FTRadius.md)
                .strokeBorder(FTColor.gold.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func runAutoCategorization() {
        guard !title.isEmpty || !merchant.isEmpty else { aiPrediction = nil; appliedRuleName = nil; return }
        let pred = AICategorizationService.shared.predictCategory(
            for: title,
            merchant: merchant.isEmpty ? nil : merchant,
            amount: amountDouble ?? 0,
            type: type,
            rules: Array(categorizationRules)
        )
        aiPrediction = pred
        // Auto-apply high-confidence predictions when adding (not editing)
        if !isEditing && pred.confidence >= 0.5 && customCategoryID == nil {
            category = pred.category
            appliedRuleName = pred.source == .rule ? pred.ruleName : nil
            // Apply rule auto-tags
            if pred.source == .rule,
               let matchedRule = categorizationRules.first(where: { $0.name == pred.ruleName }) {
                for tag in matchedRule.autoTags where !tags.contains(tag) {
                    tags.append(tag)
                }
            }
        }
    }

    private func updateTagSuggestions() {
        tagSuggestions = TagSuggestionService.shared.suggestTags(
            for: merchant,
            amount: amountDouble ?? 0,
            existing: tags
        )
    }

    private var availableSubtypes: [TransactionSubtype] {
        switch type {
        case .income:   return TransactionSubtype.incomeSubtypes
        case .expense:  return TransactionSubtype.expenseSubtypes
        case .transfer: return []
        }
    }

    private var hasLocation: Bool { latitude != nil && longitude != nil }

    private var relevantCategories: [TransactionCategory] {
        switch type {
        case .income:
            return [.salary, .bonus, .freelance, .business, .investmentIncome, .rental, .dividends,
                    .interestIncome, .cashbackIncome, .personalLentRepayment, .loyaltyEarned, .other]
        case .expense:
            return [.food, .shopping, .transportation, .fuel, .utilities, .rent, .mortgage, .education,
                    .medical, .entertainment, .travel, .insurance, .investments, .subscriptions, .gifts,
                    .personalCare, .childcare, .pets, .charity, .bankFees, .interestExpense,
                    .loanRepayment, .creditCard, .loyaltyRedeemed, .other]
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

    private func requestLocation() {
        if hasLocation {
            latitude = nil; longitude = nil; locationLabel = ""
        } else {
            locationHelper.requestOnce { coord in
                latitude = coord?.latitude
                longitude = coord?.longitude
                if let c = coord {
                    locationLabel = String(format: "%.4f, %.4f", c.latitude, c.longitude)
                }
            }
        }
    }

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
                    if let img = receiptImage {
                        Task {
                            await scanner.scanReceipt(image: img)
                            if let result = scanner.scanResult { applyScanResult(result) }
                        }
                    }
                }
            }
        }
    }

    private func applyScanResult(_ scan: ScannedReceiptData) {
        if let m = scan.merchant, title.isEmpty   { title = m }
        if let m = scan.merchant, merchant.isEmpty { merchant = m }
        if let a = scan.totalAmount               { amount = AmountTextField.string(from: a) }
        if let d = scan.date                      { date = d }
        currency = scan.currency
        paymentMethod = scan.paymentMethod
        category = scan.suggestedCategory
    }

    private func applyVoiceResult(_ parsed: ParsedVoiceTransaction) {
        if !parsed.title.isEmpty    { title = parsed.title }
        if let amt = parsed.amount  { amount = AmountTextField.string(from: amt) }
        if let cur = parsed.currency { currency = cur }
        if let mer = parsed.merchant { merchant = mer }
        type = parsed.type
        category = parsed.category
        updateDefaultCategory(for: type)
        if parsed.category != .other { category = parsed.category }
    }

    private func handleDocumentImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            let mime = mimeType(for: url)
            pendingDocuments.append((data: data, filename: url.lastPathComponent, mime: mime))
        }
    }

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":           return "application/pdf"
        case "jpg", "jpeg":  return "image/jpeg"
        case "png":           return "image/png"
        case "heic":          return "image/heic"
        default:              return "application/octet-stream"
        }
    }

    private func loadEditingData() {
        guard let tx = editingTransaction else {
            // Set default account if available
            selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
            return
        }
        title = tx.title
        amount = AmountTextField.string(from: tx.amount)
        type = tx.type
        category = tx.category
        date = tx.date
        currency = tx.currency
        notes = tx.notes ?? ""
        paymentMethod = tx.paymentMethod
        isRecurring = tx.isRecurring
        merchant = tx.merchant ?? ""
        selectedAccount = tx.account
        chequeNumber = tx.chequeNumber ?? ""
        if let cd = tx.chequeDate { chequeDate = cd }
        toAccount = tx.toAccount
        tags = tx.tags
        isPending = tx.isPending
        isScheduled = tx.isScheduled
        if let sd = tx.scheduledDate { scheduledDate = sd }
        selectedSubtype = tx.subtype
        splitItems = tx.splitItems
        isSplitEnabled = !tx.splitItems.isEmpty
        incomeSource = tx.incomeSource ?? ""
        latitude = tx.latitude
        longitude = tx.longitude
        if let la = tx.latitude, let lo = tx.longitude {
            locationLabel = String(format: "%.4f, %.4f", la, lo)
        }
        if let data = tx.receiptImageData { receiptImage = UIImage(data: data) }
        isTaxDeductible = tx.isTaxDeductible
        isVATReclaimable = tx.isVATReclaimable
        customCategoryID = tx.customCategoryID
        if let id = tx.linkedLoyaltyProgramID {
            selectedLoyaltyProgram = loyaltyPrograms.first(where: { $0.id == id })
        }
        if tx.loyaltyPointsAmount > 0 {
            loyaltyPoints = String(format: "%g", tx.loyaltyPointsAmount)
        }
    }

    // MARK: - Save

    private func saveTransaction() {
        guard canSave, let amountValue = amountDouble else { return }
        if isBalanceInsufficient { showingInsufficientFunds = true; return }

        // Auto-generate title for lent/borrowed if not filled
        if isLentMode && title.isEmpty {
            title = "Lent to \(lentBorrowerName.trimmingCharacters(in: .whitespacesAndNewlines))"
        } else if isBorrowedMode && title.isEmpty {
            title = "Borrowed from \(borrowedLenderName.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        guard !title.isEmpty else { return }

        // Duplicate detection (new transactions only)
        if !isEditing, let dup = findDuplicate(amount: amountValue, date: date, title: title) {
            potentialDuplicate = dup
            showingDuplicateWarning = true
            return
        }
        commitSave()
    }

    private func findDuplicate(amount: Double, date: Date, title: String) -> Transaction? {
        let allTx = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        return allTx.first { tx in
            abs(tx.amount - amount) < 0.01 &&
            tx.title.lowercased() == title.lowercased() &&
            abs(tx.date.timeIntervalSince(date)) < 86400 // within 24h
        }
    }

    private func commitSave() {
        isSaving = true
        guard let amountValue = amountDouble else { isSaving = false; return }

        let baseCurrency = appState.baseCurrency
        let convertedAmount = currencyService.convert(amountValue, from: currency, to: baseCurrency)
        let effectiveSplitItems = isSplitEnabled ? splitItems : []

        if let tx = editingTransaction {
            // Reverse old balance effect (only if was previously posted)
            if !tx.isPending && !tx.isScheduled, let oldAccount = tx.account {
                let oldDelta = currencyService.convert(tx.amount, from: tx.currency, to: oldAccount.currency)
                switch tx.type {
                case .income:   oldAccount.balance -= oldDelta
                case .expense:  oldAccount.balance += oldDelta
                case .transfer:
                    oldAccount.balance += oldDelta  // restore source
                    if let oldToAccount = tx.toAccount {
                        let oldToDelta = currencyService.convert(tx.amount, from: tx.currency, to: oldToAccount.currency)
                        oldToAccount.balance -= oldToDelta  // restore destination
                    }
                }
            }

            // Reverse old loyalty points effect
            if !tx.isPending && !tx.isScheduled,
               let oldProgramID = tx.linkedLoyaltyProgramID,
               let oldProgram = loyaltyPrograms.first(where: { $0.id == oldProgramID }) {
                if tx.category == .loyaltyEarned {
                    oldProgram.points -= tx.loyaltyPointsAmount
                    oldProgram.totalPointsEarned = max(0, oldProgram.totalPointsEarned - tx.loyaltyPointsAmount)
                } else if tx.category == .loyaltyRedeemed {
                    oldProgram.points += tx.loyaltyPointsAmount
                    oldProgram.totalPointsRedeemed = max(0, oldProgram.totalPointsRedeemed - tx.loyaltyPointsAmount)
                }
            }

            tx.title = title; tx.amount = amountValue; tx.currency = currency
            tx.amountInBaseCurrency = convertedAmount; tx.type = type; tx.category = effectiveSplitItems.isEmpty ? category : (effectiveSplitItems.first?.category ?? .other)
            tx.date = date; tx.notes = notes.isEmpty ? nil : notes
            tx.paymentMethod = paymentMethod; tx.isRecurring = isRecurring
            tx.merchant = merchant.isEmpty ? nil : merchant
            tx.chequeNumber = paymentMethod == .cheque && !chequeNumber.isEmpty ? chequeNumber : nil
            tx.chequeDate   = paymentMethod == .cheque ? chequeDate : nil
            tx.tags = tags
            tx.account = selectedAccount
            tx.toAccount = type == .transfer ? toAccount : nil
            tx.updatedAt = Date()
            tx.isPending = isPending
            tx.isScheduled = isScheduled
            tx.scheduledDate = isScheduled ? scheduledDate : nil
            tx.subtype = selectedSubtype
            tx.splitItems = effectiveSplitItems
            tx.incomeSource = incomeSource.isEmpty ? nil : incomeSource
            tx.latitude = latitude; tx.longitude = longitude
            tx.isTaxDeductible = isTaxDeductible
            tx.isVATReclaimable = isVATReclaimable
            tx.customCategoryID = customCategoryID
            tx.linkedLoyaltyProgramID = selectedLoyaltyProgram?.id
            tx.loyaltyPointsAmount = loyaltyPointsDouble
            if let img = receiptImage { tx.receiptImageData = img.jpegData(compressionQuality: 0.7) }

            // Attach pending documents
            for doc in pendingDocuments {
                let attachment = DocumentAttachment(data: doc.data, filename: doc.filename, mimeType: doc.mime)
                attachment.transaction = tx
                context.insert(attachment)
            }

            // Apply new balance effect (only if posting now)
            if !isPending && !isScheduled, let newAccount = selectedAccount {
                let newDelta = currencyService.convert(amountValue, from: currency, to: newAccount.currency)
                applyBalanceDelta(newDelta, to: newAccount, type: type, toAccount: toAccount)
            }

            // Apply new loyalty points effect
            if !isPending && !isScheduled && isLoyaltyCategory,
               let program = selectedLoyaltyProgram {
                if category == .loyaltyEarned {
                    program.points += loyaltyPointsDouble
                    program.totalPointsEarned += loyaltyPointsDouble
                } else if category == .loyaltyRedeemed {
                    program.points -= loyaltyPointsDouble
                    program.totalPointsRedeemed += loyaltyPointsDouble
                }
            }

        } else {
            // For loyalty categories the user's explicit choice always wins over AI
            let aiCategory = AICategorizationService.shared.suggestCategory(for: title, amount: amountValue, type: type)
            let resolvedCategory: TransactionCategory
            if isLoyaltyCategory || !effectiveSplitItems.isEmpty {
                resolvedCategory = effectiveSplitItems.isEmpty ? category : (effectiveSplitItems.first?.category ?? .other)
            } else {
                resolvedCategory = aiCategory != .other ? aiCategory : category
            }

            // For a loyalty transfer the main tx earns into the destination program
            let effectiveCategory = isLoyaltyTransfer ? .loyaltyEarned : resolvedCategory

            let tx = Transaction(
                title: title, amount: amountValue, currency: currency,
                amountInBaseCurrency: convertedAmount, type: type,
                category: effectiveCategory,
                date: date, notes: notes.isEmpty ? nil : notes,
                isRecurring: isRecurring,
                recurringRule: isRecurring ? RecurringRule(
                    frequency: recurringFrequency, interval: 1, endDate: nil, maxOccurrences: nil,
                    nextDueDate: Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
                ) : nil,
                merchant: merchant.isEmpty ? nil : merchant,
                paymentMethod: paymentMethod,
                chequeNumber: paymentMethod == .cheque && !chequeNumber.isEmpty ? chequeNumber : nil,
                chequeDate:   paymentMethod == .cheque ? chequeDate : nil,
                tags: tags,
                isPending: isPending,
                isScheduled: isScheduled,
                scheduledDate: isScheduled ? scheduledDate : nil,
                subtype: selectedSubtype,
                splitItems: effectiveSplitItems,
                incomeSource: incomeSource.isEmpty ? nil : incomeSource,
                latitude: latitude,
                longitude: longitude,
                isTaxDeductible: isTaxDeductible,
                isVATReclaimable: isVATReclaimable,
                customCategoryID: customCategoryID
            )
            if let img = receiptImage { tx.receiptImageData = img.jpegData(compressionQuality: 0.7) }
            tx.account  = selectedAccount
            tx.toAccount = type == .transfer ? toAccount : nil

            // Loyalty link: for transfer the main tx links to the destination (earn) program
            tx.linkedLoyaltyProgramID = isLoyaltyTransfer ? toLoyaltyProgram?.id : selectedLoyaltyProgram?.id
            tx.loyaltyPointsAmount = loyaltyPointsDouble
            context.insert(tx)

            // Attach pending documents
            for doc in pendingDocuments {
                let attachment = DocumentAttachment(data: doc.data, filename: doc.filename, mimeType: doc.mime)
                attachment.transaction = tx
                context.insert(attachment)
            }

            // Update balance only for immediately-posted transactions
            if !isPending && !isScheduled {
                if type == .transfer {
                    if let from = selectedAccount {
                        let delta = currencyService.convert(amountValue, from: currency, to: from.currency)
                        from.balance -= delta
                        checkMinBalance(account: from)
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
                    checkMinBalance(account: account)
                }

                // Apply loyalty points changes
                if isLoyaltyTransfer,
                   let fromProg = selectedLoyaltyProgram, let toProg = toLoyaltyProgram {
                    // Earn into destination
                    toProg.points += loyaltyPointsDouble
                    toProg.totalPointsEarned += loyaltyPointsDouble
                    // Deduct from source — also create companion redeem transaction
                    fromProg.points -= loyaltyPointsDouble
                    fromProg.totalPointsRedeemed += loyaltyPointsDouble
                    // amount=0 so this companion record doesn't inflate expense totals
                    let redeemTx = Transaction(
                        title: "Transfer to \(toProg.name)",
                        amount: 0, currency: currency,
                        amountInBaseCurrency: 0,
                        type: .expense, category: .loyaltyRedeemed,
                        date: date, notes: "Points transfer",
                        tags: tags,
                        loyaltyPointsAmount: loyaltyPointsDouble
                    )
                    redeemTx.linkedLoyaltyProgramID = fromProg.id
                    context.insert(redeemTx)
                } else if category == .loyaltyEarned, let prog = selectedLoyaltyProgram {
                    prog.points += loyaltyPointsDouble
                    prog.totalPointsEarned += loyaltyPointsDouble
                } else if category == .loyaltyRedeemed, let prog = selectedLoyaltyProgram {
                    prog.points -= loyaltyPointsDouble
                    prog.totalPointsRedeemed += loyaltyPointsDouble
                }
            }
        }

        // Create Debt Management records for lent/borrowed
        if !isEditing {
            if isLentMode {
                let lent = MoneyLent(
                    borrowerName: lentBorrowerName.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amountValue,
                    currency: currency,
                    lendingDate: date,
                    dueDate: lentHasDueDate ? lentDueDate : nil,
                    notes: notes.isEmpty ? nil : notes,
                    color: "blue"
                )
                context.insert(lent)
            } else if isBorrowedMode {
                let borrowed = MoneyBorrowed(
                    lenderName: borrowedLenderName.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amountValue,
                    currency: currency,
                    borrowDate: date,
                    dueDate: borrowedHasDueDate ? borrowedDueDate : nil,
                    notes: notes.isEmpty ? nil : notes,
                    color: "red"
                )
                context.insert(borrowed)
            }
        }

        try? context.save()

        // Record category & tag learning
        let effectiveMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !effectiveMerchant.isEmpty {
            CategoryLearningService.shared.recordCorrection(merchant: effectiveMerchant, category: category)
            for tag in tags {
                TagSuggestionService.shared.recordTagUsed(tag, for: effectiveMerchant)
            }
        }

        // Budget alert
        if type == .expense && !isPending && !isScheduled {
            fireBudgetAlertIfNeeded(category: category, amountInBase: convertedAmount)
        }

        isSaving = false
        dismiss()
    }

    private func applyBalanceDelta(_ delta: Double, to account: Account, type: TransactionType, toAccount: Account?) {
        if type == .transfer {
            account.balance -= delta
            if let to = toAccount {
                let toDelta = currencyService.convert(
                    AmountTextField.double(from: amount), from: currency, to: to.currency
                )
                to.balance += toDelta
            }
        } else {
            switch type {
            case .income:   account.balance += delta
            case .expense:  account.balance -= delta
            case .transfer: break
            }
        }
        checkMinBalance(account: account)
    }

    private func checkMinBalance(account: Account) {
        if account.minimumBalanceEnabled && account.balance < account.minimumBalance {
            NotificationService.shared.sendMinimumBalanceAlert(
                accountName: account.name, balance: account.balance,
                minimum: account.minimumBalance, currency: account.currency
            )
        }
    }

    private func fireBudgetAlertIfNeeded(category: TransactionCategory, amountInBase: Double) {
        let base = appState.baseCurrency
        let now = Date()
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        guard let matchingBudget = budgets.first(where: { $0.category == category }) else { return }
        let allTx = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let spent = allTx
            .filter { $0.type == .expense && $0.category == category && $0.date >= monthStart && !$0.isPending && !$0.isScheduled }
            .reduce(0.0) { $0 + $1.amountInBaseCurrency }
        let limit = currencyService.convert(matchingBudget.amount, from: matchingBudget.currency, to: base)
        if limit > 0 && spent / limit >= 0.8 {
            NotificationService.shared.scheduleBudgetAlert(
                categoryName: category.rawValue, spent: spent, budget: limit, currency: base
            )
        }
    }

    // MARK: - Loyalty Program Card

    private var loyaltyProgramCard: some View {
        VStack(spacing: 0) {
            if loyaltyPrograms.isEmpty {
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "star.fill", tint: FTColor.catPurple, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Loyalty Programs").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text("Add a program in Accounts first").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                .padding(.vertical, FTSpacing.md)
            } else {
                // Program picker
                if isLoyaltyTransfer {
                    // From program (source — will be redeemed)
                    detailMenuRow(label: "From Program",
                                  value: selectedLoyaltyProgram?.name ?? "Select Program") {
                        Picker("From Program", selection: $selectedLoyaltyProgram) {
                            Text("Select").tag(Optional<LoyaltyProgram>.none)
                            ForEach(loyaltyPrograms) { p in
                                Text(p.name).tag(Optional<LoyaltyProgram>.some(p))
                            }
                        }
                    }
                    .onChange(of: selectedLoyaltyProgram) { _, _ in autoFillCashValue() }

                    if let p = selectedLoyaltyProgram {
                        HStack { Spacer()
                            Text("\(Int(p.points).formatted()) \(p.programType.pointsLabel) available")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }.padding(.bottom, FTSpacing.sm)
                    }

                    Divider().opacity(0.4)
                    HStack { Spacer()
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(FTColor.accent)
                        Spacer()
                    }.padding(.vertical, FTSpacing.sm)
                    Divider().opacity(0.4)

                    // To program (destination — will be earned into)
                    detailMenuRow(label: "To Program",
                                  value: toLoyaltyProgram?.name ?? "Select Program") {
                        Picker("To Program", selection: $toLoyaltyProgram) {
                            Text("Select").tag(Optional<LoyaltyProgram>.none)
                            ForEach(loyaltyPrograms.filter { $0.id != selectedLoyaltyProgram?.id }) { p in
                                Text(p.name).tag(Optional<LoyaltyProgram>.some(p))
                            }
                        }
                    }
                    .onChange(of: toLoyaltyProgram) { _, _ in autoFillCashValue() }

                } else {
                    // Single program picker
                    detailMenuRow(label: "Program",
                                  value: selectedLoyaltyProgram?.name ?? "Select Program") {
                        Picker("Loyalty Program", selection: $selectedLoyaltyProgram) {
                            Text("Select").tag(Optional<LoyaltyProgram>.none)
                            ForEach(loyaltyPrograms) { p in
                                Label(p.name, systemImage: p.programType.icon)
                                    .tag(Optional<LoyaltyProgram>.some(p))
                            }
                        }
                    }
                    .onChange(of: selectedLoyaltyProgram) { _, p in
                        if let p { currency = p.currency }
                        autoFillCashValue()
                    }

                    if let p = selectedLoyaltyProgram {
                        HStack { Spacer()
                            Text("\(Int(p.points).formatted()) \(p.programType.pointsLabel) currently")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }.padding(.bottom, FTSpacing.sm)
                    }
                }

                // Transfer toggle (earn only, not when editing)
                if category == .loyaltyEarned && !isEditing {
                    Divider().opacity(0.4)
                    HStack(spacing: FTSpacing.md) {
                        FTIconTile(symbol: "arrow.triangle.2.circlepath", tint: FTColor.catPurple, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Transfer from another program")
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Text("Moves points between two programs")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $isLoyaltyTransfer)
                            .tint(FTColor.accent).labelsHidden()
                            .onChange(of: isLoyaltyTransfer) { _, on in
                                if !on { toLoyaltyProgram = nil }
                            }
                    }
                    .padding(.vertical, 13)
                }

                // Points amount field
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.md) {
                    let label = selectedLoyaltyProgram?.programType.pointsLabel ?? "Points"
                    Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    TextField("0", text: $loyaltyPoints)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        .frame(maxWidth: 140)
                        .onChange(of: loyaltyPoints) { _, _ in autoFillCashValue() }
                }
                .padding(.vertical, 13)

                // Estimated cash value hint
                let hintProgram = isLoyaltyTransfer ? (toLoyaltyProgram ?? selectedLoyaltyProgram) : selectedLoyaltyProgram
                if let p = hintProgram, loyaltyPointsDouble > 0 {
                    Divider().opacity(0.4)
                    HStack(spacing: FTSpacing.md) {
                        Text("Est. Value").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text("≈ \((loyaltyPointsDouble * p.pointsValuePerUnit).formatted(as: p.currency))")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    }
                    .padding(.vertical, 13)
                }
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private func autoFillCashValue() {
        let prog = isLoyaltyTransfer ? (toLoyaltyProgram ?? selectedLoyaltyProgram) : selectedLoyaltyProgram
        guard let p = prog, loyaltyPointsDouble > 0 else { return }
        let cashValue = loyaltyPointsDouble * p.pointsValuePerUnit
        let currentAmt = AmountTextField.double(from: amount)
        if currentAmt == 0 { amount = AmountTextField.string(from: cashValue) }
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
}

// MARK: - Split item row

private struct SplitItemRow: View {
    @Binding var item: SplitItem
    let currency: String
    let availableCategories: [TransactionCategory]
    let onDelete: () -> Void

    @State private var amountText = ""

    var body: some View {
        HStack(spacing: FTSpacing.sm) {
            // Category picker
            Menu {
                Picker("Category", selection: $item.category) {
                    ForEach(availableCategories, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }
            } label: {
                FTIconTile(symbol: item.category.icon,
                           tint: Color.fromString(item.category.color), size: 34)
            }

            // Amount field
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)
                .frame(maxWidth: 100)
                .multilineTextAlignment(.trailing)
                .onAppear { amountText = AmountTextField.string(from: item.amount) }
                .onChange(of: amountText) { _, new in
                    let formatted = AmountTextField.format(new)
                    if formatted != new { amountText = formatted }
                    item.amount = AmountTextField.double(from: new)
                }

            Text(currency)
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)

            Spacer()

            // Category label
            Text(item.category.rawValue)
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                .lineLimit(1)

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(FTColor.expense)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Location helper (thin CoreLocation wrapper)

final class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate, @unchecked Sendable {
    let objectWillChange = ObservableObjectPublisher()
    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestOnce(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            completion(nil)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.completion?(locations.last?.coordinate)
            self.completion = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.completion?(nil)
            self.completion = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            } else {
                self.completion?(nil)
                self.completion = nil
            }
        }
    }
}
