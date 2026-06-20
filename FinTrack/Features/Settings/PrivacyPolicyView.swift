import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, body: String)] = [
        ("Data Storage", "All your financial data is stored exclusively on your device using Apple's SwiftData framework and iCloud (when enabled). FinTrack never transmits your personal financial data to external servers without your explicit consent."),
        ("iCloud Sync", "When iCloud Backup is enabled in Settings, your data is encrypted and synced through Apple's CloudKit infrastructure. Only you and devices signed into your Apple ID can access this data."),
        ("Biometric & PIN Authentication", "Face ID, Touch ID, and PIN authentication are handled entirely by iOS. FinTrack never stores your biometric data. PIN hashes are stored locally on-device using a one-way cryptographic hash."),
        ("AI Categorization", "Transaction categorization and AI insights are computed on-device. No transaction data is sent to external AI services. The AI features use pattern matching against your local data only."),
        ("Exchange Rates", "Live exchange rate data is fetched from a public rates API. This request includes no personal or financial information — only the base currency code."),
        ("Analytics", "FinTrack does not use third-party analytics SDKs. No usage data, crash reports, or behavioral analytics are collected or transmitted."),
        ("Widget & App Extensions", "The widget extension, Watch app, and Siri intents share data with the main app exclusively via a local App Group container on your device. No data leaves your device through these channels."),
        ("Data Deletion", "You can delete all your data at any time via Settings → Data & Privacy → Clear All Data. When you delete the app, all locally stored data is removed by iOS automatically."),
        ("Children's Privacy", "FinTrack is not directed at children under 13. We do not knowingly collect personal information from children."),
        ("Changes to This Policy", "We may update this Privacy Policy from time to time. Significant changes will be communicated through an in-app notice on next launch."),
        ("Contact", "For privacy-related questions or requests, please contact us through the App Store listing or the support email shown in the About screen."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FTSpacing.xl) {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: "checkmark.shield.fill", tint: FTColor.income, size: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Privacy Policy")
                                    .font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                                Text("Effective: January 1, 2025")
                                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            }
                        }
                        Text("Your privacy is our highest priority. FinTrack is designed with a local-first architecture — your financial data stays on your devices.")
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.lg)

                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text(section.title)
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Text(section.body)
                                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.md)
                    }

                    Text("Last updated: January 2025")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, FTSpacing.xxl)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.lg)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
            }
        }
    }
}
