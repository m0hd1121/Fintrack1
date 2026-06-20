import SwiftUI
import SwiftData

// Identifiers for each dashboard section. Must match DashboardView.isWidgetHidden(id:).
enum DashboardWidget: String, CaseIterable, Identifiable {
    case hero          = "hero"
    case metrics       = "metrics"
    case income        = "income"
    case budgets       = "budgets"
    case goals         = "goals"
    case debt          = "debt"
    case investments   = "investments"
    case bills         = "bills"
    case aiInsights    = "aiInsights"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hero:        return "Net Worth Summary"
        case .metrics:     return "Monthly Metrics"
        case .income:      return "Income Sources"
        case .budgets:     return "Budget Overview"
        case .goals:       return "Savings Goals"
        case .debt:        return "Debt & BNPL"
        case .investments: return "Portfolio"
        case .bills:       return "Upcoming Bills"
        case .aiInsights:  return "AI Insights"
        }
    }

    var icon: String {
        switch self {
        case .hero:        return "chart.line.uptrend.xyaxis"
        case .metrics:     return "arrow.left.arrow.right.circle.fill"
        case .income:      return "banknote.fill"
        case .budgets:     return "chart.pie.fill"
        case .goals:       return "star.fill"
        case .debt:        return "creditcard.fill"
        case .investments: return "chart.bar.fill"
        case .bills:       return "calendar.badge.clock"
        case .aiInsights:  return "brain.head.profile"
        }
    }

    var tint: Color {
        switch self {
        case .hero:        return FTColor.accent
        case .metrics:     return FTColor.income
        case .income:      return FTColor.gold
        case .budgets:     return FTColor.catPurple
        case .goals:       return FTColor.catCoral
        case .debt:        return FTColor.expense
        case .investments: return FTColor.catBlue
        case .bills:       return FTColor.catTeal
        case .aiInsights:  return FTColor.catPurple
        }
    }
}

struct DashboardCustomizerView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    private var setting: AppSettings? { settings.first }

    private var hiddenSet: Set<String> {
        Set((setting?.dashboardHiddenWidgets ?? "").split(separator: ",").map(String.init))
    }

    private func isHidden(_ widget: DashboardWidget) -> Bool {
        hiddenSet.contains(widget.rawValue)
    }

    private func toggle(_ widget: DashboardWidget) {
        guard let setting else { return }
        var current = hiddenSet
        if current.contains(widget.rawValue) {
            current.remove(widget.rawValue)
        } else {
            current.insert(widget.rawValue)
        }
        setting.dashboardHiddenWidgets = current.joined(separator: ",")
        try? context.save()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                infoCard
                widgetList
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Dashboard Layout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var infoCard: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "square.grid.2x2.fill", tint: FTColor.accent, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("Customize Your Dashboard")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("Toggle sections on or off. Changes apply immediately.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var widgetList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("DASHBOARD SECTIONS")
                .font(.ftLabel).tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
                .padding(.leading, FTSpacing.xs)

            VStack(spacing: 0) {
                ForEach(DashboardWidget.allCases) { widget in
                    widgetRow(widget)
                    if widget != DashboardWidget.allCases.last {
                        Divider().opacity(0.4)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private func widgetRow(_ widget: DashboardWidget) -> some View {
        let hidden = isHidden(widget)
        return Button {
            withAnimation(.snappy(duration: 0.2)) { toggle(widget) }
        } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: widget.icon, tint: hidden ? FTColor.textMuted : widget.tint, size: 36)
                    .opacity(hidden ? 0.5 : 1)
                Text(widget.label)
                    .font(.ftBody)
                    .foregroundStyle(hidden ? FTColor.textSecondary : FTColor.textPrimary)
                Spacer()
                Image(systemName: hidden ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(hidden ? FTColor.textMuted : FTColor.accent)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(widget.label), \(hidden ? "hidden" : "visible")")
        .accessibilityHint("Double-tap to \(hidden ? "show" : "hide") this section")
    }
}
