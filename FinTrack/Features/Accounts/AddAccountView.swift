import SwiftUI
import SwiftData

// MARK: – Add / Edit Account (#1 #2 #3 #9 #13 #22)

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService

    var editingAccount: Account? = nil

    @State private var name = ""
    @State private var selectedBank = "Emirates NBD"
    @State private var customBankName = ""
    @State private var accountType: AccountType = .current
    @State private var currency = "AED"
    @State private var balance = ""
    @State private var accountNumber = ""
    @State private var selectedColor = "blue"
    @State private var notes = ""
    @State private var isDefault = false
    @State private var isHidden = false
    @State private var isBusiness = false
    @State private var minimumBalanceEnabled = false
    @State private var minimumBalance = ""
    @State private var walletProvider: WalletProvider = .applePay
    @State private var retirementType = "Pension"
    @State private var sharedMembersText = ""   // comma-separated emails

    private let colors = ["blue", "green", "purple", "orange", "red", "teal", "indigo", "pink"]
    private let popularBanks = ["Emirates NBD", "ADCB", "FAB", "Mashreq", "HSBC", "Citi", "DIB",
                                 "Rakbank", "CBD", "Standard Chartered", "Barclays", "Other"]
    private let retirementTypes = ["Pension", "Gratuity", "401k", "RRSP", "Provident Fund", "Other"]

    private var isEditing: Bool { editingAccount != nil }
    private var isOtherBank: Bool { selectedBank == "Other" }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Account Type
                        VStack(spacing: 0) {
                            Menu {
                                Picker("Type", selection: $accountType) {
                                    ForEach(AccountType.allCases, id: \.self) { type in
                                        Label(type.rawValue, systemImage: type.icon).tag(type)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Account Type").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Label(accountType.rawValue, systemImage: accountType.icon)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Account Details
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Account Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Main Account", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            if accountType == .digitalWallet {
                                Divider().opacity(0.4)
                                Menu {
                                    Picker("Wallet", selection: $walletProvider) {
                                        ForEach(WalletProvider.allCases, id: \.self) { p in
                                            Label(p.rawValue, systemImage: p.icon).tag(p)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: FTSpacing.md) {
                                        Text("Wallet Provider").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                        Spacer()
                                        Text(walletProvider.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                    }
                                    .padding(.vertical, 13)
                                }
                            } else if accountType == .retirement {
                                Divider().opacity(0.4)
                                Menu {
                                    Picker("Type", selection: $retirementType) {
                                        ForEach(retirementTypes, id: \.self) { Text($0).tag($0) }
                                    }
                                } label: {
                                    HStack(spacing: FTSpacing.md) {
                                        Text("Plan Type").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                        Spacer()
                                        Text(retirementType).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                    }
                                    .padding(.vertical, 13)
                                }
                            } else if accountType.needsBankName {
                                Divider().opacity(0.4)
                                Menu {
                                    Picker("Bank", selection: $selectedBank) {
                                        ForEach(popularBanks, id: \.self) { Text($0).tag($0) }
                                    }
                                } label: {
                                    HStack(spacing: FTSpacing.md) {
                                        Text("Bank").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                        Spacer()
                                        Text(selectedBank).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                    }
                                    .padding(.vertical, 13)
                                }

                                if isOtherBank {
                                    Divider().opacity(0.4)
                                    HStack(spacing: FTSpacing.md) {
                                        Text("Bank Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                        Spacer()
                                        TextField("Enter bank name", text: $customBankName)
                                            .multilineTextAlignment(.trailing)
                                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    }
                                    .padding(.vertical, 13)
                                }
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Balance & Currency
                        VStack(spacing: 0) {
                            Menu {
                                Picker("Currency", selection: $currency) {
                                    ForEach(currencyService.supportedCurrencies.prefix(15)) { info in
                                        Text("\(info.flag) \(info.code) — \(info.name)").tag(info.code)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Currency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(currency).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Balance").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Text(currency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                TextField("0.00", text: $balance)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Account Number
                        if accountType != .cash {
                            VStack(spacing: 0) {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Account Number").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    TextField("Last 4 digits (optional)", text: $accountNumber)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                }
                                .padding(.vertical, 13)
                            }
                            .padding(.horizontal, FTSpacing.lg)
                            .ftGlass(FTRadius.md)
                        }

                        // Minimum Balance
                        VStack(spacing: 0) {
                            Toggle(isOn: $minimumBalanceEnabled) {
                                Text("Minimum Balance").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }
                            .tint(FTColor.accent)
                            .padding(.vertical, 13)

                            if minimumBalanceEnabled {
                                Divider().opacity(0.4)
                                HStack(spacing: FTSpacing.md) {
                                    Text("Amount (\(currency))").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    TextField("0.00", text: $minimumBalance)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                        .frame(maxWidth: 120)
                                }
                                .padding(.vertical, 13)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Color
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("COLOR")
                                .font(.ftLabel).tracking(1.6)
                                .foregroundStyle(FTColor.textSecondary)
                            colorPicker
                        }
                        .padding(FTSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        // Account Options
                        VStack(spacing: 0) {
                            Toggle(isOn: $isDefault) {
                                Text("Set as Default Account").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }
                            .tint(FTColor.accent)
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Toggle(isOn: $isBusiness) {
                                HStack(spacing: FTSpacing.sm) {
                                    Image(systemName: "briefcase.fill").foregroundStyle(FTColor.textSecondary)
                                    Text("Business Account").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                }
                            }
                            .tint(FTColor.accent)
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Toggle(isOn: $isHidden) {
                                HStack(spacing: FTSpacing.sm) {
                                    Image(systemName: "eye.slash.fill").foregroundStyle(FTColor.textSecondary)
                                    Text("Hide from Dashboard").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                }
                            }
                            .tint(FTColor.accent)
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Image(systemName: "person.2.fill").foregroundStyle(FTColor.textSecondary)
                                Text("Shared Members").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Emails, comma-separated", text: $sharedMembersText)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftCaption).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: {
                    Text(isEditing ? "Update Account" : "Add Account")
                }
                .buttonStyle(.ftPrimary)
                .disabled(name.isEmpty || (isOtherBank && customBankName.isEmpty && accountType.needsBankName))
                .opacity((name.isEmpty || (isOtherBank && customBankName.isEmpty && accountType.needsBankName)) ? 0.55 : 1)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle(isEditing ? "Edit Account" : "Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .onAppear(perform: loadEditing)
            .dismissKeyboardOnTap()
        }
    }

    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(Color.fromString(color))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.ftCaption).fontWeight(.bold).foregroundColor(.white)
                                .opacity(selectedColor == color ? 1 : 0)
                        )
                        .onTapGesture { selectedColor = color }
                }
            }
        }
    }

    private func loadEditing() {
        guard let acc = editingAccount else { return }
        name = acc.name
        if popularBanks.contains(acc.bankName) {
            selectedBank = acc.bankName
        } else {
            selectedBank = "Other"
            customBankName = acc.bankName
        }
        if let custom = acc.customBankName { customBankName = custom }
        accountType = acc.type
        currency = acc.currency
        balance = String(acc.balance)
        accountNumber = acc.accountNumber ?? ""
        selectedColor = acc.color
        notes = acc.notes ?? ""
        isDefault = acc.isDefault
        isHidden = acc.isHidden
        isBusiness = acc.isBusiness
        minimumBalanceEnabled = acc.minimumBalanceEnabled
        minimumBalance = acc.minimumBalance > 0 ? String(acc.minimumBalance) : ""
        if let wp = acc.walletProvider, let p = WalletProvider(rawValue: wp) { walletProvider = p }
        if let rt = acc.retirementType { retirementType = rt }
        sharedMembersText = acc.sharedMembers.joined(separator: ", ")
    }

    private func save() {
        let bankLabel: String
        let customLabel: String?
        if accountType == .digitalWallet {
            bankLabel = walletProvider.rawValue
            customLabel = nil
        } else {
            bankLabel = isOtherBank ? "Other" : selectedBank
            customLabel = isOtherBank ? customBankName : nil
        }
        let balanceVal = Double(balance) ?? 0
        let members = sharedMembersText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let acc = editingAccount {
            acc.name = name
            acc.bankName = bankLabel
            acc.customBankName = customLabel
            acc.type = accountType
            acc.currency = currency
            acc.balance = balanceVal
            acc.accountNumber = accountNumber.isEmpty ? nil : accountNumber
            acc.color = selectedColor
            acc.icon = accountType.icon
            acc.isDefault = isDefault
            acc.isHidden = isHidden
            acc.isBusiness = isBusiness
            acc.walletProvider = accountType == .digitalWallet ? walletProvider.rawValue : nil
            acc.retirementType = accountType == .retirement ? retirementType : nil
            acc.sharedMembers = members
            acc.notes = notes.isEmpty ? nil : notes
            acc.minimumBalanceEnabled = minimumBalanceEnabled
            acc.minimumBalance = Double(minimumBalance) ?? 0
            acc.updatedAt = Date()
        } else {
            let account = Account(
                name: name,
                type: accountType,
                currency: currency,
                balance: balanceVal,
                bankName: bankLabel,
                customBankName: customLabel,
                accountNumber: accountNumber.isEmpty ? nil : accountNumber,
                color: selectedColor,
                icon: accountType.icon,
                isDefault: isDefault,
                isHidden: isHidden,
                isBusiness: isBusiness,
                walletProvider: accountType == .digitalWallet ? walletProvider.rawValue : nil,
                retirementType: accountType == .retirement ? retirementType : nil,
                sharedMembers: members,
                notes: notes.isEmpty ? nil : notes,
                minimumBalanceEnabled: minimumBalanceEnabled,
                minimumBalance: Double(minimumBalance) ?? 0
            )
            context.insert(account)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: – Add Credit Card

struct AddCreditCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService

    @State private var name = ""
    @State private var bankName = ""
    @State private var last4 = ""
    @State private var creditLimit = ""
    @State private var outstanding = ""
    @State private var minimumPayment = ""
    @State private var dueDate = Date()
    @State private var interestRate = ""
    @State private var currency = "AED"
    @State private var selectedColor = "purple"

    private let colors = ["blue", "green", "purple", "orange", "red", "teal", "indigo", "pink"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Card Details
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Card Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Visa Platinum", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Bank Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Emirates NBD", text: $bankName)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Last 4 Digits").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0000", text: $last4)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 80)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Limits & Balance
                        VStack(spacing: 0) {
                            Menu {
                                Picker("Currency", selection: $currency) {
                                    ForEach(currencyService.supportedCurrencies.prefix(10)) { info in
                                        Text("\(info.flag) \(info.code)").tag(info.code)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Currency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(currency).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Credit Limit").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $creditLimit)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Outstanding Balance").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $outstanding)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Minimum Payment").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $minimumPayment)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Payment Info
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            }
                            .padding(.vertical, 9)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Interest Rate (%)").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.0", text: $interestRate)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 80)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Color
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("COLOR")
                                .font(.ftLabel).tracking(1.6)
                                .foregroundStyle(FTColor.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(colors, id: \.self) { color in
                                        Circle()
                                            .fill(Color.fromString(color))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .font(.ftCaption).fontWeight(.bold).foregroundColor(.white)
                                                    .opacity(selectedColor == color ? 1 : 0)
                                            )
                                            .onTapGesture { selectedColor = color }
                                    }
                                }
                            }
                        }
                        .padding(FTSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: { Text("Add Credit Card") }
                    .buttonStyle(.ftPrimary)
                    .disabled(name.isEmpty || bankName.isEmpty)
                    .opacity(name.isEmpty || bankName.isEmpty ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Add Credit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .dismissKeyboardOnTap()
        }
    }

    private func save() {
        let card = CreditCard(
            name: name,
            bankName: bankName,
            last4Digits: last4,
            creditLimit: Double(creditLimit) ?? 0,
            outstandingBalance: Double(outstanding) ?? 0,
            minimumPayment: Double(minimumPayment) ?? 0,
            dueDate: dueDate,
            interestRate: Double(interestRate) ?? 0,
            currency: currency,
            color: selectedColor
        )
        context.insert(card)
        NotificationService.shared.scheduleCreditCardReminder(
            cardName: name, dueDate: dueDate,
            minimumPayment: card.minimumPayment, currency: currency, id: card.id.uuidString
        )
        try? context.save()
        dismiss()
    }
}

// MARK: – Add Loan (#4 installments already paid, #21 reminder days)

struct AddLoanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService

    var editingLoan: Loan? = nil

    @State private var name = ""
    @State private var loanType: LoanType = .personal
    @State private var principalAmount = ""
    @State private var outstandingBalance = ""
    @State private var interestRate = ""
    @State private var emiAmount = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 5, to: Date()) ?? Date()
    @State private var nextPaymentDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var currency = "AED"
    @State private var lenderName = ""
    @State private var lenderPersonName = ""
    @State private var notes = ""
    @State private var paidInstallments = 0
    @State private var reminderDaysBefore = 3

    private var isEditing: Bool { editingLoan != nil }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Loan Details
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Loan Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Home Loan", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Menu {
                                Picker("Loan Type", selection: $loanType) {
                                    ForEach(LoanType.allCases, id: \.self) { type in
                                        Label(type.rawValue, systemImage: type.icon).tag(type)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Loan Type").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(loanType.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Lender
                        VStack(spacing: 0) {
                            if loanType == .personalBorrowed {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Lender Name")
                                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    TextField("Full name", text: $lenderPersonName)
                                        .multilineTextAlignment(.trailing)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                }
                                .padding(.vertical, 13)

                                Divider().opacity(0.4)

                                HStack(spacing: FTSpacing.md) {
                                    Text("Contact Info").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    TextField("Optional", text: $lenderName)
                                        .multilineTextAlignment(.trailing)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                }
                                .padding(.vertical, 13)
                            } else {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Lender").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    TextField("Bank / Institution", text: $lenderName)
                                        .multilineTextAlignment(.trailing)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                }
                                .padding(.vertical, 13)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Amount & Rate
                        VStack(spacing: 0) {
                            Menu {
                                Picker("Currency", selection: $currency) {
                                    ForEach(currencyService.supportedCurrencies.prefix(10)) { info in
                                        Text("\(info.flag) \(info.code)").tag(info.code)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Currency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(currency).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Principal Amount").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $principalAmount)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Outstanding Balance").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Same as principal", text: $outstandingBalance)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Interest Rate (%)").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.0", text: $interestRate)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 80)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Monthly EMI").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $emiAmount)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Dates
                        VStack(spacing: 0) {
                            HStack {
                                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            }
                            .padding(.vertical, 9)

                            Divider().opacity(0.4)

                            HStack {
                                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            }
                            .padding(.vertical, 9)

                            Divider().opacity(0.4)

                            HStack {
                                DatePicker("Next Payment", selection: $nextPaymentDate, displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            }
                            .padding(.vertical, 9)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Payment History & Reminders
                        VStack(spacing: 0) {
                            Stepper("Installments Paid: \(paidInstallments)", value: $paidInstallments, in: 0...600)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Stepper("Remind \(reminderDaysBefore) day\(reminderDaysBefore == 1 ? "" : "s") before due",
                                    value: $reminderDaysBefore, in: 1...30)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Notes
                        VStack(spacing: 0) {
                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: {
                    Text(isEditing ? "Update Loan" : "Add Loan")
                }
                .buttonStyle(.ftPrimary)
                .disabled(name.isEmpty || principalAmount.isEmpty)
                .opacity(name.isEmpty || principalAmount.isEmpty ? 0.55 : 1)
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle(isEditing ? "Edit Loan" : "Add Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .onAppear(perform: loadEditing)
            .dismissKeyboardOnTap()
        }
    }

    private func loadEditing() {
        guard let loan = editingLoan else { return }
        name = loan.name
        loanType = loan.loanType
        principalAmount = String(loan.principalAmount)
        outstandingBalance = String(loan.outstandingBalance)
        interestRate = String(loan.interestRate)
        emiAmount = String(loan.emiAmount)
        startDate = loan.startDate
        endDate = loan.endDate
        nextPaymentDate = loan.nextPaymentDate
        currency = loan.currency
        lenderName = loan.lenderName
        lenderPersonName = loan.lenderPersonName ?? ""
        notes = loan.notes ?? ""
        paidInstallments = loan.paidInstallments
        reminderDaysBefore = loan.reminderDaysBefore
    }

    private func save() {
        if let loan = editingLoan {
            loan.name = name
            loan.loanType = loanType
            loan.principalAmount = Double(principalAmount) ?? 0
            loan.outstandingBalance = Double(outstandingBalance).flatMap { $0 > 0 ? $0 : nil } ?? (Double(principalAmount) ?? 0)
            loan.interestRate = Double(interestRate) ?? 0
            loan.emiAmount = Double(emiAmount) ?? 0
            loan.startDate = startDate
            loan.endDate = endDate
            loan.nextPaymentDate = nextPaymentDate
            loan.currency = currency
            loan.lenderName = lenderName
            loan.lenderPersonName = lenderPersonName.isEmpty ? nil : lenderPersonName
            loan.notes = notes.isEmpty ? nil : notes
            loan.paidInstallments = paidInstallments
            loan.reminderDaysBefore = reminderDaysBefore
        } else {
            let loan = Loan(
                name: name,
                loanType: loanType,
                principalAmount: Double(principalAmount) ?? 0,
                outstandingBalance: Double(outstandingBalance).flatMap { $0 > 0 ? $0 : nil },
                interestRate: Double(interestRate) ?? 0,
                emiAmount: Double(emiAmount) ?? 0,
                startDate: startDate,
                endDate: endDate,
                nextPaymentDate: nextPaymentDate,
                currency: currency,
                lenderName: lenderName,
                lenderPersonName: lenderPersonName.isEmpty ? nil : lenderPersonName,
                notes: notes.isEmpty ? nil : notes,
                paidInstallments: paidInstallments,
                reminderDaysBefore: reminderDaysBefore
            )
            context.insert(loan)
            NotificationService.shared.scheduleLoanReminder(
                loanName: name, emiAmount: loan.emiAmount, currency: currency,
                dueDate: nextPaymentDate, daysBefore: reminderDaysBefore, id: loan.id.uuidString
            )
        }
        try? context.save()
        dismiss()
    }
}

// MARK: – Add BNPL

struct AddBNPLView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var provider: BNPLProvider = .tabby
    @State private var customProviderName = ""
    @State private var merchant = ""
    @State private var totalAmount = ""
    @State private var installmentAmount = ""
    @State private var totalInstallments = 4
    @State private var paidInstallments = 0
    @State private var nextPaymentDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var currency = "AED"

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Plan Details
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Plan Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. iPhone 15", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Menu {
                                Picker("Provider", selection: $provider) {
                                    ForEach(BNPLProvider.allCases, id: \.self) { p in
                                        Text(p.rawValue).tag(p)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Provider").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(provider.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            if provider == .custom {
                                Divider().opacity(0.4)
                                HStack(spacing: FTSpacing.md) {
                                    Text("Provider Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    TextField("Enter provider name", text: $customProviderName)
                                        .multilineTextAlignment(.trailing)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                }
                                .padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Merchant").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Store / Shop", text: $merchant)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Amounts
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Total Amount").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $totalAmount)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Per Installment").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $installmentAmount)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Installments
                        VStack(spacing: 0) {
                            Stepper("Total: \(totalInstallments)", value: $totalInstallments, in: 1...36)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Stepper("Paid: \(paidInstallments)", value: $paidInstallments, in: 0...totalInstallments)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack {
                                DatePicker("Next Payment", selection: $nextPaymentDate, displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            }
                            .padding(.vertical, 9)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: { Text("Add BNPL Plan") }
                    .buttonStyle(.ftPrimary)
                    .disabled(name.isEmpty || merchant.isEmpty || (provider == .custom && customProviderName.isEmpty))
                    .opacity(name.isEmpty || merchant.isEmpty || (provider == .custom && customProviderName.isEmpty) ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Add BNPL Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .dismissKeyboardOnTap()
        }
    }

    private func save() {
        let plan = BNPLPlan(
            name: name, provider: provider,
            customProvider: provider == .custom ? customProviderName : nil,
            merchant: merchant,
            totalAmount: Double(totalAmount) ?? 0, currency: currency,
            installmentAmount: Double(installmentAmount) ?? 0,
            totalInstallments: totalInstallments,
            paidInstallments: paidInstallments,
            nextPaymentDate: nextPaymentDate
        )
        context.insert(plan)
        NotificationService.shared.scheduleBNPLReminder(
            planName: name, amount: plan.installmentAmount,
            currency: currency, dueDate: nextPaymentDate, id: plan.id.uuidString
        )
        try? context.save()
        dismiss()
    }
}

// MARK: – Add Investment

struct AddInvestmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var symbol = ""
    @State private var investmentType: InvestmentType = .stock
    @State private var quantity = ""
    @State private var averageCost = ""
    @State private var currentPrice = ""
    @State private var currency = "USD"
    @State private var exchange = ""
    @State private var purchaseDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Investment Details
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Apple Inc.", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Symbol").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. AAPL", text: $symbol)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 100)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Menu {
                                Picker("Type", selection: $investmentType) {
                                    ForEach(InvestmentType.allCases, id: \.self) { type in
                                        Label(type.rawValue, systemImage: type.icon).tag(type)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Type").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(investmentType.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Exchange").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $exchange)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Position
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Quantity").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0", text: $quantity)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 100)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Avg. Cost (USD)").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $averageCost)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Current Price (USD)").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $currentPrice)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Date & Notes
                        VStack(spacing: 0) {
                            HStack {
                                DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            }
                            .padding(.vertical, 9)

                            Divider().opacity(0.4)

                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: { Text("Add Investment") }
                    .buttonStyle(.ftPrimary)
                    .disabled(name.isEmpty || symbol.isEmpty)
                    .opacity(name.isEmpty || symbol.isEmpty ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Add Investment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .dismissKeyboardOnTap()
        }
    }

    private func save() {
        let inv = Investment(
            name: name, symbol: symbol.uppercased(), type: investmentType,
            quantity: Double(quantity) ?? 0, averageCost: Double(averageCost) ?? 0,
            currentPrice: Double(currentPrice) ?? 0, currency: currency,
            exchange: exchange.isEmpty ? nil : exchange,
            notes: notes.isEmpty ? nil : notes, purchaseDate: purchaseDate
        )
        context.insert(inv)
        try? context.save()
        dismiss()
    }
}

