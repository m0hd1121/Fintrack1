import SwiftUI
import SwiftData

struct AppearanceView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    private var setting: AppSettings? { settings.first }

    private var themeBinding: Binding<AppTheme> {
        Binding(get: { setting?.theme ?? .system },
                set: { setting?.theme = $0; try? context.save() })
    }
    private var oledBinding: Binding<Bool> {
        Binding(get: { setting?.oledMode ?? false },
                set: { setting?.oledMode = $0; try? context.save() })
    }
    private var contrastBinding: Binding<Bool> {
        Binding(get: { setting?.highContrastMode ?? false },
                set: { setting?.highContrastMode = $0; try? context.save() })
    }
    private var accentBinding: Binding<String> {
        Binding(get: { setting?.accentColorName ?? "teal" },
                set: { setting?.accentColorName = $0; try? context.save() })
    }
    private var fiscalMonthBinding: Binding<Int> {
        Binding(get: { setting?.fiscalYearStartMonth ?? 1 },
                set: { setting?.fiscalYearStartMonth = $0; try? context.save() })
    }
    private var firstDayBinding: Binding<Int> {
        Binding(get: { setting?.firstDayOfWeek ?? 1 },
                set: { setting?.firstDayOfWeek = $0; try? context.save() })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                themeSection
                accentSection
                displaySection
                calendarSection
                accessibilitySection
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Theme

    private var themeSection: some View {
        sectionCard("Color Scheme") {
            VStack(spacing: FTSpacing.md) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    themeRow(theme)
                    if theme != AppTheme.allCases.last {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        let isSelected = themeBinding.wrappedValue == theme
        let icon: String
        switch theme {
        case .light:  icon = "sun.max.fill"
        case .dark:   icon = "moon.fill"
        case .system: icon = "circle.lefthalf.filled"
        case .oled:   icon = "iphone"
        }
        let tint: Color
        switch theme {
        case .light:  tint = FTColor.gold
        case .dark:   tint = FTColor.catPurple
        case .system: tint = FTColor.accent
        case .oled:   tint = FTColor.textSecondary
        }

        return Button {
            themeBinding.wrappedValue = theme
            if theme == .oled { oledBinding.wrappedValue = true }
            else { oledBinding.wrappedValue = false }
        } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: icon, tint: tint, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.rawValue).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    if theme == .oled {
                        Text("True black — extends battery life on OLED displays")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    } else if theme == .system {
                        Text("Follows iOS Dark Mode setting")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FTColor.accent)
                        .font(.title3)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.rawValue) theme\(isSelected ? ", selected" : "")")
    }

    // MARK: – Accent color

    private let accentOptions: [(name: String, label: String, color: Color)] = [
        ("teal",   "Teal",   FTColor.accent),
        ("blue",   "Blue",   Color.ftAccent(named: "blue")),
        ("purple", "Purple", Color.ftAccent(named: "purple")),
        ("coral",  "Coral",  Color.ftAccent(named: "coral")),
        ("gold",   "Gold",   Color.ftAccent(named: "gold")),
        ("rose",   "Rose",   Color.ftAccent(named: "rose")),
    ]

    private var accentSection: some View {
        sectionCard("Accent Color") {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("Applies to buttons, toggles, and highlights")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: FTSpacing.md) {
                    ForEach(accentOptions, id: \.name) { option in
                        let isSelected = accentBinding.wrappedValue == option.name
                        Button {
                            accentBinding.wrappedValue = option.name
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 40, height: 40)
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                Text(option.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(isSelected ? option.color : FTColor.textMuted)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(option.label) accent color\(isSelected ? ", selected" : "")")
                    }
                }
            }
        }
    }

    // MARK: – Display

    private var displaySection: some View {
        sectionCard("Display") {
            VStack(spacing: 0) {
                FTToggleRow(symbol: "eye.slash.fill", tint: FTColor.catPurple,
                            title: "High Contrast Mode", isOn: contrastBinding)
                    .accessibilityHint("Increases text and border visibility")
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "textformat.size", tint: FTColor.accent, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dynamic Type").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Text("Follows iOS Text Size setting automatically")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(FTColor.textMuted)
                        .font(.caption)
                }
                .padding(.vertical, 13)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .accessibilityLabel("Dynamic Type — opens iOS Settings")
            }
        }
    }

    // MARK: – Calendar

    private var calendarSection: some View {
        sectionCard("Calendar & Fiscal Year") {
            VStack(spacing: 0) {
                // First day of week
                Menu {
                    Picker("First Day of Week", selection: firstDayBinding) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Saturday").tag(7)
                    }
                } label: {
                    HStack(spacing: FTSpacing.md) {
                        FTIconTile(symbol: "calendar", tint: FTColor.catTeal, size: 36)
                        Text("First Day of Week")
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Spacer()
                        Text(firstDayLabel(firstDayBinding.wrappedValue))
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FTColor.textMuted)
                    }
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("First Day of Week: \(firstDayLabel(firstDayBinding.wrappedValue))")

                Divider().opacity(0.4)

                // Fiscal year start month
                Menu {
                    Picker("Fiscal Year Start", selection: fiscalMonthBinding) {
                        ForEach(1...12, id: \.self) { month in
                            Text(monthName(month)).tag(month)
                        }
                    }
                } label: {
                    HStack(spacing: FTSpacing.md) {
                        FTIconTile(symbol: "calendar.badge.clock", tint: FTColor.catBlue, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fiscal Year Start").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            Text("Affects annual reports and budget periods")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                        Text(monthName(fiscalMonthBinding.wrappedValue))
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FTColor.textMuted)
                    }
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fiscal Year Start: \(monthName(fiscalMonthBinding.wrappedValue))")
            }
        }
    }

    // MARK: – Accessibility

    private var accessibilitySection: some View {
        sectionCard("Accessibility") {
            VStack(spacing: 0) {
                accessibilityLink("VoiceOver", icon: "speaker.wave.2.fill", tint: FTColor.catBlue,
                                  detail: "Enable spoken interface")
                Divider().opacity(0.4)
                accessibilityLink("Reduce Motion", icon: "waveform.path.ecg", tint: FTColor.catTeal,
                                  detail: "Minimize animations across the app")
                Divider().opacity(0.4)
                accessibilityLink("Increase Contrast", icon: "circle.lefthalf.filled", tint: FTColor.catPurple,
                                  detail: "Higher contrast for text and borders")
                Divider().opacity(0.4)
                accessibilityLink("Display & Text Size", icon: "textformat", tint: FTColor.accent,
                                  detail: "Bold text, button shapes, and more")
            }
        }
    }

    private func accessibilityLink(_ title: String, icon: String, tint: Color, detail: String) -> some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: icon, tint: tint, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Text(detail).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(FTColor.textMuted).font(.caption)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) — opens iOS Settings")
    }

    // MARK: – Helpers

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text(title.uppercased())
                .font(.ftLabel).tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
                .padding(.leading, FTSpacing.xs)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, FTSpacing.lg)
                .ftGlass(FTRadius.md)
        }
    }

    private func firstDayLabel(_ day: Int) -> String {
        switch day {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 7: return "Saturday"
        default: return "Sunday"
        }
    }

    private func monthName(_ month: Int) -> String {
        Calendar.current.monthSymbols[max(0, min(11, month - 1))]
    }
}
