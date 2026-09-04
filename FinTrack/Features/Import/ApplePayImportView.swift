import SwiftUI
import SwiftData

// MARK: - ApplePayImportView
//
// Setup + diagnostics for the Apple Pay channel. Shortcuts has a built-in
// "Transaction" Personal Automation that fires on a Wallet payment and hands
// over structured fields (amount, merchant, date, category) — no text to
// parse, unlike the SMS channel. Everything lands in the same review queue.

struct ApplePayImportView: View {
    @State private var received: [ApplePayIngestService.ReceivedApplePay] = []
    @State private var queuedCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                statusCard
                setupCard
                recentSection
                infoCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Apple Pay Import")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .onAppear {
            received = ApplePayIngestService.receivedTransactions
            queuedCount = WidgetDataService.shared.pendingApplePayCount
        }
    }

    // MARK: Status

    private var lastImportAt: Date? {
        UserDefaults.standard.object(forKey: ImportChannel.applePay.lastImportKey) as? Date
    }

    private var statusCard: some View {
        HStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle()
                    .fill((lastImportAt != nil ? FTColor.income : FTColor.textMuted).opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: lastImportAt != nil ? "checkmark.circle.fill" : "creditcard.fill")
                    .font(.ftTitle)
                    .foregroundStyle(lastImportAt != nil ? FTColor.income : FTColor.textMuted)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(lastImportAt != nil ? "Apple Pay Import Working" : "Not Set Up Yet")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text(lastImportAt != nil
                     ? "Last one \(lastImportAt?.relativeFormatted ?? "")"
                     : "Create the Shortcuts automation below to capture Apple Pay payments")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("SET UP IN SHORTCUTS")
                .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(FTColor.textMuted)

            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                stepRow(1, "Open Shortcuts → Automation → “+” → Transaction")
                stepRow(2, "Pick the card(s) you pay with; leave merchant and category unset to catch everything")
                stepRow(3, "For what it does, choose “Create New Shortcut” — not a ready-made tile")
                stepRow(4, "Add Action → FinTrack → Log Apple Pay Transaction, then map Amount, Merchant and Date to the automation's own variables")
                stepRow(5, "Turn off “Ask Before Running”, then Done")
            }

            Button {
                if let url = URL(string: "shortcuts://create-shortcut") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.forward.app.fill")
                    Text("Open Shortcuts")
                }
                .font(.ftBodySemibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(FTColor.accent, in: RoundedRectangle(cornerRadius: FTRadius.md))
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Text("\(number)")
                .font(.ftCaption).bold().foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(FTColor.accent, in: .circle)
            Text(text)
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
    }

    // MARK: Recent

    private var recentSection: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                Text("RECENT TRANSACTIONS")
                    .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(FTColor.textMuted)
                Spacer()
                if !received.isEmpty {
                    Button {
                        ApplePayIngestService.clearReceived()
                        received = []
                    } label: {
                        Text("Clear").font(.ftCaption).foregroundStyle(FTColor.accent)
                    }
                }
            }

            if queuedCount > 0 {
                Text("\(queuedCount) waiting to be processed — reopening this screen should clear them.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(FTColor.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: FTRadius.md))
            }

            if received.isEmpty {
                Text("Nothing has arrived from the Transaction automation yet.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .ftGlass(FTRadius.md)
            } else {
                ForEach(received) { item in
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: item.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.ftCallout)
                            .foregroundStyle(item.succeeded ? FTColor.income : FTColor.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.merchant.isEmpty ? "(no merchant)" : item.merchant)
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                            Text(item.outcome)
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        Spacer()
                        Text(item.receivedAt.relativeFormatted)
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    .padding()
                    .ftGlass(FTRadius.md)
                }
            }
        }
    }

    // MARK: Info

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(alignment: .top, spacing: FTSpacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.ftCaption).foregroundStyle(FTColor.income).frame(width: 20)
                Text("Wallet hands over the amount, merchant, date and category as real fields, so nothing has to be read out of text — this is more accurate than the SMS channel wherever it works.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            HStack(alignment: .top, spacing: FTSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.ftCaption).foregroundStyle(FTColor.gold).frame(width: 20)
                Text("It only sees payments made through Apple Pay. Chip-and-PIN, online card payments, transfers and cash still need the SMS channel — running both is fine, duplicates get flagged.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            HStack(alignment: .top, spacing: FTSpacing.sm) {
                Image(systemName: "tray.fill")
                    .font(.ftCaption).foregroundStyle(FTColor.catBlue).frame(width: 20)
                Text("Everything waits in the same review queue — nothing is added to your transactions until you approve it.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }
}
