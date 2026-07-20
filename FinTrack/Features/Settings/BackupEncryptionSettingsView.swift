import SwiftUI

// MARK: - BackupEncryptionSettingsView
// Read-only status screen. Backup encryption is mandatory and always on — there
// is intentionally no toggle and no passphrase to manage (the key is a random
// value held only in this device's Keychain; see BackupEncryptionService).

struct BackupEncryptionSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                statusCard
                howItWorksCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Backup Encryption")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .scrollContentBackground(.hidden)
    }

    private var statusCard: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(FTColor.income.opacity(0.1)).frame(width: 56, height: 56)
                Image(systemName: "lock.fill").font(.ftTitle).foregroundStyle(FTColor.income)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Backups Always Encrypted")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("Every export, iCloud backup, Drive backup, and email backup is encrypted automatically. This can't be turned off.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("HOW IT WORKS").font(.ftLabel).tracking(1.6)
                .fixedSize(horizontal: true, vertical: false).foregroundStyle(FTColor.textMuted)

            infoRow("lock.shield.fill", FTColor.income,
                    "Backups are locked to this device — only the FinTrack app that created them can open them.")
            infoRow("hand.raised.slash.fill", FTColor.catTeal,
                    "No other app can read a backup file, even if it's shared, copied, or intercepted.")
            infoRow("key.fill", FTColor.gold,
                    "The key stays in this device's secure storage. It's never shown to you, never transmitted, and never synced.")
            infoRow("exclamationmark.triangle.fill", FTColor.expense,
                    "Because the key can't leave this device, a backup can't be restored on a different device or after reinstalling. Keep this device to keep access.")
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func infoRow(_ icon: String, _ tint: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            Image(systemName: icon).font(.ftCallout).foregroundStyle(tint).frame(width: 22)
            Text(text).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
    }
}
