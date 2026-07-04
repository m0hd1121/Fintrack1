import SwiftUI
import SwiftData

// MARK: - EmailImportView
// Hub for email-based transaction import: connect mailboxes via OAuth,
// sync bank alerts, and jump into the review queue. UAE banks rarely offer
// open APIs — their transaction notification emails are the data source.

struct EmailImportView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \EmailAccount.connectedAt) private var emailAccounts: [EmailAccount]
    @Query private var pendingItems: [PendingEmailTransaction]
    @Query(sort: \BankEmailRule.createdAt) private var bankRules: [BankEmailRule]

    @State private var syncService = EmailSyncService.shared
    @State private var showingPasteSheet = false
    @State private var pasteText = ""
    @State private var pasteResult: String? = nil
    @State private var connectError: String? = nil
    @State private var showingPrivacy = false
    @State private var showingBankWizard = false
    @State private var editingBankRule: BankEmailRule? = nil
    @State private var oauthSetupProvider: EmailProvider? = nil
    @State private var imapSignInProvider: EmailProvider? = nil


    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                banksSection
                accountsSection
                connectSection
                manualImportSection
                privacyCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Email Import")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .sheet(isPresented: $showingPasteSheet) { pasteSheet }
        .sheet(isPresented: $showingBankWizard) { BankSetupWizardView() }
        .sheet(item: $editingBankRule) { rule in BankSetupWizardView(editingRule: rule) }
        .sheet(item: $oauthSetupProvider) { provider in
            OAuthSetupSheet(provider: provider) {
                oauthSetupProvider = nil
                connect(provider)
            }
        }
        .sheet(item: $imapSignInProvider) { provider in
            IMAPSignInSheet(provider: provider)
        }
        .alert("Connection Failed", isPresented: Binding(
            get: { connectError != nil },
            set: { if !$0 { connectError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(connectError ?? "")
        }
    }

    // MARK: - My banks (setup wizard rules)

    private var banksSection: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                Text("MY BANKS")
                    .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                Spacer()
                Button { showingBankWizard = true } label: {
                    Label("Add Bank", systemImage: "plus")
                        .font(.ftCaption).foregroundStyle(FTColor.accent)
                }
            }

            if bankRules.isEmpty {
                Button { showingBankWizard = true } label: {
                    HStack(spacing: FTSpacing.lg) {
                        FTIconTile(symbol: "building.columns.fill", tint: FTColor.gold, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Set Up Your First Bank")
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Text("Tell the app how your bank's alert emails look — imports become fully automatic")
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    .padding()
                    .ftGlassInteractive(FTRadius.md)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(bankRules, id: \.id) { rule in
                    bankRuleRow(rule)
                }
            }
        }
    }

    private func bankRuleRow(_ rule: BankEmailRule) -> some View {
        Button { editingBankRule = rule } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "building.columns.fill",
                           tint: rule.isEnabled ? FTColor.accent : FTColor.textMuted, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.displayName)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                    Text("\(rule.senderEmail.isEmpty ? rule.senderDomain : rule.senderEmail) · \(rule.matchedCount) matched")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted).lineLimit(1)
                }
                Spacer()
                if rule.autoApprove {
                    BadgeView(text: "Auto ≥\(Int(rule.confidenceThreshold * 100))%", color: FTColor.income)
                }
                Menu {
                    Toggle("Enabled", isOn: Binding(
                        get: { rule.isEnabled },
                        set: { rule.isEnabled = $0; try? context.save() }
                    ))
                    Button(role: .destructive) {
                        context.delete(rule)
                        try? context.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.ftHeadline).foregroundStyle(FTColor.textMuted)
                }
            }
            .padding(FTSpacing.md)
            .ftGlassInteractive(FTRadius.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connected accounts

    @ViewBuilder
    private var accountsSection: some View {
        if !emailAccounts.isEmpty {
            VStack(spacing: FTSpacing.md) {
                HStack {
                    Text("CONNECTED ACCOUNTS")
                        .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                    Spacer()
                    if syncService.isSyncing {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Button {
                            Task { await syncService.syncAll(accounts: emailAccounts, context: context) }
                        } label: {
                            Label("Sync Now", systemImage: "arrow.clockwise")
                                .font(.ftCaption).foregroundStyle(FTColor.accent)
                        }
                    }
                }

                ForEach(emailAccounts, id: \.id) { account in
                    accountRow(account)
                }

                if let summary = syncService.lastSyncSummary {
                    Text(summary).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                if let error = syncService.lastSyncError {
                    Text(error).font(.ftCaption).foregroundStyle(FTColor.expense)
                }
            }
        }
    }

    private func accountRow(_ account: EmailAccount) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: account.provider.icon,
                       tint: Color.fromString(account.provider.colorName), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.emailAddress)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                Text(account.lastSyncAt.map { "Synced \($0.relativeFormatted) · \(account.totalTransactionsParsed) parsed" }
                     ?? "Never synced")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            Menu {
                Toggle("Sync Enabled", isOn: Binding(
                    get: { account.syncEnabled },
                    set: { account.syncEnabled = $0; try? context.save() }
                ))
                Button(role: .destructive) {
                    syncService.disconnect(account: account, context: context, pendingItems: pendingItems)
                } label: {
                    Label("Disconnect", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.ftHeadline).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Connect providers

    private var connectSection: some View {
        VStack(spacing: FTSpacing.md) {
            Text("CONNECT A MAILBOX")
                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(EmailProvider.allCases, id: \.self) { provider in
                Button {
                    connect(provider)
                } label: {
                    HStack(spacing: FTSpacing.lg) {
                        FTIconTile(symbol: provider.icon,
                                   tint: Color.fromString(provider.colorName), size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(provider.rawValue)
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Text(providerSubtitle(provider))
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        Spacer()
                        if syncService.isConnecting {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.ftHeadline)
                                .foregroundStyle(FTColor.accent)
                        }
                    }
                    .padding()
                    .ftGlassInteractive(FTRadius.md)
                }
                .buttonStyle(.plain)
                .disabled(syncService.isConnecting)
            }
        }
    }

    private func providerSubtitle(_ provider: EmailProvider) -> String {
        switch provider {
        case .gmail:
            return syncService.isConfigured(.gmail)
                ? "OAuth sign-in · read-only · bank senders only"
                : "Sign in with your Gmail + Google App Password"
        case .outlook:
            return syncService.isConfigured(.outlook)
                ? "OAuth sign-in · read-only · bank senders only"
                : "Tap for one-time setup (Microsoft requires OAuth)"
        case .icloud:
            return "Sign in with your Apple ID email + app-specific password"
        case .imap:
            return "Any mail provider — sign in with an app password"
        }
    }

    private func connect(_ provider: EmailProvider) {
        // Direct email sign-in (app password over IMAP) is the default for
        // everything except Outlook — Microsoft disabled password IMAP in
        // 2024, so Outlook requires the OAuth client ID. Gmail uses OAuth
        // automatically once a client ID has been configured.
        if !provider.supportsOAuthSync {
            imapSignInProvider = provider
            return
        }
        if !syncService.isConfigured(provider) {
            if provider == .gmail {
                imapSignInProvider = provider   // sign in with Google App Password
            } else {
                oauthSetupProvider = provider   // Outlook: OAuth is the only way
            }
            return
        }
        Task {
            do {
                let account = try await syncService.connect(provider: provider, context: context)
                await syncService.syncAll(accounts: [account], context: context)
            } catch EmailSyncError.authCancelled {
                // user backed out — no error UI
            } catch {
                connectError = error.localizedDescription
            }
        }
    }

    // MARK: - Manual import

    private var manualImportSection: some View {
        VStack(spacing: FTSpacing.md) {
            Text("MANUAL IMPORT")
                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { showingPasteSheet = true } label: {
                HStack(spacing: FTSpacing.lg) {
                    FTIconTile(symbol: "doc.on.clipboard.fill", tint: FTColor.catTeal, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Paste a Bank Email")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text("Copy any bank alert email and paste it here")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                .padding()
                .ftGlassInteractive(FTRadius.md)
            }
            .buttonStyle(.plain)

            Button {
                let count = syncService.importSampleEmails(context: context)
                pasteResult = count > 0 ? "\(count) sample emails parsed into the queue" : "Samples already imported"
            } label: {
                HStack(spacing: FTSpacing.lg) {
                    FTIconTile(symbol: "sparkles", tint: FTColor.gold, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Try With Sample Emails")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text("See the full parse → review → approve flow safely")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                .padding()
                .ftGlassInteractive(FTRadius.md)
            }
            .buttonStyle(.plain)

            if let result = pasteResult {
                Text(result).font(.ftCaption).foregroundStyle(FTColor.income)
            }
        }
    }

    // MARK: - Privacy card

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.ftHeadline).foregroundStyle(FTColor.income)
                Text("PRIVACY BY DESIGN")
                    .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                Spacer()
                Button { withAnimation { showingPrivacy.toggle() } } label: {
                    Image(systemName: showingPrivacy ? "chevron.up" : "chevron.down")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }

            if showingPrivacy {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    privacyRow("key.fill", "OAuth only — the app never sees your email password")
                    privacyRow("envelope.badge.shield.half.filled.fill", "Read-only scope, restricted to known bank senders")
                    privacyRow("iphone", "All parsing happens on this device — nothing is uploaded")
                    privacyRow("trash.slash.fill", "Raw emails are discarded after parsing; only extracted fields are kept")
                    privacyRow("key.icloud.fill", "Tokens live in the iOS Keychain, wiped instantly on disconnect")
                    privacyRow("doc.text.magnifyingglass", "Every import is logged in the Security audit trail with its reason")
                }
            } else {
                Text("OAuth sign-in, read-only bank senders, on-device parsing. Tap to learn more.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
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

    // MARK: - Paste sheet

    private var pasteSheet: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                VStack(spacing: FTSpacing.lg) {
                    Text("Paste the full text of a bank notification email — including the From and Subject lines if you have them.")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $pasteText)
                        .font(.ftBody)
                        .scrollContentBackground(.hidden)
                        .padding(FTSpacing.sm)
                        .frame(minHeight: 220)
                        .ftGlass(FTRadius.md)

                    Spacer()
                }
                .padding(FTSpacing.screen)

                PrimaryButton("Parse Email", icon: "wand.and.stars") {
                    let created = EmailSyncService.shared.importPastedEmail(pasteText, context: context)
                    pasteResult = created
                        ? "Transaction detected — waiting in the review queue"
                        : "No transaction found in that text"
                    pasteText = ""
                    showingPasteSheet = false
                }
                .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.md)
            }
            .navigationTitle("Paste Bank Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingPasteSheet = false }
                }
            }
        }
    }
}