// MARK: – Add Crypto Asset

struct AddCryptoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var symbol = ""
    @State private var quantity = ""
    @State private var averageCost = ""
    @State private var currentPrice = ""
    @State private var walletAddress = ""
    @State private var exchange = ""
    @State private var purchaseDate = Date()

    private let popularCryptos = [("Bitcoin","BTC"),("Ethereum","ETH"),("Solana","SOL"),
                                   ("XRP","XRP"),("BNB","BNB"),("USDT","USDT"),("USDC","USDC")]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Quick Select
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("QUICK SELECT")
                                .font(.ftLabel).tracking(1.6)
                                .foregroundStyle(FTColor.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(popularCryptos, id: \.1) { crypto in
                                        Button { name = crypto.0; symbol = crypto.1 } label: {
                                            VStack(spacing: 4) {
                                                Text(crypto.1).font(.ftCaption).fontWeight(.bold)
                                                Text(crypto.0).font(.ftLabel).foregroundStyle(FTColor.textSecondary)
                                            }
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(symbol == crypto.1 ? FTColor.accent.opacity(0.2) : FTColor.bgElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(FTSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        // Details
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Coin Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Bitcoin", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Symbol").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("BTC, ETH...", text: $symbol)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 100)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Position
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Quantity").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0", text: $quantity)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 100)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Avg. Cost (USD)").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $averageCost)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Current Price (USD)").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $currentPrice)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Wallet & Exchange
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Wallet Address").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $walletAddress)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Exchange").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $exchange)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack {
                                DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            }
                            .padding(.vertical, 9)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: { Text("Add Crypto Asset") }
                    .buttonStyle(.ftPrimary)
                    .disabled(name.isEmpty || symbol.isEmpty)
                    .opacity(name.isEmpty || symbol.isEmpty ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Add Crypto Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .dismissKeyboardOnTap()
        }
    }

    private func save() {
        let holding = CryptoHolding(
            name: name, symbol: symbol.uppercased(),
            quantity: Double(quantity) ?? 0, averageCost: Double(averageCost) ?? 0,
            currentPrice: Double(currentPrice) ?? 0,
            walletAddress: walletAddress.isEmpty ? nil : walletAddress,
            exchange: exchange.isEmpty ? nil : exchange,
            purchaseDate: purchaseDate
        )
        context.insert(holding)
        try? context.save()
        dismiss()
    }
}

