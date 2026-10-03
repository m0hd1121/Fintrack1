import SwiftUI
import SwiftData

// MARK: - EmailReviewQueueView
// Inbox-style review of parsed bank emails.
// Swipe right → approve · swipe left → reject · tap → edit.
// Nothing reaches the ledger until the user approves it here.

struct EmailReviewQueueView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \PendingEmailTransaction.receivedAt, order: .reverse)
    private var allItems: [PendingEmailTransaction]
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var bnplPlans: [BNPLPlan]

    private func accountName(for item: PendingEmailTransaction) -> String? {
        guard let id = item.matchedAccountId else { return nil }
        return accounts.first { $0.id == id }?.name
    }

    @State private var editingItem: PendingEmailTransaction? = nil
    @State private var showRejected = false
    @State private var showClearHistoryConfirm = false
    @State private var showRejectAllConfirm = false
    /// Set instead of approving directly when `item.isPossibleDuplicate` —
    /// requires an explicit "Approve Anyway" tap, so a same transaction
    /// reported by both email and SMS can't be posted twice by accident.
    @State private var pendingDuplicateApproval: PendingEmailTransaction? = nil
    @State private var pendingDuplicateLentTo: String? = nil

    // Multi-select. BNPL charges each need a plan chosen before they can be
    // approved, which used to mean opening the edit sheet once per charge;
    // selecting several lets one plan choice cover all of them.
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showRejectSelectedConfirm = false
    @State private var bulkResultMessage: String? = nil

    private var pendingItems: [PendingEmailTransaction] {
        allItems.filter { $0.status == .pending }
    }

    private var pendingBNPLItems: [PendingEmailTransaction] {
        pendingItems.filter { $0.isBNPLMerchant }
    }

    /// Only items still pending count — an item approved or rejected from
    /// another screen while selecting drops out of the selection on its own.
    private var selectedItems: [PendingEmailTransaction] {
        pendingItems.filter { selectedIDs.contains($0.id) }
    }

    private var selectedBNPLItems: [PendingEmailTransaction] {
        selectedItems.filter { $0.isBNPLMerchant }
    }

    private var reviewedItems: [PendingEmailTransaction] {
        allItems.filter { $0.status != .pending }
    }

    private var highConfidenceItems: [PendingEmailTransaction] {
        pendingItems.filter {
            $0.confidence >= 0.9 && !$0.isPossibleDuplicate && !$0.isSuspiciousParse
                && !($0.isBNPLMerchant && !$0.bnplResolved)
        }
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

                if pendingBNPLItems.count >= 2 && !isSelecting {
                    Section {
                        Button { startSelectingBNPL() } label: {
                            HStack(spacing: FTSpacing.md) {
                                FTIconTile(symbol: "checklist", tint: FTColor.catPurple, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Select \(pendingBNPLItems.count) BNPL charges")
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text("Link them to a plan and approve together")
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
                        let isChecked = selectedIDs.contains(item.id)
                        HStack(spacing: FTSpacing.md) {
                            if isSelecting {
                                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isChecked ? FTColor.accent : FTColor.textMuted)
                                    .accessibilityHidden(true)
                            }
                            PendingEmailRow(item: item, accountName: accountName(for: item))
                        }
                            .contentShape(.rect)
                            .onTapGesture {
                                if isSelecting { toggleSelection(item) } else { editingItem = item }
                            }
                            // While selecting, a tap must only check the row —
                            // an accidental swipe shouldn't approve or reject it.
                            .swipeActions(edge: .leading, allowsFullSwipe: !isSelecting) {
                                if !isSelecting {
                                    Button { approve(item) } label: {
                                        Label("Approve", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: !isSelecting) {
                                if !isSelecting {
                                    Button(role: .destructive) { reject(item) } label: {
                                        Label("Reject", systemImage: "xmark")
                                    }
                                }
                            }
                            .accessibilityAddTraits(isSelecting && isChecked ? [.isSelected] : [])
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: FTSpacing.screen, bottom: 4, trailing: FTSpacing.screen))
                    }
                } header: {
                    Text("PENDING · \(pendingItems.count)")
                        .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false).foregroundStyle(FTColor.textMuted)
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { delete(item) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .refreshable {
            await EmailSyncService.shared.runSyncPass(context: context)
        }
        .navigationTitle("Review Queue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !pendingItems.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelecting ? "Done" : "Select") {
                        if isSelecting { stopSelecting() } else { isSelecting = true }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !reviewedItems.isEmpty {
                        Button(role: .destructive) {
                            showClearHistoryConfirm = true
                        } label: {
                            Label("Clear Reviewed History", systemImage: "trash")
                        }
                    }
                    if !pendingItems.isEmpty {
                        Button(role: .destructive) {
                            showRejectAllConfirm = true
                        } label: {
                            Label("Reject All Pending", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(pendingItems.isEmpty && reviewedItems.isEmpty)
            }
        }
        .confirmationDialog("Clear reviewed history?", isPresented: $showClearHistoryConfirm, titleVisibility: .visible) {
            Button("Clear \(reviewedItems.count) Reviewed Items", role: .destructive) { clearReviewedHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes approved and rejected entries from this list. It does not affect any transactions already added to your ledger.")
        }
        .confirmationDialog("Reject all pending?", isPresented: $showRejectAllConfirm, titleVisibility: .visible) {
            Button("Reject \(pendingItems.count) Pending Items", role: .destructive) { rejectAllPending() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("None of these will be added to your transactions. This can't be undone.")
        }
        .confirmationDialog("Possible duplicate", isPresented: Binding(
            get: { pendingDuplicateApproval != nil },
            set: { if !$0 { pendingDuplicateApproval = nil } }
        ), titleVisibility: .visible) {
            Button("Approve Anyway") {
                if let item = pendingDuplicateApproval {
                    EmailSyncService.shared.approveToLedger(
                        item: item, context: context, lentTo: pendingDuplicateLentTo)
                }
                pendingDuplicateApproval = nil
                pendingDuplicateLentTo = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDuplicateApproval = nil
                pendingDuplicateLentTo = nil
            }
        } message: {
            Text(pendingDuplicateApproval?.duplicateReason ?? "This looks like a transaction you already have — often the same alert reported by both email and SMS.")
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting { selectionBar }
        }
        .confirmationDialog("Reject selected?", isPresented: $showRejectSelectedConfirm, titleVisibility: .visible) {
            Button("Reject \(selectedItems.count) Items", role: .destructive) { rejectSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("None of these will be added to your transactions. This can't be undone.")
        }
        .alert("Some items were skipped", isPresented: Binding(
            get: { bulkResultMessage != nil },
            set: { if !$0 { bulkResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) { bulkResultMessage = nil }
        } message: {
            Text(bulkResultMessage ?? "")
        }
        // Nothing left to select (everything approved/rejected) — leave the
        // mode rather than strand the user in an empty selection bar.
        .onChange(of: pendingItems.isEmpty) { _, isEmpty in
            if isEmpty { stopSelecting() }
        }
        .sheet(item: $editingItem) { item in
            EditPendingEmailSheet(
                item: item,
                accounts: accounts.filter { !$0.isArchived },
                bnplPlans: bnplPlans.filter { !$0.isCompleted },
                onApprove: { lentTo in approve(item, lentTo: lentTo) }
            )
        }
    }

    private func reviewedRow(_ item: PendingEmailTransaction) -> some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: item.status == .approved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(item.status == .approved ? FTColor.income : FTColor.expense)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.merchantNormalized).font(.ftBody).foregroundStyle(FTColor.textSecondary).lineLimit(1)
                Text("\(item.wasAutoApproved ? "Auto-approved" : item.status.rawValue) · \(item.reviewedAt?.relativeFormatted ?? "")")
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

    // MARK: - Multi-select

    private func toggleSelection(_ item: PendingEmailTransaction) {
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
        else { selectedIDs.insert(item.id) }
    }

    private func startSelectingBNPL() {
        isSelecting = true
        selectedIDs = Set(pendingBNPLItems.map(\.id))
    }

    private func stopSelecting() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    private var selectionSummary: String {
        let total = selectedItems.count
        guard total > 0 else { return "Tap items to select them" }
        let bnpl = selectedBNPLItems.count
        return bnpl > 0 ? "\(total) selected · \(bnpl) BNPL" : "\(total) selected"
    }

    /// Menu choices are stored exactly as the edit sheet's picker stores them
    /// (`"none"` or a plan's UUID string), so an item linked here and one
    /// linked there are indistinguishable to `approveToLedger`.
    private func assignPlan(_ raw: String) {
        for item in selectedBNPLItems { item.bnplSelectionRaw = raw }
        try? context.save()
    }

    private var selectionBar: some View {
        VStack(spacing: FTSpacing.sm) {
            Text(selectionSummary)
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)

            // Four labelled actions would clip at large Dynamic Type in a
            // single row, so fall back to a vertical stack when they don't fit.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: FTSpacing.sm) { barActions }
                VStack(spacing: FTSpacing.sm) { barActions }
            }
        }
        .padding(FTSpacing.md)
        .frame(maxWidth: .infinity)
        .ftGlass(FTRadius.lg)
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, FTSpacing.sm)
    }

    @ViewBuilder
    private var barActions: some View {
        Menu {
            Button("All BNPL (\(pendingBNPLItems.count))") {
                selectedIDs = Set(pendingBNPLItems.map(\.id))
            }
            .disabled(pendingBNPLItems.isEmpty)
            Button("All pending (\(pendingItems.count))") {
                selectedIDs = Set(pendingItems.map(\.id))
            }
            Button("None") { selectedIDs.removeAll() }
        } label: {
            Label("Select", systemImage: "checklist")
        }

        Menu {
            Button("No linked plan") { assignPlan("none") }
            ForEach(bnplPlans.filter { !$0.isCompleted }) { plan in
                Button("\(plan.name) (\(plan.paidInstallments)/\(plan.totalInstallments))") {
                    assignPlan(plan.id.uuidString)
                }
            }
        } label: {
            Label("Plan", systemImage: "link")
        }
        .disabled(selectedBNPLItems.isEmpty)

        Button { approveSelected() } label: {
            Label("Approve", systemImage: "checkmark")
                .fontWeight(.semibold)
        }
        .disabled(selectedItems.isEmpty)

        Button(role: .destructive) { showRejectSelectedConfirm = true } label: {
            Label("Reject", systemImage: "xmark")
        }
        .disabled(selectedItems.isEmpty)
    }

    /// Approves the selection, applying the same gates a single approval has.
    /// A BNPL charge with no plan chosen can't be posted, and a flagged
    /// duplicate must still go through its explicit "Approve Anyway" — a bulk
    /// action isn't allowed to be the way around either. Skipped items stay
    /// selected so the user can fix them and go again.
    private func approveSelected() {
        var approved = 0, needsPlan = 0, duplicates = 0
        for item in selectedItems {
            if item.isBNPLMerchant && !item.bnplResolved { needsPlan += 1; continue }
            if item.isPossibleDuplicate { duplicates += 1; continue }
            EmailSyncService.shared.approveToLedger(item: item, context: context)
            if item.status == .approved {
                approved += 1
                selectedIDs.remove(item.id)
            }
        }

        var skipped: [String] = []
        if needsPlan > 0 {
            skipped.append("\(needsPlan) BNPL charge\(needsPlan == 1 ? "" : "s") with no plan chosen — use Plan first")
        }
        if duplicates > 0 {
            skipped.append("\(duplicates) possible duplicate\(duplicates == 1 ? "" : "s") — approve \(duplicates == 1 ? "it" : "those") individually")
        }
        if skipped.isEmpty {
            stopSelecting()
        } else {
            bulkResultMessage = "Approved \(approved). Skipped " + skipped.joined(separator: " and ") + "."
        }
    }

    private func rejectSelected() {
        let items = selectedItems
        for item in items {
            item.status = .rejected
            item.reviewedAt = Date()
            ImportLearningService.shared.recordRejection(rawMerchant: item.merchantRaw)
        }
        AuditLogService.log(context: context, "Rejected \(items.count) selected email imports in bulk")
        try? context.save()
        stopSelecting()
    }

    // MARK: - Approve

    /// `lentTo` is only ever supplied by the edit sheet, where the user marked
    /// the payment as money they lent. Swipe and bulk approvals never pass it.
    private func approve(_ item: PendingEmailTransaction, lentTo: String? = nil) {
        // BNPL charges need a plan selection first — route to the edit sheet
        if item.isBNPLMerchant && !item.bnplResolved {
            editingItem = item
            return
        }
        // Flagged duplicates (commonly the same transaction reported by both
        // email and SMS) need an explicit "Approve Anyway" before posting.
        if item.isPossibleDuplicate {
            pendingDuplicateApproval = item
            // Remembered across the dialog, or confirming would silently drop
            // the "lent" choice and post a plain expense.
            pendingDuplicateLentTo = lentTo
            return
        }
        EmailSyncService.shared.approveToLedger(item: item, context: context, lentTo: lentTo)
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

    // MARK: - Clear / Delete

    private func delete(_ item: PendingEmailTransaction) {
        context.delete(item)
        try? context.save()
    }

    private func clearReviewedHistory() {
        let items = reviewedItems
        for item in items { context.delete(item) }
        AuditLogService.log(context: context, "Cleared \(items.count) reviewed email imports")
        try? context.save()
    }

    private func rejectAllPending() {
        for item in pendingItems {
            item.status = .rejected
            item.reviewedAt = Date()
            ImportLearningService.shared.recordRejection(rawMerchant: item.merchantRaw)
        }
        AuditLogService.log(context: context, "Rejected all pending email imports in bulk")
        try? context.save()
    }
}

// MARK: - PendingEmailRow

private struct PendingEmailRow: View {
    let item: PendingEmailTransaction
    var accountName: String? = nil

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
                        if item.senderAddress.hasPrefix("sms:") {
                            Image(systemName: "message.fill").font(.system(size: 9))
                        } else if item.senderAddress.hasPrefix("applepay:") {
                            Image(systemName: "creditcard.fill").font(.system(size: 9))
                        }
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
                if item.isBNPLMerchant {
                    BadgeView(text: item.bnplResolved ? "BNPL" : "BNPL · select plan",
                              color: item.bnplResolved ? FTColor.catPurple : FTColor.gold)
                }
                if let accountName {
                    BadgeView(text: "→ \(accountName)", color: FTColor.accent)
                }
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
    let accounts: [Account]
    var bnplPlans: [BNPLPlan] = []
    /// Receives the borrower's name when the payment was marked as money lent,
    /// otherwise nil.
    let onApprove: (String?) -> Void

    private var bnplBlocked: Bool { item.isBNPLMerchant && !item.bnplResolved }
    /// Money in (a refund, a salary) isn't something you lend, and a BNPL
    /// instalment is a payment against a plan rather than a loan to a person.
    private var canMarkAsLent: Bool { item.direction == .debit && !item.isBNPLMerchant }
    @State private var markAsLent = false
    @State private var borrowerName = ""
    private var lentNameMissing: Bool {
        markAsLent && borrowerName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var isSMSSource: Bool { item.senderAddress.hasPrefix("sms:") }
    private var isApplePaySource: Bool { item.senderAddress.hasPrefix("applepay:") }

    @State private var amountText: String = ""
    @State private var tagsText: String = ""
    @State private var originalMerchant: String = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        if item.isPossibleDuplicate {
                            HStack(alignment: .top, spacing: FTSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.ftCallout).foregroundStyle(FTColor.gold)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Possible Duplicate").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Text(item.duplicateReason ?? "This looks like a transaction you already have.")
                                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(FTSpacing.md)
                            .background(FTColor.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: FTRadius.md))
                        }

                        // Merchant + amount
                        VStack(spacing: 0) {
                            fieldRow("Merchant") {
                                TextField("Merchant", text: $item.merchantNormalized)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            Divider().opacity(0.4)
                            fieldRow("Amount (\(item.currency))") {
                                AmountTextField("0.00", text: $amountText, font: .ftBodySemibold)
                                    .foregroundStyle(FTColor.textPrimary)
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
                            Divider().opacity(0.4)
                            fieldRow("Account") {
                                Picker("", selection: $item.matchedAccountId) {
                                    Text("None").tag(Optional<UUID>(nil))
                                    ForEach(accounts) { account in
                                        Text(account.name).tag(Optional(account.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(FTColor.accent)
                            }
                            if let reason = item.accountMatchReason, item.matchedAccountId != nil {
                                Text("Recognized from \(reason)")
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, FTSpacing.sm)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // BNPL plan selection — required for Tabby/Tamara-style merchants
                        if item.isBNPLMerchant {
                            VStack(spacing: 0) {
                                fieldRow("BNPL Plan") {
                                    Picker("", selection: Binding(
                                        get: { item.bnplSelectionRaw ?? "" },
                                        set: { item.bnplSelectionRaw = $0.isEmpty ? nil : $0 }
                                    )) {
                                        Text("Choose…").tag("")
                                        Text("No linked plan").tag("none")
                                        ForEach(bnplPlans) { plan in
                                            Text("\(plan.name) (\(plan.paidInstallments)/\(plan.totalInstallments))")
                                                .tag(plan.id.uuidString)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .accentColor(FTColor.accent)
                                }
                                Text(bnplBlocked
                                     ? "This is a BNPL charge — pick the installment plan it pays (or “No linked plan”) to enable approval."
                                     : "Approving records this as a BNPL payment\(item.linkedBNPLPlanId != nil ? " and advances the plan by one installment." : ".")")
                                    .font(.ftCaption)
                                    .foregroundStyle(bnplBlocked ? FTColor.gold : FTColor.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, FTSpacing.sm)
                            }
                            .padding(.horizontal, FTSpacing.lg)
                            .ftGlass(FTRadius.md)
                        }

                        // Money lent — an outgoing payment that someone owes back.
                        if canMarkAsLent {
                            VStack(spacing: 0) {
                                Toggle(isOn: $markAsLent) {
                                    Text("This was money I lent")
                                        .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                }
                                .tint(FTColor.accent)
                                .padding(.vertical, FTSpacing.sm)

                                if markAsLent {
                                    fieldRow("Borrower") {
                                        TextField("Name", text: $borrowerName)
                                            .multilineTextAlignment(.trailing)
                                            .foregroundStyle(FTColor.textPrimary)
                                    }
                                }

                                Text(markAsLent
                                     ? "Approving records this payment as “Lent to \(borrowerName.isEmpty ? "…" : borrowerName)” and adds it to Money Lent so you can track repayments. The account is debited once, by this payment."
                                     : "Turn on if someone owes you this back — it will be tracked under Money Lent.")
                                    .font(.ftCaption)
                                    .foregroundStyle(lentNameMissing ? FTColor.gold : FTColor.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, FTSpacing.sm)
                            }
                            .padding(.horizontal, FTSpacing.lg)
                            .ftGlass(FTRadius.md)
                        }

                        // Source context (read-only audit trail)
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text(isApplePaySource ? "SOURCE APPLE PAY"
                                 : isSMSSource ? "SOURCE SMS" : "SOURCE EMAIL")
                                .font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                            Text(item.emailSubject).font(.ftCallout).foregroundStyle(FTColor.textSecondary)
                            Text(isSMSSource || isApplePaySource ? item.bankName : item.senderAddress)
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
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
                    PrimaryButton(markAsLent ? "Save & Record as Lent" : "Save & Approve",
                                  icon: "checkmark.circle.fill") {
                        commitEdits()
                        onApprove(markAsLent ? borrowerName : nil)
                        dismiss()
                    }
                    .disabled(bnplBlocked || lentNameMissing)
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
                amountText = AmountTextField.format(String(format: "%.2f", item.amount))
                tagsText = item.suggestedTags.joined(separator: ", ")
                originalMerchant = item.merchantNormalized
                // Bank transfers usually carry the recipient's name as the
                // merchant, so it's the best starting guess for the borrower.
                if borrowerName.isEmpty { borrowerName = item.merchantNormalized }
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