// MARK: - IMAPSignInSheet
// Direct in-app email sign-in over IMAP/TLS with an app-specific password.
// No developer registration needed — works today for iCloud, Yahoo, and any
// IMAP mailbox. The password is verified against the mail server, stored in
// the Keychain, and never leaves the device otherwise.

private struct IMAPSignInSheet: View {
    let provider: EmailProvider

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var email = ""
    @State private var password = ""
    @State private var host = ""
    @State private var hostEdited = false
    @State private var isConnecting = false
    @State private var errorMessage: String? = nil

    private var canConnect: Bool {
        email.contains("@") && !password.isEmpty && !host.isEmpty && !isConnecting
    }

    private var passwordHelp: String {
        let domain = email.components(separatedBy: "@").last?.lowercased() ?? ""
        if provider == .icloud || ["icloud.com", "me.com", "mac.com"].contains(domain) {
            return "iCloud requires an app-specific password: appleid.apple.com → Sign-In & Security → App-Specific Passwords → generate one for FinTrack."
        }
        if provider == .gmail || ["gmail.com", "googlemail.com"].contains(domain) {
            return "Gmail requires an App Password: open myaccount.google.com/apppasswords, sign in, and generate one for FinTrack (2-Step Verification must be on). Your normal Gmail password won't work here."
        }
        if ["yahoo.com", "ymail.com"].contains(domain) {
            return "Yahoo requires an app password: Yahoo Account Security → Generate app password."
        }
        return "Most providers require an app-specific password for IMAP — check your mail provider's security settings."
    }

