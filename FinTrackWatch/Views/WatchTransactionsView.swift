import SwiftUI

struct WatchTransactionsView: View {
    @EnvironmentObject private var data: WatchDataSource

    var body: some View {
        List {
            if data.transactions.isEmpty {
                Text("No recent transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data.transactions.prefix(10)) { tx in
                    WatchTransactionRow(tx: tx)
                }
            }
        }
        .navigationTitle("Transactions")
        .onAppear { data.reload() }
    }
}

struct WatchTransactionRow: View {
    let tx: WatchTransaction

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tx.categoryIcon)
                .font(.system(size: 12))
                .foregroundStyle(tx.type == "income" ? .green : .red)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(tx.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(tx.date, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text((tx.type == "expense" ? "-" : "+") + watchFormat(tx.amount, currency: tx.currency))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tx.type == "income" ? .green : .red)
        }
    }

    private func watchFormat(_ value: Double, currency: String) -> String {
        let abs = Swift.abs(value)
        if abs >= 1_000 { return "\(currency)\(String(format: "%.1fK", abs / 1_000))" }
        return "\(currency)\(String(format: "%.0f", abs))"
    }
}
