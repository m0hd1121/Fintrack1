import SwiftUI

struct WatchBalanceView: View {
    @EnvironmentObject private var data: WatchDataSource

    private var incomeTotal: Double {
        data.transactions.filter { $0.type == "income" }.reduce(0) { $0 + $1.amount }
    }
    private var expenseTotal: Double {
        data.transactions.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Net worth hero
                VStack(spacing: 2) {
                    Text("Net Worth")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(data.netWorth.watchFormatted(currency: data.currency))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(.vertical, 8)

                Divider()

                // Income / Expenses
                HStack {
                    VStack(spacing: 2) {
                        Label("Income", systemImage: "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(incomeTotal.watchFormatted(currency: data.currency))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Label("Spent", systemImage: "arrow.up.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        Text(expenseTotal.watchFormatted(currency: data.currency))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                }

                if !data.budgets.isEmpty {
                    Divider()
                    // Top budget progress
                    let b = data.budgets[0]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(b.name).font(.caption).fontWeight(.medium)
                            Spacer()
                            Text("\(Int(b.progress * 100))%")
                                .font(.caption2.bold())
                                .foregroundStyle(b.progress > 1 ? .red : .green)
                        }
                        ProgressView(value: b.progress)
                            .tint(b.progress > 1 ? .red : .green)
                    }
                }

                if !data.bills.isEmpty {
                    Divider()
                    let nextBill = data.bills.sorted { $0.dueDate < $1.dueDate }.first!
                    HStack {
                        Image(systemName: nextBill.icon).font(.caption)
                        Text(nextBill.name).font(.caption).lineLimit(1)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(nextBill.amount.watchFormatted(currency: nextBill.currency))
                                .font(.caption2.bold())
                            Text(nextBill.dueDate, style: .date).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("FinTrack")
        .onAppear { data.reload() }
    }
}

private extension Double {
    func watchFormatted(currency: String) -> String {
        let abs = Swift.abs(self)
        if abs >= 1_000_000 { return "\(currency) \(String(format: "%.1fM", abs / 1_000_000))" }
        if abs >= 1_000    { return "\(currency) \(String(format: "%.1fK", abs / 1_000))" }
        return "\(currency) \(String(format: "%.0f", self))"
    }
}
