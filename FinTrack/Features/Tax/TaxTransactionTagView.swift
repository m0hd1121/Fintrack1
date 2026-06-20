import SwiftUI
import SwiftData

struct TaxTransactionTagView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]

    let taxYear: Int

    @State private var filterMode: TagFilter = .all
    @State private var searchText = ""

    enum TagFilter: String, CaseIterable {
        case all         = "All"
        case deductible  = "Deductible"
        case vat         = "VAT"
        case untagged    = "Untagged"
    }

    private var yearTransactions: [Transaction] {
        let cal = Calendar.current
        return transactions.filter {
            cal.component(.year, from: $0.date) == taxYear && $0.type == .expense
        }
    }

    private var filtered: [Transaction] {
        var base = yearTransactions
        switch filterMode {
        case .all:        break
        case .deductible: base = base.filter { $0.isTaxDeductible }
        case .vat:        base = base.filter { $0.isVATReclaimable }
        case .untagged:   base = base.filter { !$0.isTaxDeductible && !$0.isVATReclaimable }
        }
        if !searchText.isEmpty {
            base = base.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.merchant ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return base.sorted { $0.date > $1.date }
    }

    private var totalDeductible: Double {
        yearTransactions.filter { $0.isTaxDeductible }.reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    private var totalVATReclaimable: Double {
        yearTransactions.filter { $0.isVATReclaimable }.reduce(0) { $0 + $1.amountInBaseCurrency * 0.05 / 1.05 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                summaryRow
                    .padding(.horizontal, FTSpacing.screen)

                searchBar
                    .padding(.horizontal, FTSpacing.screen)

                filterPicker
                    .padding(.horizontal, FTSpacing.screen)

                if filtered.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: FTSpacing.sm) {
                        ForEach(filtered) { tx in
                            taxTagRow(tx)
                                .padding(.horizontal, FTSpacing.screen)
                        }
                    }
                }
            }
            .padding(.top, FTSpacing.md)
            .padding(.bottom, 40)
        }
        .navigationTitle("Transaction Tax Tags")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: FTSpacing.sm) {
            tagStat(
                icon: "tag.fill", color: FTColor.income,
                label: "Deductible",
                value: totalDeductible.asCompact(currency: appState.baseCurrency)
            )
            tagStat(
                icon: "percent", color: FTColor.catBlue,
                label: "VAT Reclaimable",
                value: totalVATReclaimable.asCompact(currency: appState.baseCurrency)
            )
            tagStat(
                icon: "doc.text.fill", color: FTColor.textMuted,
                label: "Tagged",
                value: "\(yearTransactions.filter { $0.isTaxDeductible || $0.isVATReclaimable }.count)"
            )
        }
    }

    private func tagStat(icon: String, color: Color, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.ftCallout).foregroundStyle(color)
            Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(FTColor.textMuted)
            TextField("Search transactions…", text: $searchText)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
        .padding()
        .ftGlass(FTRadius.pill)
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(TagFilter.allCases, id: \.rawValue) { f in
                    FilterChip(title: f.rawValue, isSelected: filterMode == f) {
                        withAnimation { filterMode = f }
                    }
                }
            }
        }
    }

    // MARK: - Tag Row

    private func taxTagRow(_ tx: Transaction) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FTRadius.sm)
                        .fill(Color.fromString(tx.category.color).opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: tx.category.icon)
                        .font(.ftCallout).foregroundStyle(Color.fromString(tx.category.color))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(tx.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                    HStack(spacing: 4) {
                        Text(tx.merchant ?? tx.category.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        Text("·").foregroundStyle(FTColor.textMuted)
                        Text(tx.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
                Spacer()
                Text(tx.amountInBaseCurrency.formatted(as: appState.baseCurrency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
            }

            HStack(spacing: FTSpacing.md) {
                tagToggle(
                    title: "Tax Deductible",
                    isOn: Binding(
                        get: { tx.isTaxDeductible },
                        set: { tx.isTaxDeductible = $0; try? context.save() }
                    ),
                    color: FTColor.income,
                    icon: "tag.fill"
                )
                tagToggle(
                    title: "VAT Reclaimable",
                    isOn: Binding(
                        get: { tx.isVATReclaimable },
                        set: { tx.isVATReclaimable = $0; try? context.save() }
                    ),
                    color: FTColor.catBlue,
                    icon: "percent"
                )
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private func tagToggle(title: String, isOn: Binding<Bool>, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isOn.wrappedValue ? icon : "\(icon.replacingOccurrences(of: ".fill", with: ""))")
                .font(.ftCaption).foregroundStyle(isOn.wrappedValue ? color : FTColor.textMuted)
            Text(title)
                .font(.ftCaption)
                .foregroundStyle(isOn.wrappedValue ? color : FTColor.textMuted)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(color).labelsHidden().scaleEffect(0.85)
        }
        .padding(.horizontal, FTSpacing.md).padding(.vertical, FTSpacing.sm)
        .background(isOn.wrappedValue ? color.opacity(0.08) : FTColor.textMuted.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            Image(systemName: "tag.slash.fill").font(.system(size: 44)).foregroundStyle(FTColor.textMuted)
            Text("No Transactions Found").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("Add expense transactions for \(taxYear) to tag them as deductible or VAT-reclaimable.")
                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, FTSpacing.xxl)
        }
        .padding(.top, 60)
    }
}
