import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, body: String)] = [
        ("Acceptance of Terms", "By downloading, installing, or using FinTrack, you agree to be bound by these Terms of Service. If you do not agree, do not use the application."),
        ("License", "FinTrack grants you a limited, non-exclusive, non-transferable, revocable license to use the application for your personal, non-commercial purposes on Apple devices you own or control, subject to these Terms."),
        ("Permitted Use", "You may use FinTrack to track your personal finances, record transactions, set budgets, monitor investments, and use all features as designed. You must not use FinTrack for any unlawful purpose or in violation of any applicable regulations."),
        ("Financial Information Disclaimer", "FinTrack is a personal finance management tool and does not constitute financial advice. All projections, estimates, AI insights, and recommendations are for informational purposes only. Consult a qualified financial advisor before making investment or financial decisions."),
        ("UAE Tax & Zakat Calculations", "The VAT calculator (5%), Zakat calculator (2.5%), and tax estimator tools are provided as guides based on publicly available UAE regulations. They do not constitute tax advice. Consult a registered UAE tax agent for formal guidance."),
        ("Exchange Rates", "Currency exchange rates displayed in the app are for reference only and sourced from third-party data providers. Rates may differ from those offered by banks, exchanges, or remittance services."),
        ("Data Responsibility", "You are solely responsible for the accuracy of data you enter into FinTrack. The app stores data locally on your device. Loss of data due to device failure, iOS updates, or accidental deletion is your responsibility. We strongly recommend enabling iCloud Backup."),
        ("Third-Party Services", "FinTrack may link to or integrate with third-party services (bank statement formats, exchange rate APIs). We are not responsible for the availability, accuracy, or privacy practices of these services."),
        ("Intellectual Property", "All content, design, code, and features of FinTrack are the intellectual property of the developer. You may not copy, modify, distribute, or reverse-engineer any part of the application."),
        ("Limitation of Liability", "To the maximum extent permitted by law, FinTrack and its developer shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the app, including financial losses."),
        ("Termination", "We reserve the right to discontinue the application at any time. Your license to use FinTrack terminates automatically if you violate these Terms."),
        ("Governing Law", "These Terms are governed by the laws of the United Arab Emirates. Any disputes shall be subject to the jurisdiction of the courts of the UAE."),
        ("Changes to Terms", "We may update these Terms from time to time. Continued use of FinTrack after changes constitutes your acceptance of the updated Terms."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FTSpacing.xl) {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: "doc.text.fill", tint: FTColor.catPurple, size: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Terms of Service")
                                    .font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                                Text("Effective: January 1, 2025")
                                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            }
                        }
                        Text("Please read these Terms carefully. They govern your use of FinTrack and describe your rights and obligations.")
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
            .navigationTitle("Terms of Service")
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
