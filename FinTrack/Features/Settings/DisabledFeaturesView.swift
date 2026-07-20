import SwiftUI
import SwiftData

/// Lets the user hide Premium Features from the rest of the app without deleting
/// any code or data — toggled off features simply stop appearing in Settings.
struct DisabledFeaturesView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    private var setting: AppSettings? { settings.first }

    private func isEnabledBinding(for feature: DisableableFeature) -> Binding<Bool> {
        Binding(
            get: { setting?.isFeatureEnabled(feature) ?? !DisableableFeature.disabledByDefault.contains(feature) },
            set: { newValue in
                guard let setting else { return }
                var current = setting.disabledFeatureSet
                if newValue { current.remove(feature) } else { current.insert(feature) }
                setting.disabledFeatureSet = current
                try? context.save()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                Text("Turn off any Premium Feature you don't want cluttering Settings. Nothing is deleted — your data stays intact and you can re-enable a feature here any time.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
                    .padding(.horizontal, FTSpacing.xs)

                VStack(spacing: 0) {
                    ForEach(Array(DisableableFeature.allCases.enumerated()), id: \.element.id) { index, feature in
                        FTToggleRow(symbol: feature.symbol, tint: feature.tint,
                                    title: feature.title, isOn: isEnabledBinding(for: feature))
                        if index < DisableableFeature.allCases.count - 1 {
                            Divider().opacity(0.4)
                        }
                    }
                }
                .padding(.horizontal, FTSpacing.lg)
                .ftGlass(FTRadius.md)
            }
            .padding(FTSpacing.screen)
        }
        .background { FTBackdrop() }
        .navigationTitle("Disabled Features")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DisabledFeaturesView()
    }
    .modelContainer(for: [AppSettings.self], inMemory: true)
}
