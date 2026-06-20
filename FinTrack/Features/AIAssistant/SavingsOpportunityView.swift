import SwiftUI
import SwiftData

struct SavingsOpportunityView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]

    @State private var opportunities: [SavingsOpportunity] = []
    @State private var selectedPriority: SavingsOpportunity.Priority? = nil
    @State private var dismissedIDs: Set<UUID> = []

    private var filtered: [SavingsOpportunity] {
        let base = opportunities.filter { !dismissedIDs.contains($0.id) }
        guard let p = selectedPriority else { return base }
        return base.filter { $0.priority == p }
    }

    private var totalPotential: Double {
        opportunities.filter { !dismissedIDs.contains($0.id) }.reduce(0) { $0 + $1.potentialMonthly }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    savingsPotentialCard
                    filterRow
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        opportunityList
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 32)
            }
            .navigationTitle("Savings Opportunities")
            .background { FTBackdrop() }
            .onAppear { compute() }
        }
    }

    // MARK: - Potential Card

    private var savingsPotentialCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("POTENTIAL MONTHLY SAVINGS")
                        .font(.ftLabel)
                        .tracking(1.6)
                        .foregroundStyle(FTColor.textMuted)
                    Text(totalPotential.formatted(as: appState.baseCurrency))
                        .font(.ftAmount)
                        .foregroundStyle(FTColor.income)
                    Text(String(format: "%.0f/year if all opportunities captured", totalPotential * 12))
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                FTIconTile(symbol: "sparkles", tint: FTColor.income, size: 42)
            }

            FTProgressBar(
                value: min(totalPotential / max(totalPotential + 1000, 1), 1),
                color: FTColor.income
            )
            .frame(height: 6)
        }
        .padding()
        .background(FTColor.income.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: FTRadius.xl).stroke(FTColor.income.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Filters

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FilterChip(title: "All", isSelected: selectedPriority == nil) { selectedPriority = nil }
                FilterChip(title: "High", isSelected: selectedPriority == .high) { selectedPriority = .high }
                FilterChip(title: "Medium", isSelected: selectedPriority == .medium) { selectedPriority = .medium }
                FilterChip(title: "Low", isSelected: selectedPriority == .low) { selectedPriority = .low }
            }
        }
    }

    // MARK: - Opportunity List

    private var opportunityList: some View {
        VStack(spacing: FTSpacing.md) {
            ForEach(filtered) { opp in
                opportunityCard(opp)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
    }

    private func opportunityCard(_ opp: SavingsOpportunity) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    Circle()
                        .fill(opp.priority.color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: opp.icon)
                        .font(.ftHeadline)
                        .foregroundStyle(opp.priority.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(opp.title)
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                        Spacer()
                        priorityTag(opp.priority)
                    }
                    if let cat = opp.category {
                        Text(cat.rawValue)
                            .font(.ftCaption)
                            .foregroundStyle(Color.fromString(cat.color))
                    }
                }
            }

            Text(opp.description)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Potential Saving")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                    Text(opp.potentialMonthly.formatted(as: appState.baseCurrency) + "/mo")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.income)
                }
                Spacer()
                Button {
                    withAnimation(.spring) { _ = dismissedIDs.insert(opp.id) }
                } label: {
                    Text("Dismiss")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                        .padding(.horizontal, FTSpacing.md)
                        .padding(.vertical, FTSpacing.sm)
                        .background(FTColor.textMuted.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.pill))
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private func priorityTag(_ p: SavingsOpportunity.Priority) -> some View {
        Text(p.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(p.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(p.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(FTColor.income)
            Text("No Opportunities Found")
                .font(.ftHeadline)
                .foregroundStyle(FTColor.textPrimary)
            Text("Your spending looks optimized. Add more transaction history for deeper analysis.")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FTSpacing.xxl)
        }
        .padding(.top, 40)
    }

    // MARK: - Compute

    private func compute() {
        opportunities = AIAnalyticsService.shared.findSavingsOpportunities(
            transactions: transactions, bills: bills, currency: appState.baseCurrency
        )
    }
}
