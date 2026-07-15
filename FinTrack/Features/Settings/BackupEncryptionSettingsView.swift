import SwiftUI

// MARK: - BackupEncryptionSettingsView
// Sets the passphrase used to encrypt (AES-256-GCM) the .fintrack backup
// file before it's written anywhere — manual Export, iCloud Backup, or
// Google Drive Backup all use the same passphrase automatically.

struct BackupEncryptionSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isEnabled = BackupEncryptionService.isEnabled
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var showingDisableConfirm = false
    @State private var resultMessage = ""
    @State private var showingResult = false

    private var canSave: Bool {
        passphrase.count >= 6 && passphrase == confirmPassphrase
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                statusCard

                if isEnabled {
                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        debtHeader
                        Text("A passphrase is set on this device. Backups are encrypted automatically.")
                            .font(.ftCallout).foregroundStyle(FTColor.textSecondary)
                        Button(role: .destructive) { showingDisableConfirm = true } label: {
                            Text("Turn Off Encryption").font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                                .frame(maxWidth: .infinity).padding()
                                .background(FTColor.expense.opacity(0.1), in: RoundedRectangle(cornerRadius: FTRadius.md))
                        }
                    }
                    .padding()
                    .ftGlass(FTRadius.xl)
                }

                setPassphraseCard
                warningCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Backup Encryption")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .scrollContentBackground(.hidden)
        .confirmationDialog("Turn off backup encryption?", isPresented: $showingDisableConfirm, titleVisibility: .visible) {
            Button("Turn Off", role: .destructive) {
                BackupEncryptionService.storedPassphrase = nil
                isEnabled = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Future backups will be saved unencrypted. Existing encrypted backups still need this passphrase to restore.")
        }
        .alert("Backup Encryption", isPresented: $showingResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
    }

    private var debtHeader: some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(FTColor.income)
            Text("ENCRYPTION ENABLED").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
        }
    }

    private var statusCard: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill((isEnabled ? FTColor.income : FTColor.textMuted).opacity(0.1)).frame(width: 56, height: 56)
                Image(systemName: isEnabled ? "lock.fill" : "lock.open.fill")
                    .font(.ftTitle).foregroundStyle(isEnabled ? FTColor.income : FTColor.textMuted)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(isEnabled ? "Backups Encrypted" : "Backups Not Encrypted")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text(isEnabled
                     ? "Every export, iCloud backup, and Drive backup is protected with AES-256."
                     : "Backup files are plain, readable data. Set a passphrase below to protect them.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var setPassphraseCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text(isEnabled ? "CHANGE PASSPHRASE" : "SET A PASSPHRASE")
                .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false).foregroundStyle(FTColor.textMuted)

            VStack(spacing: 0) {
                HStack(spacing: FTSpacing.md) {
                    Text("Passphrase").font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
                    Spacer()
                    SecureField("At least 6 characters", text: $passphrase)
                        .multilineTextAlignment(.trailing)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                }
                .padding(.vertical, 13)
                Divider().opacity(0.4)
                HStack(spacing: FTSpacing.md) {
                    Text("Confirm").font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
                    Spacer()
                    SecureField("Re-enter passphrase", text: $confirmPassphrase)
                        .multilineTextAlignment(.trailing)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                }
                .padding(.vertical, 13)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)

            if !passphrase.isEmpty && !confirmPassphrase.isEmpty && passphrase != confirmPassphrase {
                Text("Passphrases don't match.").font(.ftCaption).foregroundStyle(FTColor.expense)
            }

            Button {
                BackupEncryptionService.storedPassphrase = passphrase
                isEnabled = true
                passphrase = ""
                confirmPassphrase = ""
                resultMessage = "Passphrase saved. New backups on this device will be encrypted with it."
                showingResult = true
            } label: {
                Text(isEnabled ? "Update Passphrase" : "Enable Encryption")
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(canSave ? FTColor.accent : FTColor.accent.opacity(0.3),
                                in: RoundedRectangle(cornerRadius: FTRadius.md))
            }
            .disabled(!canSave)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill").font(.ftCallout).foregroundStyle(FTColor.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text("There Is No Password Recovery").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("This passphrase lives only in this device's Keychain — it is never sent anywhere, including to iCloud or Google Drive. To restore an encrypted backup on another device, you must set the exact same passphrase there first. If you forget it, encrypted backups cannot be recovered by anyone, including FinTrack.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }
}
