import Foundation
import SwiftData

// MARK: - Codable DTOs (Data Transfer Objects)

struct FinTrackBackup: Codable {
    let version: Int
    let exportedAt: Date
    let accounts: [AccountDTO]
    let transactions: [TransactionDTO]
    let budgets: [BudgetDTO]
    let savingsGoals: [SavingsGoalDTO]
    let loans: [LoanDTO]
    let creditCards: [CreditCardDTO]
    let investments: [InvestmentDTO]
    let cryptoHoldings: [CryptoHoldingDTO]
    let dividends: [DividendDTO]
    let bnplPlans: [BNPLPlanDTO]
    let userProfile: UserProfileDTO?
    let appSettings: AppSettingsDTO?

    static let currentVersion = 1
}

struct AccountDTO: Codable {
    var id: UUID; var name: String; var type: String; var currency: String
    var balance: Double; var initialBalance: Double; var bankName: String
    var customBankName: String?; var accountNumber: String?; var color: String
    var icon: String; var isDefault: Bool; var isArchived: Bool
    var createdAt: Date; var updatedAt: Date; var notes: String?
    var minimumBalanceEnabled: Bool; var minimumBalance: Double
}

struct TransactionDTO: Codable {
    var id: UUID; var title: String; var amount: Double; var currency: String
    var amountInBaseCurrency: Double; var type: String; var category: String
    var customCategory: String?; var date: Date; var notes: String?
    var receiptImageData: Data?; var isRecurring: Bool; var merchant: String?
    var paymentMethod: String; var tags: [String]; var isVerified: Bool
    var isDuplicate: Bool; var createdAt: Date; var updatedAt: Date
    var accountId: UUID?; var linkedLoanId: UUID?
    // v4 additions (optional for backwards-compatible decoding of older backups)
    var isPending: Bool?
    var isScheduled: Bool?
    var scheduledDate: Date?
    var subtype: String?
    var splitItems: [SplitItem]?
    var incomeSource: String?
    var latitude: Double?
    var longitude: Double?
    var chequeNumber: String?
    var chequeDate: Date?
    // v5 additions
    var isTaxDeductible: Bool?
    var isVATReclaimable: Bool?
    var customCategoryID: UUID?
}

struct BudgetDTO: Codable {
    var id: UUID; var name: String; var category: String; var customCategory: String?
    var amount: Double; var currency: String; var period: String
    var startDate: Date; var endDate: Date?; var alertThreshold: Double
    var isActive: Bool; var color: String; var createdAt: Date; var spent: Double
}

struct SavingsGoalDTO: Codable {
    var id: UUID; var name: String; var targetAmount: Double; var currentAmount: Double
    var currency: String; var targetDate: Date?; var icon: String; var color: String
    var notes: String?; var isCompleted: Bool; var createdAt: Date
}

struct LoanDTO: Codable {
    var id: UUID; var name: String; var loanType: String
    var principalAmount: Double; var outstandingBalance: Double
    var interestRate: Double; var emiAmount: Double
    var startDate: Date; var endDate: Date; var nextPaymentDate: Date
    var currency: String; var lenderName: String; var notes: String?
    var isActive: Bool; var createdAt: Date; var paidInstallments: Int
    var reminderDaysBefore: Int; var lenderPersonName: String?; var lenderContactInfo: String?
}

struct CreditCardDTO: Codable {
    var id: UUID; var name: String; var bankName: String; var last4Digits: String
    var creditLimit: Double; var outstandingBalance: Double; var minimumPayment: Double
    var dueDate: Date; var statementDate: Int; var interestRate: Double
    var currency: String; var color: String; var icon: String
    var isActive: Bool; var createdAt: Date
}

struct InvestmentDTO: Codable {
    var id: UUID; var name: String; var symbol: String; var type: String
    var quantity: Double; var averageCost: Double; var currentPrice: Double
    var currency: String; var exchange: String?
    var purchaseDate: Date; var createdAt: Date; var updatedAt: Date
}

struct CryptoHoldingDTO: Codable {
    var id: UUID; var name: String; var symbol: String
    var quantity: Double; var averageCost: Double; var currentPrice: Double
    var currency: String; var walletAddress: String?; var exchange: String?
    var purchaseDate: Date; var createdAt: Date; var updatedAt: Date
}

struct DividendDTO: Codable {
    var id: UUID; var investmentId: UUID; var amount: Double
    var currency: String; var date: Date
}

