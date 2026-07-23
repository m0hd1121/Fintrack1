import SwiftUI
import UIKit

// Settings screen for the Cloudflare email-sync backend. Lets the user enable
// cloud sync, enter the Worker URL + API key + forwarding domain, see the
// address to forward bank alerts to, and sync/register on demand.
struct CloudEmailSyncView: View {
    private let service = RemoteEmailSyncService.shared

    @State private var enabled = false
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var domain = ""
    @State private var statusMessage = ""
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpacing.lg) {
                enableCard
                if enabled {
                    connectionCard
                    forwardingCard
                    actionsCard
                }
                infoText
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.lg)
            .padding(.bottom, 40)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Cloud Email Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            enabled = service.isEnabled
            baseURL = service.baseURL
            apiKey = service.apiKey
            domain = service.forwardingDomain
        }
    }

    // MARK: Enable

    private var enableCard: some View {
        VStack(spacing: 0) {
            FTToggleRow(symbol: "cloud.fill", tint: FTColor.accent,
                        title: "Cloud Email Sync",
                        isOn: Binding(
                            get: { enabled },
                            set: { newValue in
                                enabled = newValue
                                service.isEnabled = newValue
                                if newValue { Task { await service.enablePush() } }
                            }
                        ))
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: Connection

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("BACKEND").font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(FTColor.textSecondary)

            field("Worker URL", text: $baseURL, placeholder: "https://fintrack-email-sync.you.workers.dev", keyboard: .URL)
            Divider().opacity(0.4)
            field("API Key", text: $apiKey, placeholder: "APP_API_KEY", secure: true)
            Divider().opacity(0.4)
            field("Forwarding Domain", text: $domain, placeholder: "sync.yourdomain.com", keyboard: .URL)

            Button {
                service.baseURL = baseURL
                service.apiKey = apiKey
                service.forwardingDomain = domain
                Task {
                    await service.enablePush()
                    await service.registerDevice()
                    statusMessage = "Saved. Device registered for push."
                }
            } label: {
                Text("Save & Register Device")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
            }
            .padding(.top, FTSpacing.xs)
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }

    // MARK: Forwarding address

    private var forwardingCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("FORWARD BANK ALERTS TO").font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(FTColor.textSecondary)
            if service.forwardingAddress.isEmpty {
                Text("Enter a forwarding domain above to get your address.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            } else {
                HStack {
                    Text(service.forwardingAddress)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = service.forwardingAddress
                        statusMessage = "Address copied."
                    } label: {
                        Image(systemName: "doc.on.doc").foregroundStyle(FTColor.accent)
                    }
                }
                Text("In your mailbox, add a rule that forwards your bank's alert emails to this address.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }

    // MARK: Actions / status

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Button {
                isWorking = true
                Task {
                    let n = await service.syncPending()
                    statusMessage = service.lastError ?? "Synced — \(n) new transaction\(n == 1 ? "" : "s")."
                    isWorking = false
                }
            } label: {
                HStack(spacing: FTSpacing.sm) {
                    if isWorking { ProgressView().scaleEffect(0.8) }
                    Text("Sync Now").font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                }
            }
            .disabled(isWorking || !service.isConfigured)

            if let last = service.lastSyncDate {
                Text("Last synced \(last.relativeFormatted)")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            if !statusMessage.isEmpty {
                Text(statusMessage).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }

    private var infoText: some View {
        Text("Bank alerts you forward are parsed in the background and pushed to your phone. Tap the notification to review, then confirm, reject, or edit the transaction — the same review queue used for on-device email import.")
            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Helpers

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                }
            }
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
        .padding(.vertical, 4)
    }
}
