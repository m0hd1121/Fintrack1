import SwiftUI

// MARK: - Design Tokens

struct AppColors {
    // Semantic surfaces — mapped to FT tokens for consistent light/dark
    static let surface            = FTColor.bgElevated
    static let surfaceSecondary   = FTColor.bgBase
    static let surfaceTertiary    = FTColor.bgBase
    static let groupedBackground  = FTColor.bgBase

    // Brand gradients — mapped to FT gradients
    static let primaryGradient    = FTColor.heroGradient
    static let incomeGradient     = LinearGradient(
        colors: [FTColor.income, FTColor.accentBright],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let expenseGradient    = LinearGradient(
        colors: [FTColor.expense, Color(light: 0xF45C43, dark: 0xFF8A80)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let goldGradient = LinearGradient(
        colors: [Color(hex: "#f7971e"), Color(hex: "#ffd200")],
        startPoint: .leading, endPoint: .trailing
    )
    static let purpleGradient = LinearGradient(
        colors: [Color(hex: "#8360c3"), Color(hex: "#2ebf91")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let blueGradient = LinearGradient(
        colors: [Color(hex: "#4facfe"), Color(hex: "#00f2fe")],
        startPoint: .leading, endPoint: .trailing
    )

    // Card tints
    static let cardBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
}

struct AppSpacing {
    static let xs: CGFloat = FTSpacing.xs   // 4
    static let sm: CGFloat = FTSpacing.sm   // 8
    static let md: CGFloat = FTSpacing.lg   // 16
    static let lg: CGFloat = FTSpacing.xxl  // 24
    static let xl: CGFloat = 32
}

struct AppRadius {
    static let sm: CGFloat = FTRadius.sm    // 12
    static let md: CGFloat = FTRadius.md    // 16
    static let lg: CGFloat = FTRadius.lg    // 22
    static let xl: CGFloat = FTRadius.xl    // 26
}

// MARK: - Color(hex:)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Reusable Components

/// Frosted Liquid Glass card — wraps FTCard
struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = FTRadius.lg

    init(cornerRadius: CGFloat = FTRadius.lg, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .ftGlass(cornerRadius)
    }
}

/// Elevated card — Liquid Glass surface
struct Card<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = FTRadius.md
    var padding: CGFloat = FTSpacing.lg

    init(cornerRadius: CGFloat = FTRadius.md, padding: CGFloat = FTSpacing.lg, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    var body: some View {
        content
            .padding(padding)
            .ftGlass(cornerRadius)
    }
}

/// Full-width primary action button — uses FTPrimaryButtonStyle for non-destructive
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false
    var isDestructive: Bool = false

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isLoading = isLoading
        self.isDestructive = isDestructive
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: FTSpacing.sm) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                }
                Text(title).font(.ftHeadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(isDestructive ? AnyShapeStyle(FTColor.expense) : AnyShapeStyle(FTColor.accentGradient), in: .rect(cornerRadius: FTRadius.md))
            .foregroundStyle(.white)
            .shadow(color: (isDestructive ? FTColor.expense : FTColor.accentDeep).opacity(0.35), radius: 18, y: 8)
        }
        .disabled(isLoading)
    }
}

/// Amount display with hide support
struct AmountDisplayView: View {
    let amount: Double
    let currency: String
    var isHidden: Bool = false
    var style: AmountStyle = .large

    enum AmountStyle {
        case large, medium, small
        var fontSize: CGFloat {
            switch self {
            case .large: return 38
            case .medium: return 24
            case .small: return 16
            }
        }
    }

    var body: some View {
        if isHidden {
            Text("••••••")
                .font(.system(size: style.fontSize, weight: .bold, design: .rounded))
        } else {
            Text(amount.formatted(as: currency))
                .font(.system(size: style.fontSize, weight: .bold, design: .rounded))
        }
    }
}

/// Section header with optional trailing action
struct SectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.ftHeadline)
                .foregroundStyle(FTColor.textPrimary)
            Spacer()
            if let action, let onAction {
                Button(action: onAction) {
                    Text(action)
                        .font(.ftCallout)
                        .foregroundStyle(FTColor.accent)
                }
            }
        }
    }
}

/// Engaging empty state
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

/// Compact pill badge
struct BadgeView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

/// Icon in a rounded-rect container — mirrors FTIconTile
struct IconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        FTIconTile(symbol: icon, tint: color, size: size)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(padding: CGFloat = FTSpacing.lg) -> some View {
        self
            .padding(padding)
            .ftGlass(FTRadius.md)
    }

    func glassBackground(opacity: Double = 0.1) -> some View {
        self.ftGlass(FTRadius.md)
    }

    func dismissKeyboardOnTap() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }
}
