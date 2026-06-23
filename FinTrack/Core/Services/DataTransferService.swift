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
    var bills: [BillDTO]?                   // v7+ (optional for backward-compatible decoding)
    var salaryRecords: [SalaryRecordDTO]?   // v8+
    var freelanceProjects: [FreelanceProjectDTO]?  // v8+
    var rentalProperties: [RentalPropertyDTO]?     // v8+
    var moneyLent: [MoneyLentDTO]?          // v9+
    var moneyBorrowed: [MoneyBorrowedDTO]?  // v9+
    var goldHoldings: [GoldHoldingDTO]?          // v10+
    var realEstateProperties: [RealEstatePropertyDTO]?  // v11+
    var vehicles: [VehicleDTO]?                  // v11+
    var personalAssets: [PersonalAssetDTO]?      // v11+
    var digitalAssets: [DigitalAssetDTO]?        // v11+
    var netWorthSnapshots: [NetWorthSnapshotDTO]? // v11+

    static let currentVersion = 6
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
    // v12+ fields (optional for backward-compat decoding)
    var goalTypeRaw: String?
    var linkedAccountId: UUID?
    var autoContributionEnabled: Bool?
    var autoContributionAmount: Double?
    var autoContributionFrequencyRaw: String?
    var autoContributionDay: Int?
    var roundUpEnabled: Bool?
    var salaryPercentage: Double?
    var conflictPriority: Int?
    var isArchived: Bool?
    var updatedAt: Date?
    var notifiedMilestones: [Double]?
    var propertyTargetPrice: Double?
    var downPaymentPercent: Double?
    var educationInstitution: String?
    var hajjTravelYear: Int?
    var emergencyMonthsTarget: Int?
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
    var currency: String; var exchange: String?; var notes: String?
    var purchaseDate: Date; var createdAt: Date; var updatedAt: Date
    // v10+ additions (optional for backward-compat decoding)
    var expenseRatio: Double?; var dividendYield: Double?
    var lotsData: Data?; var salesData: Data?; var realizedPnL: Double?
}

struct CryptoHoldingDTO: Codable {
    var id: UUID; var name: String; var symbol: String
    var quantity: Double; var averageCost: Double; var currentPrice: Double
    var currency: String; var walletAddress: String?; var exchange: String?; var notes: String?
    var purchaseDate: Date; var createdAt: Date; var updatedAt: Date
    // v10+ additions
    var lotsData: Data?; var salesData: Data?; var realizedPnL: Double?
}

struct GoldHoldingDTO: Codable {
    var id: UUID; var name: String; var metalRaw: String; var formRaw: String
    var weightGrams: Double; var weightUnitRaw: String
    var purchasePricePerGram: Double; var currentPricePerGram: Double
    var currency: String; var storageLocation: String?; var locationPurchased: String?
    var isDubaiGoldSoukPurchase: Bool; var purchaseDate: Date
    var notes: String?; var isArchived: Bool; var createdAt: Date; var updatedAt: Date
}

struct RealEstatePropertyDTO: Codable {
    var id: UUID; var name: String; var propertyTypeRaw: String; var address: String?
    var purchasePrice: Double; var purchaseDate: Date; var currentValue: Double
    var mortgageBalance: Double; var ownershipPercentage: Double; var currency: String
    var area: Double?; var areaUnit: String?; var notes: String?
    var isArchived: Bool; var createdAt: Date; var updatedAt: Date
}

struct VehicleDTO: Codable {
    var id: UUID; var make: String; var model: String; var year: Int
    var purchasePrice: Double; var purchaseDate: Date; var currency: String
    var registrationNumber: String?; var registrationExpiry: Date?
    var insuranceProvider: String?; var insuranceExpiry: Date?
    var depreciationRate: Double; var depreciationMethodRaw: String
    var manualCurrentValue: Double?; var color: String?; var notes: String?
    var isArchived: Bool; var createdAt: Date; var updatedAt: Date
}

struct PersonalAssetDTO: Codable {
    var id: UUID; var name: String; var categoryRaw: String
    var purchasePrice: Double; var purchaseDate: Date
    var insuranceValue: Double; var estimatedMarketValue: Double; var currency: String
    var serialNumber: String?; var brand: String?; var notes: String?
    var isArchived: Bool; var createdAt: Date; var updatedAt: Date
}

struct DigitalAssetDTO: Codable {
    var id: UUID; var name: String; var typeRaw: String
    var acquisitionValue: Double; var acquisitionDate: Date; var currentValue: Double
    var currency: String; var platform: String?; var identifier: String?
    var expiryDate: Date?; var notes: String?; var isArchived: Bool
    var createdAt: Date; var updatedAt: Date
}

struct NetWorthSnapshotDTO: Codable {
    var id: UUID; var date: Date; var totalAssets: Double
    var totalLiabilities: Double; var netWorth: Double; var currency: String
    var breakdownData: Data
}