struct BNPLPlanDTO: Codable {
    var id: UUID; var name: String; var provider: String; var customProvider: String?
    var merchant: String; var totalAmount: Double; var currency: String
    var installmentAmount: Double; var totalInstallments: Int; var paidInstallments: Int
    var startDate: Date; var nextPaymentDate: Date; var notes: String?
    var isCompleted: Bool; var createdAt: Date
}

struct UserProfileDTO: Codable {
    var id: UUID; var name: String; var baseCurrency: String; var language: String
    var monthlyIncomeGoal: Double; var monthlySavingsGoal: Double
    var joinDate: Date; var isPremium: Bool; var hasCompletedOnboarding: Bool
}

struct AppSettingsDTO: Codable {
    var id: UUID; var useBiometrics: Bool; var usePIN: Bool; var pinHash: String?
    var autoLockMinutes: Int; var showBalanceOnDashboard: Bool
    var defaultCurrency: String; var notificationsEnabled: Bool
    var budgetAlertsEnabled: Bool; var billRemindersEnabled: Bool
    var salaryReminderEnabled: Bool; var reminderDaysBefore: Int
    var cloudSyncEnabled: Bool; var theme: String; var accentColor: String
}

// MARK: - Service

@MainActor
final class DataTransferService {
    static let shared = DataTransferService()
    private init() {}

    // MARK: Export

