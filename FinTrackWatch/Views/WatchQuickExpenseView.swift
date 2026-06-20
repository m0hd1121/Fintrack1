import SwiftUI

struct WatchQuickExpenseView: View {
    @EnvironmentObject private var dataSource: WatchDataSource

    @State private var amount: Double = 10
    @State private var category = "Shopping"
    @State private var type = "expense"
    @State private var title_ = ""
    @State private var showingConfirmation = false

    private let categories = [
        "Food", "Shopping", "Transport", "Entertainment",
        "Health", "Bills", "Other"
    ]
    private let quickAmounts: [Double] = [10, 25, 50, 100, 200, 500]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Type picker
                Picker("Type", selection: $type) {
                    Text("Expense").tag("expense")
                    Text("Income").tag("income")
                }
                .pickerStyle(.segmented)

                // Amount with Digital Crown
                VStack(spacing: 4) {
                    Text("Amount")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(dataSource.currency) \(String(format: "%.0f", amount))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .focusable()
                        .digitalCrownRotation($amount, from: 1, through: 10000, by: 1, sensitivity: .medium)
                }

                // Quick amount buttons
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(quickAmounts, id: \.self) { amt in
                        Button(action: { amount = amt }) {
                            Text("\(Int(amt))")
                                .font(.system(size: 11, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(amount == amt ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Category picker
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.navigationLink)

                // Log button
                Button(action: logTransaction) {
                    Label(type == "expense" ? "Log Expense" : "Log Income",
                          systemImage: type == "expense" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(type == "expense" ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Quick Add")
        .alert("Logged!", isPresented: $showingConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(dataSource.currency) \(String(format: "%.0f", amount)) \(type) added. Open FinTrack to confirm.")
        }
    }

    private func logTransaction() {
        let tx = WatchPendingTransaction(
            id: UUID(),
            title: title_.isEmpty ? category : title_,
            amount: amount,
            currency: dataSource.currency,
            type: type,
            categoryName: category,
            date: Date(),
            createdAt: Date()
        )
        dataSource.enqueuePendingTransaction(tx)
        showingConfirmation = true
        WKInterfaceDevice.current().play(.success)
    }
}
