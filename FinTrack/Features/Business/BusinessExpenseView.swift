import SwiftUI
import SwiftData
import Charts

struct BusinessExpenseView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var clients: [ClientProfile]
    @Query private var projects: [BusinessProject]

    @State private var selectedProject: BusinessProject? = nil
    @State private var selectedClient: ClientProfile? = nil
    @State private var dateFilter: DateRange = .thisMonth
    @State private var showingTagFilter = false

    enum DateRange: String, CaseIterable {
        case thisMonth = "This Month"
        case last3     = "Last 3 Mo"
        case thisYear  = "This Year"
        case all       = "All Time"
    }

    private var businessExpenses: [Transaction] {
        let base = transactions.filter { tx in
            tx.type == .expense && !tx.isPending &&
            (tx.isTaxDeductible || !tx.tags.isEmpty)
        }
        return applyDateFilter(base)
    }

    private var filteredExpenses: [Transaction] {
        var result = businessExpenses
        if let project = selectedProject {
            result = result.filter { $0.tags.contains(project.tagKey) }
        }
        if let client = selectedClient {
            result = result.filter {
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(client.name) }) ||
                $0.incomeSource?.localizedCaseInsensitiveContains(client.name) == true
            }
        }
        return result
    }

    private var totalExpenses: Double {
        filteredExpenses.reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    private var vatReclaimable: Double {
        filteredExpenses.filter { $0.isVATReclaimable }
                       .reduce(0) { $0 + $1.amountInBaseCurrency * 0.05 }
    }

    private var taxDeductible: Double {
        filteredExpenses.filter { $0.isTaxDeductible }
                       .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    private var categoryBreakdown: [(category: String, amount: Double)] {
        Dictionary(grouping: filteredExpenses) { $0.category.rawValue }
            .mapValues { $0.reduce(0) { $0 + $1.amountInBaseCurrency } }
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { (category: $0.key, amount: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                summaryCard
                filtersSection
                if !categoryBreakdown.isEmpty { categoryChart }
                transactionsList
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Business Expenses")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BUSINESS EXPENSES").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(totalExpenses.formatted(as: appState.baseCurrency))
                        .font(.ftAmount).foregroundStyle(FTColor.expense)
                    Text("\(filteredExpenses.count) transactions · \(dateFilter.rawValue)")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(FTColor.expense.opacity(0.1)).frame(width: 52, height: 52)
                    Image(systemName: "creditcard.fill").font(.ftTitle).foregroundStyle(FTColor.expense)
                }
            }
            HStack(spacing: FTSpacing.sm) {
                tile("Tax Deductible", value: taxDeductible, color: FTColor.income)
                tile("VAT Reclaimable", value: vatReclaimable, color: FTColor.catBlue)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func tile(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value.asCompact(currency: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.md)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        VStack(spacing: FTSpacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    ForEach(DateRange.allCases, id: \.self) { dr in
                        FilterChip(title: dr.rawValue, isSelected: dateFilter == dr) { dateFilter = dr }
                    }
                }
            }

            if !projects.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.sm) {
                        FilterChip(title: "All Projects", isSelected: selectedProject == nil) { selectedProject = nil }
                        ForEach(projects.filter { $0.status == .active }) { proj in
                            FilterChip(title: proj.name, isSelected: selectedProject?.id == proj.id) {
                                selectedProject = selectedProject?.id == proj.id ? nil : proj
                            }
                        }
                    }
                }
            }

            if !clients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.sm) {
                        FilterChip(title: "All Clients", isSelected: selectedClient == nil) { selectedClient = nil }
                        ForEach(clients.filter { $0.status == .active }) { client in
                            FilterChip(title: client.name, isSelected: selectedClient?.id == client.id) {
                                selectedClient = selectedClient?.id == client.id ? nil : client
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Category Chart

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("BY CATEGORY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            Chart {
                ForEach(categoryBreakdown, id: \.category) { item in
                    BarMark(
                        x: .value("Amount", item.amount),
                        y: .value("Category", item.category)
                    )
                    .foregroundStyle(FTColor.expense.gradient)
                    .annotation(position: .trailing) {
                        Text(item.amount.asCompact(currency: appState.baseCurrency))
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
            }
            .frame(height: CGFloat(categoryBreakdown.count * 44))
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TRANSACTIONS (\(filteredExpenses.count))")
                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if filteredExpenses.isEmpty {
                Text("No business expenses found for the selected filters.")
                    .font(.ftBody).foregroundStyle(FTColor.textMuted)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                VStack(spacing: 1) {
                    ForEach(filteredExpenses) { tx in
                        expenseRow(tx)
                    }
                }
                .ftGlass(FTRadius.md)
            }
        }
    }

    private func expenseRow(_ tx: Transaction) -> some View {
        let catColor = Color.fromString(tx.category.color)
        return HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(catColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: tx.category.icon).font(.ftCaption).foregroundStyle(catColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                HStack(spacing: FTSpacing.xs) {
                    Text(tx.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    if tx.isTaxDeductible {
                        Text("Tax").font(.ftCaption).foregroundStyle(FTColor.income)
                            .padding(.horizontal, 4).background(FTColor.income.opacity(0.1), in: Capsule())
                    }
                    if tx.isVATReclaimable {
                        Text("VAT").font(.ftCaption).foregroundStyle(FTColor.catBlue)
                            .padding(.horizontal, 4).background(FTColor.catBlue.opacity(0.1), in: Capsule())
                    }
                }
                if !tx.tags.isEmpty {
                    Text(tx.tags.joined(separator: ", ")).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }
            Spacer()
            Text(tx.amountInBaseCurrency.formatted(as: appState.baseCurrency))
                .font(.ftCallout).foregroundStyle(FTColor.expense)
        }
        .padding(FTSpacing.md)
    }

    // MARK: - Helpers

    private func applyDateFilter(_ txs: [Transaction]) -> [Transaction] {
        let now = Date()
        let cal = Calendar.current
        switch dateFilter {
        case .thisMonth:
            return txs.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .last3:
            guard let start = cal.date(byAdding: .month, value: -3, to: now) else { return txs }
            return txs.filter { $0.date >= start }
        case .thisYear:
            return txs.filter { cal.isDate($0.date, equalTo: now, toGranularity: .year) }
        case .all:
            return txs
        }
    }
}
