import SwiftUI
import SwiftData

/// "Deposit To" picker for the income-recording sheets (rent, invoice,
/// dividend). Without an account the income transaction moved no balance and
/// a matching bank alert approved from the review queue double-counted it.
struct IncomeAccountRow: View {
    @Binding var accountId: UUID?
    @Query(sort: \Account.name) private var accounts: [Account]

    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            Text("Deposit To")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize()
            Spacer()
            Picker("", selection: $accountId) {
                Text("None").tag(Optional<UUID>(nil))
                ForEach(activeAccounts) { account in
                    Text(account.name).tag(Optional(account.id))
                }
            }
            .pickerStyle(.menu)
            .tint(FTColor.accent)
        }
        .padding(.vertical, FTSpacing.sm)
        .onAppear {
            if accountId == nil {
                accountId = activeAccounts.first(where: { $0.isDefault })?.id
            }
        }
    }

    /// Links `tx` to the chosen account and credits its balance.
    static func deposit(_ tx: Transaction, into accountId: UUID?, context: ModelContext) {
        guard let accountId,
              let account = try? context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.id == accountId })).first
        else { return }
        tx.account = account
        account.balance += CurrencyService.shared.convert(tx.amount, from: tx.currency, to: account.currency)
    }
}
