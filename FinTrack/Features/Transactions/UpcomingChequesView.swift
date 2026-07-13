import SwiftUI
import SwiftData

/// Dedicated list of cheque-method transactions with a future or overdue
/// `chequeDate`, grouped like `UpcomingPaymentsView` (Overdue/Today/Week/Month/Later).
struct UpcomingChequesView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.dismiss) private var dismiss

    @Query private var allTransactions: [Transaction]

    @State private var selectedTransaction: Transaction? = nil

    private var baseCurrency: String { appState.baseCurrency }

    private var cheques: [Transaction] {
        allTransactions
            .filter { $0.paymentMethod == .cheque && $0.chequeDate != nil }
            .sorted { ($0.chequeDate ?? .distantFuture) < ($1.chequeDate ?? .distantFuture) }
    }

    private var groupedCheques: [(label: String, cheques: [Transaction])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let endOfToday = cal.date(byAdding: .day, value: 1, to: today)!
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: today)!
        let endOfMonth = cal.date(byAdding: .month, value: 1, to: today)!

        var overdue: [Transaction] = []
        var todayCheques: [Transaction] = []
        var thisWeek: [Transaction] = []
        var thisMonth: [Transaction] = []
        var later: [Transaction] = []

        for tx in cheques {
            guard let chequeDate = tx.chequeDate else { continue }
            if chequeDate < today {
                overdue.append(tx)
            } else if chequeDate < endOfToday {
                todayCheques.append(tx)
            } else if chequeDate < endOfWeek {
                thisWeek.append(tx)
            } else if chequeDate < endOfMonth {
                thisMonth.append(tx)
            } else {
                later.append(tx)
            }
        }

        var groups: [(label: String, cheques: [Transaction])] = []
        if !overdue.isEmpty { groups.append(("Overdue", overdue)) }
        if !todayCheques.isEmpty { groups.append(("Today", todayCheques)) }
        if !thisWeek.isEmpty { groups.append(("This Week", thisWeek)) }
        if !thisMonth.isEmpty { groups.append(("This Month", thisMonth)) }
        if !later.isEmpty { groups.append(("Later", later)) }
        return groups
    }

    private var totalDue: Double {
        cheques.reduce(0) { $0 + currencyService.convert($1.amount, from: $1.currency, to: baseCurrency) }
    }

    private var overdueCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return cheques.filter { ($0.chequeDate ?? .distantFuture) < today }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !cheques.isEmpty {
                        summaryCard
                            .padding(.horizontal, FTSpacing.lg)
                            .padding(.top, 8)
                    }

                    if groupedCheques.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else {
                        ForEach(groupedCheques, id: \.label) { group in
                            groupSection(group)
                                .padding(.horizontal, FTSpacing.lg)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .background { FTBackdrop() }
            .navigationTitle("Upcoming Cheques")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedTransaction) { tx in
                TransactionDetailView(transaction: tx)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(label: "Total Due", value: totalDue.formatted(as: baseCurrency), color: .primary)
            Divider().frame(height: 36)
            summaryItem(label: "Cheques", value: "\(cheques.count)", color: .secondary)
            Divider().frame(height: 36)
            summaryItem(label: "Overdue", value: "\(overdueCount)", color: overdueCount > 0 ? .red : .secondary)
        }
        .padding(.vertical, FTSpacing.lg)
        .ftGlass(FTRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.ftHeadline)
                .foregroundStyle(color)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Group Section

    private func groupSection(_ group: (label: String, cheques: [Transaction])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group.label)
                    .font(.ftCallout)
                    .foregroundStyle(group.label == "Overdue" ? .red : .secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                let groupTotal = group.cheques.reduce(0) { $0 + currencyService.convert($1.amount, from: $1.currency, to: baseCurrency) }
                Text(groupTotal.formatted(as: baseCurrency))
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(group.cheques.enumerated()), id: \.element.id) { index, tx in
                    chequeRow(tx)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTransaction = tx }
                    if index < group.cheques.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Cheque Row

    private func chequeRow(_ tx: Transaction) -> some View {
        let overdue = (tx.chequeDate ?? .distantFuture) < Calendar.current.startOfDay(for: Date())
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(overdue ? FTColor.expense.opacity(0.12) : FTColor.gold.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "signature")
                    .foregroundStyle(overdue ? .red : FTColor.gold)
                    .font(.ftHeadline)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tx.title)
                    .font(.ftBody)
                Text(tx.chequeNumber?.isEmpty == false ? "Cheque #\(tx.chequeNumber!)" : "Cheque")
                    .font(.caption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(tx.amount.formatted(as: tx.currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(overdue ? .red : .primary)
                if let chequeDate = tx.chequeDate {
                    Text(dueLabelFor(chequeDate, overdue: overdue))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(urgencyColor(for: chequeDate, overdue: overdue))
                }
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.ftDisplay)
                .foregroundStyle(FTColor.income)
            Text("No Upcoming Cheques")
                .font(.ftHeadline)
            Text("Cheque payments you add will show up here as their date approaches.")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FTSpacing.xl)
        }
    }

    // MARK: - Helpers

    private func dueLabelFor(_ date: Date, overdue: Bool) -> String {
        if overdue {
            let days = Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: date),
                to: Calendar.current.startOfDay(for: Date())).day ?? 0
            return days == 0 ? "Today" : "\(days)d overdue"
        }
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days)d"
    }

    private func urgencyColor(for date: Date, overdue: Bool) -> Color {
        if overdue { return .red }
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)).day ?? 0
        return days <= 3 ? .red : days <= 7 ? .orange : .secondary
    }
}
