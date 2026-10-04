import SwiftUI

struct PrivacyPolicyView: View {

    private let sections: [(title: String, body: String)] = [
        ("Data Storage", "All your financial data is stored exclusively on your device using Apple's SwiftData framework. FinTrack never transmits your personal financial data to external servers without your explicit consent."),
        ("Backup", "Backups are always encrypted and kept in FinTrack's private storage on this device. They only leave the device when you export one, or turn on Google Drive or Email Backup. A backup can only be restored by FinTrack on the iPhone that created it."),
        ("Biometric & PIN Authentication", "Face ID and Touch ID are handled entirely by iOS; FinTrack never sees or stores biometric data. The app PIN is checked by FinTrack itself and stored only as a salted one-way hash on this device (it is included in your encrypted backups)."),
        ("AI Categorization", "Transaction categorization and AI insights are computed on-device. No transaction data is sent to external AI services. The AI features use pattern matching against your local data only."),
        ("Network Requests", "FinTrack contacts outside services only for specific features: exchange rates (sends a currency code), stock and crypto prices (sends the ticker symbols you hold), merchant category lookup (sends a merchant name and your region to OpenStreetMap, or to Google Places if you add your own key), and email import (connects to the mail provider you sign in to). No balances, amounts or account details are sent."),
        ("Analytics", "FinTrack does not use third-party analytics SDKs. No usage data, crash reports, or behavioral analytics are collected or transmitted."),
        ("Siri & Shortcuts", "Siri and Shortcuts actions run inside FinTrack on your device and read a local summary the app keeps up to date. Actions that read balances require your device to be unlocked. No data leaves your device through these channels."),
        ("Data Deletion", "You can delete all your data at any time via Settings → Data & Privacy → Clear All Data. Deleting the app removes its data, except an encrypted recovery copy kept in the iOS Keychain so a reinstall can restore your data — Clear All Data removes that copy too."),
        ("Children's Privacy", "FinTrack is not directed at children under 13. We do not knowingly collect personal information from children."),
        ("Changes to This Policy", "We may update this Privacy Policy from time to time. Significant changes will be communicated through an in-app notice on next launch."),
        ("Contact", "For privacy-related questions or requests, please contact us through the App Store listing or the support email shown in the About screen."),
    ]

    var body: some View {
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
    
    }
}
