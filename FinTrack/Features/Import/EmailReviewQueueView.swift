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
    @State private var pendingDuplicateLentShares: [LentShare] = []

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
                && !($0.isBNPLMerchant && (!$0.bnplResolved || $0.bnplNeedsAmountFix))
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
                        item: item, context: context, lentShares: pendingDuplicateLentShares)
                }
                pendingDuplicateApproval = nil
                pendingDuplicateLentShares = []
            }
            Button("Cancel", role: .cancel) {
                pendingDuplicateApproval = nil
                pendingDuplicateLentShares = []
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
                onApprove: { shares in approve(item, lentShares: shares) }
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
            if item.isBNPLMerchant && (!item.bnplResolved || item.bnplNeedsAmountFix) { needsPlan += 1; continue }
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

    /// `lentShares` is only ever supplied by the edit sheet, where the user said
    /// they paid for someone else. Swipe and bulk approvals never pass it.
    private func approve(_ item: PendingEmailTransaction, lentShares: [LentShare] = []) {
        // BNPL charges need a plan selection first — route to the edit sheet.
        // Also when a charge pays several plans but its per-plan amounts don't
        // add up to the charge, which only the sheet can fix.
        if item.isBNPLMerchant && (!item.bnplResolved || item.bnplNeedsAmountFix) {
            editingItem = item
            return
        }
        // Flagged duplicates (commonly the same transaction reported by both
        // email and SMS) need an explicit "Approve Anyway" before posting.
        if item.isPossibleDuplicate {
            pendingDuplicateApproval = item
            // Remembered across the dialog, or confirming would silently drop
            // who owes what and post a plain expense.
            pendingDuplicateLentShares = lentShares
            return
        }
        EmailSyncService.shared.approveToLedger(item: item, context: context, lentShares: lentShares)
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

    private var bnplBadgeText: String {
        guard item.bnplResolved else { return "BNPL · select plan" }
        let plans = item.bnplAllocations.count
        if plans >= 2 { return item.bnplNeedsAmountFix ? "BNPL · \(plans) plans · set amounts" : "BNPL · \(plans) plans" }
        return "BNPL"
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
                    BadgeView(text: bnplBadgeText,
                              color: item.bnplResolved && !item.bnplNeedsAmountFix ? FTColor.catPurple : FTColor.gold)
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
    /// Receives who owes the user what when they paid for someone else;
    /// empty for an ordinary approval.
    let onApprove: ([LentShare]) -> Void

    private var bnplBlocked: Bool { item.isBNPLMerchant && !item.bnplResolved }

    /// What each selected plan received, as typed. Kept as text so a half-typed
    /// number isn't rewritten under the user's cursor; pushed into the item's
    /// encoded selection on every change.
    @State private var allocationTexts: [UUID: String] = [:]

    /// Why a multi-plan charge can't be approved yet, or nil when it can.
    private var bnplAllocationProblem: String? {
        let allocations = item.bnplAllocations
        guard allocations.count >= 2 else { return nil }
        if allocations.contains(where: { ($0.amount ?? 0) <= 0 }) {
            return "Enter how much of this charge went to each plan."
        }
        let total = allocations.reduce(0) { $0 + ($1.amount ?? 0) }
        if abs(total - currentAmount) > 0.005 {
            return "The plan amounts add up to \(total.formatted(as: item.currency)), but this charge is \(currentAmount.formatted(as: item.currency))."
        }
        return nil
    }

    private var bnplExplanation: String {
        if bnplBlocked {
            return "This is a BNPL charge — pick the installment plan(s) it pays (or “No linked plan”) to enable approval."
        }
        if let problem = bnplAllocationProblem { return problem }
        let count = item.bnplAllocations.count
        if count >= 2 {
            return "Approving records one payment per plan and advances each plan by one installment. Your account is debited once, for the whole charge."
        }
        return "Approving records this as a BNPL payment\(count == 1 ? " and advances the plan by one installment." : ".")"
    }

    private func bnplChoiceRow(title: String, subtitle: String?, isOn: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: FTSpacing.md) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? FTColor.accent : FTColor.textMuted)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, FTSpacing.sm)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// Picking a plan clears "No linked plan"; picking a second one starts the
    /// per-plan amounts at each plan's own instalment, since a combined charge
    /// is usually exactly the instalments added together.
    private func togglePlan(_ plan: BNPLPlan) {
        var allocations = item.bnplAllocations
        if let index = allocations.firstIndex(where: { $0.planId == plan.id }) {
            allocations.remove(at: index)
            allocationTexts[plan.id] = nil
        } else {
            allocations.append(BNPLAllocation(planId: plan.id, amount: nil))
        }
        if allocations.count >= 2 {
            for index in allocations.indices where allocations[index].amount == nil {
                let id = allocations[index].planId
                let suggested = bnplPlans.first(where: { $0.id == id })?.installmentAmount ?? 0
                allocations[index].amount = suggested
                allocationTexts[id] = String(format: "%.2f", suggested)
            }
        } else {
            for index in allocations.indices { allocations[index].amount = nil }
        }
        item.setBNPLAllocations(allocations)
    }

    private func allocationTextBinding(for planId: UUID) -> Binding<String> {
        Binding(
            get: { allocationTexts[planId] ?? "" },
            set: { newValue in
                allocationTexts[planId] = newValue
                var allocations = item.bnplAllocations
                guard allocations.count >= 2,
                      let index = allocations.firstIndex(where: { $0.planId == planId }) else { return }
                allocations[index].amount = Double(newValue.replacingOccurrences(of: ",", with: ""))
                item.setBNPLAllocations(allocations)
            }
        )
    }

    // "I paid for someone else" — the user bought things at this merchant for
    // friends and wants to be paid back. The purchase stays at the merchant;
    // each person added here owes a share of it.
    @State private var paidForOthers = false
    @State private var people: [PersonDraft] = []

    struct PersonDraft: Identifiable {
        let id = UUID()
        var name = ""
        var amountText = ""
    }

    /// Money in (a refund, a salary) isn't paid on anyone's behalf, and a BNPL
    /// instalment is a payment against a plan rather than a purchase for a friend.
    private var canMarkAsLent: Bool { item.direction == .debit && !item.isBNPLMerchant }

    /// The amount as currently typed — the user may correct it in this same
    /// sheet, so the shares are checked against that, not the stored value.
    private var currentAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")).flatMap { $0 > 0 ? $0 : nil } ?? item.amount
    }

    private func amount(of person: PersonDraft) -> Double? {
        Double(person.amountText.replacingOccurrences(of: ",", with: "")).flatMap { $0 > 0 ? $0 : nil }
    }

    private var sharesTotal: Double { people.reduce(0) { $0 + (amount(of: $1) ?? 0) } }

    /// Why the shares can't be saved yet, or nil when they're fine. Shown in
    /// place of the explanation so the disabled button is never a mystery.
    private var sharesProblem: String? {
        guard paidForOthers else { return nil }
        if people.isEmpty { return "Add who owes you." }
        if people.contains(where: { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return "Add a name for each person."
        }
        if people.contains(where: { amount(of: $0) == nil }) {
            return "Enter what each person owes."
        }
        if sharesTotal > currentAmount + 0.005 {
            return "Their shares add up to more than this purchase."
        }
        return nil
    }

    private var lentShares: [LentShare] {
        guard paidForOthers else { return [] }
        return people.compactMap { person in
            guard let owed = amount(of: person) else { return nil }
            return LentShare(borrower: person.name, amount: owed)
        }
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

                        // BNPL plan(s) — required for Tabby/Tamara-style merchants. One
                        // charge can pay several plans, so this is a multi-select.
                        if item.isBNPLMerchant {
                            VStack(spacing: 0) {
                                bnplChoiceRow(title: "No linked plan", subtitle: nil,
                                              isOn: item.bnplSelectionRaw == "none") {
                                    item.bnplSelectionRaw = item.bnplSelectionRaw == "none" ? nil : "none"
                                }
                                ForEach(bnplPlans) { plan in
                                    bnplChoiceRow(
                                        title: plan.name,
                                        subtitle: "\(plan.paidInstallments)/\(plan.totalInstallments) paid · \(plan.installmentAmount.formatted(as: plan.currency)) each",
                                        isOn: item.bnplAllocations.contains { $0.planId == plan.id }
                                    ) { togglePlan(plan) }
                                }

                                // With two or more plans, say how much of the charge
                                // each one received. They must add up to the charge.
                                if item.bnplAllocations.count >= 2 {
                                    ForEach(item.bnplAllocations, id: \.planId) { allocation in
                                        if let plan = bnplPlans.first(where: { $0.id == allocation.planId }) {
                                            fieldRow("\(plan.name) (\(item.currency))") {
                                                TextField("0.00", text: allocationTextBinding(for: plan.id))
                                                    .keyboardType(.decimalPad)
                                                    .multilineTextAlignment(.trailing)
                                                    .foregroundStyle(FTColor.textPrimary)
                                            }
                                        }
                                    }
                                }

                                Text(bnplExplanation)
                                    .font(.ftCaption)
                                    .foregroundStyle(bnplBlocked || bnplAllocationProblem != nil ? FTColor.gold : FTColor.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, FTSpacing.sm)
                            }
                            .padding(.horizontal, FTSpacing.lg)
                            .ftGlass(FTRadius.md)
                        }

                        // Paid for someone else — friends owe the user part of this purchase.
                        if canMarkAsLent {
                            VStack(spacing: 0) {
                                Toggle(isOn: $paidForOthers.animation()) {
                                    Text("I paid for someone else")
                                        .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                }
                                .tint(FTColor.accent)
                                .padding(.vertical, FTSpacing.sm)
                                .onChange(of: paidForOthers) { _, isOn in
                                    // Start with one person owing the whole bill —
                                    // the common case is trimming it down, not
                                    // typing a number from scratch.
                                    if isOn && people.isEmpty {
                                        people = [PersonDraft(amountText: String(format: "%.2f", currentAmount))]
                                    }
                                }

                                if paidForOthers {
                                    ForEach($people) { $person in
                                        VStack(spacing: 0) {
                                            fieldRow("Who owes you") {
                                                TextField("Name", text: $person.name)
                                                    .multilineTextAlignment(.trailing)
                                                    .foregroundStyle(FTColor.textPrimary)
                                            }
                                            fieldRow("Their share (\(item.currency))") {
                                                TextField("0.00", text: $person.amountText)
                                                    .keyboardType(.decimalPad)
                                                    .multilineTextAlignment(.trailing)
                                                    .foregroundStyle(FTColor.textPrimary)
                                            }
                                            if people.count > 1 {
                                                Button(role: .destructive) {
                                                    people.removeAll { $0.id == person.id }
                                                } label: {
                                                    Label("Remove", systemImage: "minus.circle")
                                                        .font(.ftCaption)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                                .padding(.bottom, FTSpacing.xs)
                                            }
                                        }
                                    }
                                    Button {
                                        people.append(PersonDraft())
                                    } label: {
                                        Label("Add another person", systemImage: "plus.circle")
                                            .font(.ftCallout)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, FTSpacing.sm)
                                }

                                Text(paidForOthers
                                     ? (sharesProblem
                                        ?? "The purchase stays recorded at \(item.merchantNormalized) and your account is debited once. Each person's share is added to Money Lent so you can track it coming back\(sharesTotal < currentAmount - 0.005 ? ", and only the rest counts as your own spending" : "").")
                                     : "Turn on if you bought this for friends and they owe you part of it back.")
                                    .font(.ftCaption)
                                    .foregroundStyle(sharesProblem != nil ? FTColor.gold : FTColor.textMuted)
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
                    PrimaryButton(paidForOthers ? "Save & Track What They Owe" : "Save & Approve",
                                  icon: "checkmark.circle.fill") {
                        commitEdits()
                        onApprove(lentShares)
                        dismiss()
                    }
                    .disabled(bnplBlocked || bnplAllocationProblem != nil || sharesProblem != nil)
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
                for allocation in item.bnplAllocations {
                    allocationTexts[allocation.planId] = allocation.amount.map { String(format: "%.2f", $0) } ?? ""
                }
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
