import SwiftUI
import SwiftData

struct EstatePlanningView: View {
    @Environment(AppState.self) private var appState
    @Query private var accounts: [Account]
    @Query private var realEstateProps: [RealEstateProperty]
    @Query private var vehicles: [Vehicle]
    @Query private var personalAssets: [PersonalAsset]
    @Query private var investments: [Investment]
    @Query private var cryptoHoldings: [CryptoHolding]
    @Query private var goldHoldings: [GoldHolding]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]
    @Query private var profiles: [UserProfile]
    @Query private var moneyLent: [MoneyLent]

    private var currency: String { appState.baseCurrency }
    private var profile: UserProfile? { profiles.first }

    private var totalAssets: Double {
        let cash = accounts.reduce(0) { $0 + $1.balance }
        let reEstate = realEstateProps.reduce(0) { $0 + $1.currentValue }
        let veh = vehicles.reduce(0) { $0 + $1.currentValue }
        let personal = personalAssets.reduce(0) { $0 + $1.currentValue }
        let inv = investments.reduce(0) { $0 + $1.currentValue }
        let crypto = cryptoHoldings.reduce(0) { $0 + $1.currentValue }
        let gold = goldHoldings.reduce(0) { $0 + $1.currentValue }
        let lent = moneyLent.filter { !$0.isFullyRepaid }.reduce(0) { $0 + $1.remainingBalance }
        return cash + reEstate + veh + personal + inv + crypto + gold + lent
    }

    private var totalLiabilities: Double {
        let loanBal = loans.reduce(0) { $0 + $1.outstandingBalance }
        let ccBal = creditCards.reduce(0) { $0 + $1.outstandingBalance }
        return loanBal + ccBal
    }

    private var netEstate: Double { totalAssets - totalLiabilities }

    private var zakatableWealth: Double {
        let cash = accounts.reduce(0) { $0 + $1.balance }
        let inv = investments.reduce(0) { $0 + $1.currentValue }
        let crypto = cryptoHoldings.reduce(0) { $0 + $1.currentValue }
        let gold = goldHoldings.reduce(0) { $0 + $1.currentValue }
        return max(0, cash + inv + crypto + gold - totalLiabilities)
    }

    private let nisabAED: Double = 7200

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                summaryCard
                assetBreakdownCard
                liabilitiesCard
                zakatCard
                distributionCard
                checklist
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Estate Planning")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Cards

    private var summaryCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Estate Value")
                        .font(.ftLabel)
                        .foregroundStyle(FTColor.textSecondary)
                        .tracking(1.2)
                    Text(netEstate.formatted(as: currency))
                        .font(.ftDisplay)
                        .foregroundStyle(netEstate >= 0 ? FTColor.textPrimary : FTColor.expense)
                }
                Spacer()
                FTIconTile(symbol: "scroll.fill", tint: FTColor.gold, size: 48)
            }

            HStack(spacing: 0) {
                estateStat("Total Assets", totalAssets.asCompact(currency: currency), FTColor.income)
                Spacer()
                Divider().frame(height: 40)
                Spacer()
                estateStat("Liabilities", totalLiabilities.asCompact(currency: currency), FTColor.expense)
                Spacer()
                Divider().frame(height: 40)
                Spacer()
                estateStat("Net", netEstate.asCompact(currency: currency), netEstate >= 0 ? FTColor.accent : FTColor.expense)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var assetBreakdownCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Asset Breakdown").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            let items: [(String, String, Double, Color)] = [
                ("Cash & Accounts", "dollarsign.circle.fill",
                 accounts.reduce(0) { $0 + $1.balance }, FTColor.accent),
                ("Real Estate", "house.fill",
                 realEstateProps.reduce(0) { $0 + $1.currentValue }, FTColor.catTeal),
                ("Vehicles", "car.fill",
                 vehicles.reduce(0) { $0 + $1.currentValue }, FTColor.catBlue),
                ("Investments", "chart.line.uptrend.xyaxis",
                 investments.reduce(0) { $0 + $1.currentValue }, FTColor.income),
                ("Crypto", "bitcoinsign.circle.fill",
                 cryptoHoldings.reduce(0) { $0 + $1.currentValue }, FTColor.catCoral),
                ("Gold", "circle.fill",
                 goldHoldings.reduce(0) { $0 + $1.currentValue }, FTColor.gold),
                ("Personal Assets", "bag.fill",
                 personalAssets.reduce(0) { $0 + $1.currentValue }, FTColor.catPurple),
            ].filter { $0.2 > 0 }

            ForEach(items, id: \.0) { name, icon, amount, color in
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: icon, tint: color, size: 34)
                    Text(name).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(amount.formatted(as: currency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text(totalAssets > 0 ? (amount / totalAssets).asPercentage() : "—")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var liabilitiesCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Liabilities").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            if loans.isEmpty && creditCards.isEmpty {
                Text("No liabilities recorded.").font(.ftBody).foregroundStyle(FTColor.textMuted)
            } else {
                ForEach(loans) { loan in
                    HStack {
                        FTIconTile(symbol: "banknote.fill", tint: FTColor.expense, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loan.lenderName).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            Text(loan.loanType.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                        Text(loan.outstandingBalance.formatted(as: loan.currency))
                            .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                    }
                }
                ForEach(creditCards) { card in
                    HStack {
                        FTIconTile(symbol: "creditcard.fill", tint: FTColor.catCoral, size: 34)
                        Text(card.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Spacer()
                        Text(card.currentBalance.formatted(as: card.currency))
                            .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                    }
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var zakatCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                FTIconTile(symbol: "moon.stars.fill", tint: FTColor.gold, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zakat Estimate").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text("2.5% of zakatable wealth above nisab").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
            }

            if zakatableWealth >= nisabAED {
                let zakat = zakatableWealth * 0.025
                HStack {
                    Text("Zakatable Wealth")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(zakatableWealth.formatted(as: currency))
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                }
                HStack {
                    Text("Zakat Due (2.5%)")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(zakat.formatted(as: currency))
                        .font(.ftHeadline).foregroundStyle(FTColor.gold)
                }
            } else {
                Text("Below nisab threshold (\(nisabAED.formatted(as: currency))). No Zakat due.")
                    .font(.ftBody).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("UAE Inheritance Notes").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("For Muslims, UAE distributes estate per Islamic Sharia (Faraid) law. Non-Muslims may register a DIFC Will to apply home country law. Key steps:")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .lineSpacing(4)

            ForEach([
                "Register a DIFC Will (non-Muslims) or Wasiya (Muslims) at Dubai Courts",
                "Designate beneficiaries on UAE bank accounts",
                "DEWA/utility accounts in next-of-kin name upon death",
                "Life insurance policy: ensure beneficiary up to date",
                "Guardianship of minor children — specify in registered will",
            ], id: \.self) { item in
                HStack(alignment: .top, spacing: FTSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FTColor.accent)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(item)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Estate Readiness Checklist").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            let items: [(String, Bool)] = [
                ("Will or Wasiya registered", false),
                ("Life insurance in place", !investments.isEmpty),
                ("Emergency fund ≥ 6 months", accounts.reduce(0) { $0 + $1.balance } > 0),
                ("Beneficiaries designated", false),
                ("Digital assets documented", !cryptoHoldings.isEmpty),
                ("Debt manageable (<30% of assets)", totalLiabilities < totalAssets * 0.3),
            ]

            ForEach(items, id: \.0) { title, done in
                HStack(spacing: FTSpacing.md) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done ? FTColor.income : FTColor.textMuted)
                    Text(title)
                        .font(.ftBody)
                        .foregroundStyle(done ? FTColor.textPrimary : FTColor.textSecondary)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private func estateStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
    }
}
