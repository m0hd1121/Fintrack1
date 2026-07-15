import SwiftUI
import SwiftData

// MARK: - GoogleDriveBackupView
// Automatic backup to Google Drive — sits alongside iCloud Backup as a
// free-tier alternative that doesn't need a paid Apple Developer account.

struct GoogleDriveBackupView: View {
    @Environment(\.modelContext) private var context
    private let backup = GoogleDriveBackupService.shared
    @State private var showingSetup = false
    @State private var showingRestoreConfirm = false
    @State private var resultMessage = ""
    @State private var showingResult = false

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                statusCard
                if backup.isConnected {
                    settingsCard
                    limitationCard
                }
                privacyCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Google Drive Backup")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showingSetup) {
            DriveOAuthSetupSheet {
                showingSetup = false
                connect()
            }
        }
        .confirmationDialog("Restore from Google Drive?", isPresented: $showingRestoreConfirm, titleVisibility: .visible) {
            Button("Merge with current data") {
                Task {
                    resultMessage = await backup.restoreFromDrive(context: context, mode: .merge)
                    showingResult = true
                }
            }
            Button("Replace all data", role: .destructive) {
                Task {
                    resultMessage = await backup.restoreFromDrive(context: context, mode: .replace)
                    showingResult = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how to restore: merge adds new items without removing existing ones, replace deletes everything first.")
        }
        .alert("Google Drive Backup", isPresented: $showingResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GOOGLE DRIVE").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    if backup.isBackingUp || backup.isRestoring {
                        HStack(spacing: FTSpacing.sm) {
                            ProgressView().scaleEffect(0.7).tint(FTColor.income)
                            Text("Syncing…").font(.ftHeadline).foregroundStyle(FTColor.income)
                        }
                    } else if backup.isConnected {
                        Text(backup.connectedEmail ?? "Connected").font(.ftHeadline).foregroundStyle(FTColor.income)
                    } else {
                        Text("Not Connected").font(.ftHeadline).foregroundStyle(FTColor.textMuted)
                    }
                    if let last = backup.lastBackupDate {
                        Text("Last synced: \(last.relativeFormatted)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    } else {
                        Text("No sync yet").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle().fill((backup.isConnected ? FTColor.income : FTColor.textMuted).opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "doc.badge.gearshape.fill")
                        .font(.ftTitle)
                        .foregroundStyle(backup.isConnected ? FTColor.income : FTColor.textMuted)
                }
            }

            if let err = backup.lastError {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(FTColor.expense)
                    Text(err).font(.ftCaption).foregroundStyle(FTColor.expense)
                }
            }

            if backup.isConnected {
                HStack(spacing: FTSpacing.md) {
                    Button {
                        Task {
                            await backup.syncNow(context: context)
                            if let err = backup.lastError {
                                resultMessage = err
                                showingResult = true
                            }
                        }
                    } label: {
                        Label((backup.isBackingUp || backup.isRestoring) ? "Syncing…" : "Sync Now",
                              systemImage: (backup.isBackingUp || backup.isRestoring) ? "arrow.clockwise" : "arrow.triangle.2.circlepath")
                            .font(.ftBodySemibold)
                            .foregroundStyle((backup.isBackingUp || backup.isRestoring) ? FTColor.textMuted : .white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background((backup.isBackingUp || backup.isRestoring) ? FTColor.income.opacity(0.1) : FTColor.income,
                                        in: RoundedRectangle(cornerRadius: FTRadius.md))
                    }
                    .disabled(backup.isBackingUp || backup.isRestoring)

                    Button {
                        showingRestoreConfirm = true
                    } label: {
                        Label("Restore", systemImage: "icloud.and.arrow.down")
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.income)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(FTColor.income.opacity(0.1), in: RoundedRectangle(cornerRadius: FTRadius.md))
                    }
                    .disabled(backup.isRestoring)
                }

                Button(role: .destructive) {
                    backup.disconnect()
                } label: {
                    Text("Disconnect").font(.ftCaption).foregroundStyle(FTColor.expense)
                }
            } else {
                Button {
                    if backup.isConfigured {
                        connect()
                    } else {
                        showingSetup = true
                    }
                } label: {
                    Label(backup.isConnecting ? "Connecting…" : "Connect Google Drive", systemImage: "key.fill")
                        .font(.ftBodySemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(FTColor.income, in: RoundedRectangle(cornerRadius: FTRadius.md))
                }
                .disabled(backup.isConnecting)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            FTToggleRow(symbol: "arrow.triangle.2.circlepath.circle.fill", tint: FTColor.income,
                        title: "Automatic Sync",
                        isOn: Binding(
                            get: { backup.backupEnabled },
                            set: { backup.backupEnabled = $0 }
                        ))
            Text("While this device and another connected device are both open, new accounts, transactions, budgets, etc. added on either one appear on the other within a couple of minutes.")
                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                .padding(.horizontal, FTSpacing.md)
            Divider().background(FTColor.textMuted.opacity(0.3)).padding(.top, FTSpacing.xs)
            FTToggleRow(symbol: "wifi", tint: FTColor.catTeal,
                        title: "Sync on Wi-Fi only",
                        isOn: Binding(
                            get: { backup.wifiOnly },
                            set: { backup.wifiOnly = $0 }
                        ))
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Limitation Card

    private var limitationCard: some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill").font(.ftCallout).foregroundStyle(FTColor.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text("New Records Only").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("Sync only adds records your other devices don't have yet. Editing or deleting something that already exists on another device won't change it there — you'd need to make the same edit on each device, or use Restore \u{2192} Replace to force one device's data to fully overwrite another's.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Privacy Card

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.ftHeadline).foregroundStyle(FTColor.income)
                Text("PRIVACY").font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false).foregroundStyle(FTColor.textMuted)
            }
            privacyRow("key.fill", "OAuth only — the app never sees your Google password")
            privacyRow("doc.fill", "Uses the narrow \u{201c}drive.file\u{201d} scope: only the single backup file this app creates is ever visible to it — nothing else in your Drive")
            privacyRow("arrow.triangle.2.circlepath", "Each sync overwrites the same file — no clutter, no duplicates")
            privacyRow("key.icloud.fill", "Tokens live in the iOS Keychain, wiped instantly on disconnect")
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private func connect() {
        Task {
            do {
                try await backup.connect()
            } catch DriveBackupError.authCancelled {
                // user backed out — no error UI
            } catch {
                backup.lastError = error.localizedDescription
            }
        }
    }

    private func privacyRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Image(systemName: icon)
                .font(.ftCaption).foregroundStyle(FTColor.income)
                .frame(width: 20)
            Text(text).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
    }
}