// MARK: – Add Gold / Precious Metal

struct AddGoldHoldingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService

    @State private var name = ""
    @State private var metal: PreciousMetal = .gold
    @State private var form: GoldForm = .bar
    @State private var weightGrams = ""
    @State private var purchasePricePerGram = ""
    @State private var currentPricePerGram = ""
    @State private var currency = "AED"
    @State private var storageLocation = ""
    @State private var purchaseDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {

                        // Metal & Form
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Gold Bar 100g", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Menu {
                                Picker("Metal", selection: $metal) {
                                    ForEach(PreciousMetal.allCases, id: \.self) { m in
                                        Label(m.rawValue, systemImage: m.icon).tag(m)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Metal").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(metal.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)

                            Menu {
                                Picker("Form", selection: $form) {
                                    ForEach(GoldForm.allCases, id: \.self) { f in
                                        Label(f.rawValue, systemImage: f.icon).tag(f)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Form").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(form.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Weight & Pricing
                        VStack(spacing: 0) {
                            Menu {
                                Picker("Currency", selection: $currency) {
                                    ForEach(currencyService.supportedCurrencies.prefix(10)) { info in
                                        Text("\(info.flag) \(info.code)").tag(info.code)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Currency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(currency).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Weight (grams)").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $weightGrams)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Buy Price / gram").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $purchasePricePerGram)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Current Price / gram").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $currentPricePerGram)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Details
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Storage Location").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Bank Safe", text: $storageLocation)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                                .font(.ftBody)
                                .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: { Text("Add Holding") }
                    .buttonStyle(.ftPrimary)
                    .disabled(name.isEmpty || weightGrams.isEmpty || purchasePricePerGram.isEmpty || currentPricePerGram.isEmpty)
                    .opacity(name.isEmpty || weightGrams.isEmpty || purchasePricePerGram.isEmpty || currentPricePerGram.isEmpty ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Add \(metal.rawValue) Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .dismissKeyboardOnTap()
        }
    }

    private func save() {
        let holding = GoldHolding(
            name: name, metal: metal, form: form,
            weightGrams: Double(weightGrams) ?? 0,
            purchasePricePerGram: Double(purchasePricePerGram) ?? 0,
            currentPricePerGram: Double(currentPricePerGram) ?? 0,
            currency: currency,
            storageLocation: storageLocation.isEmpty ? nil : storageLocation,
            purchaseDate: purchaseDate,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(holding)
        try? context.save()
        dismiss()
    }
}

// MARK: – Add Gift Card

struct AddGiftCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService

    @State private var merchant = ""
    @State private var balance = ""
    @State private var currency = "AED"
    @State private var cardNumber = ""
    @State private var pinCode = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedColor = "teal"
    @State private var notes = ""

    private let colors = ["blue", "green", "purple", "orange", "red", "teal", "indigo", "pink"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {

                        // Card Info
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Merchant").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Amazon, Noon", text: $merchant)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Menu {
                                Picker("Currency", selection: $currency) {
                                    ForEach(currencyService.supportedCurrencies.prefix(10)) { info in
                                        Text("\(info.flag) \(info.code)").tag(info.code)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Currency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(currency).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Balance").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Text(currency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                TextField("0.00", text: $balance)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Card Details
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Card Number").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $cardNumber)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("PIN").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $pinCode)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Toggle(isOn: $hasExpiry) {
                                Text("Has Expiry Date").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }
                            .tint(FTColor.accent)
                            .padding(.vertical, 13)

                            if hasExpiry {
                                Divider().opacity(0.4)
                                DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                                    .font(.ftBody)
                                    .padding(.vertical, 13)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Color
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("COLOR").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(colors, id: \.self) { color in
                                        Circle().fill(Color.fromString(color)).frame(width: 36, height: 36)
                                            .overlay(Image(systemName: "checkmark").font(.ftCaption).fontWeight(.bold).foregroundColor(.white).opacity(selectedColor == color ? 1 : 0))
                                            .onTapGesture { selectedColor = color }
                                    }
                                }
                            }
                        }
                        .padding(FTSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        // Notes
                        VStack(spacing: 0) {
                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: { Text("Add Gift Card") }
                    .buttonStyle(.ftPrimary)
                    .disabled(merchant.isEmpty || balance.isEmpty)
                    .opacity(merchant.isEmpty || balance.isEmpty ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Add Gift Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .dismissKeyboardOnTap()
        }
    }

    private func save() {
        let card = GiftCard(
            merchant: merchant,
            balance: Double(balance) ?? 0,
            currency: currency,
            cardNumber: cardNumber.isEmpty ? nil : cardNumber,
            pinCode: pinCode.isEmpty ? nil : pinCode,
            expiryDate: hasExpiry ? expiryDate : nil,
            notes: notes.isEmpty ? nil : notes,
            color: selectedColor
        )
        context.insert(card)
        try? context.save()
        if let expiry = hasExpiry ? expiryDate : nil {
            NotificationService.shared.scheduleGiftCardExpiry(
                merchant: merchant,
                balance: Double(balance) ?? 0,
                currency: currency,
                expiryDate: expiry,
                id: card.id.uuidString
            )
        }
        dismiss()
    }
}

// MARK: – Add Loyalty Program

struct AddLoyaltyProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService

    @State private var name = ""
    @State private var programType: LoyaltyProgramType = .emiratesSkwards
    @State private var customProgramName = ""
    @State private var points = ""
    @State private var pointsValuePerUnit = "0.01"
    @State private var currency = "AED"
    @State private var membershipNumber = ""
    @State private var tier = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedColor = "purple"
    @State private var notes = ""

    private let colors = ["blue", "green", "purple", "orange", "red", "teal", "indigo", "pink"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {

                        // Program
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. My Skywards", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Menu {
                                Picker("Program", selection: $programType) {
                                    ForEach(LoyaltyProgramType.allCases, id: \.self) { p in
                                        Label(p.rawValue, systemImage: p.icon).tag(p)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Program").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(programType.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            if programType == .other {
                                Divider().opacity(0.4)
                                HStack(spacing: FTSpacing.md) {
                                    Text("Program Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    TextField("Enter program name", text: $customProgramName)
                                        .multilineTextAlignment(.trailing)
                                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                }
                                .padding(.vertical, 13)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Points & Value
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text(programType.pointsLabel).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0", text: $points)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 140)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Menu {
                                Picker("Currency", selection: $currency) {
                                    ForEach(currencyService.supportedCurrencies.prefix(10)) { info in
                                        Text("\(info.flag) \(info.code)").tag(info.code)
                                    }
                                }
                            } label: {
                                HStack(spacing: FTSpacing.md) {
                                    Text("Currency").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Text(currency).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                                }
                                .padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Value / \(programType.pointsLabel.lowercased())").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Text(currency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                TextField("0.01", text: $pointsValuePerUnit)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).frame(maxWidth: 80)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Membership
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Membership No.").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $membershipNumber)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Tier / Status").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Gold", text: $tier)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            Toggle(isOn: $hasExpiry) {
                                Text("Points Expire").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }
                            .tint(FTColor.accent)
                            .padding(.vertical, 13)

                            if hasExpiry {
                                Divider().opacity(0.4)
                                DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                                    .font(.ftBody)
                                    .padding(.vertical, 13)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Color
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("COLOR").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(colors, id: \.self) { color in
                                        Circle().fill(Color.fromString(color)).frame(width: 36, height: 36)
                                            .overlay(Image(systemName: "checkmark").font(.ftCaption).fontWeight(.bold).foregroundColor(.white).opacity(selectedColor == color ? 1 : 0))
                                            .onTapGesture { selectedColor = color }
                                    }
                                }
                            }
                        }
                        .padding(FTSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        // Notes
                        VStack(spacing: 0) {
                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: { Text("Add Program") }
                    .buttonStyle(.ftPrimary)
                    .disabled(name.isEmpty || (programType == .other && customProgramName.isEmpty))
                    .opacity(name.isEmpty || (programType == .other && customProgramName.isEmpty) ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Add Loyalty Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .dismissKeyboardOnTap()
        }
    }

    private func save() {
        let program = LoyaltyProgram(
            name: name,
            programType: programType,
            customProgramName: programType == .other ? customProgramName : nil,
            points: Double(points) ?? 0,
            pointsValuePerUnit: Double(pointsValuePerUnit) ?? 0.01,
            currency: currency,
            membershipNumber: membershipNumber.isEmpty ? nil : membershipNumber,
            tier: tier.isEmpty ? nil : tier,
            expiryDate: hasExpiry ? expiryDate : nil,
            notes: notes.isEmpty ? nil : notes,
            color: selectedColor
        )
        context.insert(program)
        try? context.save()
        if let expiry = hasExpiry ? expiryDate : nil {
            NotificationService.shared.scheduleLoyaltyExpiry(
                programName: name,
                points: Double(points) ?? 0,
                pointsLabel: "points",
                expiryDate: expiry,
                id: program.id.uuidString
            )
        }
        dismiss()
    }
}

// MARK: – Edit Investment

struct EditInvestmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let investment: Investment

    @State private var name = ""
    @State private var quantity = ""
    @State private var averageCost = ""
    @State private var currentPrice = ""
    @State private var exchange = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Name").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Name", text: $name).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Quantity").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0", text: $quantity).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Avg Cost").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $averageCost).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Current Price").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $currentPrice).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Exchange").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $exchange).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                        }
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                    .padding(.top, FTSpacing.lg).padding(.bottom, 100)
                }
                Button("Save") { save() }
                    .buttonStyle(.ftPrimary)
                    .padding(.horizontal, FTSpacing.screen).padding(.bottom, FTSpacing.xl)
            }
            .navigationTitle("Edit \(investment.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .dismissKeyboardOnTap()
            .onAppear {
                name = investment.name; quantity = String(investment.quantity)
                averageCost = String(investment.averageCost); currentPrice = String(investment.currentPrice)
                exchange = investment.exchange ?? ""
            }
        }
    }
    private func save() {
        investment.name = name
        investment.quantity = Double(quantity) ?? investment.quantity
        investment.averageCost = Double(averageCost) ?? investment.averageCost
        investment.currentPrice = Double(currentPrice) ?? investment.currentPrice
        investment.exchange = exchange.isEmpty ? nil : exchange
        try? context.save(); dismiss()
    }
}

