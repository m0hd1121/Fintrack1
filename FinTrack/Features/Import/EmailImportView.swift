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

    @State private var syncService = EmailSyncService.shared
    @State private var showingPasteSheet = false
    @State private var pasteText = ""
    @State private var pasteResult: String? = nil
    @State private var connectError: String? = nil
    @State private var showingPrivacy = false

    private var pendingCount: Int { pendingItems.filter { $0.status == .pending }.count }
    private var approvedCount: Int { pendingItems.filter { $0.status == .approved }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                reviewQueueCard
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
        .alert("Connection Failed", isPresented: Binding(
            get: { connectError != nil },
            set: { if !$0 { connectError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(connectError ?? "")
        }
    }

    // MARK: - Review queue entry

    private var reviewQueueCard: some View {
        NavigationLink(destination: EmailReviewQueueView()) {
            HStack(spacing: FTSpacing.lg) {
                ZStack {
                    FTIconTile(symbol: "tray.full.fill", tint: FTColor.accent, size: 48)
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.ftCaption).bold().foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(FTColor.expense, in: .capsule)
                            .offset(x: 20, y: -20)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Review Queue").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text(pendingCount > 0
                         ? "\(pendingCount) transactions waiting for approval"
                         : "All caught up · \(approvedCount) approved so far")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            .padding()
            .ftGlassInteractive(FTRadius.lg)
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
                            Image(systemName: provider.supportsOAuthSync ? "plus.circle.fill" : "doc.on.clipboard")
                                .font(.ftHeadline)
                                .foregroundStyle(provider.supportsOAuthSync ? FTColor.accent : FTColor.textMuted)
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
                : "Requires OAuth setup — use Paste Email meanwhile"
        case .outlook:
            return syncService.isConfigured(.outlook)
                ? "OAuth sign-in · read-only · bank senders only"
                : "Requires OAuth setup — use Paste Email meanwhile"
        case .icloud, .imap:
            return "No sync API — paste or share bank emails instead"
        }
    }

    private func connect(_ provider: EmailProvider) {
        guard provider.supportsOAuthSync, syncService.isConfigured(provider) else {
            showingPasteSheet = true
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
