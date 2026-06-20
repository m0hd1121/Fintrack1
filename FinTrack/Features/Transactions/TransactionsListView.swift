import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil
    @State private var selectedCategory: TransactionCategory? = nil
    @State private var showingFilters = false
    @State private var showingAddTransaction = false
    @State private var selectedTransaction: Transaction? = nil
    @State private var debouncedSearch = ""
    @State private var groupedCache: [(String, [Transaction])] = []

    // Custom date-range filter
    @State private var showingDateFilter = false
    @State private var dateFilterActive = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()

    // Bulk edit
    @State private var isEditing = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showingBulkCategoryPicker = false
    @State private var bulkNewCategory: TransactionCategory = .other
    @State private var showingBulkTagAlert = false
    @State private var bulkNewTag = ""
    @State private var showingBulkDeleteConfirm = false

    // Undo delete
    @State private var pendingDelete: Transaction? = nil
    @State private var undoTask: Task<Void, Never>? = nil

    // CSV import
    @State private var showingCSVImport = false

    private var hasDuplicates: Bool {
        transactions.contains { $0.isDuplicate }
    }

    private var duplicateCount: Int {
        transactions.filter { $0.isDuplicate }.count
    }

    private var groupingKey: String {
        let dateKey = dateFilterActive ? "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)" : "off"
        let pendingID = pendingDelete?.id.uuidString ?? ""
        return "\(debouncedSearch)|\(selectedType?.rawValue ?? "")|\(selectedCategory?.rawValue ?? "")|\(dateKey)|\(transactions.count)|\(pendingID)"
    }

    private func recomputeGroups() {
        let search = debouncedSearch
        let excludeID = pendingDelete?.id
        let rangeStart = Calendar.current.startOfDay(for: startDate)
        let rangeEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        let filtered = transactions.filter { tx in
            if let excl = excludeID, tx.id == excl { return false }
            let matchesSearch = search.isEmpty ||
                tx.title.localizedCaseInsensitiveContains(search) ||
                tx.category.rawValue.localizedCaseInsensitiveContains(search) ||
                (tx.merchant?.localizedCaseInsensitiveContains(search) ?? false)
            let matchesType = selectedType == nil || tx.type == selectedType
            let matchesCategory = selectedCategory == nil || tx.category == selectedCategory
            let matchesDate = !dateFilterActive || (tx.date >= rangeStart && tx.date <= rangeEnd)
            return matchesSearch && matchesType && matchesCategory && matchesDate
        }
        let grouped = Dictionary(grouping: filtered) { tx -> String in
            if tx.date.isSameDay(as: Date()) { return "Today" }
            if tx.date.isSameDay(as: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) { return "Yesterday" }
            return tx.date.formatted
        }
        groupedCache = grouped.sorted { lhs, rhs in
            let order = ["Today", "Yesterday"]
            if let li = order.firstIndex(of: lhs.key), let ri = order.firstIndex(of: rhs.key) {
                return li < ri
            }
            if order.contains(lhs.key) { return true }
            if order.contains(rhs.key) { return false }
            return lhs.key > rhs.key
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if transactions.isEmpty {
                        ZStack {
                            FTBackdrop()
                            EmptyStateView(
                                icon: "arrow.left.arrow.right.circle",
                                title: "No Transactions",
                                message: "Start tracking your finances by adding your first transaction.",
                                actionTitle: "Add Transaction"
                            ) {
                                showingAddTransaction = true
                            }
                        }
                    } else {
                        List {
                            // Duplicate detection banner
                            if hasDuplicates {
                                duplicateBanner
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: FTSpacing.screen, bottom: 4, trailing: FTSpacing.screen))
                            }

                            // Filter chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(title: "All", isSelected: selectedType == nil) {
                                        selectedType = nil
                                        selectedCategory = nil
                                    }
                                    ForEach(TransactionType.allCases, id: \.self) { type in
                                        FilterChip(title: type.rawValue, isSelected: selectedType == type) {
                                            selectedType = selectedType == type ? nil : type
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))

                            ForEach(groupedCache, id: \.0) { group in
                                Section(header: SectionDateHeader(title: group.0, transactions: group.1, baseCurrency: appState.baseCurrency)) {
                                    ForEach(group.1) { tx in
                                        transactionRow(tx)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .contentMargins(.bottom, 100, for: .scrollContent)
                        .searchable(text: $searchText, prompt: "Search transactions...")
                        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
                    }
                }
                .task(id: searchText) {
                    if searchText.isEmpty {
                        debouncedSearch = ""
                    } else {
                        try? await Task.sleep(for: .milliseconds(250))
                        guard !Task.isCancelled else { return }
                        debouncedSearch = searchText
                    }
                }
                .task(id: groupingKey) {
                    recomputeGroups()
                }
                .onAppear {
                    recomputeGroups()
                }
                .scrollContentBackground(.hidden)
                .background { FTBackdrop() }
                .navigationTitle("Transactions")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(isEditing ? "Done" : "Edit") {
                            withAnimation(.snappy(duration: 0.25)) {
                                isEditing.toggle()
                                if !isEditing { selectedIDs.removeAll() }
                            }
                        }
                        .font(isEditing ? .ftBodySemibold : .ftBody)
                        .foregroundStyle(FTColor.accent)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingDateFilter = true
                        } label: {
                            Image(systemName: dateFilterActive ? "calendar.badge.checkmark" : "calendar")
                                .foregroundStyle(dateFilterActive ? FTColor.accent : FTColor.textPrimary)
                        }
                        .accessibilityLabel("Filter by date")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showingAddTransaction = true
                            } label: {
                                Label("Add Transaction", systemImage: "plus")
                            }
                            Button {
                                showingCSVImport = true
                            } label: {
                                Label("Import CSV", systemImage: "doc.text")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingDateFilter) {
                    DateRangeFilterSheet(
                        startDate: $startDate,
                        endDate: $endDate,
                        isActive: $dateFilterActive,
                        onApply: { recomputeGroups() }
                    )
                    .presentationDetents([.medium])
                }
                .sheet(isPresented: $showingAddTransaction, onDismiss: { recomputeGroups() }) {
                    AddTransactionView()
                }
                .sheet(item: $selectedTransaction, onDismiss: { recomputeGroups() }) { tx in
                    TransactionDetailView(transaction: tx)
                }
                .sheet(isPresented: $showingCSVImport, onDismiss: { recomputeGroups() }) {
                    CSVImportView()
                }
                .sheet(isPresented: $showingBulkCategoryPicker) {
                    BulkCategoryPickerSheet(selectedCategory: $bulkNewCategory) {
                        applyBulkCategory(bulkNewCategory)
                    }
                    .presentationDetents([.medium])
                }
                .alert("Add Tag to Selected", isPresented: $showingBulkTagAlert) {
                    TextField("Tag name", text: $bulkNewTag)
                    Button("Add") {
                        let tag = bulkNewTag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !tag.isEmpty { applyBulkTag(tag) }
                        bulkNewTag = ""
                    }
                    Button("Cancel", role: .cancel) { bulkNewTag = "" }
                }
                .alert("Delete \(selectedIDs.count) Transaction\(selectedIDs.count == 1 ? "" : "s")?",
                       isPresented: $showingBulkDeleteConfirm) {
                    Button("Delete", role: .destructive) { commitBulkDelete() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action cannot be undone.")
                }

                // Undo snackbar
                if pendingDelete != nil {
                    UndoSnackbar(
                        message: "Transaction deleted",
                        commitAction: { commitPendingDelete() },
                        undoAction: { undoDelete() }
                    )
                    .zIndex(10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: pendingDelete != nil)
                }

                // Bulk edit action bar
                if isEditing && !selectedIDs.isEmpty {
                    BulkEditBar(
                        selectedCount: selectedIDs.count,
                        onDelete: { showingBulkDeleteConfirm = true },
                        onChangeCategory: { showingBulkCategoryPicker = true },
                        onAddTag: { showingBulkTagAlert = true }
                    )
                    .zIndex(9)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedIDs.count)
                }
            }
        }
    }

    // MARK: - Transaction Row

    @ViewBuilder
    private func transactionRow(_ tx: Transaction) -> some View {
        let isSelected = selectedIDs.contains(tx.id)

        HStack(spacing: 0) {
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? FTColor.accent : FTColor.textMuted)
                    .font(.title3)
                    .frame(width: 40)
                    .animation(.snappy(duration: 0.2), value: isSelected)
            }

            TransactionRowView(transaction: tx, baseCurrency: appState.baseCurrency)
                .padding(.trailing, FTSpacing.sm)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.xs)
        .background(
            isSelected && isEditing
                ? FTColor.accent.opacity(0.08)
                : Color(UIColor.secondarySystemBackground),
            in: .rect(cornerRadius: FTRadius.md)
        )
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.xs)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                if selectedIDs.contains(tx.id) {
                    selectedIDs.remove(tx.id)
                } else {
                    selectedIDs.insert(tx.id)
                }
            } else {
                selectedTransaction = tx
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: !isEditing) {
            if !isEditing {
                Button(role: .destructive) {
                    scheduleDeletion(tx)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading) {
            if !isEditing {
                Button {
                    selectedTransaction = tx
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(FTColor.accent)
            }
        }
    }

    // MARK: - Duplicate Banner

    private var duplicateBanner: some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: "doc.on.doc.fill")
                .foregroundStyle(FTColor.gold)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(duplicateCount) duplicate transaction\(duplicateCount == 1 ? "" : "s") detected")
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Review and remove them to keep your data clean.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            Button {
                selectedType = nil
                selectedCategory = nil
                // Show duplicates in search
                searchText = ""
            } label: {
                Image(systemName: "chevron.right")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(FTSpacing.md)
        .background(FTColor.gold.opacity(0.12), in: .rect(cornerRadius: FTRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: FTRadius.md)
                .strokeBorder(FTColor.gold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Delete / Undo

    private func scheduleDeletion(_ tx: Transaction) {
        // Commit any already-pending deletion before queuing new one
        if pendingDelete != nil { commitPendingDelete() }

        withAnimation { pendingDelete = tx }
        recomputeGroups()

        undoTask?.cancel()
        undoTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run { commitPendingDelete() }
        }
    }

    private func commitPendingDelete() {
        guard let tx = pendingDelete else { return }
        undoTask?.cancel()
        undoTask = nil
        deleteTransaction(tx)
        withAnimation { pendingDelete = nil }
        recomputeGroups()
    }

    private func undoDelete() {
        undoTask?.cancel()
        undoTask = nil
        withAnimation { pendingDelete = nil }
        recomputeGroups()
    }

    private func deleteTransaction(_ tx: Transaction) {
        if let account = tx.account, !tx.isPending, !tx.isScheduled {
            let delta = currencyService.convert(tx.amount, from: tx.currency, to: account.currency)
            switch tx.type {
            case .income:   account.balance -= delta
            case .expense:  account.balance += delta
            case .transfer: account.balance += delta
            }
        }
        if let loan = tx.linkedLoan,
           tx.category == .personalLentRepayment || tx.category == .loanRepayment {
            loan.outstandingBalance += tx.amount
            if !loan.isActive { loan.isActive = true }
        }
        context.delete(tx)
        try? context.save()
    }

    // MARK: - Bulk Actions

    private func commitBulkDelete() {
        let toDelete = transactions.filter { selectedIDs.contains($0.id) }
        for tx in toDelete { deleteTransaction(tx) }
        withAnimation {
            selectedIDs.removeAll()
            isEditing = false
        }
        recomputeGroups()
    }

    private func applyBulkCategory(_ category: TransactionCategory) {
        let toUpdate = transactions.filter { selectedIDs.contains($0.id) }
        for tx in toUpdate {
            tx.category = category
            tx.updatedAt = Date()
        }
        try? context.save()
        withAnimation { selectedIDs.removeAll() }
        recomputeGroups()
    }

    private func applyBulkTag(_ tag: String) {
        let toUpdate = transactions.filter { selectedIDs.contains($0.id) }
        for tx in toUpdate where !tx.tags.contains(tag) {
            tx.tags.append(tag)
            tx.updatedAt = Date()
        }
        try? context.save()
        withAnimation { selectedIDs.removeAll() }
    }
}

// MARK: - Undo Snackbar

struct UndoSnackbar: View {
    let message: String
    let commitAction: () -> Void
    let undoAction: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.ftCallout)
                .foregroundStyle(.white)
            Spacer()
            Button("Undo", action: undoAction)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.gold)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, FTSpacing.md)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: FTRadius.lg))
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, 108)
    }
}