// MARK: – Edit Crypto Holding

struct EditCryptoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let holding: CryptoHolding

    @State private var quantity = ""
    @State private var averageCost = ""
    @State private var currentPrice = ""
    @State private var walletAddress = ""
    @State private var exchange = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Quantity").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0", text: $quantity).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Avg Cost (USD)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $averageCost).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Current Price").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $currentPrice).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Exchange").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $exchange).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Wallet Address").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $walletAddress).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                        }
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                    .padding(.top, FTSpacing.lg).padding(.bottom, 100)
                }
                Button("Save") { save() }
                    .buttonStyle(.ftPrimary)
                    .padding(.horizontal, FTSpacing.screen).padding(.bottom, FTSpacing.xl)
            }
            .navigationTitle("Edit \(holding.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .dismissKeyboardOnTap()
            .onAppear {
                quantity = String(holding.quantity); averageCost = String(holding.averageCost)
                currentPrice = String(holding.currentPrice)
                exchange = holding.exchange ?? ""; walletAddress = holding.walletAddress ?? ""
            }
        }
    }
    private func save() {
        holding.quantity = Double(quantity) ?? holding.quantity
        holding.averageCost = Double(averageCost) ?? holding.averageCost
        holding.currentPrice = Double(currentPrice) ?? holding.currentPrice
        holding.exchange = exchange.isEmpty ? nil : exchange
        holding.walletAddress = walletAddress.isEmpty ? nil : walletAddress
        try? context.save(); dismiss()
    }
}

