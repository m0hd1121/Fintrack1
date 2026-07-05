import SwiftUI
import SwiftData

// MARK: - EmailBackupView
// Automatic backup via plain email — sits alongside iCloud Backup and Google
// Drive Backup as a zero-setup alternative: sign in with an email address +
// app-specific password (same as IMAP email sync), no OAuth, no developer
// console, no client ID.

struct EmailBackupView: View {
    @Environment(\.modelContext) private var context
    private let backup = EmailBackupService.shared
    @State private var showingSignIn = false
    @State private var showingRestoreConfirm = false
    @State private var resultMessage = ""
    @State private var showingResult = false

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                statusCard
                if backup.isConnected {
                    settingsCard
                }
                privacyCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Email Backup")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showingSignIn) {
            EmailBackupSignInSheet()
        }
        .confirmationDialog("Restore from Email?", isPresented: $showingRestoreConfirm, titleVisibility: .visible) {
            Button("Merge with current data") {
                Task {
                    resultMessage = await backup.restoreFromEmail(context: context, mode: .merge)
                    showingResult = true
                }
            }
            Button("Replace all data", role: .destructive) {
                Task {
                    resultMessage = await backup.restoreFromEmail(context: context, mode: .replace)
                    showingResult = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how to restore: merge adds new items without removing existing ones, replace deletes everything first.")
        }
        .alert("Email Backup", isPresented: $showingResult) {
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
                    Text("EMAIL BACKUP").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    if backup.isBackingUp || backup.isRestoring {
                        HStack(spacing: FTSpacing.sm) {
                            ProgressView().scaleEffect(0.7).tint(FTColor.catCoral)
                            Text(backup.isBackingUp ? "Backing up…" : "Restoring…")
                                .font(.ftHeadline).foregroundStyle(FTColor.catCoral)
                        }
                    } else if backup.isConnected {
                        Text(backup.connectedEmail ?? "Connected").font(.ftHeadline).foregroundStyle(FTColor.catCoral)
                    } else {
                        Text("Not Connected").font(.ftHeadline).foregroundStyle(FTColor.textMuted)
                    }
                    if let last = backup.lastBackupDate {
                        Text("Last backup: \(last.relativeFormatted)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    } else {
                        Text("No backup sent yet").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle().fill((backup.isConnected ? FTColor.catCoral : FTColor.textMuted).opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "envelope.badge.shield.half.filled.fill")
                        .font(.ftTitle)
                        .foregroundStyle(backup.isConnected ? FTColor.catCoral : FTColor.textMuted)
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
                            let ok = await backup.performBackup(context: context)
                            if !ok {
                                resultMessage = backup.lastError ?? "Backup failed."
                                showingResult = true
                            }
                        }
                    } label: {
                        Label(backup.isBackingUp ? "Backing Up…" : "Back Up Now",
                              systemImage: backup.isBackingUp ? "arrow.clockwise" : "envelope.arrow.triangle.branch")
                            .font(.ftBodySemibold)
                            .foregroundStyle(backup.isBackingUp ? FTColor.textMuted : .white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(backup.isBackingUp ? FTColor.catCoral.opacity(0.1) : FTColor.catCoral,
                                        in: RoundedRectangle(cornerRadius: FTRadius.md))
                    }
                    .disabled(backup.isBackingUp || backup.isRestoring)

                    Button {
                        showingRestoreConfirm = true
                    } label: {
                        Label("Restore", systemImage: "icloud.and.arrow.down")
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.catCoral)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(FTColor.catCoral.opacity(0.1), in: RoundedRectangle(cornerRadius: FTRadius.md))
                    }
                    .disabled(backup.isBackingUp || backup.isRestoring)
                }

                Button(role: .destructive) {
                    backup.disconnect()
                } label: {
                    Text("Disconnect").font(.ftCaption).foregroundStyle(FTColor.expense)
                }
            } else {
                Button {
                    showingSignIn = true
                } label: {
                    Label("Sign In to Email", systemImage: "envelope.badge.shield.half.filled.fill")
                        .font(.ftBodySemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(FTColor.catCoral, in: RoundedRectangle(cornerRadius: FTRadius.md))
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            FTToggleRow(symbol: "clock.arrow.circlepath", tint: FTColor.catCoral,
                        title: "Automatic Daily Backup",
                        isOn: Binding(
                            get: { backup.backupEnabled },
                            set: { backup.backupEnabled = $0 }
                        ))
            Divider().background(FTColor.textMuted.opacity(0.3))
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

    // MARK: - Privacy Card

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.ftHeadline).foregroundStyle(FTColor.income)
                Text("PRIVACY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            }
            privacyRow("key.fill", "No OAuth, no developer setup — just your email address and an app-specific password, verified directly against your mail server")
            privacyRow("lock.doc.fill", "Turn on Backup Encryption (Settings → Data & Privacy) to protect the file's contents even though it travels as an email attachment")
            privacyRow("envelope.fill", "The backup is sent from your address to your address — it never goes anywhere else")
            privacyRow("key.icloud.fill", "Your password is stored in the iOS Keychain, wiped instantly on disconnect")
        }
        .padding()
        .ftGlass(FTRadius.lg)
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

// MARK: - EmailBackupSignInSheet
// Direct email + app-specific password sign-in — verified against both the
// SMTP (send) and IMAP (restore) servers before saving. No OAuth, no
// third-party console.

private struct EmailBackupSignInSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var smtpHost = ""
    @State private var imapHost = ""
    @State private var hostEdited = false
    @State private var isConnecting = false
    @State private var errorMessage: String? = nil

    private var canConnect: Bool {
        email.contains("@") && !password.isEmpty && !smtpHost.isEmpty && !imapHost.isEmpty && !isConnecting
    }

    private var domain: String { email.components(separatedBy: "@").last?.lowercased() ?? "" }

    private var requiresAppPassword: Bool {
        ["icloud.com", "me.com", "mac.com", "gmail.com", "googlemail.com", "yahoo.com", "ymail.com"].contains(domain)
    }

    private var passwordHelp: String {
        if ["icloud.com", "me.com", "mac.com"].contains(domain) {
            return "iCloud requires an app-specific password: appleid.apple.com → Sign-In & Security → App-Specific Passwords → generate one for FinTrack."
        }
        if ["gmail.com", "googlemail.com"].contains(domain) {
            return "Gmail requires an App Password: myaccount.google.com/apppasswords (2-Step Verification must be on). Your normal Gmail password won't work here."
        }
        if ["yahoo.com", "ymail.com"].contains(domain) {
            return "Yahoo requires an app password: Yahoo Account Security → Generate app password."
        }
        return "Try your regular email password first. If sign-in fails, your provider likely requires an app-specific password — check its account security settings for one."
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Email").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("you@example.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .onChange(of: email) {
                                        guard !hostEdited else { return }
                                        smtpHost = EmailBackupService.suggestedSMTPHost(for: email)
                                        imapHost = EmailSyncService.suggestedIMAPHost(for: email)
                                    }
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text(requiresAppPassword ? "App Password" : "Password").font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
                                Spacer()
                                SecureField(requiresAppPassword ? "xxxx-xxxx-xxxx-xxxx" : "Password", text: $password)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("SMTP Server").font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
                                Spacer()
                                TextField("smtp.example.com", text: $smtpHost)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                    .onChange(of: smtpHost) { hostEdited = true }
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("IMAP Server").font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
                                Spacer()
                                TextField("imap.example.com", text: $imapHost)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                    .onChange(of: imapHost) { hostEdited = true }
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        HStack(alignment: .top, spacing: FTSpacing.sm) {
                            Image(systemName: "key.fill")
                                .font(.ftCaption).foregroundStyle(FTColor.gold)
                                .frame(width: 20)
                            Text(passwordHelp)
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        HStack(alignment: .top, spacing: FTSpacing.sm) {
                            Image(systemName: "lock.shield.fill")
                                .font(.ftCaption).foregroundStyle(FTColor.income)
                                .frame(width: 20)
                            Text("TLS-only connection directly to your mail servers. Your password is stored in the iOS Keychain and never sent anywhere but your own mail provider.")
                                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.ftCaption).foregroundStyle(FTColor.expense)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Color.clear.frame(height: 110)
                    }
                    .padding(FTSpacing.screen)
                }

                PrimaryButton(isConnecting ? "Connecting…" : "Sign In & Verify",
                              icon: "envelope.badge.shield.half.filled.fill",
                              isLoading: isConnecting) {
                    signIn()
                }
                .disabled(!canConnect)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.md)
            }
            .navigationTitle("Sign In to Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func signIn() {
        isConnecting = true
        errorMessage = nil
        let cleanEmail = email.trimmingCharacters(in: .whitespaces)
        let cleanSMTPHost = smtpHost.trimmingCharacters(in: .whitespaces)
        let cleanIMAPHost = imapHost.trimmingCharacters(in: .whitespaces)
        // App passwords are shown in spaced groups by Google/Apple/Yahoo but
        // never contain spaces themselves — strip whatever copying dragged along.
        var cleanPassword = password
        if requiresAppPassword {
            cleanPassword = cleanPassword.components(separatedBy: .whitespacesAndNewlines).joined()
        }
        Task {
            do {
                try await EmailBackupService.shared.connect(
                    email: cleanEmail, password: cleanPassword,
                    smtpHost: cleanSMTPHost, imapHost: cleanIMAPHost)
                isConnecting = false
                dismiss()
            } catch {
                isConnecting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