// MARK: - Bulk Edit Bar

struct BulkEditBar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onChangeCategory: () -> Void
    let onAddTag: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("\(selectedCount) selected")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
                .padding(.bottom, FTSpacing.xs)

            HStack(spacing: FTSpacing.md) {
                bulkButton("trash", "Delete", FTColor.expense, onDelete)
                bulkButton("tag", "Category", FTColor.accent, onChangeCategory)
                bulkButton("number", "Tag", FTColor.catTeal, onAddTag)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: FTRadius.xl))
        .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: -6)
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, 100)
    }

    private func bulkButton(_ icon: String, _ label: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.ftCaption)
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FTSpacing.sm)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: FTRadius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bulk Category Picker Sheet

struct BulkCategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: TransactionCategory
    let onApply: () -> Void

    private let categories = TransactionCategory.allCases

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                List(categories, id: \.self) { cat in
                    Button {
                        selectedCategory = cat
                        onApply()
                        dismiss()
                    } label: {
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: cat.icon, tint: Color.fromString(cat.color), size: 36)
                            Text(cat.rawValue)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Spacer()
                            if cat == selectedCategory {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(FTColor.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Change Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Date Range Filter Sheet

struct DateRangeFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isActive: Bool
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                VStack(spacing: FTSpacing.lg) {
                    // Quick presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FTSpacing.sm) {
                            presetButton("Last Month", months: 1)
                            presetButton("Last 3 Months", months: 3)
                            presetButton("Last 6 Months", months: 6)
                            presetButton("Past Year", months: 12)
                        }
                        .padding(.horizontal, 2)
                    }

                    VStack(spacing: 0) {
                        DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                            .font(.ftBody)
                            .padding(.vertical, 4)
                        Divider().opacity(0.4)
                        DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .font(.ftBody)
                            .padding(.vertical, 4)
                    }
                    .tint(FTColor.accent)
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    Button {
                        isActive = true
                        onApply()
                        dismiss()
                    } label: {
                        Text("Apply Filter")
                    }
                    .buttonStyle(.ftPrimary)

                    if isActive {
                        Button {
                            isActive = false
                            onApply()
                            dismiss()
                        } label: {
                            Text("Clear Filter")
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.expense)
                        }
                    }

                    Spacer()
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func presetButton(_ title: String, months: Int) -> some View {
        Button {
            endDate = Date()
            startDate = Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
            isActive = true
            onApply()
            dismiss()
        } label: {
            Text(title)
                .font(.ftCallout)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .foregroundStyle(FTColor.textPrimary)
                .glassEffect(.regular, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ftCallout)
                .padding(.horizontal, FTSpacing.md)
                .padding(.vertical, FTSpacing.sm + 1)
                .foregroundStyle(isSelected ? .white : FTColor.textPrimary)
                .background(isSelected ? FTColor.accent : FTColor.bgElevated, in: .capsule)
                .animation(.snappy(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Date Header

struct SectionDateHeader: View {
    let title: String
    let transactions: [Transaction]
    let baseCurrency: String

    private var netAmount: Double {
        transactions.reduce(0) { result, tx in
            switch tx.type {
            case .income:  return result + tx.amountInBaseCurrency
            case .expense: return result - tx.amountInBaseCurrency
            case .transfer: return result
            }
        }
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)
            Spacer()
            Text((netAmount >= 0 ? "+" : "") + netAmount.formatted(as: baseCurrency))
                .font(.ftCaption)
                .foregroundStyle(netAmount >= 0 ? FTColor.income : FTColor.expense)
        }
    }
}

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let transaction: Transaction
    @State private var showingEdit = false

    private var tint: Color { Color.fromString(transaction.category.color) }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Hero
                        VStack(spacing: FTSpacing.md) {
                            ZStack(alignment: .bottomTrailing) {
                                FTIconTile(symbol: transaction.category.icon, tint: tint, size: 72)
                                if transaction.isPending {
                                    Label("Pending", systemImage: "clock.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(FTColor.gold, in: Capsule())
                                        .offset(y: 16)
                                } else if transaction.isScheduled {
                                    Label("Scheduled", systemImage: "calendar")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(FTColor.accent, in: Capsule())
                                        .offset(y: 16)
                                }
                            }
                            .padding(.bottom, transaction.isPending || transaction.isScheduled ? 16 : 0)

                            Text((transaction.type == .expense ? "-" : "+") + transaction.amount.formatted(as: transaction.currency))
                                .font(.ftAmount)
                                .foregroundStyle(
                                    transaction.isPending || transaction.isScheduled
                                        ? FTColor.textMuted
                                        : transaction.type == .expense ? FTColor.expense : FTColor.income
                                )
                                .lineLimit(1).minimumScaleFactor(0.5)
                            Text(transaction.title)
                                .font(.ftHeadline)
                                .foregroundStyle(FTColor.textPrimary)
                            if transaction.isRecurring {
                                Label("Recurring", systemImage: "repeat")
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.accent)
                                    .padding(.horizontal, FTSpacing.md)
                                    .padding(.vertical, 5)
                                    .background(FTColor.accent.opacity(0.1), in: .capsule)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FTSpacing.lg)

                        // Details card
                        VStack(spacing: 0) {
                            detailRow(label: "Category", value: transaction.category.rawValue, icon: transaction.category.icon)
                            Divider().padding(.leading, 52)
                            detailRow(label: "Date", value: transaction.date.formatted, icon: "calendar")
                            Divider().padding(.leading, 52)
                            detailRow(label: "Payment", value: transaction.paymentMethod.rawValue, icon: "creditcard")
                            Divider().padding(.leading, 52)
                            detailRow(label: "Type", value: transaction.type.rawValue, icon: "arrow.left.arrow.right")
                            if let merchant = transaction.merchant, !merchant.isEmpty {
                                Divider().padding(.leading, 52)
                                detailRow(label: "Merchant", value: merchant, icon: "storefront")
                            }
                            if let sub = transaction.subtype {
                                Divider().padding(.leading, 52)
                                detailRow(label: "Subtype", value: sub.rawValue, icon: sub.icon)
                            }
                            if let src = transaction.incomeSource, !src.isEmpty {
                                Divider().padding(.leading, 52)
                                detailRow(label: "Income Source", value: src, icon: "building.2")
                            }
                            if let scheduled = transaction.scheduledDate, transaction.isScheduled {
                                Divider().padding(.leading, 52)
                                detailRow(label: "Scheduled For", value: scheduled.formatted, icon: "calendar.badge.clock")
                            }
                            if transaction.hasLocation, let lat = transaction.latitude, let lon = transaction.longitude {
                                Divider().padding(.leading, 52)
                                detailRow(label: "Location", value: String(format: "%.4f, %.4f", lat, lon), icon: "location.fill")
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground), in: .rect(cornerRadius: FTRadius.md))

                        // Split items
                        if transaction.isSplit {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("SPLIT BREAKDOWN")
                                    .font(.ftLabel).tracking(1.4)
                                    .foregroundStyle(FTColor.textSecondary)
                                ForEach(transaction.splitItems) { item in
                                    HStack {
                                        FTIconTile(symbol: item.category.icon, tint: Color.fromString(item.category.color), size: 30)
                                        Text(item.category.rawValue)
                                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                        if let note = item.notes, !note.isEmpty {
                                            Text("· \(note)")
                                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                        }
                                        Spacer()
                                        Text(item.amount.formatted(as: transaction.currency))
                                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    }
                                    .padding(.vertical, FTSpacing.xs)
                                }
                            }
                            .padding(FTSpacing.md)
                            .background(Color(UIColor.secondarySystemBackground), in: .rect(cornerRadius: FTRadius.md))
                        }

                        // Tags
                        if !transaction.tags.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("TAGS")
                                    .font(.ftLabel).tracking(1.4)
                                    .foregroundStyle(FTColor.textSecondary)
                                FlowLayout(spacing: FTSpacing.sm) {
                                    ForEach(transaction.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.ftCaption)
                                            .foregroundStyle(FTColor.accent)
                                            .padding(.horizontal, 10).padding(.vertical, 5)
                                            .background(FTColor.accent.opacity(0.1), in: Capsule())
                                    }
                                }
                            }
                            .padding(FTSpacing.md)
                            .background(Color(UIColor.secondarySystemBackground), in: .rect(cornerRadius: FTRadius.md))
                        }

                        // Notes
                        if let notes = transaction.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("NOTES")
                                    .font(.ftLabel).tracking(1.4)
                                    .foregroundStyle(FTColor.textSecondary)
                                Text(notes)
                                    .font(.ftBody)
                                    .foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(FTSpacing.md)
                            .background(Color(UIColor.secondarySystemBackground), in: .rect(cornerRadius: FTRadius.md))
                        }

                        // Receipt
                        if let imageData = transaction.receiptImageData,
                           let uiImage = UIImage(data: imageData) {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("RECEIPT")
                                    .font(.ftLabel).tracking(1.4)
                                    .foregroundStyle(FTColor.textSecondary)
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                            }
                            .padding(FTSpacing.md)
                            .background(Color(UIColor.secondarySystemBackground), in: .rect(cornerRadius: FTRadius.md))
                        }

                        // Document attachments
                        if !transaction.documents.isEmpty {
                            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                                Text("DOCUMENTS")
                                    .font(.ftLabel).tracking(1.4)
                                    .foregroundStyle(FTColor.textSecondary)
                                ForEach(transaction.documents) { doc in
                                    HStack(spacing: FTSpacing.sm) {
                                        Image(systemName: doc.displayIcon)
                                            .foregroundStyle(FTColor.accent)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(doc.filename)
                                                .font(.ftCaption)
                                                .foregroundStyle(FTColor.textPrimary)
                                                .lineLimit(1)
                                            Text(doc.fileSizeLabel)
                                                .font(.system(size: 10))
                                                .foregroundStyle(FTColor.textMuted)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, FTSpacing.xs)
                                }
                            }
                            .padding(FTSpacing.md)
                            .background(Color(UIColor.secondarySystemBackground), in: .rect(cornerRadius: FTRadius.md))
                        }

                        Color.clear.frame(height: FTSpacing.xl)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showingEdit = true }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
            }
            .sheet(isPresented: $showingEdit) {
                AddTransactionView(editingTransaction: transaction)
            }
        }
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(FTColor.textSecondary)
                .frame(width: 28)
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.last.map { $0.maxY } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [CGRect] {
        var rows: [CGRect] = []
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > maxWidth, origin.x > 0 {
                origin.x = 0
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            rows.append(CGRect(origin: origin, size: size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return rows
    }
}

// MARK: - Shared Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)
        }
    }
}