// MARK: – Edit Gold Holding

struct EditGoldHoldingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let holding: GoldHolding

    @State private var name = ""
    @State private var weightGrams = ""
    @State private var purchasePricePerGram = ""
    @State private var currentPricePerGram = ""
    @State private var storageLocation = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Name").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Name", text: $name).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Weight (g)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $weightGrams).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Purchase Price/g").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $purchasePricePerGram).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Current Price/g").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $currentPricePerGram).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Storage Location").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $storageLocation).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                        }
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                    .padding(.top, FTSpacing.lg).padding(.bottom, 100)
                }
                Button("Save") { save() }
                    .buttonStyle(.ftPrimary)
                    .padding(.horizontal, FTSpacing.screen).padding(.bottom, FTSpacing.xl)
            }
            .navigationTitle("Edit \(holding.metal.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .dismissKeyboardOnTap()
            .onAppear {
                name = holding.name; weightGrams = String(holding.weightGrams)
                purchasePricePerGram = String(holding.purchasePricePerGram)
                currentPricePerGram = String(holding.currentPricePerGram)
                storageLocation = holding.storageLocation ?? ""
            }
        }
    }
    private func save() {
        holding.name = name
        holding.weightGrams = Double(weightGrams) ?? holding.weightGrams
        holding.purchasePricePerGram = Double(purchasePricePerGram) ?? holding.purchasePricePerGram
        holding.currentPricePerGram = Double(currentPricePerGram) ?? holding.currentPricePerGram
        holding.storageLocation = storageLocation.isEmpty ? nil : storageLocation
        try? context.save(); dismiss()
    }
}