struct DividendDTO: Codable {
    var id: UUID; var investmentId: UUID; var amount: Double
    var currency: String; var date: Date; var paymentDate: Date?; var notes: String?
    var securityName: String?; var exDividendDate: Date?; var taxWithholding: Double?
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
    var defaultCurrency: String
    var decoyPINHash: String?; var hiddenModeEnabled: Bool?
    var twoFactorEnabled: Bool?; var twoFactorSecret: String?
    var auditLogEnabled: Bool?; var encryptionEnabled: Bool?
    var notificationsEnabled: Bool; var budgetAlertsEnabled: Bool
    var billRemindersEnabled: Bool; var salaryReminderEnabled: Bool; var reminderDaysBefore: Int
    var lowBalanceAlertEnabled: Bool?; var lowBalanceThreshold: Double?
    var largeTransactionAlertEnabled: Bool?; var largeTransactionThreshold: Double?
    var goalMilestoneAlertEnabled: Bool?
    var budgetAlertAt75: Bool?; var budgetAlertAt90: Bool?; var budgetAlertAt100: Bool?
    var weeklyDigestEnabled: Bool?; var monthlyDigestEnabled: Bool?
    var digestDayOfWeek: Int?; var digestDayOfMonth: Int?; var digestHour: Int?
    var cloudSyncEnabled: Bool; var theme: String; var accentColor: String?; var accentColorName: String?
}

struct BillDTO: Codable {
    var id: UUID; var name: String; var provider: String?
    var billCategoryRaw: String; var amount: Double; var currency: String
    var billingCycleRaw: String; var nextDueDate: Date; var isAutoPay: Bool
    var autoPayWindowDays: Int; var paymentMethodRaw: String; var notes: String?
    var colorName: String; var icon: String; var isActive: Bool; var isSubscription: Bool
    var reminderDaysBefore: [Int]; var priceHistory: [PriceHistoryEntry]
    var lastPaidDate: Date?; var lastPaidAmount: Double?; var createdAt: Date
}

struct SalaryRecordDTO: Codable {
    var id: UUID; var employerName: String; var jobTitle: String; var currency: String
    var expectedAmount: Double; var expectedPaymentDay: Int; var paymentFrequencyRaw: String
    var isActive: Bool; var colorName: String; var notes: String?
    var paymentsData: Data; var createdAt: Date; var updatedAt: Date
}

struct FreelanceProjectDTO: Codable {
    var id: UUID; var projectName: String; var clientName: String
    var projectDescription: String?; var currency: String; var totalValue: Double
    var statusRaw: String; var startDate: Date; var endDate: Date?
    var invoicesData: Data; var notes: String?; var colorName: String
    var isArchived: Bool; var createdAt: Date; var updatedAt: Date
}

struct RentalPropertyDTO: Codable {
    var id: UUID; var propertyName: String; var propertyTypeRaw: String
    var address: String?; var currency: String; var monthlyRentExpected: Double
    var isOccupied: Bool; var occupancyPeriodsData: Data; var paymentHistoryData: Data
    var notes: String?; var colorName: String; var isActive: Bool
    var createdAt: Date; var updatedAt: Date
}

struct MoneyLentDTO: Codable {
    var id: UUID; var borrowerName: String; var contactInfo: String?
    var amount: Double; var currency: String; var lendingDate: Date
    var dueDate: Date?; var notes: String?; var statusRaw: String
    var reminderEnabled: Bool; var reminderDaysBefore: Int; var color: String
    var repaymentsData: Data; var createdAt: Date; var updatedAt: Date
}

struct MoneyBorrowedDTO: Codable {
    var id: UUID; var lenderName: String; var contactInfo: String?
    var amount: Double; var currency: String; var borrowDate: Date
    var dueDate: Date?; var notes: String?; var statusRaw: String
    var reminderEnabled: Bool; var reminderDaysBefore: Int; var color: String
    var repaymentsData: Data; var createdAt: Date; var updatedAt: Date
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
        let bills           = try context.fetch(FetchDescriptor<Bill>())
        let salaryRecs      = try context.fetch(FetchDescriptor<SalaryRecord>())
        let freelanceProjs  = try context.fetch(FetchDescriptor<FreelanceProject>())
        let rentalProps     = try context.fetch(FetchDescriptor<RentalProperty>())
        let lentItems       = try context.fetch(FetchDescriptor<MoneyLent>())
        let borrowedItems   = try context.fetch(FetchDescriptor<MoneyBorrowed>())
        let goldItems       = try context.fetch(FetchDescriptor<GoldHolding>())
        let realEstateItems = try context.fetch(FetchDescriptor<RealEstateProperty>())
        let vehicleItems    = try context.fetch(FetchDescriptor<Vehicle>())
        let personalItems   = try context.fetch(FetchDescriptor<PersonalAsset>())
        let digitalItems    = try context.fetch(FetchDescriptor<DigitalAsset>())
        let snapshots       = try context.fetch(FetchDescriptor<NetWorthSnapshot>())

