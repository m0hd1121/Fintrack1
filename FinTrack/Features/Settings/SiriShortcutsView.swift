import SwiftUI
import AppIntents

/// Settings → Siri & Shortcuts. The App Intents in `Features/AppIntents`
/// already work with Siri and Shortcuts, but nothing in the app said so; this
/// page lists their phrases (kept in step with `FinTrackShortcuts`) and the
/// two Shortcuts automations that feed the review queue.
struct SiriShortcutsView: View {
    private struct Phrase: Identifiable {
        let id = UUID()
        let symbol: String
        let text: String
        let detail: String
    }

    private let phrases: [Phrase] = [
        Phrase(symbol: "arrow.up.circle.fill", text: "“Log an expense in FinTrack”",
               detail: "Asks for the amount and adds it to Activity"),
        Phrase(symbol: "arrow.down.circle.fill", text: "“Log income in FinTrack”",
               detail: "Asks for the amount and adds it to Activity"),
        Phrase(symbol: "chart.line.uptrend.xyaxis", text: "“What's my net worth in FinTrack”",
               detail: "Answers after Face ID or your passcode"),
        Phrase(symbol: "chart.pie.fill", text: "“Check my budget in FinTrack”",
               detail: "Reads out this month's budget status"),
        Phrase(symbol: "list.bullet.rectangle.portrait", text: "“Show my transactions in FinTrack”",
               detail: "Opens Activity"),
        Phrase(symbol: "chart.pie", text: "“Show my budget in FinTrack”",
               detail: "Opens Plan"),
        Phrase(symbol: "building.columns", text: "“Show my accounts in FinTrack”",
               detail: "Opens Wealth"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                HubSection(title: "Ask Siri") {
                    ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: phrase.symbol, tint: FTColor.accent, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(phrase.text).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                Text(phrase.detail).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        .accessibilityElement(children: .combine)
                        if index < phrases.count - 1 { Divider().opacity(0.4) }
                    }
                }

                HubSection(title: "Automations") {
                    NavigationLink { SMSImportView() } label: {
                        HubRow(symbol: "message.fill", tint: FTColor.catBlue, title: "Bank SMS",
                               subtitle: "Bank texts arrive in To Review")
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.4)
                    NavigationLink { ApplePayImportView() } label: {
                        HubRow(symbol: "wallet.pass.fill", tint: FTColor.catPurple, title: "Apple Pay",
                               subtitle: "Wallet purchases arrive in To Review")
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("You can also add FinTrack actions to your own shortcuts.")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                    ShortcutsLink()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .background { FTBackdrop() }
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
