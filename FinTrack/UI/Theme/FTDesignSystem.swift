//
//  FTDesignSystem.swift
//  FinTrack Pro — iOS 26 Liquid Glass Design System
//
//  Single source of truth for color/spacing/radius/type tokens, glass
//  surfaces, and the reusable component library. Mirrors the Figma file
//  "FinTrack — iOS 26 Anchor Screens" 1:1.
//
//  Requirements: iOS 26+ (uses the native `.glassEffect` Liquid Glass API).
//  Production font: SF Pro (system). The Figma build used Inter as a stand-in.
//
//  RULE FOR THE WHOLE APP: never hardcode a hex color, font size, corner
//  radius, or spacing value in a screen. Always reference the tokens below.
//

import SwiftUI

// MARK: - Color utilities

extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >>  8) & 0xFF) / 255,
            blue:  CGFloat( rgb        & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// Static hex color.
    init(hex: UInt) { self.init(uiColor: UIColor(rgb: hex)) }

    /// Adaptive color that resolves per light/dark appearance.
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

// MARK: - Color tokens  (Figma collection: FinTrack/Color — Light + Dark modes)

enum FTColor {
    static let bgBase       = Color(light: 0xE8EDF1, dark: 0x0E1620)
    static let bgElevated   = Color(light: 0xFFFFFF, dark: 0x18222E)

    static let textPrimary  = Color(light: 0x0F1B2A, dark: 0xF2F6FA)
    static let textSecondary = Color(light: 0x5A6B7B, dark: 0x9DB0C0)
    static let textMuted    = Color(light: 0x9AA8B4, dark: 0x5E6F7E)

    static let accent       = Color(light: 0x0E9C8A, dark: 0x2FD4BE)
    static let accentDeep    = Color(light: 0x0C8478, dark: 0x13B89C)
    static let accentBright = Color(light: 0x13B89C, dark: 0x3BE3CC)

    static let gold         = Color(light: 0xC8902B, dark: 0xE8B64B)
    static let income       = Color(light: 0x1FA463, dark: 0x3BD685)
    static let expense      = Color(light: 0xE5484D, dark: 0xFF6B6F)

    // Category accents (used for icon tiles)
    static let catBlue      = Color(hex: 0x2E78C8)
    static let catPurple    = Color(hex: 0x7C5BD0)
    static let catCoral     = Color(hex: 0xE5736B)
    static let catGold      = Color(hex: 0xC8902B)
    static let catTeal      = Color(hex: 0x0E9C8A)

    // Gradients
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x13B89C), Color(hex: 0x0C8478)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x12A594), Color(hex: 0x0A6E7E)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let portfolioGradient = LinearGradient(
        colors: [Color(hex: 0x1E2A38), Color(hex: 0x0B141E)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Spacing tokens  (Figma: FinTrack/Scale · space/*)

enum FTSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 20
    static let xxl: CGFloat = 24
    /// Standard screen side padding.
    static let screen: CGFloat = 20
}

// MARK: - Radius tokens  (Figma: FinTrack/Scale · radius/*)

enum FTRadius {
    static let sm:   CGFloat = 12
    static let md:   CGFloat = 16
    static let lg:   CGFloat = 22
    static let xl:   CGFloat = 26
    static let pill: CGFloat = 30
}

// MARK: - Typography tokens  (Figma: Type/* — production face SF Pro)

extension Font {
    static let ftDisplay      = Font.system(size: 38,   weight: .heavy,    design: .rounded)
    static let ftAmount       = Font.system(size: 34,   weight: .heavy,    design: .rounded)
    static let ftTitle        = Font.system(size: 22,   weight: .bold)
    static let ftHeadline     = Font.system(size: 17,   weight: .bold)
    static let ftBody         = Font.system(size: 15,   weight: .medium)
    static let ftBodySemibold = Font.system(size: 15,   weight: .semibold)
    static let ftCallout      = Font.system(size: 13.5, weight: .semibold)
    static let ftCaption      = Font.system(size: 12.5, weight: .regular)
    static let ftLabel        = Font.system(size: 11.5, weight: .semibold) // use .tracking(1.6)
}

// MARK: - Liquid Glass surfaces

/// Applies `.glassEffect`, and degrades it to an opaque surface when the
/// system asks for less transparency or more contrast.
///
/// **Reduce Transparency** (Settings → Accessibility → Display & Text Size) is
/// the closest thing iOS exposes publicly to "the user's Liquid Glass
/// preference": there is no public API for reading the glass
/// transparency/intensity level itself, and the private preference must not be
/// touched. Apple's own materials already dim themselves under this setting,
/// but reading it directly lets a surface become genuinely opaque rather than
/// merely less translucent — which is what the setting is actually asking for,
/// and it also skips the blur pass entirely.
///
/// `colorSchemeContrast` is the *system* Increase Contrast setting; the app's
/// own `isHighContrast` toggle is separate, so either one turns the border on.
private struct FTGlassModifier: ViewModifier {
    let radius: CGFloat
    var interactive: Bool = false
    @Environment(\.isHighContrast) private var isHighContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var wantsHighContrast: Bool {
        isHighContrast || colorSchemeContrast == .increased
    }

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                // Opaque, no blur and no offscreen pass. Bordered unconditionally:
                // without the glass edge the surface would otherwise have no
                // boundary against the page background.
                content.background(FTColor.bgElevated, in: .rect(cornerRadius: radius))
            } else {
                content.glassEffect(interactive ? .regular.interactive() : .regular,
                                    in: .rect(cornerRadius: radius))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(
                    (wantsHighContrast || reduceTransparency)
                        ? FTColor.textPrimary.opacity(wantsHighContrast ? 0.45 : 0.14)
                        : Color.clear,
                    lineWidth: wantsHighContrast ? 1.5 : 1
                )
                .allowsHitTesting(false)
        )
    }
}

extension View {
    /// A frosted Liquid Glass surface clipped to a rounded rect.
    func ftGlass(_ radius: CGFloat = FTRadius.lg) -> some View {
        modifier(FTGlassModifier(radius: radius))
    }

    /// Glass surface that reacts to touch (use for tappable cards/rows).
    func ftGlassInteractive(_ radius: CGFloat = FTRadius.lg) -> some View {
        modifier(FTGlassModifier(radius: radius, interactive: true))
    }
}

/// Padded Liquid Glass card container.
struct FTCard<Content: View>: View {
    var radius: CGFloat = FTRadius.lg
    var padding: CGFloat = FTSpacing.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ftGlass(radius)
    }
}

// MARK: - Buttons

struct FTPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ftHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.md + 2))
            .shadow(color: Color(hex: 0x0C8478).opacity(0.35), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FTPrimaryButtonStyle {
    static var ftPrimary: FTPrimaryButtonStyle { .init() }
}

// Secondary buttons should use the system glass style: `.buttonStyle(.glass)`

// MARK: - Icon tile

struct FTIconTile: View {
    let symbol: String          // SF Symbol name
    let tint: Color
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: .rect(cornerRadius: size * 0.3))
            // Purely decorative: it always sits beside text that says the same
            // thing. Left visible, VoiceOver reads the raw symbol name
            // ("cart dot fill") before every row.
            .accessibilityHidden(true)
    }
}

// MARK: - Chip

struct FTChip: View {
    let symbol: String
    let title: String
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                .accessibilityHidden(true)
            Text(title).font(.ftCallout)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .foregroundStyle(selected ? .white : FTColor.textPrimary)
        .modifier(FTChipBackground(selected: selected))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        // Selection is otherwise carried only by the fill colour, which
        // VoiceOver and colour-blind users can't see.
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct FTChipBackground: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        if selected {
            content.background(FTColor.accent, in: .capsule)
        } else {
            content
                .background(.regularMaterial, in: .capsule)
                .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
        }
    }
}

// MARK: - Progress bar

struct FTProgressBar: View {
    /// 0...1 (clamps; pass >1 to show "over budget" — cap fill, color it red).
    var value: Double
    var color: Color = FTColor.accent
    var height: CGFloat = 9
    /// What the bar measures. Optional so the 58 existing call sites are
    /// unaffected, but worth passing — "Budget used, 64%" beats "64%".
    var accessibilityTitle: String = "Progress"

    /// The bar carries no text at all, so without this VoiceOver skips it
    /// entirely and the figure it represents is simply unavailable. Over-budget
    /// is called out because past 100% the bar looks identical to full — only
    /// the colour differs, and colour alone isn't information.
    private var spokenValue: String {
        let percent = Int((value * 100).rounded())
        return value > 1 ? "\(percent) percent, over budget" : "\(percent) percent"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(FTColor.textPrimary.opacity(0.08))
                Capsule().fill(color)
                    .frame(width: max(8, geo.size.width * min(value, 1)))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(spokenValue)
    }
}

// MARK: - Segmented control

struct FTSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { i in
                Text(options[i])
                    .font(.ftCallout)
                    .foregroundStyle(selection == i ? .white : FTColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selection == i {
                            RoundedRectangle(cornerRadius: 13)
                                .fill(FTColor.accentGradient)
                                .matchedGeometryEffect(id: "ftSeg", in: ns)
                                .shadow(color: Color(hex: 0x0C8478).opacity(0.3), radius: 8, y: 3)
                        }
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        if reduceMotion { selection = i }
                        else { withAnimation(.snappy(duration: 0.25)) { selection = i } }
                    }
                    .accessibilityLabel(options[i])
                    .accessibilityAddTraits(selection == i ? [.isSelected] : [])
            }
        }
        .padding(4)
        .ftGlass(FTRadius.md)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Toggle row

struct FTToggleRow: View {
    let symbol: String
    let tint: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: symbol, tint: tint, size: 36)
            Text(title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                .accessibilityHidden(true)
            Spacer()
            // The title goes *into* the Toggle rather than beside it:
            // `labelsHidden()` keeps it off screen but VoiceOver still reads
            // it, so the switch stops announcing as an unlabelled control.
            // The separate Text above is hidden to avoid saying it twice.
            Toggle(title, isOn: $isOn).labelsHidden().tint(FTColor.accent)
        }
        .padding(.vertical, 13)
    }
}

// MARK: - Transaction row

struct FTTransactionRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let amount: String
    var amountColor: Color = FTColor.expense

    /// Amounts are formatted for the eye ("−AED 184.50"). U+2212 MINUS and a
    /// leading "+" are punctuation to VoiceOver, so the sign — the difference
    /// between money in and money out — is the part most likely to be dropped.
    private var spokenAmount: String {
        amount
            .replacingOccurrences(of: "\u{2212}", with: "minus ")
            .replacingOccurrences(of: "-", with: "minus ")
            .replacingOccurrences(of: "+", with: "plus ")
    }

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(subtitle).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            Text(amount).font(.ftBodySemibold.weight(.bold)).foregroundStyle(amountColor)
        }
        .padding(.vertical, 13)
        // One swipe per transaction instead of three: title, then subtitle and
        // amount as the value.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(subtitle), \(spokenAmount)")
    }
}

// MARK: - Floating glass tab bar

struct FTTab: Identifiable {
    let id = UUID()
    let symbol: String
    let index: Int
}

struct FTGlassTabBar: View {
    @Binding var selection: Int
    var onAdd: () -> Void
    private let tabs = ["house.fill", "creditcard.fill", "chart.bar.fill", "person.fill"]
    /// The app's primary navigation was five icon-only buttons with no labels,
    /// so VoiceOver announced them by SF Symbol name — "house dot fill, button".
    private let tabNames = ["Dashboard", "Transactions", "Budget", "Accounts"]

    var body: some View {
        ZStack {
            HStack {
                tabButton(0, tabs[0]); Spacer()
                tabButton(1, tabs[1]); Spacer()
                Color.clear.frame(width: 40)   // gap for the FAB
                Spacer()
                tabButton(2, tabs[2]); Spacer()
                tabButton(3, tabs[3])
            }
            .padding(.horizontal, 30)
            .frame(height: 66)
            .ftGlass(FTRadius.pill)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(FTColor.accentGradient, in: .circle)
                    .shadow(color: Color(hex: 0x0C8478).opacity(0.45), radius: 18, y: 8)
            }
            .offset(y: -28)
            .accessibilityLabel("Add transaction")
        }
        .padding(.horizontal, FTSpacing.screen)
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ i: Int, _ symbol: String) -> some View {
        Button { selection = i } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(selection == i ? FTColor.accent : FTColor.textMuted)
                // The glyph is ~26pt, well under the 44pt minimum target. The
                // icon stays where it was; only the tappable area grows.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(tabNames[i])
        // Which tab is current was previously conveyed by tint alone.
        .accessibilityAddTraits(selection == i ? [.isButton, .isSelected] : [.isButton])
    }
}

// MARK: - Environment keys for personalization

private struct OLEDModeKey: EnvironmentKey { static let defaultValue = false }
private struct HighContrastKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var isOLEDMode: Bool {
        get { self[OLEDModeKey.self] }
        set { self[OLEDModeKey.self] = newValue }
    }
    var isHighContrast: Bool {
        get { self[HighContrastKey.self] }
        set { self[HighContrastKey.self] = newValue }
    }
}

// MARK: - Accent color presets

extension Color {
    /// Resolve a named accent color to a SwiftUI Color.
    static func ftAccent(named name: String) -> Color {
        switch name {
        case "blue":   return Color(light: 0x1A6FD0, dark: 0x4A9EFF)
        case "purple": return Color(light: 0x7C5BD0, dark: 0xA07EE8)
        case "coral":  return Color(light: 0xE5736B, dark: 0xFF9590)
        case "gold":   return Color(light: 0xC8902B, dark: 0xE8B64B)
        case "rose":   return Color(light: 0xD04B7C, dark: 0xFF70A6)
        default:       return FTColor.accent  // teal
        }
    }
}

// MARK: - Soft blurred-blob backdrop (the iOS 26 "colorful frost" base)

struct FTBackdrop: View {
    @Environment(\.isOLEDMode) private var isOLEDMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if isOLEDMode {
            Color.black.ignoresSafeArea()
        } else if reduceTransparency {
            // Three 55pt-blurred blobs inside a `drawingGroup()` mean an
            // offscreen Metal pass behind essentially every screen in the app.
            // Reduce Transparency is a request to drop exactly this kind of
            // decorative depth, so the flat ground is both the accessible
            // answer and the cheap one — it costs a single fill.
            FTColor.bgBase.ignoresSafeArea()
        } else {
            ZStack {
                FTColor.bgBase.ignoresSafeArea()
                GeometryReader { geo in
                    blob(Color(hex: 0x13B8A6), 180).position(x: 40, y: 60)
                    blob(Color(hex: 0x5B86E5), 160).position(x: geo.size.width - 30, y: 150)
                    blob(Color(hex: 0xE8B64B), 180).position(x: geo.size.width * 0.5, y: geo.size.height * 0.7)
                }
                .drawingGroup()
                .ignoresSafeArea()
            }
        }
    }
    private func blob(_ color: Color, _ size: CGFloat) -> some View {
        Circle().fill(color).frame(width: size, height: size)
            .blur(radius: 55).opacity(0.35)
    }
}

// MARK: - Preview

#Preview("Components") {
    ZStack {
        FTBackdrop()
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                FTSegmentedControlPreview()
                HStack { FTChip(symbol: "fork.knife", title: "Food", selected: true)
                         FTChip(symbol: "car.fill", title: "Transport") }
                FTCard {
                    FTTransactionRow(symbol: "cart.fill", tint: FTColor.catBlue,
                                     title: "Carrefour", subtitle: "Groceries · Today",
                                     amount: "−AED 184.50")
                }
                FTProgressBar(value: 0.64)
                Button("Add Transaction") {}.buttonStyle(.ftPrimary)
            }
            .padding(FTSpacing.screen)
        }
    }
}

private struct FTSegmentedControlPreview: View {
    @State private var sel = 0
    var body: some View { FTSegmentedControl(options: ["Expense", "Income", "Transfer"], selection: $sel) }
}