        var backup = FinTrackBackup(
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
        backup.bills = bills.map(\.dto)
        backup.salaryRecords = salaryRecs.map(\.dto)
        backup.freelanceProjects = freelanceProjs.map(\.dto)
        backup.rentalProperties = rentalProps.map(\.dto)
        backup.moneyLent = lentItems.map(\.dto)
        backup.moneyBorrowed = borrowedItems.map(\.dto)
        backup.goldHoldings         = goldItems.map(\.dto)
        backup.realEstateProperties = realEstateItems.map(\.dto)
        backup.vehicles             = vehicleItems.map(\.dto)
        backup.personalAssets       = personalItems.map(\.dto)
        backup.digitalAssets        = digitalItems.map(\.dto)
        backup.netWorthSnapshots    = snapshots.map(\.dto)

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
        let existingBillIds          = mode == .merge ? Set((try? context.fetch(FetchDescriptor<Bill>()))?.map(\.id) ?? []) : []
        let existingSalaryIds        = mode == .merge ? Set((try? context.fetch(FetchDescriptor<SalaryRecord>()))?.map(\.id) ?? []) : []
        let existingFreelanceIds     = mode == .merge ? Set((try? context.fetch(FetchDescriptor<FreelanceProject>()))?.map(\.id) ?? []) : []
        let existingRentalIds        = mode == .merge ? Set((try? context.fetch(FetchDescriptor<RentalProperty>()))?.map(\.id) ?? []) : []
        let existingLentIds          = mode == .merge ? Set((try? context.fetch(FetchDescriptor<MoneyLent>()))?.map(\.id) ?? []) : []
        let existingBorrowedIds      = mode == .merge ? Set((try? context.fetch(FetchDescriptor<MoneyBorrowed>()))?.map(\.id) ?? []) : []
        let existingGoldIds          = mode == .merge ? Set((try? context.fetch(FetchDescriptor<GoldHolding>()))?.map(\.id) ?? []) : []

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
        for dto in (backup.bills ?? []) where !existingBillIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.bills += 1
        }
        for dto in (backup.salaryRecords ?? []) where !existingSalaryIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.salaryRecords += 1
        }
        for dto in (backup.freelanceProjects ?? []) where !existingFreelanceIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.freelanceProjects += 1
        }
        for dto in (backup.rentalProperties ?? []) where !existingRentalIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.rentalProperties += 1
        }
        for dto in (backup.moneyLent ?? []) where !existingLentIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.moneyLent += 1
        }
        for dto in (backup.moneyBorrowed ?? []) where !existingBorrowedIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.moneyBorrowed += 1
        }
        for dto in (backup.goldHoldings ?? []) where !existingGoldIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.goldHoldings += 1
        }

        let existingREIds = Set((try? context.fetch(FetchDescriptor<RealEstateProperty>()))?.map(\.id) ?? [])
        let existingVehIds = Set((try? context.fetch(FetchDescriptor<Vehicle>()))?.map(\.id) ?? [])
        let existingPAIds = Set((try? context.fetch(FetchDescriptor<PersonalAsset>()))?.map(\.id) ?? [])
        let existingDAIds = Set((try? context.fetch(FetchDescriptor<DigitalAsset>()))?.map(\.id) ?? [])
        let existingSnapIds = Set((try? context.fetch(FetchDescriptor<NetWorthSnapshot>()))?.map(\.id) ?? [])

        for dto in (backup.realEstateProperties ?? []) where !existingREIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.realEstateProperties += 1
        }
        for dto in (backup.vehicles ?? []) where !existingVehIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.vehicles += 1
        }
        for dto in (backup.personalAssets ?? []) where !existingPAIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.personalAssets += 1
        }
        for dto in (backup.digitalAssets ?? []) where !existingDAIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.digitalAssets += 1
        }
        for dto in (backup.netWorthSnapshots ?? []) where !existingSnapIds.contains(dto.id) {
            context.insert(dto.toModel()); summary.netWorthSnapshots += 1
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
        // Financial records
        try context.delete(model: Transaction.self)
        try context.delete(model: Account.self)
        try context.delete(model: Budget.self)
        try context.delete(model: SavingsGoal.self)
        try context.delete(model: BudgetEnvelope.self)
        try context.delete(model: BudgetTemplate.self)
        try context.delete(model: Loan.self)
        try context.delete(model: CreditCard.self)
        try context.delete(model: BNPLPlan.self)
        try context.delete(model: GiftCard.self)
        try context.delete(model: LoyaltyProgram.self)
        // Investments
        try context.delete(model: Investment.self)
        try context.delete(model: CryptoHolding.self)
        try context.delete(model: Dividend.self)
        try context.delete(model: GoldHolding.self)
        // Bills & income
        try context.delete(model: Bill.self)
        try context.delete(model: SalaryRecord.self)
        try context.delete(model: FreelanceProject.self)
        try context.delete(model: RentalProperty.self)
        // Debt tracking
        try context.delete(model: MoneyLent.self)
        try context.delete(model: MoneyBorrowed.self)
        // Assets & net worth
        try context.delete(model: RealEstateProperty.self)
        try context.delete(model: Vehicle.self)
        try context.delete(model: PersonalAsset.self)
        try context.delete(model: DigitalAsset.self)
        try context.delete(model: NetWorthSnapshot.self)
        try context.delete(model: NetWorthMilestone.self)
        // Tax
        try context.delete(model: TaxRecord.self)
        try context.delete(model: TaxDocument.self)
        try context.delete(model: ZakatRecord.self)
        try context.delete(model: TaxConfiguration.self)
        // Business
        try context.delete(model: ClientProfile.self)
        try context.delete(model: BusinessInvoice.self)
        try context.delete(model: MileageTrip.self)
        try context.delete(model: BusinessProject.self)
        // Family
        try context.delete(model: FamilyGroup.self)
        try context.delete(model: ChildProfile.self)
        try context.delete(model: SharedFamilyGoal.self)
        // Premium
        try context.delete(model: RetirementPlan.self)
        try context.delete(model: LifeEventPlan.self)
        try context.delete(model: AdvisorAccess.self)
        // Misc
        try context.delete(model: RemittanceRecord.self)
        try context.delete(model: InsurancePolicy.self)
        try context.delete(model: ImportedFile.self)
        try context.delete(model: DocumentAttachment.self)
        try context.delete(model: AuditLogEntry.self)
        try context.delete(model: CategorizationRule.self)
        try context.delete(model: CustomCategory.self)
        // Profile / settings (restore from backup after this)
        try context.delete(model: UserProfile.self)
        try context.delete(model: AppSettings.self)
        try context.save()
    }
}