    func exportBackup(context: ModelContext) throws -> URL {
        let accounts     = try context.fetch(FetchDescriptor<Account>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let budgets      = try context.fetch(FetchDescriptor<Budget>())
        let goals        = try context.fetch(FetchDescriptor<SavingsGoal>())
        let loans        = try context.fetch(FetchDescriptor<Loan>())
        let cards        = try context.fetch(FetchDescriptor<CreditCard>())
        let investments  = try context.fetch(FetchDescriptor<Investment>())
        let crypto       = try context.fetch(FetchDescriptor<CryptoHolding>())
        let dividends    = try context.fetch(FetchDescriptor<Dividend>())
        let bnpl         = try context.fetch(FetchDescriptor<BNPLPlan>())
        let profiles     = try context.fetch(FetchDescriptor<UserProfile>())
        let settings     = try context.fetch(FetchDescriptor<AppSettings>())

        let backup = FinTrackBackup(
            version: FinTrackBackup.currentVersion,
            exportedAt: Date(),
            accounts: accounts.map(\.dto),
            transactions: transactions.map(\.dto),
            budgets: budgets.map(\.dto),
            savingsGoals: goals.map(\.dto),
            loans: loans.map(\.dto),
            creditCards: cards.map(\.dto),
            investments: investments.map(\.dto),
            cryptoHoldings: crypto.map(\.dto),
            dividends: dividends.map(\.dto),
            bnplPlans: bnpl.map(\.dto),
            userProfile: profiles.first?.dto,
            appSettings: settings.first?.dto
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let filename = "FinTrack_Backup_\(formatter.string(from: Date())).fintrack"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    // MARK: Import

    enum ImportMode {
        case merge      // keep existing + add new (skip duplicate IDs)
        case replace    // delete everything first, then insert
    }

    func importBackup(from url: URL, context: ModelContext, mode: ImportMode) throws -> ImportSummary {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(FinTrackBackup.self, from: data)

        if mode == .replace {
            try deleteAll(context: context)
        }

        var summary = ImportSummary()

        // Collect existing IDs for merge-dedup
        let existingAccountIds    = mode == .merge ? Set((try? context.fetch(FetchDescriptor<Account>()))?.map(\.id) ?? []) : []
        let existingTxIds         = mode == .merge ? Set((try? context.fetch(FetchDescriptor<Transaction>()))?.map(\.id) ?? []) : []
        let existingBudgetIds     = mode == .merge ? Set((try? context.fetch(FetchDescriptor<Budget>()))?.map(\.id) ?? []) : []
        let existingGoalIds       = mode == .merge ? Set((try? context.fetch(FetchDescriptor<SavingsGoal>()))?.map(\.id) ?? []) : []
        let existingLoanIds       = mode == .merge ? Set((try? context.fetch(FetchDescriptor<Loan>()))?.map(\.id) ?? []) : []
        let existingCardIds       = mode == .merge ? Set((try? context.fetch(FetchDescriptor<CreditCard>()))?.map(\.id) ?? []) : []
        let existingInvestmentIds = mode == .merge ? Set((try? context.fetch(FetchDescriptor<Investment>()))?.map(\.id) ?? []) : []
        let existingCryptoIds     = mode == .merge ? Set((try? context.fetch(FetchDescriptor<CryptoHolding>()))?.map(\.id) ?? []) : []
        let existingBNPLIds       = mode == .merge ? Set((try? context.fetch(FetchDescriptor<BNPLPlan>()))?.map(\.id) ?? []) : []

        // Insert accounts first, build id→object map for relationship linking
        var accountMap: [UUID: Account] = [:]
        for dto in backup.accounts where !existingAccountIds.contains(dto.id) {
            let obj = dto.toModel(); context.insert(obj)
            accountMap[dto.id] = obj; summary.accounts += 1
        }
        // Also populate map for existing accounts (needed for tx linking in merge mode)
        if mode == .merge {
            for acc in (try? context.fetch(FetchDescriptor<Account>())) ?? [] { accountMap[acc.id] = acc }
        }

        var loanMap: [UUID: Loan] = [:]
        for dto in backup.loans where !existingLoanIds.contains(dto.id) {
            let obj = dto.toModel(); context.insert(obj)
            loanMap[dto.id] = obj; summary.loans += 1
        }
        if mode == .merge {
            for loan in (try? context.fetch(FetchDescriptor<Loan>())) ?? [] { loanMap[loan.id] = loan }
        }

        for dto in backup.transactions where !existingTxIds.contains(dto.id) {
            let obj = dto.toModel()
            obj.account = dto.accountId.flatMap { accountMap[$0] }
            obj.linkedLoan = dto.linkedLoanId.flatMap { loanMap[$0] }
            context.insert(obj); summary.transactions += 1
        }

        for dto in backup.budgets where !existingBudgetIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.budgets += 1
        }
        for dto in backup.savingsGoals where !existingGoalIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.goals += 1
        }
        for dto in backup.creditCards where !existingCardIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.creditCards += 1
        }
        for dto in backup.investments where !existingInvestmentIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.investments += 1
        }
        for dto in backup.cryptoHoldings where !existingCryptoIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.crypto += 1
        }
        for dto in backup.dividends {
            context.insert(dto.toModel()); summary.dividends += 1
        }
        for dto in backup.bnplPlans where !existingBNPLIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.bnpl += 1
        }

        if mode == .replace {
            if let dto = backup.userProfile  { context.insert(dto.toModel()) }
            if let dto = backup.appSettings  { context.insert(dto.toModel()) }
        }

        try context.save()
        return summary
    }

    // MARK: Delete all

    private func deleteAll(context: ModelContext) throws {
        try context.delete(model: Transaction.self)
        try context.delete(model: Account.self)
        try context.delete(model: Budget.self)
        try context.delete(model: SavingsGoal.self)
        try context.delete(model: Loan.self)
        try context.delete(model: CreditCard.self)
        try context.delete(model: Investment.self)
        try context.delete(model: CryptoHolding.self)
        try context.delete(model: Dividend.self)
        try context.delete(model: BNPLPlan.self)
        try context.delete(model: UserProfile.self)
        try context.delete(model: AppSettings.self)
        try context.save()
    }
}

struct ImportSummary {
    var accounts = 0; var transactions = 0; var budgets = 0; var goals = 0
    var loans = 0; var creditCards = 0; var investments = 0; var crypto = 0
    var dividends = 0; var bnpl = 0

    var total: Int { accounts + transactions + budgets + goals + loans + creditCards + investments + crypto + dividends + bnpl }

    var description: String {
        var parts: [String] = []
        if accounts > 0     { parts.append("\(accounts) accounts") }
        if transactions > 0 { parts.append("\(transactions) transactions") }
        if budgets > 0      { parts.append("\(budgets) budgets") }
        if goals > 0        { parts.append("\(goals) goals") }
        if loans > 0        { parts.append("\(loans) loans") }
        if creditCards > 0  { parts.append("\(creditCards) credit cards") }
        if investments > 0  { parts.append("\(investments) investments") }
        if crypto > 0       { parts.append("\(crypto) crypto") }
        if bnpl > 0         { parts.append("\(bnpl) BNPL plans") }
        return parts.isEmpty ? "Nothing imported" : parts.joined(separator: ", ")
    }
}

// MARK: - Model → DTO extensions

