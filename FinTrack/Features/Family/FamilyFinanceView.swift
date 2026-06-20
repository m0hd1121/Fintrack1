import SwiftUI
import SwiftData

struct FamilyFinanceView: View {
    @Environment(AppState.self) private var appState
    @Query private var familyGroups: [FamilyGroup]
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]
    @Query private var sharedGoals: [SharedFamilyGoal]
    @Query private var children: [ChildProfile]

    @State private var showingSetup = false

    private var group: FamilyGroup? { familyGroups.first(where: { $0.isActive }) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    if let g = group {
                        familyHeroCard(g)
                        quickStatsRow(g)
                        featuresGrid(g)
                    } else {
                        welcomeCard
                    }
                    insightsSection
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .navigationTitle("Family Finance")
            .background { FTBackdrop() }
            .toolbar {
                if group != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: FamilySetupView(group: group)) {
                            Image(systemName: "gear").font(.ftCallout).foregroundStyle(FTColor.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSetup) {
                FamilySetupView(group: nil)
            }
        }
    }

    // MARK: - Welcome Card (no family)

    private var welcomeCard: some View {
        VStack(spacing: FTSpacing.xxl) {
            VStack(spacing: FTSpacing.lg) {
                ZStack {
                    Circle().fill(FTColor.heroGradient).frame(width: 80, height: 80)
                    Image(systemName: "person.3.fill").font(.ftTitle).foregroundStyle(.white)
                }
                Text("Family Finance").font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                Text("Manage household budgets, shared goals, partner finances, child allowances, and family permissions — all in one place.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, FTSpacing.lg)
            }

            VStack(spacing: FTSpacing.sm) {
                featurePill(icon: "person.2.fill", text: "Partner/Couple mode with shared overview")
                featurePill(icon: "figure.and.child.holdinghands", text: "Child allowance tracker with savings goals")
                featurePill(icon: "house.fill", text: "Household budget consolidation")
                featurePill(icon: "shield.fill", text: "Granular permission management")
                featurePill(icon: "star.fill", text: "Collaborative family savings goals")
            }

            Button { showingSetup = true } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Set Up Family Group")
                }
                .font(.ftBodySemibold).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .ftGlass(FTRadius.xl)
        .padding(.top, FTSpacing.xxl)
    }

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: icon).foregroundStyle(FTColor.accent).font(.ftCallout).frame(width: 24)
            Text(text).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, FTSpacing.lg).padding(.vertical, FTSpacing.sm)
    }

    // MARK: - Family Hero Card

    private func familyHeroCard(_ g: FamilyGroup) -> some View {
        HStack(spacing: FTSpacing.lg) {
            familyAvatarStack(g.members)
            VStack(alignment: .leading, spacing: 4) {
                Text(g.name).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("\(g.members.count) member\(g.members.count == 1 ? "" : "s")")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Text("Admin: \(g.adminName)").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func familyAvatarStack(_ members: [FamilyMemberData]) -> some View {
        HStack(spacing: -10) {
            ForEach(members.prefix(3)) { member in
                Text(member.initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color(hex: member.avatarColorHex))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.ultraThinMaterial, lineWidth: 2))
            }
            if members.count > 3 {
                Text("+\(members.count - 3)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FTColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(FTColor.textMuted.opacity(0.2))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.ultraThinMaterial, lineWidth: 2))
            }
        }
    }

    // MARK: - Quick Stats

    private func quickStatsRow(_ g: FamilyGroup) -> some View {
        let summary = FamilyService.shared.householdBudgetSummary(
            transactions: transactions, bills: bills, currency: appState.baseCurrency
        )
        return HStack(spacing: FTSpacing.sm) {
            familyStat(
                value: summary.totalMonthlyIncome.asCompact(currency: appState.baseCurrency),
                label: "Family Income", color: FTColor.income
            )
            familyStat(
                value: "\(sharedGoals.filter { !$0.isCompleted && !$0.isArchived }.count)",
                label: "Shared Goals", color: FTColor.catBlue
            )
            familyStat(
                value: "\(children.filter { $0.isActive }.count)",
                label: "Children", color: FTColor.gold
            )
        }
    }

    private func familyStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Features Grid

    private func featuresGrid(_ g: FamilyGroup) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("FAMILY TOOLS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.md) {
                familyFeatureCard(
                    icon: "person.2.fill", title: "Family Dashboard",
                    subtitle: "Shared financial overview",
                    color: FTColor.accent,
                    destination: AnyView(FamilyDashboardView(group: g))
                )
                familyFeatureCard(
                    icon: "house.fill", title: "Household Budget",
                    subtitle: "Consolidated spending view",
                    color: FTColor.catBlue,
                    destination: AnyView(HouseholdBudgetView())
                )
                familyFeatureCard(
                    icon: "figure.and.child.holdinghands", title: "Child Allowances",
                    subtitle: "Allowances & savings goals",
                    color: FTColor.gold,
                    badge: children.filter { $0.isAllowanceDue && $0.isActive }.count,
                    destination: AnyView(ChildAllowanceView())
                )
                familyFeatureCard(
                    icon: "star.fill", title: "Shared Goals",
                    subtitle: "Family savings targets",
                    color: FTColor.catTeal,
                    badge: sharedGoals.filter { !$0.isCompleted && !$0.isArchived }.count,
                    destination: AnyView(SharedFamilyGoalsView(group: g))
                )
                familyFeatureCard(
                    icon: "shield.fill", title: "Permissions",
                    subtitle: "Access control per member",
                    color: FTColor.catPurple,
                    destination: AnyView(FamilyPermissionsView(group: g))
                )
                familyFeatureCard(
                    icon: "person.badge.plus", title: "Members",
                    subtitle: "Add & manage family members",
                    color: FTColor.catCoral,
                    destination: AnyView(FamilySetupView(group: g))
                )
            }
        }
    }

    private func familyFeatureCard(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        badge: Int = 0,
        destination: AnyView
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: FTRadius.sm)
                            .fill(color.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: icon).font(.ftCallout).foregroundStyle(color)
                    }
                    Spacer()
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(color).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                Text(title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Insights

    private var insightsSection: some View {
        let summary = FamilyService.shared.householdBudgetSummary(
            transactions: transactions, bills: bills, currency: appState.baseCurrency
        )
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("HOUSEHOLD INSIGHTS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                if summary.savingsRate > 0 {
                    insightRow(
                        icon: "checkmark.circle.fill", color: FTColor.income,
                        text: "Household savings rate this month: \(summary.savingsRate.asPercentage())."
                    )
                }
                if summary.totalMonthlyBills > 0 {
                    insightRow(
                        icon: "info.circle.fill", color: FTColor.catBlue,
                        text: "Monthly recurring bills: \(summary.totalMonthlyBills.formatted(as: appState.baseCurrency))."
                    )
                }
                let dueChildren = children.filter { $0.isAllowanceDue && $0.isActive }
                if !dueChildren.isEmpty {
                    insightRow(
                        icon: "exclamationmark.circle.fill", color: FTColor.gold,
                        text: "Allowance due for: \(dueChildren.map { $0.name }.joined(separator: ", "))."
                    )
                }
                let nearGoals = sharedGoals.filter { $0.progress > 0.9 && !$0.isCompleted }
                if !nearGoals.isEmpty {
                    insightRow(
                        icon: "star.fill", color: FTColor.income,
                        text: "\(nearGoals.first!.name) is almost complete — \(nearGoals.first!.progress.asPercentage()) reached!"
                    )
                }
            }
        }
    }

    private func insightRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            Image(systemName: icon).foregroundStyle(color).font(.ftCallout)
            Text(text).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
    }
}
