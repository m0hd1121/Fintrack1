import SwiftUI
import SwiftData

// MARK: - EmailReviewQueueView
// Inbox-style review of parsed bank emails.
// Swipe right → approve · swipe left → reject · tap → edit.
// Nothing reaches the ledger until the user approves it here.

struct EmailReviewQueueView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query(sort: \PendingEmailTransaction.receivedAt, order: .reverse)
    private var allItems: [PendingEmailTransaction]
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var editingItem: PendingEmailTransaction? = nil
    @State private var showRejected = false

    private var pendingItems: [PendingEmailTransaction] {
        allItems.filter { $0.status == .pending }
    }

    private var reviewedItems: [PendingEmailTransaction] {
        allItems.filter { $0.status != .pending }
    }

    private var highConfidenceItems: [PendingEmailTransaction] {
        pendingItems.filter { $0.confidence >= 0.9 && !$0.isPossibleDuplicate && !$0.isSuspiciousParse }
    }

    var body: some View {
        List {
            if pendingItems.isEmpty {
                Section {
                    EmptyStateView(
                        icon: "tray.circle.fill",
                        title: "Review Queue Empty",
                        message: "New bank emails will appear here for your approval before anything is added to your transactions."
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                if highConfidenceItems.count >= 2 {
                    Section {
                        Button {
                            for item in highConfidenceItems { approve(item) }
                        } label: {
                            HStack(spacing: FTSpacing.md) {
                                FTIconTile(symbol: "checkmark.seal.fill", tint: FTColor.income, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Approve \(highConfidenceItems.count) high-confidence")
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text("All ≥90% confidence, no duplicates, no warnings")
                                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: FTSpacing.screen, bottom: 4, trailing: FTSpacing.screen))
                    }
                }

                Section {
                    ForEach(pendingItems, id: \.id) { item in
                        PendingEmailRow(item: item)
                            .contentShape(.rect)
                            .onTapGesture { editingItem = item }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { approve(item) } label: {
                                    Label("Approve", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { reject(item) } label: {
                                    Label("Reject", systemImage: "xmark")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: FTSpacing.screen, bottom: 4, trailing: FTSpacing.screen))
                    }
                } header: {
                    Text("PENDING · \(pendingItems.count)")
                        .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                }
            }

            if !reviewedItems.isEmpty {
                Section {
                    Button { withAnimation { showRejected.toggle() } } label: {
                        HStack {
                            Text(showRejected ? "Hide reviewed" : "Show \(reviewedItems.count) reviewed")
                                .font(.ftCallout).foregroundStyle(FTColor.accent)
                            Spacer()
                            Image(systemName: showRejected ? "chevron.up" : "chevron.down")
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if showRejected {
                        ForEach(reviewedItems.prefix(20), id: \.id) { item in
                            reviewedRow(item)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: FTSpacing.screen, bottom: 4, trailing: FTSpacing.screen))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Review Queue")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingItem) { item in
            EditPendingEmailSheet(item: item, onApprove: { approve(item) })
        }
    }

    private func reviewedRow(_ item: PendingEmailTransaction) -> some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: item.status == .approved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(item.status == .approved ? FTColor.income : FTColor.expense)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.merchantNormalized).font(.ftBody).foregroundStyle(FTColor.textSecondary).lineLimit(1)
                Text("\(item.status.rawValue) · \(item.reviewedAt?.relativeFormatted ?? "")")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            Text(item.amount.formatted(as: item.currency))
                .font(.ftCallout).foregroundStyle(FTColor.textMuted)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.sm)
        .opacity(0.7)
    }

    // MARK: - Approve

    private func approve(_ item: PendingEmailTransaction) {
        guard item.status == .pending else { return }

        let type = item.direction.transactionType
        let baseAmount = CurrencyService.shared.convert(item.amount, from: item.currency, to: appState.baseCurrency)

        var notes = "Imported from \(item.bankName) email"
        if let reference = item.referenceNumber { notes += " · Ref: \(reference)" }

        let tx = Transaction(
            title: item.merchantNormalized,
            amount: item.amount,
            currency: item.currency,
            amountInBaseCurrency: baseAmount,
            type: type,
            category: item.suggestedCategory,
            date: item.transactionDate,
            notes: notes,
            merchant: item.merchantNormalized,
            paymentMethod: item.cardLast4 != nil ? .debitCard : .bankTransfer,
            tags: item.suggestedTags,
            isVerified: true
        )

        // Link to the account whose stored last-4 digits match the card in the email
        if let last4 = item.cardLast4,
           let account = accounts.first(where: { !$0.isArchived && ($0.accountNumber?.hasSuffix(last4) ?? false) }) {
            tx.account = account
            let delta = CurrencyService.shared.convert(item.amount, from: item.currency, to: account.currency)
            switch type {
            case .income:  account.balance += delta
            case .expense: account.balance -= delta
            default: break
            }
        }

        context.insert(tx)
        item.status = .approved
        item.reviewedAt = Date()
        item.approvedTransactionId = tx.id

        // Learning: final category + tags become the suggestion next time
        CategoryLearningService.shared.recordCorrection(
            merchant: item.merchantNormalized, category: item.suggestedCategory)
        ImportLearningService.shared.recordApprovedTags(
            rawMerchant: item.merchantRaw, tags: item.suggestedTags)

        AuditLogService.log(context: context,
            "Approved email import: \(item.merchantNormalized) \(item.currency) \(String(format: "%.2f", item.amount)) from \(item.bankName)")
        try? context.save()
    }

    // MARK: - Reject

    private func reject(_ item: PendingEmailTransaction) {
        guard item.status == .pending else { return }
        item.status = .rejected
        item.reviewedAt = Date()
        ImportLearningService.shared.recordRejection(rawMerchant: item.merchantRaw)
        AuditLogService.log(context: context,
            "Rejected email import: \(item.merchantNormalized) from \(item.bankName)")
        try? context.save()
    }
}

// MARK: - PendingEmailRow

private struct PendingEmailRow: View {
    let item: PendingEmailTransaction

    @State private var showExplanation = false

    private var amountColor: Color {
        item.direction == .credit ? FTColor.income : FTColor.expense
    }

    private var confidenceColor: Color {
        if item.confidence >= 0.85 { return FTColor.income }
        if item.confidence >= 0.6 { return FTColor.gold }
        return FTColor.expense
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: item.suggestedCategory.icon,
                           tint: Color.fromString(item.suggestedCategory.color), size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.merchantNormalized)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                    HStack(spacing: 4) {
                        Text(item.bankName)
                        if let last4 = item.cardLast4 {
                            Text("· •\(last4)")
                        }
                        Text("· \(item.transactionDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(item.direction == .credit ? "+" : "−")\(item.amount.formatted(as: item.currency))")
                        .font(.ftBodySemibold).foregroundStyle(amountColor)
                    Text(item.suggestedCategory.rawValue)
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted).lineLimit(1)
                }
            }

            HStack(spacing: FTSpacing.xs) {
                BadgeView(text: "AI \(item.confidencePercent)%", color: confidenceColor)
                if item.isPossibleDuplicate {
                    BadgeView(text: "Possible duplicate", color: FTColor.expense)
                }
                if item.isSuspiciousParse {
                    BadgeView(text: "Check details", color: FTColor.gold)
                }
                if ImportLearningService.shared.isUsuallyRejected(rawMerchant: item.merchantRaw) {
                    BadgeView(text: "Usually rejected", color: FTColor.textMuted)
                }
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.2)) { showExplanation.toggle() }
                } label: {
                    Image(systemName: showExplanation ? "questionmark.circle.fill" : "questionmark.circle")
                        .font(.ftCallout).foregroundStyle(FTColor.textMuted)
                }
                .buttonStyle(.plain)
            }

            if showExplanation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WHY THIS WAS DETECTED")
                        .font(.ftLabel).tracking(1.2).foregroundStyle(FTColor.textMuted)
                    Text(item.parseExplanation)
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    if let reason = item.duplicateReason {
                        Text("Duplicate: \(reason)")
                            .font(.ftCaption).foregroundStyle(FTColor.expense)
                    }
                    if let reason = item.suspiciousReason {
                        Text("Warning: \(reason)")
                            .font(.ftCaption).foregroundStyle(FTColor.gold)
                    }
                }
                .padding(FTSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FTColor.bgBase.opacity(0.5), in: RoundedRectangle(cornerRadius: FTRadius.sm))
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - EditPendingEmailSheet