extension Account {
    var dto: AccountDTO {
        AccountDTO(id: id, name: name, type: type.rawValue, currency: currency,
                   balance: balance, initialBalance: initialBalance, bankName: bankName,
                   customBankName: customBankName, accountNumber: accountNumber,
                   color: color, icon: icon, isDefault: isDefault, isArchived: isArchived,
                   createdAt: createdAt, updatedAt: updatedAt, notes: notes,
                   minimumBalanceEnabled: minimumBalanceEnabled, minimumBalance: minimumBalance)
    }
}

extension Transaction {
    var dto: TransactionDTO {
        TransactionDTO(id: id, title: title, amount: amount, currency: currency,
                       amountInBaseCurrency: amountInBaseCurrency, type: type.rawValue,
                       category: category.rawValue, customCategory: customCategory,
                       date: date, notes: notes, receiptImageData: receiptImageData,
                       isRecurring: isRecurring, merchant: merchant,
                       paymentMethod: paymentMethod.rawValue, tags: tags,
                       isVerified: isVerified, isDuplicate: isDuplicate,
                       createdAt: createdAt, updatedAt: updatedAt,
                       accountId: account?.id, linkedLoanId: linkedLoan?.id,
                       isPending: isPending, isScheduled: isScheduled,
                       scheduledDate: scheduledDate, subtype: subtype?.rawValue,
                       splitItems: splitItems.isEmpty ? nil : splitItems,
                       incomeSource: incomeSource, latitude: latitude, longitude: longitude,
                       chequeNumber: chequeNumber, chequeDate: chequeDate,
                       isTaxDeductible: isTaxDeductible,
                       isVATReclaimable: isVATReclaimable,
                       customCategoryID: customCategoryID)
    }
}

extension Budget {
    var dto: BudgetDTO {
        BudgetDTO(id: id, name: name, category: category.rawValue,
                  customCategory: customCategory, amount: amount, currency: currency,
                  period: period.rawValue, startDate: startDate, endDate: endDate,
                  alertThreshold: alertThreshold, isActive: isActive, color: color,
                  createdAt: createdAt, spent: spent)
    }
}

extension SavingsGoal {
    var dto: SavingsGoalDTO {
        SavingsGoalDTO(id: id, name: name, targetAmount: targetAmount,
                       currentAmount: currentAmount, currency: currency,
                       targetDate: targetDate, icon: icon, color: color,
                       notes: notes, isCompleted: isCompleted, createdAt: createdAt)
    }
}

extension Loan {
    var dto: LoanDTO {
        LoanDTO(id: id, name: name, loanType: loanType.rawValue,
                principalAmount: principalAmount, outstandingBalance: outstandingBalance,
                interestRate: interestRate, emiAmount: emiAmount,
                startDate: startDate, endDate: endDate, nextPaymentDate: nextPaymentDate,
                currency: currency, lenderName: lenderName, notes: notes,
                isActive: isActive, createdAt: createdAt, paidInstallments: paidInstallments,
                reminderDaysBefore: reminderDaysBefore,
                lenderPersonName: lenderPersonName, lenderContactInfo: lenderContactInfo)
    }
}

extension CreditCard {
    var dto: CreditCardDTO {
        CreditCardDTO(id: id, name: name, bankName: bankName, last4Digits: last4Digits,
                      creditLimit: creditLimit, outstandingBalance: outstandingBalance,
                      minimumPayment: minimumPayment, dueDate: dueDate,
                      statementDate: statementDate, interestRate: interestRate,
                      currency: currency, color: color, icon: icon,
                      isActive: isActive, createdAt: createdAt)
    }
}

