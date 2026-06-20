//
//  FTSampleScreens.swift
//  FinTrack Pro — reference implementations
//
//  Shows how the design system composes into screens. Build the remaining
//  screens (Add Transaction, Account Overview, Analytics, Budgets,
//  Investments, Transactions, Settings) the same way, following DESIGN_SPEC.md.
//
//  These use placeholder/mock data. Wire them to your SwiftData @Query models.
//

import SwiftUI

// MARK: - Root scaffold

struct FTRootView: View {
    @State private var tab = 0
    @State private var showAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // iOS 26 TabView gets Liquid Glass automatically, but we use a
            // custom floating bar to match the design (raised center FAB).
            Group {
                switch tab {
                case 0: FTDashboardView()
                case 1: Text("Account Overview")     // -> FTAccountOverviewView()
                case 2: Text("Analytics")            // -> FTAnalyticsView()
                default: Text("Settings")            // -> FTSettingsView()
                }
            }
            FTGlassTabBar(selection: $tab) { showAdd = true }
        }
        .sheet(isPresented: $showAdd) {
            Text("Add Transaction")                  // -> FTAddTransactionView()
                .presentationDetents([.large])
        }
    }
}

// MARK: - Dashboard (reference build)

struct FTDashboardView: View {
    var body: some View {
        ZStack {
            FTBackdrop()
            ScrollView {
                VStack(spacing: FTSpacing.lg) {
                    header
                    netWorthHero
                    accountsRow
                    spendingCard
                    recentSection
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 120)   // clear the floating tab bar
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Good morning,").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text("Mohammad").font(.ftTitle).foregroundStyle(FTColor.textPrimary)
            }
            Spacer()
            Image(systemName: "bell")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(FTColor.textPrimary)
                .frame(width: 44, height: 44)
                .ftGlass(FTRadius.md)
        }
    }

    private var netWorthHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TOTAL NET WORTH")
                .font(.ftLabel).tracking(1.6).foregroundStyle(.white.opacity(0.8))
            Text("AED 248,560").font(.ftDisplay).foregroundStyle(.white)
            HStack(spacing: 10) {
                Text("↑ 2.4%").font(.ftCaption.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: .capsule)
                Text("+AED 5,840 this month").font(.ftCaption).foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(FTSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
        .shadow(color: Color(hex: 0x0A6E7E).opacity(0.35), radius: 30, y: 14)
    }

    private var accountsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.md) {
                accountCard("building.columns.fill", FTColor.catBlue, "Emirates NBD", "AED 84,200")
                accountCard("banknote.fill", FTColor.catTeal, "Cash", "AED 12,400")
                accountCard("circle.hexagongrid.fill", FTColor.catGold, "Gold · 142g", "AED 31,960")
            }
        }
    }

    private func accountCard(_ symbol: String, _ tint: Color, _ name: String, _ balance: String) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            FTIconTile(symbol: symbol, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(balance).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            }
        }
        .padding(15)
        .frame(width: 150, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Text("Spending this month").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Text("View all").font(.ftCallout).foregroundStyle(FTColor.accent)
            }
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(FTColor.textPrimary.opacity(0.07), lineWidth: 13)
                    Circle().trim(from: 0, to: 0.64)
                        .stroke(FTColor.accent, style: .init(lineWidth: 13, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("64%").font(.system(size: 23, weight: .heavy))
                        Text("of budget").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                .frame(width: 108, height: 108)

                VStack(spacing: 11) {
                    legendRow(FTColor.accent, "Food & Dining", "AED 1,840")
                    legendRow(FTColor.catBlue, "Shopping", "AED 2,310")
                    legendRow(FTColor.gold, "Bills", "AED 1,420")
                    legendRow(FTColor.catCoral, "Transport", "AED 850")
                }
            }
        }
        .padding(18)
        .ftGlass(FTRadius.xl)
    }

    private func legendRow(_ color: Color, _ name: String, _ amount: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(name).font(.ftCaption.weight(.medium)).foregroundStyle(FTColor.textPrimary)
            Spacer()
            Text(amount).font(.ftCaption.weight(.semibold)).foregroundStyle(FTColor.textPrimary)
        }
    }

    private var recentSection: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                Text("Recent Transactions").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Text("See all").font(.ftCallout).foregroundStyle(FTColor.accent)
            }
            FTCard(padding: FTSpacing.lg) {
                VStack(spacing: 0) {
                    FTTransactionRow(symbol: "cart.fill", tint: FTColor.catBlue,
                                     title: "Carrefour", subtitle: "Groceries · Today",
                                     amount: "−AED 184.50")
                    Divider().opacity(0.4)
                    FTTransactionRow(symbol: "fork.knife", tint: FTColor.catCoral,
                                     title: "Salt Bae", subtitle: "Dining · Yesterday",
                                     amount: "−AED 420.00")
                    Divider().opacity(0.4)
                    FTTransactionRow(symbol: "building.columns.fill", tint: FTColor.catTeal,
                                     title: "Salary", subtitle: "Income · 1 Nov",
                                     amount: "+AED 22,000", amountColor: FTColor.income)
                }
            }
        }
    }
}

#Preview { FTRootView() }