// MARK: – Edit Gift Card

struct EditGiftCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let card: GiftCard

    @State private var merchant = ""
    @State private var balance = ""
    @State private var cardNumber = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Merchant").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Merchant", text: $merchant).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Balance").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.00", text: $balance).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Card Number").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $cardNumber).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            Toggle(isOn: $hasExpiry) {
                                Text("Has Expiry Date").font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            if hasExpiry {
                                Divider().opacity(0.4)
                                DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                                    .font(.ftBody).padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            }
                        }
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                    .padding(.top, FTSpacing.lg).padding(.bottom, 100)
                }
                Button("Save") { save() }
                    .buttonStyle(.ftPrimary)
                    .padding(.horizontal, FTSpacing.screen).padding(.bottom, FTSpacing.xl)
            }
            .navigationTitle("Edit Gift Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .dismissKeyboardOnTap()
            .onAppear {
                merchant = card.merchant; balance = String(card.balance)
                cardNumber = card.cardNumber ?? ""
                hasExpiry = card.expiryDate != nil
                expiryDate = card.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
                notes = card.notes ?? ""
            }
        }
    }
    private func save() {
        card.merchant = merchant; card.balance = Double(balance) ?? card.balance
        card.cardNumber = cardNumber.isEmpty ? nil : cardNumber
        card.expiryDate = hasExpiry ? expiryDate : nil
        card.notes = notes.isEmpty ? nil : notes
        try? context.save(); dismiss()
    }
}

