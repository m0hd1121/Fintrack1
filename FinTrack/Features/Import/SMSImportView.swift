import SwiftUI
import SwiftData

// MARK: - SMSImportView
//
// SMS notifications never reach a third-party app directly — there's no iOS
// read API for them. Instead, this screen walks the user through creating a
// Shortcuts "When I receive a message" Personal Automation per bank, which
// hands the message text to `LogTransactionFromText` (FinTrackIntents.swift).
// Parsing (on-device template match, falling back to Apple Intelligence)
// happens entirely on the phone — see `BankSMSParser`.
//
// Per-bank config reuses `BankEmailRule` (see `SMSIngestService`) tagged
// with a "sms:" sender prefix, so this feature needed no new model.

struct SMSImportView: View {
    @Environment(\.modelContext) private var context

    @Query private var allBankRules: [BankEmailRule]
    private var smsRules: [BankEmailRule] {
        allBankRules.filter { $0.senderEmail.hasPrefix("sms:") }
    }

    @State private var showingAddBank = false
    @State private var editingRule: BankEmailRule? = nil
    @State private var unparsed: [SMSIngestService.UnparsedSMS] = []

    private let setupStartedKey = "ft_sms_setup_started_at"

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                statusCard
                shortcutsCard
                unrecognizedSection
                banksSection
                privacyCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("SMS Import")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .onAppear {
            if UserDefaults.standard.object(forKey: setupStartedKey) == nil {
                UserDefaults.standard.set(Date(), forKey: setupStartedKey)
            }
            unparsed = SMSIngestService.unparsedMessages
        }
        .sheet(isPresented: $showingAddBank) { SMSBankRuleSheet() }
        .sheet(item: $editingRule) { rule in SMSBankRuleSheet(editingRule: rule) }
    }

    // MARK: - Status

    private var setupStartedAt: Date {
        (UserDefaults.standard.object(forKey: setupStartedKey) as? Date) ?? Date()
    }

    private var lastImportAt: Date? {
        UserDefaults.standard.object(forKey: SMSIngestService.lastImportKey) as? Date
    }

    private var firstImportLanded: Bool {
        guard let lastImportAt else { return false }
        return lastImportAt >= setupStartedAt
    }

    private var withinFirstDay: Bool {
        Date().timeIntervalSince(setupStartedAt) < 86_400
    }

    private var statusCard: some View {
        HStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle()
                    .fill((firstImportLanded ? FTColor.income : FTColor.textMuted).opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: firstImportLanded ? "checkmark.circle.fill" : "message.badge.fill")
                    .font(.ftTitle)
                    .foregroundStyle(firstImportLanded ? FTColor.income : FTColor.textMuted)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(firstImportLanded ? "SMS Import Working"
                     : withinFirstDay ? "Waiting for Your First SMS" : "No SMS Received Yet")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text(firstImportLanded
                     ? "Last one \(lastImportAt?.relativeFormatted ?? "")"
                     : withinFirstDay
                        ? "Set up the automation below, then trigger a real bank SMS to confirm it"
                        : "Double-check the automation is on and not set to “Ask Before Running”")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Shortcuts setup

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("SET UP IN SHORTCUTS")
                .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(FTColor.textMuted)

            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                stepRow(1, "Open Shortcuts → Automation → “+” → Message")
                stepRow(2, "Under “When”, tap From and select every bank you get SMS alerts from — one automation covers all of them at once")
                stepRow(3, "For what it does, choose “Create New Shortcut” — not the ready-made “Log Transaction” tile, which can't take the message text")
                stepRow(4, "In the editor: Add Action → search FinTrack → Log Transaction, then tap the Message field and insert the “Shortcut Input” variable")
                stepRow(5, "Turn off “Ask Before Running”, then Done")
            }
            Text("Which bank sent it, what the transaction was, and matching it to an account all happen automatically inside FinTrack — nothing below is required for that to work.")
                .font(.ftCaption).foregroundStyle(FTColor.textMuted)

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

    // MARK: - Messages that arrived but produced no transaction

    @ViewBuilder
    private var unrecognizedSection: some View {
        if !unparsed.isEmpty {
            VStack(spacing: FTSpacing.md) {
                HStack {
                    Text("NOT RECOGNIZED")
                        .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Button {
                        SMSIngestService.clearUnparsed()
                        unparsed = []
                    } label: {
                        Text("Clear").font(.ftCaption).foregroundStyle(FTColor.accent)
                    }
                }

                Text("These messages reached FinTrack but no transaction could be read from them — either they weren't about a payment, or the bank's wording isn't recognized yet.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(unparsed) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.senderId?.isEmpty == false ? item.senderId! : "Unknown sender")
                                .font(.ftCallout).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(item.receivedAt.relativeFormatted)
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        Text(item.rawText.isEmpty ? "(empty message)" : item.rawText)
                            .font(.ftCaption)
                            .foregroundStyle(item.rawText.isEmpty ? FTColor.expense : FTColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ftGlass(FTRadius.md)
                }
            }
        }
    }

    // MARK: - Configured banks

    private var banksSection: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                Text("MY BANKS (OPTIONAL)")
                    .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false).foregroundStyle(FTColor.textMuted)
                Spacer()
                Button { showingAddBank = true } label: {
                    Label("Add Bank", systemImage: "plus")
                        .font(.ftCaption).foregroundStyle(FTColor.accent)
                }
            }

            if smsRules.isEmpty {
                Text("Nothing to set up here — SMS from any bank is recognized and parsed automatically. Add one only if you want its transactions pinned to a specific account.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .ftGlass(FTRadius.md)
            } else {
                ForEach(smsRules, id: \.id) { rule in
                    Button { editingRule = rule } label: {
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(symbol: "building.columns.fill",
                                       tint: rule.isEnabled ? FTColor.accent : FTColor.textMuted, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.displayName)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                                Text("\(rule.matchedCount) matched")
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        .padding()
                        .ftGlass(FTRadius.md)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Privacy

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(alignment: .top, spacing: FTSpacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.ftCaption).foregroundStyle(FTColor.income).frame(width: 20)
                Text("Message text is parsed entirely on this device — first against a bank-identity list, then, only if that fails, with Apple Intelligence's on-device model. Nothing about your SMS is ever uploaded.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            HStack(alignment: .top, spacing: FTSpacing.sm) {
                Image(systemName: "tray.fill")
                    .font(.ftCaption).foregroundStyle(FTColor.catBlue).frame(width: 20)
                Text("Every parsed SMS waits in the same review queue as email imports — nothing is ever added to your transactions without you tapping Approve.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }
}

// MARK: - SMSBankRuleSheet

/// Add/edit one bank's SMS automation. Reuses `BankEmailRule` — `senderEmail`
/// carries the `"sms:<slug>"` tag `SMSIngestService` matches against instead
/// of an email address.
struct SMSBankRuleSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editingRule: BankEmailRule? = nil

    @State private var bankName = BankSMSTemplateStore.active.first?.bankName ?? ""
    @State private var isCustomBank = false
    @State private var customBankName = ""
    @State private var senderId = ""
    @State private var linkedAccountId: UUID? = nil

    @Query(sort: \Account.name) private var accounts: [Account]

    private var isEditing: Bool { editingRule != nil }
    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }
    private var effectiveBankName: String {
        (isCustomBank ? customBankName : bankName).trimmingCharacters(in: .whitespaces)
    }
    private var canSave: Bool { !effectiveBankName.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        bankSection
                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }
                PrimaryButton(isEditing ? "Save Changes" : "Add Bank", icon: "checkmark.circle.fill") {
                    save()
                }
                .disabled(!canSave)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.md)
            }
            .navigationTitle(isEditing ? "Edit Bank" : "Add Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear(perform: populateForEditing)
        }
    }

    private var bankSection: some View {
        VStack(spacing: 0) {
            wizardField("Bank") {
                Picker("", selection: $bankName) {
                    ForEach(BankSMSTemplateStore.active) { template in
                        Text(template.bankName).tag(template.bankName)
                    }
                    Text("Other…").tag("")
                }
                .pickerStyle(.menu)
                .accentColor(FTColor.accent)
                .onChange(of: bankName) { _, newValue in isCustomBank = newValue.isEmpty }
            }
            if isCustomBank {
                Divider().opacity(0.4)
                wizardField("Bank Name") {
                    TextField("e.g. My Bank", text: $customBankName)
                        .multilineTextAlignment(.trailing)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                }
            }
            Divider().opacity(0.4)
            wizardField("SMS Sender ID") {
                TextField("optional, as shown in Messages", text: $senderId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
            Divider().opacity(0.4)
            wizardField("Post To Account") {
                Picker("", selection: $linkedAccountId) {
                    Text("Match by card digits").tag(Optional<UUID>(nil))
                    ForEach(activeAccounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                .pickerStyle(.menu)
                .accentColor(FTColor.accent)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private func wizardField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
            Spacer()
            content()
        }
        .padding(.vertical, 13)
    }

    private func populateForEditing() {
        guard let rule = editingRule else { return }
        let slug = String(rule.senderEmail.dropFirst("sms:".count))
        if let template = BankSMSTemplateStore.active.first(where: { BankSMSTemplateStore.slug($0.bankName) == slug }) {
            bankName = template.bankName
            isCustomBank = false
        } else {
            isCustomBank = true
            bankName = ""
            customBankName = rule.bankName
        }
        senderId = rule.keywords.first ?? ""
        linkedAccountId = rule.linkedAccountId
    }

    private func save() {
        let name = effectiveBankName
        let tag = "sms:" + BankSMSTemplateStore.slug(name)
        let senderKeywords = senderId.trimmingCharacters(in: .whitespaces).isEmpty
            ? [] : [senderId.trimmingCharacters(in: .whitespaces)]

        if let rule = editingRule {
            rule.bankName = name
            rule.senderEmail = tag
            rule.keywords = senderKeywords
            rule.linkedAccountId = linkedAccountId
        } else {
            let rule = BankEmailRule(
                bankName: name,
                senderEmail: tag,
                keywords: senderKeywords,
                linkedAccountId: linkedAccountId
            )
            context.insert(rule)
        }
        try? context.save()
        dismiss()
    }
}
