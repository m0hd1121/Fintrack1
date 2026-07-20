import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var creditCards: [CreditCard]
    @Query private var investments: [Investment]
    @Query private var cryptoHoldings: [CryptoHolding]
    @Query private var goldHoldings: [GoldHolding]
    @Query private var giftCards: [GiftCard]
    @Query private var loyaltyPrograms: [LoyaltyProgram]
    @Query private var loans: [Loan]
    @Query private var bnplPlans: [BNPLPlan]
    @Query private var moneyBorrowed: [MoneyBorrowed]
    @Query private var moneyLent: [MoneyLent]
    @Query private var transactions: [Transaction]
    @Query private var netWorthMilestones: [NetWorthMilestone]
    @Query(filter: #Predicate<SalaryRecord> { $0.isActive }) private var salaryRecords: [SalaryRecord]
    @Query(filter: #Predicate<FreelanceProject> { $0.isArchived == false }) private var freelanceProjects: [FreelanceProject]
    @Query(filter: #Predicate<RentalProperty> { $0.isActive }) private var rentalProperties: [RentalProperty]
    @Query(filter: #Predicate<SavingsGoal> { $0.isArchived == false && $0.isCompleted == false }) private var activeGoals: [SavingsGoal]
    @Query(filter: #Predicate<RealEstateProperty> { $0.isArchived == false }) private var realEstateProperties: [RealEstateProperty]
    @Query(filter: #Predicate<Vehicle> { $0.isArchived == false }) private var vehicles: [Vehicle]
    @Query(filter: #Predicate<PersonalAsset> { $0.isArchived == false }) private var personalAssets: [PersonalAsset]
    @Query(filter: #Predicate<DigitalAsset> { $0.isArchived == false }) private var digitalAssets: [DigitalAsset]

    @State private var tab = 0
    @State private var showingAddAccount = false
    @State private var showingAddCreditCard = false
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

    // Module destinations (relocated from Dashboard)
    @State private var showingIncome = false
    @State private var showingPortfolio = false
    @State private var showingGoals = false
    @State private var showingAssetsLiabilities = false
    @State private var showingDebt = false
    @State private var showingNetWorth = false
    @State private var showingNotifications = false

    private let tabs = ["Accounts", "Investments", "Crypto", "Assets"]
    private var baseCurrency: String { appState.baseCurrency }

    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }
    private var visibleAccounts: [Account] { activeAccounts.filter { !$0.isHidden } }
    private var activeCreditCards: [CreditCard] { creditCards.filter { $0.isActive } }
    private var activeGoldHoldings: [GoldHolding] { goldHoldings.filter { !$0.isArchived } }
    private var activeGiftCards: [GiftCard] { giftCards.filter { !$0.isUsedUp } }
    private var activeLoyaltyPrograms: [LoyaltyProgram] { loyaltyPrograms.filter { !$0.isExpired } }
    private var activeLoans: [Loan] { loans.filter { $0.isActive } }
    private var activeBNPL: [BNPLPlan] { bnplPlans.filter { !$0.isCompleted } }
    private var activeBorrowed: [MoneyBorrowed] { moneyBorrowed.filter { $0.computedStatus != .repaid && $0.computedStatus != .writtenOff } }

    private var totalBalance: Double {
        visibleAccounts.reduce(0) {
            $0 + currencyService.convert($1.balance, from: $1.currency, to: baseCurrency)
        }
    }

    private var totalDebt: Double {
        let creditCardDebt = activeCreditCards
            .reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency) }
        let loanDebt = activeLoans
            .reduce(0) { $0 + currencyService.convert($1.outstandingBalance, from: $1.currency, to: baseCurrency) }
        let bnplDebt = activeBNPL
            .reduce(0) { $0 + currencyService.convert($1.remainingAmount, from: $1.currency, to: baseCurrency) }
        let borrowedDebt = activeBorrowed
            .reduce(0) { $0 + currencyService.convert($1.remainingBalance, from: $1.currency, to: baseCurrency) }
        return creditCardDebt + loanDebt + bnplDebt + borrowedDebt
    }

    private var investmentValue: Double {
        let stocks = investments.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        let crypto = cryptoHoldings.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        let gold = activeGoldHoldings.reduce(0) {
            $0 + currencyService.convert($1.currentValue, from: $1.currency, to: baseCurrency)
        }
        return stocks + crypto + gold
    }

    private var giftCardValue: Double {
        activeGiftCards.filter { !$0.isExpired }.reduce(0) {
            $0 + currencyService.convert($1.balance, from: $1.currency, to: baseCurrency)
        }
    }

    private var loyaltyValue: Double {
        activeLoyaltyPrograms.reduce(0) {
            $0 + currencyService.convert($1.estimatedValue, from: $1.currency, to: baseCurrency)
        }
    }

    private var netWorth: Double { totalBalance + investmentValue + giftCardValue - totalDebt }

    // MARK: Module metrics (relocated from DashboardView)

    private var activeIncomeStreams: Int {
        (salaryRecords.isEmpty ? 0 : 1) + (freelanceProjects.isEmpty ? 0 : 1) + (rentalProperties.isEmpty ? 0 : 1)
    }
    private var monthlyIncome: Double {
        transactions
            .filter { $0.type == .income && !$0.isPending && !$0.isScheduled && $0.date.isSameMonth(as: Date()) }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }
    private var overdueIncomeCount: Int {
        freelanceProjects.flatMap { $0.overdueInvoices }.count + rentalProperties.flatMap { $0.overduePayments }.count
    }

    private var portfolioTotalValue: Double {
        InvestmentService.shared.totalValue(
            investments: investments, cryptos: cryptoHoldings, golds: goldHoldings,
            currencyService: currencyService, baseCurrency: baseCurrency)
    }
    private var portfolioPnL: Double {
        InvestmentService.shared.unrealizedPnL(
            investments: investments, cryptos: cryptoHoldings, golds: goldHoldings,
            currencyService: currencyService, baseCurrency: baseCurrency)
    }
    private var portfolioAssetCount: Int {
        investments.count + cryptoHoldings.count + activeGoldHoldings.count
    }

    private var goalConflict: SavingsGoalService.GoalConflict {
        SavingsGoalService.shared.analyzeConflicts(
            goals: activeGoals, transactions: transactions, currencyService: currencyService, base: baseCurrency)
    }
    private var goalsSaved: Double {
        activeGoals.reduce(0) { $0 + currencyService.convert($1.currentAmount, from: $1.currency, to: baseCurrency) }
    }
    private var goalsTarget: Double {
        activeGoals.reduce(0) { $0 + currencyService.convert($1.targetAmount, from: $1.currency, to: baseCurrency) }
    }
    private var goalsProgress: Double { goalsTarget > 0 ? min(goalsSaved / goalsTarget, 1.0) : 0 }

    private var hardAssetsTotal: Double {
        let svc = NetWorthService.shared
        return svc.realEstateTotal(realEstate: realEstateProperties, currencyService: currencyService, base: baseCurrency)
            + svc.vehicleTotal(vehicles: vehicles, currencyService: currencyService, base: baseCurrency)
            + svc.personalAssetTotal(assets: personalAssets, currencyService: currencyService, base: baseCurrency)
            + svc.digitalAssetTotal(assets: digitalAssets, currencyService: currencyService, base: baseCurrency)
    }
    private var hardAssetsCount: Int {
        realEstateProperties.count + vehicles.count + personalAssets.count + digitalAssets.count
    }

    private var debtCount: Int { activeLoans.count + activeCreditCards.count }
    private var debtOverdueCount: Int {
        let overdueLoans = activeLoans.filter { $0.nextPaymentDate < Date() }.count
        let overdueLent = moneyLent.filter { !$0.isFullyRepaid && ($0.dueDate ?? .distantFuture) < Date() }.count
        return overdueLoans + overdueLent
    }

    private var unacknowledgedMilestones: [NetWorthMilestone] {
        netWorthMilestones.filter { !$0.isAcknowledged }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        header
                        netWorthHero
                        moduleGrid

                        VStack(spacing: FTSpacing.md) {
                            FTSegmentedControl(options: tabs, selection: .init(
                                get: { tab },
                                set: { newValue in withAnimation(.snappy(duration: 0.25)) { tab = newValue } }
                            ))

                            HStack(alignment: .lastTextBaseline) {
                                Text(currentTabTitle.uppercased())
                                    .font(.ftLabel).tracking(1.4)
                                    .foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                if !currentTabCountLabel.isEmpty {
                                    Text(currentTabCountLabel)
                                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                }
                            }

                            tabContent
                            addButtonForTab
                        }
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                    .padding(.bottom, 120)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddAccount) { AddAccountView() }
            .sheet(isPresented: $showingAddCreditCard) { AddCreditCardView() }
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
            .sheet(isPresented: $showingIncome) { IncomeManagementView() }
            .sheet(isPresented: $showingPortfolio) { InvestmentPortfolioView() }
            .sheet(isPresented: $showingGoals) { SavingsGoalsView() }
            .sheet(isPresented: $showingAssetsLiabilities) { AssetsLiabilitiesView() }
            .sheet(isPresented: $showingDebt) { DebtManagementView() }
            .sheet(isPresented: $showingNetWorth) { NetWorthDashboardView() }
            .sheet(isPresented: $showingNotifications) { NotificationSettingsView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Accounts & Assets")
                .font(.ftTitle)
                .foregroundStyle(FTColor.textPrimary)
            Spacer()
            Button { showingNotifications = true } label: {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FTColor.accent)
                    .frame(width: 44, height: 44)
                    .ftGlass(FTRadius.md)
            }
            .accessibilityLabel("Notification Settings")
        }
    }

    // MARK: - Net Worth Hero

    private var netWorthHero: some View {
        let isNegative = netWorth < 0

        return Button { showingNetWorth = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("TOTAL NET WORTH")
                        .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if !unacknowledgedMilestones.isEmpty {
                        Text("🎉 \(unacknowledgedMilestones.count)")
                            .font(.ftCaption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(.white.opacity(0.22), in: .capsule)
                    }
                }

                Text(netWorth.formatted(as: baseCurrency))
                    .font(.ftDisplay).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)

                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: isNegative ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(isNegative ? "Liabilities exceed assets" : "Assets exceed liabilities")
                            .font(.ftCaption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.18), in: .capsule)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("View breakdown").font(.ftCaption)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(FTSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
            .contentShape(.rect(cornerRadius: FTRadius.xl))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total Net Worth, \(netWorth.formatted(as: baseCurrency))")
    }

    // MARK: - Module Grid

    private struct ModuleCardData {
        let icon: String
        let tint: Color
        let label: String
        let value: String
        let valueColor: Color
        let sub: String
        let wide: Bool
        let badge: Bool
        let action: () -> Void
    }

    private var moduleCards: [ModuleCardData] {
        let incomeAlert = overdueIncomeCount > 0
        let incomeSub = incomeAlert
            ? "\(overdueIncomeCount) overdue"
            : activeIncomeStreams > 0
                ? "\(activeIncomeStreams) active stream\(activeIncomeStreams == 1 ? "" : "s")"
                : "Track salary, freelance & rental"

        let isGain = portfolioPnL >= 0
        let portfolioSub = portfolioAssetCount > 0
            ? "\(portfolioAssetCount) holding\(portfolioAssetCount == 1 ? "" : "s") · \(isGain ? "+" : "")\(portfolioPnL.asCompact(currency: baseCurrency))"
            : "Track stocks, crypto & gold"

        let goalsSub = activeGoals.isEmpty
            ? "Set savings goals"
            : "\(activeGoals.count) goal\(activeGoals.count == 1 ? "" : "s") · \(Int(goalsProgress * 100))% funded"

        let assetsSub = hardAssetsCount > 0
            ? "\(hardAssetsCount) asset\(hardAssetsCount == 1 ? "" : "s")"
            : "Real estate, vehicles & valuables"

        let debtAlert = debtOverdueCount > 0
        let debtSub = debtAlert
            ? "\(debtOverdueCount) overdue"
            : debtCount > 0
                ? "\(debtCount) active debt\(debtCount == 1 ? "" : "s")"
                : "Loans, cards & personal debts"

        return [
            ModuleCardData(
                icon: incomeAlert ? "exclamationmark.triangle.fill" : "arrow.down.left.circle.fill",
                tint: incomeAlert ? FTColor.expense : FTColor.income,
                label: "Income Management",
                value: monthlyIncome.asCompact(currency: baseCurrency),
                valueColor: FTColor.textPrimary, sub: incomeSub, wide: false, badge: false,
                action: { showingIncome = true }
            ),
            ModuleCardData(
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                tint: isGain ? FTColor.income : FTColor.expense,
                label: "Investment Portfolio",
                value: portfolioTotalValue.asCompact(currency: baseCurrency),
                valueColor: FTColor.textPrimary, sub: portfolioSub, wide: false, badge: false,
                action: { showingPortfolio = true }
            ),
            ModuleCardData(
                icon: "star.fill", tint: FTColor.catTeal,
                label: "Savings Goals",
                value: goalsSaved.asCompact(currency: baseCurrency),
                valueColor: FTColor.textPrimary, sub: goalsSub, wide: false, badge: goalConflict.hasConflict,
                action: { showingGoals = true }
            ),
            ModuleCardData(
                icon: "building.columns.fill", tint: FTColor.catBlue,
                label: "Assets & Liabilities",
                value: hardAssetsTotal.asCompact(currency: baseCurrency),
                valueColor: FTColor.textPrimary, sub: assetsSub, wide: false, badge: false,
                action: { showingAssetsLiabilities = true }
            ),
            ModuleCardData(
                icon: debtAlert ? "creditcard.trianglebadge.exclamationmark" : "creditcard.fill",
                tint: FTColor.expense,
                label: "Debt Management",
                value: totalDebt.asCompact(currency: baseCurrency),
                valueColor: FTColor.textPrimary, sub: debtSub, wide: true, badge: false,
                action: { showingDebt = true }
            ),
        ]
    }

    // LazyVGrid's `.gridCellColumns` only works inside the newer `Grid` container, not
    // `LazyVGrid` — so the "wide" (Debt Management) card is rendered full-width below
    // the 2-column grid instead, rather than relying on a modifier that would silently
    // no-op here.
    private var moduleGrid: some View {
        let regular = moduleCards.filter { !$0.wide }
        let wide = moduleCards.first { $0.wide }

        return VStack(spacing: FTSpacing.sm) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: FTSpacing.sm), GridItem(.flexible(), spacing: FTSpacing.sm)], spacing: FTSpacing.sm) {
                ForEach(regular.indices, id: \.self) { i in
                    moduleCardView(regular[i])
                }
            }
            if let wide {
                moduleCardView(wide)
            }
        }
    }

    private func moduleCardView(_ m: ModuleCardData) -> some View {
        Button(action: m.action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    FTIconTile(symbol: m.icon, tint: m.tint, size: 38)
                    Spacer()
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FTColor.textMuted)
                        if m.badge {
                            Circle().fill(FTColor.gold).frame(width: 8, height: 8).offset(x: 6, y: -6)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.label)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(FTColor.textSecondary)
                        .lineLimit(1)
                    Text(m.value)
                        .font(.ftHeadline)
                        .foregroundStyle(m.valueColor)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(m.sub)
                        .font(.ftLabel)
                        .foregroundStyle(FTColor.textMuted)
                        .lineLimit(1)
                }
            }
            .padding(FTSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ftGlassInteractive(FTRadius.lg)
            .contentShape(.rect(cornerRadius: FTRadius.lg))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab list

    private var currentTabTitle: String {
        switch tab {
        case 0:  return "Bank & Cash Accounts"
        case 1:  return "Investments"
        case 2:  return "Crypto Assets"
        default: return "Other Assets"
        }
    }

    private var currentTabItemCount: Int {
        switch tab {
        case 0:  return visibleAccounts.count + activeCreditCards.count
        case 1:  return investments.count
        case 2:  return cryptoHoldings.count
        default: return activeGoldHoldings.count + activeGiftCards.count + activeLoyaltyPrograms.count
        }
    }

    private var currentTabCountLabel: String {
        guard currentTabItemCount > 0 else { return "" }
        return "\(currentTabItemCount) \(tab == 2 ? "coins" : "items")"
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case 0:  accountsTabContent
        case 1:  investmentsTabContent
        case 2:  cryptoTabContent
        default: assetsTabContent
        }
    }

    private func rowCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(FTSpacing.md)
            .ftGlassInteractive(FTRadius.lg)
    }

    private var accountsTabContent: some View {
        Group {
            if visibleAccounts.isEmpty && activeCreditCards.isEmpty {
                EmptyStateView(icon: "building.columns", title: "No Accounts Yet",
                               message: "Add a bank, cash wallet, or credit card to start tracking your money.")
                    .ftGlass(FTRadius.lg)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(visibleAccounts) { account in
                        rowCard { AccountRow(account: account, baseCurrency: baseCurrency) }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedAccount = account }
                            .contextMenu {
                                Button { selectedAccount = account } label: { Label("View", systemImage: "eye") }
                                Button(role: .destructive) {
                                    context.delete(account); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                                Button {
                                    account.isArchived = true; try? context.save()
                                } label: { Label("Archive", systemImage: "archivebox") }
                            }
                    }
                    ForEach(activeCreditCards) { card in
                        rowCard { CreditCardRow(card: card, baseCurrency: baseCurrency) }
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    context.delete(card); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }

    private var investmentsTabContent: some View {
        Group {
            if investments.isEmpty {
                EmptyStateView(icon: "chart.line.uptrend.xyaxis", title: "No Investments Yet",
                               message: "Add stocks, funds or other holdings to track performance.")
                    .ftGlass(FTRadius.lg)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(investments) { inv in
                        rowCard { InvestmentRow(investment: inv, baseCurrency: baseCurrency) }
                            .contentShape(Rectangle())
                            .onTapGesture { editingInvestment = inv }
                            .contextMenu {
                                Button { editingInvestment = inv } label: { Label("Edit", systemImage: "pencil") }
                                Button(role: .destructive) {
                                    context.delete(inv); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }

    private var cryptoTabContent: some View {
        Group {
            if cryptoHoldings.isEmpty {
                EmptyStateView(icon: "bitcoinsign.circle", title: "No Crypto Yet",
                               message: "Add a crypto holding to track its value.")
                    .ftGlass(FTRadius.lg)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(cryptoHoldings) { holding in
                        rowCard { CryptoRow(holding: holding, baseCurrency: baseCurrency) }
                            .contentShape(Rectangle())
                            .onTapGesture { editingCrypto = holding }
                            .contextMenu {
                                Button { editingCrypto = holding } label: { Label("Edit", systemImage: "pencil") }
                                Button(role: .destructive) {
                                    context.delete(holding); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }

    private var assetsTabContent: some View {
        Group {
            if activeGoldHoldings.isEmpty && activeGiftCards.isEmpty && activeLoyaltyPrograms.isEmpty {
                EmptyStateView(icon: "archivebox.fill", title: "No Other Assets Yet",
                               message: "Add gold, gift cards or loyalty points to track everything in one place.")
                    .ftGlass(FTRadius.lg)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(activeGoldHoldings) { holding in
                        rowCard { GoldHoldingRow(holding: holding, baseCurrency: baseCurrency) }
                            .contentShape(Rectangle())
                            .onTapGesture { editingGold = holding }
                            .contextMenu {
                                Button { editingGold = holding } label: { Label("Edit", systemImage: "pencil") }
                                Button {
                                    holding.isArchived = true; try? context.save()
                                } label: { Label("Archive", systemImage: "archivebox") }
                                Button(role: .destructive) {
                                    context.delete(holding); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                    ForEach(activeGiftCards) { card in
                        rowCard { GiftCardRow(card: card, baseCurrency: baseCurrency) }
                            .contentShape(Rectangle())
                            .onTapGesture { editingGiftCard = card }
                            .contextMenu {
                                Button { editingGiftCard = card } label: { Label("Edit", systemImage: "pencil") }
                                Button {
                                    card.isUsedUp = true; try? context.save()
                                } label: { Label("Mark Used", systemImage: "checkmark.circle") }
                                Button(role: .destructive) {
                                    context.delete(card); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                    ForEach(activeLoyaltyPrograms) { program in
                        rowCard { LoyaltyProgramRow(program: program, baseCurrency: baseCurrency) }
                            .contentShape(Rectangle())
                            .onTapGesture { editingLoyalty = program }
                            .contextMenu {
                                Button { editingLoyalty = program } label: { Label("Edit", systemImage: "pencil") }
                                Button(role: .destructive) {
                                    context.delete(program); try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Add button

    @ViewBuilder
    private var addButtonForTab: some View {
        switch tab {
        case 0:
            Menu {
                Button { showingAddAccount = true } label: {
                    Label("Bank / Cash Account", systemImage: "building.columns")
                }
                Button { showingAddCreditCard = true } label: {
                    Label("Credit Card", systemImage: "creditcard")
                }
            } label: { addRowLabel("Add Account") }
        case 1:
            Button { showingAddInvestment = true } label: { addRowLabel("Add Investment") }
        case 2:
            Button { showingAddCrypto = true } label: { addRowLabel("Add Crypto Asset") }
        default:
            Menu {
                Button { showingAddGold = true } label: {
                    Label("Precious Metal", systemImage: "circle.hexagongrid.fill")
                }
                Button { showingAddGiftCard = true } label: {
                    Label("Gift Card", systemImage: "gift")
                }
                Button { showingAddLoyalty = true } label: {
                    Label("Loyalty Program", systemImage: "star.circle")
                }
            } label: { addRowLabel("Add Asset") }
        }
    }

    private func addRowLabel(_ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill").font(.system(size: 20))
            Text(title).font(.ftBodySemibold)
        }
        .foregroundStyle(FTColor.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.md)
        .background(FTColor.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: FTRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: FTRadius.lg)
                .strokeBorder(FTColor.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }
}

// MARK: – Row views

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.name), credit card, outstanding \(card.outstandingBalance.formatted(as: card.currency)), \(Int(card.utilizationRate * 100)) percent utilized\(card.isPaymentDueSoon ? ", payment due soon" : "")")
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
                if program.totalPointsEarned > 0 || program.totalPointsRedeemed > 0 {
                    HStack(spacing: 6) {
                        if program.totalPointsEarned > 0 {
                            Label("\(Int(program.totalPointsEarned).formatted()) earned",
                                  systemImage: "arrow.down.circle.fill")
                                .font(.ftLabel).foregroundStyle(FTColor.income)
                        }
                        if program.totalPointsRedeemed > 0 {
                            Label("\(Int(program.totalPointsRedeemed).formatted()) redeemed",
                                  systemImage: "arrow.up.circle.fill")
                                .font(.ftLabel).foregroundStyle(FTColor.expense)
                        }
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
    }
}