struct ImportSummary {
    var accounts = 0; var transactions = 0; var budgets = 0; var goals = 0
    var loans = 0; var creditCards = 0; var investments = 0; var crypto = 0
    var dividends = 0; var bnpl = 0; var bills = 0
    var salaryRecords = 0; var freelanceProjects = 0; var rentalProperties = 0
    var moneyLent = 0; var moneyBorrowed = 0; var goldHoldings = 0
    var realEstateProperties = 0; var vehicles = 0; var personalAssets = 0
    var digitalAssets = 0; var netWorthSnapshots = 0

    var total: Int {
        accounts + transactions + budgets + goals + loans + creditCards
        + investments + crypto + dividends + bnpl + bills
        + salaryRecords + freelanceProjects + rentalProperties
        + moneyLent + moneyBorrowed + goldHoldings
        + realEstateProperties + vehicles + personalAssets + digitalAssets + netWorthSnapshots
    }

    var description: String {
        var parts: [String] = []
        if accounts > 0          { parts.append("\(accounts) accounts") }
        if transactions > 0      { parts.append("\(transactions) transactions") }
        if budgets > 0           { parts.append("\(budgets) budgets") }
        if goals > 0             { parts.append("\(goals) goals") }
        if loans > 0             { parts.append("\(loans) loans") }
        if creditCards > 0       { parts.append("\(creditCards) credit cards") }
        if investments > 0       { parts.append("\(investments) investments") }
        if crypto > 0            { parts.append("\(crypto) crypto") }
        if bnpl > 0              { parts.append("\(bnpl) BNPL plans") }
        if bills > 0             { parts.append("\(bills) bills") }
        if salaryRecords > 0     { parts.append("\(salaryRecords) salary records") }
        if freelanceProjects > 0 { parts.append("\(freelanceProjects) freelance projects") }
        if rentalProperties > 0  { parts.append("\(rentalProperties) rental properties") }
        if moneyLent > 0         { parts.append("\(moneyLent) money lent records") }
        if moneyBorrowed > 0     { parts.append("\(moneyBorrowed) money borrowed records") }
        if goldHoldings > 0      { parts.append("\(goldHoldings) gold holdings") }
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
        SavingsGoalDTO(
            id: id, name: name, targetAmount: targetAmount,
            currentAmount: currentAmount, currency: currency,
            targetDate: targetDate, icon: icon, color: color,
            notes: notes, isCompleted: isCompleted, createdAt: createdAt,
            goalTypeRaw: goalTypeRaw,
            linkedAccountId: linkedAccountId,
            autoContributionEnabled: autoContributionEnabled,
            autoContributionAmount: autoContributionAmount,
            autoContributionFrequencyRaw: autoContributionFrequencyRaw,
            autoContributionDay: autoContributionDay,
            roundUpEnabled: roundUpEnabled,
            salaryPercentage: salaryPercentage,
            conflictPriority: conflictPriority,
            isArchived: isArchived,
            updatedAt: updatedAt,
            notifiedMilestones: notifiedMilestones,
            propertyTargetPrice: propertyTargetPrice,
            downPaymentPercent: downPaymentPercent,
            educationInstitution: educationInstitution,
            hajjTravelYear: hajjTravelYear,
            emergencyMonthsTarget: emergencyMonthsTarget
        )
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
                      currency: currency, exchange: exchange, notes: notes,
                      purchaseDate: purchaseDate, createdAt: createdAt, updatedAt: updatedAt,
                      expenseRatio: expenseRatio, dividendYield: dividendYield,
                      lotsData: lotsData.isEmpty ? nil : lotsData,
                      salesData: salesData.isEmpty ? nil : salesData,
                      realizedPnL: realizedPnL)
    }
}

extension CryptoHolding {
    var dto: CryptoHoldingDTO {
        CryptoHoldingDTO(id: id, name: name, symbol: symbol,
                         quantity: quantity, averageCost: averageCost, currentPrice: currentPrice,
                         currency: currency, walletAddress: walletAddress, exchange: exchange,
                         notes: notes, purchaseDate: purchaseDate,
                         createdAt: createdAt, updatedAt: updatedAt,
                         lotsData: lotsData.isEmpty ? nil : lotsData,
                         salesData: salesData.isEmpty ? nil : salesData,
                         realizedPnL: realizedPnL)
    }
}