// MARK: – Edit Loyalty Program

struct EditLoyaltyProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let program: LoyaltyProgram

    @State private var points = ""
    @State private var pointsValuePerUnit = ""
    @State private var membershipNumber = ""
    @State private var tier = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Date()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Points Balance").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0", text: $points).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Value per Point").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("0.01", text: $pointsValuePerUnit).keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Membership #").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $membershipNumber).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            HStack {
                                Text("Tier").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. Gold", text: $tier).multilineTextAlignment(.trailing).font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            Divider().opacity(0.4)
                            Toggle(isOn: $hasExpiry) {
                                Text("Has Expiry Date").font(.ftBody)
                            }
                            .padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            if hasExpiry {
                                Divider().opacity(0.4)
                                DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                                    .font(.ftBody).padding(.vertical, 13).padding(.horizontal, FTSpacing.lg)
                            }
                        }
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                    .padding(.top, FTSpacing.lg).padding(.bottom, 100)
                }
                Button("Save") { save() }
                    .buttonStyle(.ftPrimary)
                    .padding(.horizontal, FTSpacing.screen).padding(.bottom, FTSpacing.xl)
            }
            .navigationTitle("Edit \(program.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .dismissKeyboardOnTap()
            .onAppear {
                points = String(program.points); pointsValuePerUnit = String(program.pointsValuePerUnit)
                membershipNumber = program.membershipNumber ?? ""; tier = program.tier ?? ""
                hasExpiry = program.expiryDate != nil
                expiryDate = program.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            }
        }
    }
    private func save() {
        program.points = Double(points) ?? program.points
        program.pointsValuePerUnit = Double(pointsValuePerUnit) ?? program.pointsValuePerUnit
        program.membershipNumber = membershipNumber.isEmpty ? nil : membershipNumber
        program.tier = tier.isEmpty ? nil : tier
        program.expiryDate = hasExpiry ? expiryDate : nil
        try? context.save(); dismiss()
    }
}

