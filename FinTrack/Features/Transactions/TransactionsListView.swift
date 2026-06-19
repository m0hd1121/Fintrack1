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

    private var groupingKey: String {
        let dateKey = dateFilterActive ? "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)" : "off"
        return "\(debouncedSearch)|\(selectedType?.rawValue ?? "")|\(selectedCategory?.rawValue ?? "")|\(dateKey)|\(transactions.count)"
    }

    private func recomputeGroups() {
        let search = debouncedSearch
        // Normalize the date range to whole days so the bounds are inclusive.
        let rangeStart = Calendar.current.startOfDay(for: startDate)
        let rangeEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let filtered = transactions.filter { tx in
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
                                    TransactionRowView(transaction: tx, baseCurrency: appState.baseCurrency)
                                        .padding(.horizontal, FTSpacing.screen)
                                        .padding(.vertical, FTSpacing.xs)
                                        .background(Color(UIColor.secondarySystemBackground), in: .rect(cornerRadius: FTRadius.md))
                                        .padding(.horizontal, FTSpacing.screen)
                                        .padding(.vertical, FTSpacing.xs)
                                        .listRowInsets(EdgeInsets())
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .onTapGesture { selectedTransaction = tx }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteTransaction(tx)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                selectedTransaction = tx
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(FTColor.accent)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .contentMargins(.bottom, 100, for: .scrollContent)
                    .searchable(text: $searchText, prompt: "Search transactions...")
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
                    Button {
                        showingAddTransaction = true
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
        }
    }

    private func deleteTransaction(_ tx: Transaction) {
        // Reverse account balance
        if let account = tx.account {
            let delta = currencyService.convert(tx.amount, from: tx.currency, to: account.currency)
            switch tx.type {
            case .income:   account.balance -= delta
            case .expense:  account.balance += delta
            case .transfer: account.balance += delta
            }
        }
        // Restore loan outstanding balance for repayment-type transactions
        if let loan = tx.linkedLoan,
           tx.category == .personalLentRepayment || tx.category == .loanRepayment {
            loan.outstandingBalance += tx.amount
            if !loan.isActive { loan.isActive = true }
        }
        context.delete(tx)
        try? context.save()
    }
}

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

struct SectionDateHeader: View {
    let title: String
    let transactions: [Transaction]
    let baseCurrency: String

    private var netAmount: Double {
        transactions.reduce(0) { result, tx in
            switch tx.type {
            case .income: return result + tx.amountInBaseCurrency
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
                            FTIconTile(symbol: transaction.category.icon, tint: tint, size: 72)
                            Text((transaction.type == .expense ? "-" : "+") + transaction.amount.formatted(as: transaction.currency))
                                .font(.ftAmount)
                                .foregroundStyle(transaction.type == .expense ? FTColor.expense : FTColor.income)
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
                        }
                        .background(Color(UIColor.secondarySystemBackground), in: .rect(cornerRadius: FTRadius.md))

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

// Shared detail row used by AccountDetailView and other screens
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