extension GoldHolding {
    var dto: GoldHoldingDTO {
        GoldHoldingDTO(id: id, name: name, metalRaw: metal.rawValue, formRaw: form.rawValue,
                       weightGrams: weightGrams, weightUnitRaw: weightUnit.rawValue,
                       purchasePricePerGram: purchasePricePerGram,
                       currentPricePerGram: currentPricePerGram, currency: currency,
                       storageLocation: storageLocation, locationPurchased: locationPurchased,
                       isDubaiGoldSoukPurchase: isDubaiGoldSoukPurchase,
                       purchaseDate: purchaseDate, notes: notes, isArchived: isArchived,
                       createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension Dividend {
    var dto: DividendDTO {
        DividendDTO(id: id, investmentId: investmentId, amount: amount,
                    currency: currency, date: date, notes: notes,
                    securityName: securityName, exDividendDate: exDividendDate,
                    taxWithholding: taxWithholding)
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

extension Bill {
    var dto: BillDTO {
        BillDTO(id: id, name: name, provider: provider,
                billCategoryRaw: billCategoryRaw, amount: amount, currency: currency,
                billingCycleRaw: billingCycleRaw, nextDueDate: nextDueDate,
                isAutoPay: isAutoPay, autoPayWindowDays: autoPayWindowDays,
                paymentMethodRaw: paymentMethodRaw, notes: notes,
                colorName: colorName, icon: icon, isActive: isActive,
                isSubscription: isSubscription, reminderDaysBefore: reminderDaysBefore,
                priceHistory: priceHistory, lastPaidDate: lastPaidDate,
                lastPaidAmount: lastPaidAmount, createdAt: createdAt)
    }
}

extension AppSettings {
    var dto: AppSettingsDTO {
        AppSettingsDTO(
            id: id, useBiometrics: useBiometrics, usePIN: usePIN,
            pinHash: pinHash, autoLockMinutes: autoLockMinutes,
            showBalanceOnDashboard: showBalanceOnDashboard,
            defaultCurrency: defaultCurrency,
            decoyPINHash: decoyPINHash, hiddenModeEnabled: hiddenModeEnabled,
            twoFactorEnabled: twoFactorEnabled, twoFactorSecret: twoFactorSecret,
            auditLogEnabled: auditLogEnabled, encryptionEnabled: encryptionEnabled,
            notificationsEnabled: notificationsEnabled,
            budgetAlertsEnabled: budgetAlertsEnabled,
            billRemindersEnabled: billRemindersEnabled,
            salaryReminderEnabled: salaryReminderEnabled,
            reminderDaysBefore: reminderDaysBefore,
            lowBalanceAlertEnabled: lowBalanceAlertEnabled,
            lowBalanceThreshold: lowBalanceThreshold,
            largeTransactionAlertEnabled: largeTransactionAlertEnabled,
            largeTransactionThreshold: largeTransactionThreshold,
            goalMilestoneAlertEnabled: goalMilestoneAlertEnabled,
            budgetAlertAt75: budgetAlertAt75, budgetAlertAt90: budgetAlertAt90,
            budgetAlertAt100: budgetAlertAt100,
            weeklyDigestEnabled: weeklyDigestEnabled, monthlyDigestEnabled: monthlyDigestEnabled,
            digestDayOfWeek: digestDayOfWeek, digestDayOfMonth: digestDayOfMonth,
            digestHour: digestHour,
            cloudSyncEnabled: cloudSyncEnabled, theme: theme.rawValue,
            accentColor: accentColorName, accentColorName: accentColorName
        )
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
        let g = SavingsGoal(
            id: id, name: name, targetAmount: targetAmount,
            currentAmount: currentAmount, currency: currency,
            targetDate: targetDate, icon: icon, color: color, notes: notes,
            goalType: SavingsGoalType(rawValue: goalTypeRaw ?? "") ?? .custom,
            linkedAccountId: linkedAccountId,
            autoContributionEnabled: autoContributionEnabled ?? false,
            autoContributionAmount: autoContributionAmount ?? 0,
            autoContributionFrequency: GoalContributionFrequency(rawValue: autoContributionFrequencyRaw ?? "") ?? .monthly,
            autoContributionDay: autoContributionDay ?? 1,
            roundUpEnabled: roundUpEnabled ?? false,
            salaryPercentage: salaryPercentage ?? 0,
            conflictPriority: conflictPriority ?? 0,
            isArchived: isArchived ?? false,
            propertyTargetPrice: propertyTargetPrice ?? 0,
            downPaymentPercent: downPaymentPercent ?? 20,
            educationInstitution: educationInstitution,
            hajjTravelYear: hajjTravelYear ?? 0,
            emergencyMonthsTarget: emergencyMonthsTarget ?? 3
        )
        g.isCompleted = isCompleted
        g.createdAt = createdAt
        if let updated = updatedAt { g.updatedAt = updated }
        if let milestones = notifiedMilestones { g.notifiedMilestones = milestones }
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
                           exchange: exchange, notes: notes, purchaseDate: purchaseDate,
                           expenseRatio: expenseRatio ?? 0,
                           dividendYield: dividendYield ?? 0,
                           realizedPnL: realizedPnL ?? 0)
        if let ld = lotsData  { i.lotsData  = ld }
        if let sd = salesData { i.salesData = sd }
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
                              notes: notes, purchaseDate: purchaseDate,
                              realizedPnL: realizedPnL ?? 0)
        if let ld = lotsData  { c.lotsData  = ld }
        if let sd = salesData { c.salesData = sd }
        c.createdAt = createdAt; c.updatedAt = updatedAt
        return c
    }
}

extension GoldHoldingDTO {
    func toModel() -> GoldHolding {
        GoldHolding(id: id, name: name,
                    metal: PreciousMetal(rawValue: metalRaw) ?? .gold,
                    form: GoldForm(rawValue: formRaw) ?? .bar,
                    weightGrams: weightGrams,
                    weightUnit: WeightUnit(rawValue: weightUnitRaw) ?? .grams,
                    purchasePricePerGram: purchasePricePerGram,
                    currentPricePerGram: currentPricePerGram,
                    currency: currency, storageLocation: storageLocation,
                    locationPurchased: locationPurchased,
                    isDubaiGoldSoukPurchase: isDubaiGoldSoukPurchase,
                    purchaseDate: purchaseDate, notes: notes, isArchived: isArchived)
    }
}

extension DividendDTO {
    func toModel() -> Dividend {
        Dividend(id: id, investmentId: investmentId, amount: amount,
                 currency: currency, date: date, paymentDate: paymentDate,
                 notes: notes, securityName: securityName,
                 exDividendDate: exDividendDate, taxWithholding: taxWithholding ?? 0)
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

extension BillDTO {
    func toModel() -> Bill {
        let b = Bill(id: id, name: name, provider: provider,
                     billCategory: BillCategory(rawValue: billCategoryRaw) ?? .other,
                     amount: amount, currency: currency,
                     billingCycle: BillingCycle(rawValue: billingCycleRaw) ?? .monthly,
                     nextDueDate: nextDueDate, isAutoPay: isAutoPay,
                     autoPayWindowDays: autoPayWindowDays,
                     paymentMethod: PaymentMethod(rawValue: paymentMethodRaw) ?? .bankTransfer,
                     notes: notes, colorName: colorName, icon: icon,
                     isActive: isActive, isSubscription: isSubscription,
                     reminderDaysBefore: reminderDaysBefore)
        b.priceHistory = priceHistory
        b.lastPaidDate = lastPaidDate
        b.lastPaidAmount = lastPaidAmount
        b.createdAt = createdAt
        return b
    }
}

extension AppSettingsDTO {
    func toModel() -> AppSettings {
        AppSettings(
            id: id, useBiometrics: useBiometrics, usePIN: usePIN,
            pinHash: pinHash, autoLockMinutes: autoLockMinutes,
            showBalanceOnDashboard: showBalanceOnDashboard,
            defaultCurrency: defaultCurrency,
            decoyPINHash: decoyPINHash, hiddenModeEnabled: hiddenModeEnabled ?? false,
            twoFactorEnabled: twoFactorEnabled ?? false, twoFactorSecret: twoFactorSecret,
            auditLogEnabled: auditLogEnabled ?? true, encryptionEnabled: encryptionEnabled ?? true,
            notificationsEnabled: notificationsEnabled,
            budgetAlertsEnabled: budgetAlertsEnabled,
            billRemindersEnabled: billRemindersEnabled,
            salaryReminderEnabled: salaryReminderEnabled,
            reminderDaysBefore: reminderDaysBefore,
            lowBalanceAlertEnabled: lowBalanceAlertEnabled ?? true,
            lowBalanceThreshold: lowBalanceThreshold ?? 100,
            largeTransactionAlertEnabled: largeTransactionAlertEnabled ?? true,
            largeTransactionThreshold: largeTransactionThreshold ?? 1000,
            goalMilestoneAlertEnabled: goalMilestoneAlertEnabled ?? true,
            budgetAlertAt75: budgetAlertAt75 ?? true, budgetAlertAt90: budgetAlertAt90 ?? true,
            budgetAlertAt100: budgetAlertAt100 ?? true,
            weeklyDigestEnabled: weeklyDigestEnabled ?? false,
            monthlyDigestEnabled: monthlyDigestEnabled ?? false,
            digestDayOfWeek: digestDayOfWeek ?? 2, digestDayOfMonth: digestDayOfMonth ?? 1,
            digestHour: digestHour ?? 9,
            cloudSyncEnabled: cloudSyncEnabled,
            theme: AppTheme(rawValue: theme) ?? .system,
            accentColorName: accentColorName ?? accentColor ?? "teal"
        )
    }
}

// MARK: - Income Model DTO extensions

extension SalaryRecord {
    var dto: SalaryRecordDTO {
        SalaryRecordDTO(id: id, employerName: employerName, jobTitle: jobTitle,
                        currency: currency, expectedAmount: expectedAmount,
                        expectedPaymentDay: expectedPaymentDay,
                        paymentFrequencyRaw: paymentFrequencyRaw,
                        isActive: isActive, colorName: colorName, notes: notes,
                        paymentsData: paymentsData,
                        createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension SalaryRecordDTO {
    func toModel() -> SalaryRecord {
        let r = SalaryRecord(id: id, employerName: employerName, jobTitle: jobTitle,
                             currency: currency, expectedAmount: expectedAmount,
                             expectedPaymentDay: expectedPaymentDay,
                             paymentFrequencyRaw: paymentFrequencyRaw,
                             isActive: isActive, colorName: colorName, notes: notes)
        r.paymentsData = paymentsData
        r.createdAt = createdAt; r.updatedAt = updatedAt
        return r
    }
}

extension FreelanceProject {
    var dto: FreelanceProjectDTO {
        FreelanceProjectDTO(id: id, projectName: projectName, clientName: clientName,
                            projectDescription: projectDescription, currency: currency,
                            totalValue: totalValue, statusRaw: statusRaw,
                            startDate: startDate, endDate: endDate,
                            invoicesData: invoicesData, notes: notes,
                            colorName: colorName, isArchived: isArchived,
                            createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension FreelanceProjectDTO {
    func toModel() -> FreelanceProject {
        let p = FreelanceProject(id: id, projectName: projectName, clientName: clientName,
                                 projectDescription: projectDescription, currency: currency,
                                 totalValue: totalValue, statusRaw: statusRaw,
                                 startDate: startDate, endDate: endDate,
                                 notes: notes, colorName: colorName)
        p.invoicesData = invoicesData
        p.isArchived = isArchived
        p.createdAt = createdAt; p.updatedAt = updatedAt
        return p
    }
}

extension RentalProperty {
    var dto: RentalPropertyDTO {
        RentalPropertyDTO(id: id, propertyName: propertyName, propertyTypeRaw: propertyTypeRaw,
                          address: address, currency: currency,
                          monthlyRentExpected: monthlyRentExpected, isOccupied: isOccupied,
                          occupancyPeriodsData: occupancyPeriodsData,
                          paymentHistoryData: paymentHistoryData,
                          notes: notes, colorName: colorName, isActive: isActive,
                          createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension RentalPropertyDTO {
    func toModel() -> RentalProperty {
        let p = RentalProperty(id: id, propertyName: propertyName, propertyTypeRaw: propertyTypeRaw,
                               address: address, currency: currency,
                               monthlyRentExpected: monthlyRentExpected, notes: notes,
                               colorName: colorName)
        p.isOccupied = isOccupied
        p.occupancyPeriodsData = occupancyPeriodsData
        p.paymentHistoryData = paymentHistoryData
        p.isActive = isActive
        p.createdAt = createdAt; p.updatedAt = updatedAt
        return p
    }
}

extension MoneyLent {
    var dto: MoneyLentDTO {
        MoneyLentDTO(id: id, borrowerName: borrowerName, contactInfo: contactInfo,
                     amount: amount, currency: currency, lendingDate: lendingDate,
                     dueDate: dueDate, notes: notes, statusRaw: status.rawValue,
                     reminderEnabled: reminderEnabled, reminderDaysBefore: reminderDaysBefore,
                     color: color, repaymentsData: repaymentsData,
                     createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension MoneyLentDTO {
    func toModel() -> MoneyLent {
        let m = MoneyLent(id: id, borrowerName: borrowerName, contactInfo: contactInfo,
                          amount: amount, currency: currency, lendingDate: lendingDate,
                          dueDate: dueDate, notes: notes,
                          status: PersonalDebtStatus(rawValue: statusRaw) ?? .active,
                          reminderEnabled: reminderEnabled,
                          reminderDaysBefore: reminderDaysBefore, color: color)
        m.repaymentsData = repaymentsData
        m.createdAt = createdAt; m.updatedAt = updatedAt
        return m
    }
}

extension MoneyBorrowed {
    var dto: MoneyBorrowedDTO {
        MoneyBorrowedDTO(id: id, lenderName: lenderName, contactInfo: contactInfo,
                         amount: amount, currency: currency, borrowDate: borrowDate,
                         dueDate: dueDate, notes: notes, statusRaw: status.rawValue,
                         reminderEnabled: reminderEnabled, reminderDaysBefore: reminderDaysBefore,
                         color: color, repaymentsData: repaymentsData,
                         createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension MoneyBorrowedDTO {
    func toModel() -> MoneyBorrowed {
        let m = MoneyBorrowed(id: id, lenderName: lenderName, contactInfo: contactInfo,
                              amount: amount, currency: currency, borrowDate: borrowDate,
                              dueDate: dueDate, notes: notes,
                              status: PersonalDebtStatus(rawValue: statusRaw) ?? .active,
                              reminderEnabled: reminderEnabled,
                              reminderDaysBefore: reminderDaysBefore, color: color)
        m.repaymentsData = repaymentsData
        m.createdAt = createdAt; m.updatedAt = updatedAt
        return m
    }
}

// MARK: - Asset DTO Extensions

extension RealEstateProperty {
    var dto: RealEstatePropertyDTO {
        RealEstatePropertyDTO(id: id, name: name, propertyTypeRaw: propertyTypeRaw,
                              address: address, purchasePrice: purchasePrice,
                              purchaseDate: purchaseDate, currentValue: currentValue,
                              mortgageBalance: mortgageBalance,
                              ownershipPercentage: ownershipPercentage, currency: currency,
                              area: area, areaUnit: areaUnit, notes: notes,
                              isArchived: isArchived, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension RealEstatePropertyDTO {
    func toModel() -> RealEstateProperty {
        let p = RealEstateProperty(id: id, name: name,
                                   propertyType: RealEstateType(rawValue: propertyTypeRaw) ?? .apartment,
                                   address: address, purchasePrice: purchasePrice,
                                   purchaseDate: purchaseDate, currentValue: currentValue,
                                   mortgageBalance: mortgageBalance,
                                   ownershipPercentage: ownershipPercentage, currency: currency,
                                   area: area, areaUnit: areaUnit, notes: notes,
                                   isArchived: isArchived)
        p.createdAt = createdAt; p.updatedAt = updatedAt
        return p
    }
}

extension Vehicle {
    var dto: VehicleDTO {
        VehicleDTO(id: id, make: make, model: model, year: year,
                   purchasePrice: purchasePrice, purchaseDate: purchaseDate, currency: currency,
                   registrationNumber: registrationNumber, registrationExpiry: registrationExpiry,
                   insuranceProvider: insuranceProvider, insuranceExpiry: insuranceExpiry,
                   depreciationRate: depreciationRate, depreciationMethodRaw: depreciationMethodRaw,
                   manualCurrentValue: manualCurrentValue, color: color, notes: notes,
                   isArchived: isArchived, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension VehicleDTO {
    func toModel() -> Vehicle {
        let v = Vehicle(id: id, make: make, model: model, year: year,
                        purchasePrice: purchasePrice, purchaseDate: purchaseDate, currency: currency,
                        registrationNumber: registrationNumber, registrationExpiry: registrationExpiry,
                        insuranceProvider: insuranceProvider, insuranceExpiry: insuranceExpiry,
                        depreciationRate: depreciationRate,
                        depreciationMethod: VehicleDepreciationMethod(rawValue: depreciationMethodRaw) ?? .decliningBalance,
                        manualCurrentValue: manualCurrentValue, color: color, notes: notes,
                        isArchived: isArchived)
        v.createdAt = createdAt; v.updatedAt = updatedAt
        return v
    }
}

extension PersonalAsset {
    var dto: PersonalAssetDTO {
        PersonalAssetDTO(id: id, name: name, categoryRaw: categoryRaw,
                         purchasePrice: purchasePrice, purchaseDate: purchaseDate,
                         insuranceValue: insuranceValue, estimatedMarketValue: estimatedMarketValue,
                         currency: currency, serialNumber: serialNumber, brand: brand, notes: notes,
                         isArchived: isArchived, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension PersonalAssetDTO {
    func toModel() -> PersonalAsset {
        let a = PersonalAsset(id: id, name: name,
                              category: PersonalAssetCategory(rawValue: categoryRaw) ?? .other,
                              purchasePrice: purchasePrice, purchaseDate: purchaseDate,
                              insuranceValue: insuranceValue, estimatedMarketValue: estimatedMarketValue,
                              currency: currency, serialNumber: serialNumber, brand: brand, notes: notes,
                              isArchived: isArchived)
        a.createdAt = createdAt; a.updatedAt = updatedAt
        return a
    }
}

extension DigitalAsset {
    var dto: DigitalAssetDTO {
        DigitalAssetDTO(id: id, name: name, typeRaw: typeRaw,
                        acquisitionValue: acquisitionValue, acquisitionDate: acquisitionDate,
                        currentValue: currentValue, currency: currency, platform: platform,
                        identifier: identifier, expiryDate: expiryDate, notes: notes,
                        isArchived: isArchived, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension DigitalAssetDTO {
    func toModel() -> DigitalAsset {
        let d = DigitalAsset(id: id, name: name,
                             type: DigitalAssetType(rawValue: typeRaw) ?? .other,
                             acquisitionValue: acquisitionValue, acquisitionDate: acquisitionDate,
                             currentValue: currentValue, currency: currency, platform: platform,
                             identifier: identifier, expiryDate: expiryDate, notes: notes,
                             isArchived: isArchived)
        d.createdAt = createdAt; d.updatedAt = updatedAt
        return d
    }
}

extension NetWorthSnapshot {
    var dto: NetWorthSnapshotDTO {
        NetWorthSnapshotDTO(id: id, date: date, totalAssets: totalAssets,
                            totalLiabilities: totalLiabilities, netWorth: netWorth,
                            currency: currency, breakdownData: breakdownData)
    }
}

extension NetWorthSnapshotDTO {
    func toModel() -> NetWorthSnapshot {
        let s = NetWorthSnapshot(date: date, totalAssets: totalAssets,
                                 totalLiabilities: totalLiabilities, currency: currency)
        s.id = id
        s.breakdownData = breakdownData
        return s
    }
}