// MARK: - DriveOAuthSetupSheet
// One-time setup: Google only allows registered apps to access Drive, so the
// owner creates a (free) client ID once — the same one used for Gmail sync
// works here too, as long as the Drive API is enabled on that project.

private struct DriveOAuthSetupSheet: View {
    let onConfigured: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var clientId = ""

    private let steps = [
        "Open console.cloud.google.com — reuse the project from Gmail sync, or create a new one (free)",
        "APIs & Services → Library → enable \u{201c}Google Drive API\u{201d}",
        "APIs & Services → OAuth consent screen → add \u{201c}.../auth/drive.file\u{201d} to the scopes list",
        "Credentials → if you already created an iOS OAuth client for Gmail, reuse its Client ID below",
        "Otherwise: Create Credentials → OAuth client ID → type \u{201c}iOS\u{201d}, bundle ID of this app",
        "Copy the Client ID (ends in .apps.googleusercontent.com) and paste it below",
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: FTSpacing.lg) {
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: "key.horizontal.fill", tint: FTColor.income, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("One-Time Setup Required")
                                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                                Text("Google only allows registered apps to access Drive, even for a single file the app creates itself. Create your free client ID once; every backup after that is automatic.")
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            }
                        }
                        .padding()
                        .ftGlass(FTRadius.md)

                        VStack(alignment: .leading, spacing: FTSpacing.md) {
                            Text("STEPS")
                                .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false).foregroundStyle(FTColor.textMuted)
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: FTSpacing.sm) {
                                    Text("\(index + 1)")
                                        .font(.ftCaption).bold().foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(FTColor.income, in: .circle)
                                    Text(step)
                                        .font(.ftCallout).foregroundStyle(FTColor.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("CLIENT ID")
                                .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false).foregroundStyle(FTColor.textMuted)
                            TextField("xxxx.apps.googleusercontent.com", text: $clientId, axis: .vertical)
                                .font(.ftBody)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(FTSpacing.md)
                                .ftGlass(FTRadius.sm)
                        }

                        Color.clear.frame(height: 110)
                    }
                    .padding(FTSpacing.screen)
                }

                PrimaryButton("Save & Connect Google Drive", icon: "checkmark.circle.fill") {
                    GoogleDriveBackupService.saveClientId(clientId)
                    onConfigured()
                }
                .disabled(clientId.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.md)
            }
            .navigationTitle("Connect Google Drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                clientId = GoogleDriveBackupService.storedClientId() ?? ""
            }
        }
    }
}