    private var defaultHost: String {
        switch provider {
        case .gmail:  return "imap.gmail.com"
        case .icloud: return "imap.mail.me.com"
        default:      return ""
        }
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
                                TextField("you@icloud.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .onChange(of: email) {
                                        guard !hostEdited else { return }
                                        host = EmailSyncService.suggestedIMAPHost(for: email)
                                    }
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("App Password").font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
                                Spacer()
                                SecureField("xxxx-xxxx-xxxx-xxxx", text: $password)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("IMAP Server").font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
                                Spacer()
                                TextField("imap.mail.me.com", text: $host)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                    .onChange(of: host) { _, _ in
                                        if host != EmailSyncService.suggestedIMAPHost(for: email) {
                                            hostEdited = true
                                        }
                                    }
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
                            Text("TLS-only connection directly to your mail server. The password is stored in the iOS Keychain and only bank-sender emails from the last 30 days are ever searched.")
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

                PrimaryButton(isConnecting ? "Connecting…" : "Sign In & Sync",
                              icon: "envelope.badge.shield.half.filled.fill",
                              isLoading: isConnecting) {
                    signIn()
                }
                .disabled(!canConnect)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.md)
            }
            .navigationTitle("Sign In to \(provider.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if host.isEmpty { host = defaultHost }
            }
        }
    }

    private func signIn() {
        isConnecting = true
        errorMessage = nil
        let cleanEmail = email.trimmingCharacters(in: .whitespaces)
        let cleanHost = host.trimmingCharacters(in: .whitespaces)
        // Google/Apple/Yahoo app passwords never contain spaces, but the
        // providers display them in spaced groups — strip whatever copying
        // dragged along so a pasted password just works.
        var password = self.password
        let appPasswordHosts = ["imap.gmail.com", "imap.mail.me.com", "imap.mail.yahoo.com", "imap.aol.com"]
        if appPasswordHosts.contains(cleanHost.lowercased()) {
            password = password.components(separatedBy: .whitespacesAndNewlines).joined()
        }
        Task {
            do {
                let account = try await EmailSyncService.shared.connectIMAP(
                    email: cleanEmail, password: password, host: cleanHost,
                    provider: provider, context: context)
                await EmailSyncService.shared.syncAll(accounts: [account], context: context)
                isConnecting = false
                dismiss()
            } catch {
                isConnecting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - OAuthSetupSheet
// One-time setup: Google/Microsoft only allow mailbox access to registered
// OAuth apps, so the owner creates a (free) client ID once and pastes it
// here. After that, connecting is a normal sign-in — fully automatic.

private struct OAuthSetupSheet: View {
    let provider: EmailProvider
    let onConfigured: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var clientId = ""

    private var steps: [String] {
        switch provider {
        case .gmail:
            return [
                "Open console.cloud.google.com and create a project (free)",
                "APIs & Services → Library → enable “Gmail API”",
                "APIs & Services → OAuth consent screen → External → add your own Gmail as a test user",
                "Credentials → Create Credentials → OAuth client ID → type “iOS”, bundle ID of this app",
                "Copy the Client ID (ends in .apps.googleusercontent.com) and paste it below",
            ]
        case .outlook:
            return [
                "Open portal.azure.com → Microsoft Entra ID → App registrations → New registration",
                "Supported accounts: “Personal Microsoft accounts and any organization”",
                "Add a redirect URI of type “Mobile and desktop”: fintrack://oauth-callback",
                "API permissions → add Microsoft Graph → Delegated → Mail.Read",
                "Copy the Application (client) ID and paste it below",
            ]
        default:
            return []
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: FTSpacing.lg) {
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: "key.horizontal.fill", tint: FTColor.gold, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("One-Time Setup Required")
                                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                                Text("\(provider.rawValue) only allows registered apps to read mail — even read-only. Create your free client ID once; every sync after that is automatic.")
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            }
                        }
                        .padding()
                        .ftGlass(FTRadius.md)

                        VStack(alignment: .leading, spacing: FTSpacing.md) {
                            Text("STEPS")
                                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: FTSpacing.sm) {
                                    Text("\(index + 1)")
                                        .font(.ftCaption).bold().foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(FTColor.accent, in: .circle)
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
                                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                            TextField(provider == .gmail
                                      ? "xxxx.apps.googleusercontent.com"
                                      : "00000000-0000-0000-0000-000000000000",
                                      text: $clientId, axis: .vertical)
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

                PrimaryButton("Save & Connect \(provider.rawValue)", icon: "checkmark.circle.fill") {
                    EmailSyncService.saveClientId(clientId, for: provider)
                    onConfigured()
                }
                .disabled(clientId.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.md)
            }
            .navigationTitle("Connect \(provider.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                clientId = EmailSyncService.storedClientId(for: provider) ?? ""
            }
        }
    }
}
