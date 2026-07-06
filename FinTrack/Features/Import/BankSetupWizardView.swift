import SwiftUI
import SwiftData

// MARK: - BankSetupWizardView
// Add/edit one bank's email notification profile: what the bank's alert
// emails look like (sender, subject, keywords) and how automation should
// behave (auto-approval + confidence threshold). Configured once — after
// that, imports from this bank are fully automatic.

struct BankSetupWizardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editingRule: BankEmailRule? = nil

    // Bank & account
    @State private var bankName = ""
    @State private var nickname = ""
    @State private var accountType: AccountType = .current
    @State private var currency = "AED"
    @State private var linkedAccountId: UUID? = nil

    // Email matching
    @State private var senderEmail = ""
    @State private var senderDomain = ""
    @State private var subjectPattern = ""
    @State private var keywordsText = ""

    // Automation
    @State private var autoApprove = false
    @State private var confidenceThreshold = 0.9

    @Query(sort: \Account.name) private var accounts: [Account]

    private var isEditing: Bool { editingRule != nil }
    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }

    private var canSave: Bool {
        !bankName.trimmingCharacters(in: .whitespaces).isEmpty
            && !(senderEmail.trimmingCharacters(in: .whitespaces).isEmpty
                 && senderDomain.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        stepHeader(1, "Bank & Account")
                        bankSection
                        stepHeader(2, "How the Bank Emails You")
                        matchingSection
                        stepHeader(3, "Automation")
                        automationSection
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: populateForEditing)
        }
    }

    private func stepHeader(_ number: Int, _ title: String) -> some View {
        HStack(spacing: FTSpacing.sm) {
            Text("\(number)")
                .font(.ftCaption).bold().foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(FTColor.accent, in: .circle)
            Text(title.uppercased())
                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            Spacer()
        }
    }

    // MARK: - Step 1: Bank & Account

    private var bankSection: some View {
        VStack(spacing: 0) {
            wizardField("Bank Name") {
                TextField("e.g. Emirates NBD", text: $bankName)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            Divider().opacity(0.4)
            wizardField("Nickname") {
                TextField("optional, e.g. Salary Account", text: $nickname)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
            Divider().opacity(0.4)
            wizardField("Account Type") {
                Picker("", selection: $accountType) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .accentColor(FTColor.accent)
            }
            Divider().opacity(0.4)
            wizardField("Currency") {
                Picker("", selection: $currency) {
                    ForEach(CurrencyService.shared.supportedCurrencies) { info in
                        Text("\(info.flag) \(info.code)").tag(info.code)
                    }
                }
                .pickerStyle(.menu)
                .accentColor(FTColor.accent)
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

    // MARK: - Step 2: Email matching

    private var matchingSection: some View {
        VStack(spacing: 0) {
            wizardField("Sender Email") {
                TextField("alerts@bank.com", text: $senderEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            Divider().opacity(0.4)
            wizardField("Sender Domain") {
                TextField("optional, e.g. bank.com", text: $senderDomain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
            Divider().opacity(0.4)
            wizardField("Subject Contains") {
                TextField("optional, e.g. Transaction Alert", text: $subjectPattern)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
            Divider().opacity(0.4)
            wizardField("Keywords") {
                TextField("optional, comma separated", text: $keywordsText)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Step 3: Automation

    private var automationSection: some View {
        VStack(spacing: 0) {
            FTToggleRow(symbol: "checkmark.seal.fill", tint: FTColor.income,
                        title: "Auto-Approve High Confidence", isOn: $autoApprove)

            if autoApprove {
                Divider().opacity(0.4)
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    HStack {
                        Text("Confidence Threshold")
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text("\(Int(confidenceThreshold * 100))%")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                    }
                    Slider(value: $confidenceThreshold, in: 0.5...0.99, step: 0.01)
                        .tint(FTColor.accent)
                    Text("Transactions at or above this confidence are added automatically. Duplicates and suspicious parses always require review.")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                .padding(.vertical, FTSpacing.md)
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
        .animation(.snappy(duration: 0.25), value: autoApprove)
    }

    private func wizardField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary).fixedSize()
            Spacer()
            content()
        }
        .padding(.vertical, 13)
    }

    // MARK: - Save

    private func populateForEditing() {
        guard let rule = editingRule else { return }
        bankName = rule.bankName
        nickname = rule.nickname
        accountType = rule.accountType
        currency = rule.currency
        linkedAccountId = rule.linkedAccountId
        senderEmail = rule.senderEmail
        senderDomain = rule.senderDomain
        subjectPattern = rule.subjectPattern
        keywordsText = rule.keywords.joined(separator: ", ")
        autoApprove = rule.autoApprove
        confidenceThreshold = rule.confidenceThreshold
    }

    private func save() {
        let keywords = keywordsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let rule = editingRule {
            rule.bankName = bankName.trimmingCharacters(in: .whitespaces)
            rule.nickname = nickname.trimmingCharacters(in: .whitespaces)
            rule.accountType = accountType
            rule.currency = currency
            rule.linkedAccountId = linkedAccountId
            rule.senderEmail = senderEmail.trimmingCharacters(in: .whitespaces)
            rule.senderDomain = senderDomain.trimmingCharacters(in: .whitespaces)
            rule.subjectPattern = subjectPattern.trimmingCharacters(in: .whitespaces)
            rule.keywords = keywords
            rule.autoApprove = autoApprove
            rule.confidenceThreshold = confidenceThreshold
        } else {
            let rule = BankEmailRule(
                bankName: bankName.trimmingCharacters(in: .whitespaces),
                nickname: nickname.trimmingCharacters(in: .whitespaces),
                senderEmail: senderEmail.trimmingCharacters(in: .whitespaces),
                senderDomain: senderDomain.trimmingCharacters(in: .whitespaces),
                subjectPattern: subjectPattern.trimmingCharacters(in: .whitespaces),
                keywords: keywords,
                currency: currency,
                accountType: accountType,
                linkedAccountId: linkedAccountId,
                autoApprove: autoApprove,
                confidenceThreshold: confidenceThreshold
            )
            context.insert(rule)
        }
        AuditLogService.log(context: context,
            "\(isEditing ? "Updated" : "Added") bank email rule: \(bankName) (auto-approve \(autoApprove ? "on, ≥\(Int(confidenceThreshold * 100))%" : "off"))")
        try? context.save()
        dismiss()
    }
}
