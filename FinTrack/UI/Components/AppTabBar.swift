import SwiftUI

/// The bottom navigation bar on compact width (iPhone, iPad Slide Over):
/// Home · Activity · New · Plan · Wealth · Search.
///
/// Why not the system tab bar: on iPhone it shows at most five items and
/// moves the rest into an automatic "More" screen, it shows the search-role
/// tab as an unlabelled button, and a tab is always a destination. Here every
/// item is labelled, Search is a regular item, and **New** is an action that
/// opens the transaction form without changing the selected tab.
///
/// Sized for one-handed use: six equal items of at least 48 pt, labels capped
/// at the `.large` Dynamic Type size (like the system tab bar) with the Large
/// Content Viewer on long-press for bigger sizes. `HStack` order follows the
/// layout direction, so the bar mirrors in right-to-left languages.
struct AppTabBar: View {
    let selection: AppTab
    let reviewCount: Int
    let onSelect: (AppTab) -> Void
    let onNewTransaction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 0) {
            destination(.dashboard, title: "Home", symbol: AppTab.dashboard.icon)
            destination(.transactions, title: "Activity", symbol: AppTab.transactions.icon, badge: reviewCount)
            newTransactionItem
            destination(.budget, title: "Plan", symbol: AppTab.budget.icon)
            destination(.accounts, title: "Wealth", symbol: AppTab.accounts.icon)
            destination(.search, title: "Search", symbol: AppTab.search.icon)
        }
        .padding(FTSpacing.xs)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: selection)
        .ftGlass(FTRadius.pill)
        .padding(.horizontal, FTSpacing.md)
        .padding(.bottom, FTSpacing.xs)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }

    // MARK: Items

    private func destination(_ tab: AppTab, title: LocalizedStringKey, symbol: String, badge: Int = 0) -> some View {
        let isSelected = selection == tab
        return Button { onSelect(tab) } label: {
            itemLabel(title: title, symbol: symbol, filled: isSelected, badge: badge)
                .foregroundStyle(isSelected ? FTColor.accent : FTColor.textSecondary)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(FTColor.accent.opacity(0.14))
                            .matchedGeometryEffect(id: "selection", in: highlight)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(badge > 0 ? Text("\(badge) to review") : Text(""))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityShowsLargeContentViewer {
            Label(title, systemImage: symbol)
        }
    }

    /// An action, not a destination: it never becomes the selected item, so
    /// the user stays on (and returns to) the screen they were on.
    private var newTransactionItem: some View {
        Button(action: onNewTransaction) {
            itemLabel(title: "New", symbol: "plus.circle.fill", filled: true, badge: 0)
                .foregroundStyle(FTColor.accent)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
        .accessibilityLabel("New Transaction")
        .accessibilityHint("Opens a form to add an expense, income or transfer")
        .accessibilityShowsLargeContentViewer {
            Label("New Transaction", systemImage: "plus.circle.fill")
        }
    }

    private func itemLabel(title: LocalizedStringKey, symbol: String, filled: Bool, badge: Int) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .symbolVariant(filled ? .fill : .none)
                .font(.ftHeadline)
                .frame(height: 24)
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(.ftLabel)
                            .foregroundStyle(.white)
                            .padding(.horizontal, FTSpacing.xs)
                            .background(FTColor.expense, in: .capsule)
                            .offset(x: layoutDirection == .rightToLeft ? -12 : 12, y: -6)
                            .accessibilityHidden(true)
                    }
                }
            Text(title)
                .font(.ftLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }
}
