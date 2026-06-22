import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var creditCards: [CreditCard]
    @Query private var loans: [Loan]
    @Query private var bnplPlans: [BNPLPlan]
    @Query private var investments: [Investment]
    @Query private var cryptoHoldings: [CryptoHolding]
    @Query private var goldHoldings: [GoldHolding]
    @Query private var giftCards: [GiftCard]
    @Query private var loyaltyPrograms: [LoyaltyProgram]

    @State private var showingAddAccount = false
    @State private var showingAddCreditCard = false
    @State private var showingAddLoan = false
    @State private var showingAddBNPL = false
    @State private var showingAddInvestment = false
    @State private var showingAddCrypto = false
    @State private var showingAddGold = false
    @State private var showingAddGiftCard = false
    @State private var showingAddLoyalty = false
    @State private var selectedAccount: Account? = nil

    // Edit sheets
    @State private var editingInvestment: Investment? = nil
    @State private var editingCrypto: CryptoHolding? = nil
    @State private var editingGold: GoldHolding? = nil
    @State private var editingGiftCard: GiftCard? = nil
    @State private var editingLoyalty: LoyaltyProgram? = nil

    private var baseCurrency: String { appState.baseCurrency }

    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }
    private var visibleAccounts: [Account] { activeAccounts.filter { !$0.isHidden } }

    private var totalBalance: Double {
        visibleAccounts.reduce(0) {
            $0 + currencyService.convert($1.balance, from: $1.currency, to: baseCurrency)
        }
    }

    private var totalDebt: Double {
        let loanDebt = loans.filter { $0.isActive }
            .reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency) }
        let ccDebt = creditCards.filter { $0.isActive }
            .reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency) }
        return loanDebt + ccDebt
    }

    private var investmentValue: Double {
        let stocks = investments.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        let crypto = cryptoHoldings.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        let gold = goldHoldings.filter { !$0.isArchived }.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        return stocks + crypto + gold
    }

    private var giftCardValue: Double {
        giftCards.filter { !$0.isUsedUp && !$0.isExpired }.reduce(0) {
            $0 + currencyService.convert($1.balance, from: $1.currency, to: baseCurrency)
        }
    }

    private var loyaltyValue: Double {
        loyaltyPrograms.filter { !$0.isExpired }.reduce(0) {
            $0 + currencyService.convert($1.estimatedValue, from: $1.currency, to: baseCurrency)
        }
    }

    private var netWorth: Double { totalBalance + investmentValue + giftCardValue - totalDebt }

    var body: some View {
        NavigationStack {
            List {
                summarySection

                // #9 – Unified Accounts section (bank + cash + credit cards)
                Section {
                    ForEach(visibleAccounts) { account in
                        AccountRow(account: account, baseCurrency: baseCurrency)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedAccount = account }
                            .accountRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(account); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }

                                Button {
                                    account.isArchived = true; try? context.save()
                                } label: { Label("Archive", systemImage: "archivebox") }
                                .tint(FTColor.gold)
                            }
                    }
                    ForEach(creditCards.filter { $0.isActive }) { card in
                        CreditCardRow(card: card, baseCurrency: baseCurrency)
                            .accountRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(card); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                    Menu {
                        Button { showingAddAccount = true } label: {
                            Label("Bank / Cash Account", systemImage: "building.columns")
                        }
                        Button { showingAddCreditCard = true } label: {
                            Label("Credit Card", systemImage: "creditcard")
                        }
                    } label: {
                        Label("Add Account", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Accounts").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
                }

                // Loans / Debts
                Section {
                    ForEach(loans.filter { $0.isActive }) { loan in
                        NavigationLink(destination: LazyView { LoanDetailView(loan: loan) }) {
                            LoanRow(loan: loan, baseCurrency: baseCurrency)
                        }
                        .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(loan); try? context.save()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    Button { showingAddLoan = true } label: {
                        Label("Add Loan", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Loans / Debts").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
                }

                // BNPL
                Section {
                    ForEach(bnplPlans.filter { !$0.isCompleted }) { plan in
                        BNPLRow(plan: plan, baseCurrency: baseCurrency)
                            .accountRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(plan); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                    Button { showingAddBNPL = true } label: {
                        Label("Add BNPL Plan", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Buy Now Pay Later").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
                }

                // Investments
                Section {
                    ForEach(investments) { inv in
                        InvestmentRow(investment: inv, baseCurrency: baseCurrency)
                            .accountRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(inv); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                                Button { editingInvestment = inv } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(FTColor.accent)
                            }
                    }
                    Button { showingAddInvestment = true } label: {
                        Label("Add Investment", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Investments").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
                }

                // #6 – Renamed from "Crypto" to "Assets"
                Section {
                    ForEach(cryptoHoldings) { holding in
                        CryptoRow(holding: holding, baseCurrency: baseCurrency)
                            .accountRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(holding); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                                Button { editingCrypto = holding } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(FTColor.accent)
                            }
                    }
                    Button { showingAddCrypto = true } label: {
                        Label("Add Crypto Asset", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Crypto Assets").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
                }

                // Gold & Precious Metals
                Section {
                    ForEach(goldHoldings.filter { !$0.isArchived }) { holding in
                        GoldHoldingRow(holding: holding, baseCurrency: baseCurrency)
                            .accountRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(holding); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                                Button { editingGold = holding } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(FTColor.accent)
                                Button {
                                    holding.isArchived = true; try? context.save()
                                } label: { Label("Archive", systemImage: "archivebox") }
                                .tint(FTColor.gold)
                            }
                    }
                    Button { showingAddGold = true } label: {
                        Label("Add Precious Metal", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Gold & Precious Metals").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
                }

                // Gift Cards
                Section {
                    ForEach(giftCards.filter { !$0.isUsedUp }) { card in
                        GiftCardRow(card: card, baseCurrency: baseCurrency)
                            .accountRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(card); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                                Button { editingGiftCard = card } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(FTColor.accent)
                                Button {
                                    card.isUsedUp = true; try? context.save()
                                } label: { Label("Mark Used", systemImage: "checkmark.circle") }
                                .tint(FTColor.income)
                            }
                    }
                    Button { showingAddGiftCard = true } label: {
                        Label("Add Gift Card", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Gift Cards").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
                }

                // Loyalty Programs
                Section {
                    ForEach(loyaltyPrograms.filter { !$0.isExpired }) { program in
                        LoyaltyProgramRow(program: program, baseCurrency: baseCurrency)
                            .accountRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(program); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                                Button { editingLoyalty = program } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(FTColor.accent)
                            }
                    }
                    Button { showingAddLoyalty = true } label: {
                        Label("Add Loyalty Program", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Loyalty & Rewards").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textSecondary)
                }

            }
            .listStyle(.plain)
            .contentMargins(.horizontal, FTSpacing.screen, for: .scrollContent)
            .contentMargins(.bottom, 100, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Accounts & Assets")
            // #5 – NO floating button inside this view; it lives in the tab bar
            .sheet(isPresented: $showingAddAccount) { AddAccountView() }
            .sheet(isPresented: $showingAddCreditCard) { AddCreditCardView() }
            .sheet(isPresented: $showingAddLoan) { AddLoanView() }
            .sheet(isPresented: $showingAddBNPL) { AddBNPLView() }
            .sheet(isPresented: $showingAddInvestment) { AddInvestmentView() }
            .sheet(isPresented: $showingAddCrypto) { AddCryptoView() }
            .sheet(isPresented: $showingAddGold) { AddGoldHoldingView() }
            .sheet(isPresented: $showingAddGiftCard) { AddGiftCardView() }
            .sheet(isPresented: $showingAddLoyalty) { AddLoyaltyProgramView() }
            .sheet(item: $selectedAccount) { acc in AccountDetailView(account: acc) }
            .sheet(item: $editingInvestment) { inv in EditInvestmentView(investment: inv) }
            .sheet(item: $editingCrypto) { h in EditCryptoView(holding: h) }
            .sheet(item: $editingGold) { h in EditGoldHoldingView(holding: h) }
            .sheet(item: $editingGiftCard) { c in EditGiftCardView(card: c) }
            .sheet(item: $editingLoyalty) { p in EditLoyaltyProgramView(program: p) }
        }
    }

    private var summarySection: some View {
        VStack(spacing: FTSpacing.md) {
            // Net worth hero
            VStack(alignment: .leading, spacing: 8) {
                Text("NET WORTH")
                    .font(.ftLabel).tracking(1.6)
                    .foregroundStyle(.white.opacity(0.8))
                Text(netWorth.formatted(as: baseCurrency))
                    .font(.ftAmount)
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .padding(FTSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))

            HStack(spacing: FTSpacing.md) {
                SummaryTile(title: "Cash & Banks", amount: totalBalance,
                            currency: baseCurrency, color: FTColor.accent, icon: "building.columns.fill")
                SummaryTile(title: "Investments", amount: investmentValue,
                            currency: baseCurrency, color: FTColor.income, icon: "chart.line.uptrend.xyaxis")
                SummaryTile(title: "Total Debt", amount: totalDebt,
                            currency: baseCurrency, color: FTColor.expense, icon: "creditcard.fill")
            }

            if giftCardValue > 0 || loyaltyValue > 0 {
                HStack(spacing: FTSpacing.md) {
                    if giftCardValue > 0 {
                        SummaryTile(title: "Gift Cards", amount: giftCardValue,
                                    currency: baseCurrency, color: FTColor.catTeal, icon: "gift.fill")
                    }
                    if loyaltyValue > 0 {
                        SummaryTile(title: "Rewards", amount: loyaltyValue,
                                    currency: baseCurrency, color: FTColor.catPurple, icon: "star.fill")
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: FTSpacing.sm, trailing: 0))
    }
}

// MARK: – Helpers

private extension View {
    func accountRowStyle() -> some View {
        self
            .listRowBackground(
                RoundedRectangle(cornerRadius: FTRadius.md)
                    .fill(.regularMaterial)
                    .overlay(RoundedRectangle(cornerRadius: FTRadius.md)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                    .padding(.vertical, FTSpacing.xs)
            )
            .listRowSeparator(.hidden)
    }
}

// MARK: – Row views

struct SummaryTile: View {
    let title: String; let amount: Double; let currency: String; let color: Color; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Image(systemName: icon).foregroundStyle(color).font(.ftCaption)
            Text(title).font(.ftLabel).foregroundStyle(FTColor.textSecondary).lineLimit(1)
            Text(amount.asCompact(currency: currency))
                .font(.ftBodySemibold)
                .foregroundStyle(FTColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(FTSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }
}

struct AccountRow: View {
    let account: Account; let baseCurrency: String
    @Environment(CurrencyService.self) private var currencyService

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: account.icon, tint: Color.fromString(account.color))
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Text(account.effectiveBankName.isEmpty ? account.type.rawValue : account.effectiveBankName)
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(account.balance.formatted(as: account.currency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                if account.currency != baseCurrency {
                    Text(currencyService.convert(account.balance, from: account.currency, to: baseCurrency).formatted(as: baseCurrency))
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                // badges
                if account.minimumBalanceEnabled && account.balance < account.minimumBalance {
                    Text("Low balance").font(.ftCaption).foregroundStyle(FTColor.expense)
                }
                if account.isBusiness {
                    Text("Business").font(.ftCaption).foregroundStyle(FTColor.catBlue)
                }
                if !account.sharedMembers.isEmpty {
                    Text("Shared").font(.ftCaption).foregroundStyle(FTColor.catPurple)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            var label = "\(account.name), \(account.type.rawValue), balance \(account.balance.formatted(as: account.currency))"
            if account.minimumBalanceEnabled && account.balance < account.minimumBalance {
                label += ", low balance warning"
            }
            return label
        }())
    }
}

struct CreditCardRow: View {
    let card: CreditCard; let baseCurrency: String
    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "creditcard.fill", tint: Color.fromString(card.color))
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                HStack {
                    Text(card.bankName).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    if card.isPaymentDueSoon { BadgeView(text: "Due Soon", color: FTColor.expense) }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(card.outstandingBalance.formatted(as: card.currency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                Text("\(Int(card.utilizationRate * 100))% used")
                    .font(.ftCaption)
                    .foregroundStyle(card.utilizationRate > 0.7 ? FTColor.expense : FTColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.name), credit card, outstanding \(card.outstandingBalance.formatted(as: card.currency)), \(Int(card.utilizationRate * 100)) percent utilized\(card.isPaymentDueSoon ? ", payment due soon" : "")")
    }
}

struct LoanRow: View {
    let loan: Loan; let baseCurrency: String
    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: loan.loanType.icon, tint: FTColor.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(loan.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Text(loan.loanType.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(loan.outstandingBalance.formatted(as: loan.currency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.gold)
                Text("EMI: \(loan.emiAmount.formatted(as: loan.currency))")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct BNPLRow: View {
    let plan: BNPLPlan; let baseCurrency: String
    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "cart.fill", tint: Color.fromString(plan.provider.color))
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Text("\(plan.provider.rawValue) • \(plan.merchant)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(plan.remainingAmount.formatted(as: plan.currency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.accentBright)
                Text("\(plan.paidInstallments)/\(plan.totalInstallments)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InvestmentRow: View {
    let investment: Investment; let baseCurrency: String
    @Environment(CurrencyService.self) private var currencyService
    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: investment.type.icon, tint: FTColor.income)
            VStack(alignment: .leading, spacing: 2) {
                Text(investment.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Text("\(investment.symbol) • \(investment.type.rawValue)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(investment.currentValue.formatted(as: investment.currency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                HStack(spacing: 2) {
                    Image(systemName: investment.isProfit ? "arrow.up.right" : "arrow.down.right").font(.ftCaption)
                    Text(investment.profitLossPercent.asPercentage()).font(.ftCaption)
                }
                .foregroundStyle(investment.isProfit ? FTColor.income : FTColor.expense)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CryptoRow: View {
    let holding: CryptoHolding; let baseCurrency: String
    @Environment(CurrencyService.self) private var currencyService
    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "bitcoinsign.circle.fill", tint: FTColor.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Text("\(holding.quantity) \(holding.symbol)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(holding.currentValue.formatted(as: holding.currency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                HStack(spacing: 2) {
                    Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right").font(.ftCaption)
                    Text(holding.profitLossPercent.asPercentage()).font(.ftCaption)
                }
                .foregroundStyle(holding.isProfit ? FTColor.income : FTColor.expense)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GoldHoldingRow: View {
    let holding: GoldHolding
    let baseCurrency: String
    @Environment(CurrencyService.self) private var currencyService

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: holding.metal.icon, tint: Color.fromString(holding.metal.color))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(holding.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    if holding.form != .other {
                        Text("· \(holding.form.rawValue)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Text("\(String(format: "%.2f", holding.weightGrams))g \(holding.metal.rawValue)")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(holding.currentValue.formatted(as: holding.currency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                HStack(spacing: 2) {
                    Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right").font(.ftCaption)
                    Text(holding.profitLossPercent.asPercentage()).font(.ftCaption)
                }
                .foregroundStyle(holding.isProfit ? FTColor.income : FTColor.expense)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GiftCardRow: View {
    let card: GiftCard
    let baseCurrency: String
    @Environment(CurrencyService.self) private var currencyService

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "gift.fill", tint: Color.fromString(card.color))
            VStack(alignment: .leading, spacing: 2) {
                Text(card.merchant).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                HStack(spacing: 4) {
                    if card.isExpiringSoon {
                        Text("Expires soon").font(.ftCaption).foregroundStyle(FTColor.expense)
                    } else if let expiry = card.expiryDate {
                        Text(expiry.formatted(date: .abbreviated, time: .omitted))
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    } else {
                        Text("No expiry").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(card.balance.formatted(as: card.currency))
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("\(Int((1 - card.usagePercent) * 100))% remaining")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct LoyaltyProgramRow: View {
    let program: LoyaltyProgram
    let baseCurrency: String
    @Environment(CurrencyService.self) private var currencyService

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: program.programType.icon, tint: Color.fromString(program.color))
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                HStack(spacing: 4) {
                    Text(program.programType == .other ? (program.customProgramName ?? program.programType.rawValue) : program.programType.rawValue)
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    if let tier = program.tier, !tier.isEmpty {
                        Text("· \(tier)").font(.ftCaption).foregroundStyle(FTColor.gold)
                    }
                    if program.isExpiringSoon {
                        Text("· Expiring").font(.ftCaption).foregroundStyle(FTColor.expense)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(program.points).formatted()) \(program.programType.pointsLabel)")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("≈ \(program.estimatedValue.formatted(as: program.currency))")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct LazyView<Content: View>: View {
    let build: () -> Content
    var body: some View { build() }
}