extension Investment {
    var dto: InvestmentDTO {
        InvestmentDTO(id: id, name: name, symbol: symbol, type: type.rawValue,
                      quantity: quantity, averageCost: averageCost, currentPrice: currentPrice,
                      currency: currency, exchange: exchange,
                      purchaseDate: purchaseDate, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension CryptoHolding {
    var dto: CryptoHoldingDTO {
        CryptoHoldingDTO(id: id, name: name, symbol: symbol,
                         quantity: quantity, averageCost: averageCost, currentPrice: currentPrice,
                         currency: currency, walletAddress: walletAddress, exchange: exchange,
                         purchaseDate: purchaseDate, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension Dividend {
    var dto: DividendDTO {
        DividendDTO(id: id, investmentId: investmentId, amount: amount,
                    currency: currency, date: date)
    }
}

extension BNPLPlan {
    var dto: BNPLPlanDTO {
        BNPLPlanDTO(id: id, name: name, provider: provider.rawValue,
                    customProvider: customProvider, merchant: merchant,
                    totalAmount: totalAmount, currency: currency,
                    installmentAmount: installmentAmount, totalInstallments: totalInstallments,
                    paidInstallments: paidInstallments, startDate: startDate,
                    nextPaymentDate: nextPaymentDate, notes: notes,
                    isCompleted: isCompleted, createdAt: createdAt)
    }
}

extension UserProfile {
    var dto: UserProfileDTO {
        UserProfileDTO(id: id, name: name, baseCurrency: baseCurrency,
                       language: language.rawValue, monthlyIncomeGoal: monthlyIncomeGoal,
                       monthlySavingsGoal: monthlySavingsGoal, joinDate: joinDate,
                       isPremium: isPremium, hasCompletedOnboarding: hasCompletedOnboarding)
    }
}

extension AppSettings {
    var dto: AppSettingsDTO {
        AppSettingsDTO(id: id, useBiometrics: useBiometrics, usePIN: usePIN,
                       pinHash: pinHash, autoLockMinutes: autoLockMinutes,
                       showBalanceOnDashboard: showBalanceOnDashboard,
                       defaultCurrency: defaultCurrency,
                       notificationsEnabled: notificationsEnabled,
                       budgetAlertsEnabled: budgetAlertsEnabled,
                       billRemindersEnabled: billRemindersEnabled,
                       salaryReminderEnabled: salaryReminderEnabled,
                       reminderDaysBefore: reminderDaysBefore,
                       cloudSyncEnabled: cloudSyncEnabled,
                       theme: theme.rawValue, accentColor: accentColor)
    }
}

// MARK: - DTO → Model extensions

extension AccountDTO {
    func toModel() -> Account {
        let a = Account(id: id, name: name, type: AccountType(rawValue: type) ?? .current,
                        currency: currency, balance: balance, bankName: bankName,
                        customBankName: customBankName, accountNumber: accountNumber,
                        color: color, icon: icon, isDefault: isDefault,
                        isArchived: isArchived, notes: notes,
                        minimumBalanceEnabled: minimumBalanceEnabled, minimumBalance: minimumBalance)
        a.initialBalance = initialBalance
        a.createdAt = createdAt; a.updatedAt = updatedAt
        return a
    }
}

extension TransactionDTO {
    func toModel() -> Transaction {
        let t = Transaction(id: id, title: title, amount: amount, currency: currency,
                            amountInBaseCurrency: amountInBaseCurrency,
                            type: TransactionType(rawValue: type) ?? .expense,
                            category: TransactionCategory(rawValue: category) ?? .other,
                            customCategory: customCategory, date: date, notes: notes,
                            receiptImageData: receiptImageData, isRecurring: isRecurring,
                            merchant: merchant,
                            paymentMethod: PaymentMethod(rawValue: paymentMethod) ?? .cash,
                            chequeNumber: chequeNumber, chequeDate: chequeDate,
                            tags: tags, isVerified: isVerified, isDuplicate: isDuplicate,
                            isPending: isPending ?? false,
                            isScheduled: isScheduled ?? false,
                            scheduledDate: scheduledDate,
                            subtype: subtype.flatMap { TransactionSubtype(rawValue: $0) },
                            splitItems: splitItems ?? [],
                            incomeSource: incomeSource,
                            latitude: latitude, longitude: longitude,
                            isTaxDeductible: isTaxDeductible ?? false,
                            isVATReclaimable: isVATReclaimable ?? false,
                            customCategoryID: customCategoryID)
        t.createdAt = createdAt; t.updatedAt = updatedAt
        return t
    }
}

extension BudgetDTO {
    func toModel() -> Budget {
        let b = Budget(id: id, name: name,
                       category: TransactionCategory(rawValue: category) ?? .other,
                       customCategory: customCategory, amount: amount, currency: currency,
                       period: BudgetPeriod(rawValue: period) ?? .monthly,
                       startDate: startDate, endDate: endDate,
                       alertThreshold: alertThreshold, isActive: isActive, color: color)
        b.spent = spent; b.createdAt = createdAt
        return b
    }
}

extension SavingsGoalDTO {
    func toModel() -> SavingsGoal {
        let g = SavingsGoal(id: id, name: name, targetAmount: targetAmount,
                            currentAmount: currentAmount, currency: currency,
                            targetDate: targetDate, icon: icon, color: color, notes: notes)
        g.isCompleted = isCompleted; g.createdAt = createdAt
        return g
    }
}

extension LoanDTO {
    func toModel() -> Loan {
        let l = Loan(id: id, name: name,
                     loanType: LoanType(rawValue: loanType) ?? .personal,
                     principalAmount: principalAmount, outstandingBalance: outstandingBalance,
                     interestRate: interestRate, emiAmount: emiAmount,
                     startDate: startDate, endDate: endDate, nextPaymentDate: nextPaymentDate,
                     currency: currency, lenderName: lenderName,
                     lenderPersonName: lenderPersonName, lenderContactInfo: lenderContactInfo,
                     notes: notes, paidInstallments: paidInstallments,
                     reminderDaysBefore: reminderDaysBefore)
        l.isActive = isActive; l.createdAt = createdAt
        return l
    }
}

extension CreditCardDTO {
    func toModel() -> CreditCard {
        let c = CreditCard(id: id, name: name, bankName: bankName, last4Digits: last4Digits,
                           creditLimit: creditLimit, outstandingBalance: outstandingBalance,
                           minimumPayment: minimumPayment, dueDate: dueDate,
                           statementDate: statementDate, interestRate: interestRate,
                           currency: currency, color: color, icon: icon)
        c.isActive = isActive; c.createdAt = createdAt
        return c
    }
}

extension InvestmentDTO {
    func toModel() -> Investment {
        let i = Investment(id: id, name: name, symbol: symbol,
                           type: InvestmentType(rawValue: type) ?? .stock,
                           quantity: quantity, averageCost: averageCost,
                           currentPrice: currentPrice, currency: currency,
                           exchange: exchange, purchaseDate: purchaseDate)
        i.createdAt = createdAt; i.updatedAt = updatedAt
        return i
    }
}

extension CryptoHoldingDTO {
    func toModel() -> CryptoHolding {
        let c = CryptoHolding(id: id, name: name, symbol: symbol,
                              quantity: quantity, averageCost: averageCost,
                              currentPrice: currentPrice, currency: currency,
                              walletAddress: walletAddress, exchange: exchange,
                              purchaseDate: purchaseDate)
        c.createdAt = createdAt; c.updatedAt = updatedAt
        return c
    }
}

extension DividendDTO {
    func toModel() -> Dividend {
        Dividend(id: id, investmentId: investmentId, amount: amount,
                 currency: currency, date: date)
    }
}

extension BNPLPlanDTO {
    func toModel() -> BNPLPlan {
        let b = BNPLPlan(id: id, name: name,
                         provider: BNPLProvider(rawValue: provider) ?? .custom,
                         customProvider: customProvider, merchant: merchant,
                         totalAmount: totalAmount, currency: currency,
                         installmentAmount: installmentAmount,
                         totalInstallments: totalInstallments,
                         paidInstallments: paidInstallments,
                         startDate: startDate, nextPaymentDate: nextPaymentDate, notes: notes)
        b.isCompleted = isCompleted; b.createdAt = createdAt
        return b
    }
}

extension UserProfileDTO {
    func toModel() -> UserProfile {
        let p = UserProfile(id: id, name: name, baseCurrency: baseCurrency,
                            language: AppLanguage(rawValue: language) ?? .english,
                            monthlyIncomeGoal: monthlyIncomeGoal,
                            monthlySavingsGoal: monthlySavingsGoal)
        p.isPremium = isPremium
        p.hasCompletedOnboarding = hasCompletedOnboarding
        p.joinDate = joinDate
        return p
    }
}

extension AppSettingsDTO {
    func toModel() -> AppSettings {
        let s = AppSettings(id: id, useBiometrics: useBiometrics, usePIN: usePIN,
                            pinHash: pinHash, autoLockMinutes: autoLockMinutes,
                            showBalanceOnDashboard: showBalanceOnDashboard,
                            defaultCurrency: defaultCurrency,
                            notificationsEnabled: notificationsEnabled,
                            budgetAlertsEnabled: budgetAlertsEnabled,
                            billRemindersEnabled: billRemindersEnabled,
                            salaryReminderEnabled: salaryReminderEnabled,
                            reminderDaysBefore: reminderDaysBefore,
                            cloudSyncEnabled: cloudSyncEnabled,
                            theme: AppTheme(rawValue: theme) ?? .system,
                            accentColor: accentColor)
        return s
    }
}