private struct EditPendingEmailSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var item: PendingEmailTransaction
    let onApprove: () -> Void

    @State private var amountText: String = ""
    @State private var tagsText: String = ""
    @State private var originalMerchant: String = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Merchant + amount
                        VStack(spacing: 0) {
                            fieldRow("Merchant") {
                                TextField("Merchant", text: $item.merchantNormalized)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            Divider().opacity(0.4)
                            fieldRow("Amount (\(item.currency))") {
                                TextField("0.00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 120)
                            }
                            Divider().opacity(0.4)
                            fieldRow("Type") {
                                Picker("", selection: Binding(
                                    get: { item.direction },
                                    set: { item.direction = $0 }
                                )) {
                                    Text("Expense").tag(ParsedDirection.debit)
                                    Text("Income").tag(ParsedDirection.credit)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 180)
                            }
                            Divider().opacity(0.4)
                            fieldRow("Date") {
                                DatePicker("", selection: $item.transactionDate, displayedComponents: [.date])
                                    .labelsHidden()
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Category + tags
                        VStack(spacing: 0) {
                            fieldRow("Category") {
                                Picker("", selection: Binding(
                                    get: { item.suggestedCategory },
                                    set: { item.suggestedCategory = $0 }
                                )) {
                                    ForEach(TransactionCategory.allCases, id: \.self) { category in
                                        Label(category.rawValue, systemImage: category.icon).tag(category)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(FTColor.accent)
                            }
                            Divider().opacity(0.4)
                            fieldRow("Tags") {
                                TextField("comma, separated", text: $tagsText)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Source context (read-only audit trail)
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("SOURCE EMAIL")
                                .font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                            Text(item.emailSubject).font(.ftCallout).foregroundStyle(FTColor.textSecondary)
                            Text(item.senderAddress).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            Text(item.emailSnippet)
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                .lineLimit(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                VStack(spacing: FTSpacing.sm) {
                    PrimaryButton("Save & Approve", icon: "checkmark.circle.fill") {
                        commitEdits()
                        onApprove()
                        dismiss()
                    }
                    Button("Save Changes Only") {
                        commitEdits()
                        dismiss()
                    }
                    .font(.ftCallout).foregroundStyle(FTColor.accent)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.md)
            }
            .navigationTitle("Edit Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                amountText = String(format: "%.2f", item.amount)
                tagsText = item.suggestedTags.joined(separator: ", ")
                originalMerchant = item.merchantNormalized
            }
        }
    }

    private func fieldRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
            Spacer()
            content()
        }
        .padding(.vertical, 13)
    }

    private func commitEdits() {
        if let amount = Double(amountText.replacingOccurrences(of: ",", with: "")), amount > 0 {
            item.amount = amount
        }
        item.suggestedTags = tagsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Merchant rename → the engine remembers it for every future import
        if item.merchantNormalized != originalMerchant {
            ImportLearningService.shared.recordMerchantRename(
                raw: item.merchantRaw, cleanName: item.merchantNormalized)
        }
    }
}
