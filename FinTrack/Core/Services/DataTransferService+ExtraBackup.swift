import Foundation
import SwiftData

// MARK: - Full-coverage backup for the "secondary" models
//
// The core FinTrackBackup (in DataTransferService) covers accounts,
// transactions, budgets, goals, debts, investments, income, assets and
// net-worth. This file extends the backup to every remaining @Model so a
// backup captures the WHOLE app (Tax, Business, Family, Premium, gift cards,
// loyalty, config, email-import setup, etc.). Every backup method (file
// export/import, iCloud, Google Drive, Email) shares this one engine.
//
// Pattern: each DTO mirrors only the model's STORED properties (enums as their
// `…Raw` string, embedded arrays as their `…Data` blob). `insert(into:)`
// rebuilds the model from a default instance + assignment, so it never depends
// on an initializer's argument list.

/// A model that exposes a stable `id` for merge-dedup during restore.
protocol BackupIdentifiable {
    var id: UUID { get }
}

/// A Codable snapshot of one extra model that can re-insert itself.
protocol BackupDTO: Codable {
    var id: UUID { get }
    func insert(into context: ModelContext)
}

extension DataTransferService {
    /// Restore a batch of extra-model DTOs, skipping ids that already exist in
    /// merge mode. Returns how many were inserted.
    func restoreExtras<M: PersistentModel & BackupIdentifiable, D: BackupDTO>(
        _ dtos: [D]?, existing _: M.Type, mode: ImportMode, context: ModelContext
    ) -> Int {
        let dtos = dtos ?? []
        guard !dtos.isEmpty else { return 0 }
        let existingIDs: Set<UUID> = mode == .merge
            ? Set((try? context.fetch(FetchDescriptor<M>()))?.map(\.id) ?? [])
            : []
        var n = 0
        for dto in dtos where !existingIDs.contains(dto.id) {
            dto.insert(into: context)
            n += 1
        }
        return n
    }
}

// MARK: - Tax

extension TaxRecord: BackupIdentifiable {}
extension TaxDocument: BackupIdentifiable {}
extension ZakatRecord: BackupIdentifiable {}
extension TaxConfiguration: BackupIdentifiable {}

struct TaxRecordDTO: BackupDTO {
    var id: UUID
    var title: String
    var vendorOrCustomer: String
    var amount: Double
    var vatAmount: Double
    var vatRate: Double
    var vatTypeRaw: String
    var date: Date
    var invoiceNumber: String?
    var currency: String
    var taxYear: Int
    var linkedTransactionId: UUID?
    var notes: String?
    var createdAt: Date

    func insert(into context: ModelContext) {
        let m = TaxRecord()
        m.id = id; m.title = title; m.vendorOrCustomer = vendorOrCustomer
        m.amount = amount; m.vatAmount = vatAmount; m.vatRate = vatRate
        m.vatTypeRaw = vatTypeRaw; m.date = date; m.invoiceNumber = invoiceNumber
        m.currency = currency; m.taxYear = taxYear
        m.linkedTransactionId = linkedTransactionId; m.notes = notes; m.createdAt = createdAt
        context.insert(m)
    }
}
extension TaxRecord {
    var backupDTO: TaxRecordDTO {
        TaxRecordDTO(id: id, title: title, vendorOrCustomer: vendorOrCustomer, amount: amount,
                     vatAmount: vatAmount, vatRate: vatRate, vatTypeRaw: vatTypeRaw, date: date,
                     invoiceNumber: invoiceNumber, currency: currency, taxYear: taxYear,
                     linkedTransactionId: linkedTransactionId, notes: notes, createdAt: createdAt)
    }
}

struct TaxDocumentDTO: BackupDTO {
    var id: UUID
    var name: String
    var documentTypeRaw: String
    var taxYear: Int
    var taxCategory: String
    var fileData: Data
    var mimeType: String
    var linkedTransactionId: UUID?
    var linkedVATRecordId: UUID?
    var notes: String?
    var tags: [String]
    var isArchived: Bool
    var createdAt: Date

    func insert(into context: ModelContext) {
        let m = TaxDocument()
        m.id = id; m.name = name; m.documentTypeRaw = documentTypeRaw; m.taxYear = taxYear
        m.taxCategory = taxCategory; m.fileData = fileData; m.mimeType = mimeType
        m.linkedTransactionId = linkedTransactionId; m.linkedVATRecordId = linkedVATRecordId
        m.notes = notes; m.tags = tags; m.isArchived = isArchived; m.createdAt = createdAt
        context.insert(m)
    }
}
extension TaxDocument {
    var backupDTO: TaxDocumentDTO {
        TaxDocumentDTO(id: id, name: name, documentTypeRaw: documentTypeRaw, taxYear: taxYear,
                       taxCategory: taxCategory, fileData: fileData, mimeType: mimeType,
                       linkedTransactionId: linkedTransactionId, linkedVATRecordId: linkedVATRecordId,
                       notes: notes, tags: tags, isArchived: isArchived, createdAt: createdAt)
    }
}

struct ZakatRecordDTO: BackupDTO {
    var id: UUID
    var taxYear: Int
    var cashAndSavings: Double
    var goldValueAED: Double
    var silverValueAED: Double
    var investmentsValue: Double
    var businessInventory: Double
    var receivablesValue: Double
    var immediateDebts: Double
    var basicExpenses: Double
    var nisabBasisRaw: String
    var goldNisabGrams: Double
    var silverNisabGrams: Double
    var goldPricePerGramAED: Double
    var silverPricePerGramAED: Double
    var useManualOverride: Bool
    var manualZakatAmount: Double
    var isPaid: Bool
    var paidDate: Date?
    var paidAmount: Double
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    func insert(into context: ModelContext) {
        let m = ZakatRecord()
        m.id = id; m.taxYear = taxYear; m.cashAndSavings = cashAndSavings
        m.goldValueAED = goldValueAED; m.silverValueAED = silverValueAED
        m.investmentsValue = investmentsValue; m.businessInventory = businessInventory
        m.receivablesValue = receivablesValue; m.immediateDebts = immediateDebts
        m.basicExpenses = basicExpenses; m.nisabBasisRaw = nisabBasisRaw
        m.goldNisabGrams = goldNisabGrams; m.silverNisabGrams = silverNisabGrams
        m.goldPricePerGramAED = goldPricePerGramAED; m.silverPricePerGramAED = silverPricePerGramAED
        m.useManualOverride = useManualOverride; m.manualZakatAmount = manualZakatAmount
        m.isPaid = isPaid; m.paidDate = paidDate; m.paidAmount = paidAmount
        m.notes = notes; m.createdAt = createdAt; m.updatedAt = updatedAt
        context.insert(m)
    }
}
extension ZakatRecord {
    var backupDTO: ZakatRecordDTO {
        ZakatRecordDTO(id: id, taxYear: taxYear, cashAndSavings: cashAndSavings,
                       goldValueAED: goldValueAED, silverValueAED: silverValueAED,
                       investmentsValue: investmentsValue, businessInventory: businessInventory,
                       receivablesValue: receivablesValue, immediateDebts: immediateDebts,
                       basicExpenses: basicExpenses, nisabBasisRaw: nisabBasisRaw,
                       goldNisabGrams: goldNisabGrams, silverNisabGrams: silverNisabGrams,
                       goldPricePerGramAED: goldPricePerGramAED, silverPricePerGramAED: silverPricePerGramAED,
                       useManualOverride: useManualOverride, manualZakatAmount: manualZakatAmount,
                       isPaid: isPaid, paidDate: paidDate, paidAmount: paidAmount,
                       notes: notes, createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct TaxConfigurationDTO: BackupDTO {
    var id: UUID
    var countryCode: String
    var countryName: String
    var isSubjectToIncomeTax: Bool
    var vatRate: Double
    var personalAllowance: Double
    var fiscalYearStartMonth: Int
    var currency: String
    var bracketsData: Data
    var updatedAt: Date

    func insert(into context: ModelContext) {
        let m = TaxConfiguration()
        m.id = id; m.countryCode = countryCode; m.countryName = countryName
        m.isSubjectToIncomeTax = isSubjectToIncomeTax; m.vatRate = vatRate
        m.personalAllowance = personalAllowance; m.fiscalYearStartMonth = fiscalYearStartMonth
        m.currency = currency; m.bracketsData = bracketsData; m.updatedAt = updatedAt
        context.insert(m)
    }
}
extension TaxConfiguration {
    var backupDTO: TaxConfigurationDTO {
        TaxConfigurationDTO(id: id, countryCode: countryCode, countryName: countryName,
                            isSubjectToIncomeTax: isSubjectToIncomeTax, vatRate: vatRate,
                            personalAllowance: personalAllowance, fiscalYearStartMonth: fiscalYearStartMonth,
                            currency: currency, bracketsData: bracketsData, updatedAt: updatedAt)
    }
}

// MARK: - Business

extension ClientProfile: BackupIdentifiable {}
extension BusinessInvoice: BackupIdentifiable {}
extension MileageTrip: BackupIdentifiable {}
extension BusinessProject: BackupIdentifiable {}

struct ClientProfileDTO: BackupDTO {
    var id: UUID
    var name: String
    var company: String?
    var email: String?
    var phone: String?
    var address: String?
    var currency: String
    var statusRaw: String
    var vatNumber: String?
    var notes: String?
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    func insert(into context: ModelContext) {
        let m = ClientProfile()
        m.id = id; m.name = name; m.company = company; m.email = email; m.phone = phone
        m.address = address; m.currency = currency; m.statusRaw = statusRaw
        m.vatNumber = vatNumber; m.notes = notes; m.colorHex = colorHex
        m.createdAt = createdAt; m.updatedAt = updatedAt
        context.insert(m)
    }
}
extension ClientProfile {
    var backupDTO: ClientProfileDTO {
        ClientProfileDTO(id: id, name: name, company: company, email: email, phone: phone,
                         address: address, currency: currency, statusRaw: statusRaw,
                         vatNumber: vatNumber, notes: notes, colorHex: colorHex,
                         createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct BusinessInvoiceDTO: BackupDTO {
    var id: UUID
    var invoiceNumber: String
    var clientId: String
    var clientName: String
    var clientEmail: String?
    var currency: String
    var statusRaw: String
    var issueDate: Date
    var dueDate: Date
    var notes: String?
    var vatIncluded: Bool
    var projectName: String?
    var lineItemsData: Data
    var paymentsData: Data
    var createdAt: Date
    var updatedAt: Date

    func insert(into context: ModelContext) {
        let m = BusinessInvoice()
        m.id = id; m.invoiceNumber = invoiceNumber; m.clientId = clientId; m.clientName = clientName
        m.clientEmail = clientEmail; m.currency = currency; m.statusRaw = statusRaw
        m.issueDate = issueDate; m.dueDate = dueDate; m.notes = notes; m.vatIncluded = vatIncluded
        m.projectName = projectName; m.lineItemsData = lineItemsData; m.paymentsData = paymentsData
        m.createdAt = createdAt; m.updatedAt = updatedAt
        context.insert(m)
    }
}
extension BusinessInvoice {
    var backupDTO: BusinessInvoiceDTO {
        BusinessInvoiceDTO(id: id, invoiceNumber: invoiceNumber, clientId: clientId, clientName: clientName,
                           clientEmail: clientEmail, currency: currency, statusRaw: statusRaw,
                           issueDate: issueDate, dueDate: dueDate, notes: notes, vatIncluded: vatIncluded,
                           projectName: projectName, lineItemsData: lineItemsData, paymentsData: paymentsData,
                           createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct MileageTripDTO: BackupDTO {
    var id: UUID
    var date: Date
    var fromLocation: String
    var toLocation: String
    var distanceKm: Double
    var ratePerKm: Double
    var vehicleTypeRaw: String
    var purposeRaw: String
    var clientName: String?
    var projectName: String?
    var notes: String?
    var isReimbursable: Bool
    var isReimbursed: Bool
    var currency: String
    var createdAt: Date

    func insert(into context: ModelContext) {
        let m = MileageTrip()
        m.id = id; m.date = date; m.fromLocation = fromLocation; m.toLocation = toLocation
        m.distanceKm = distanceKm; m.ratePerKm = ratePerKm; m.vehicleTypeRaw = vehicleTypeRaw
        m.purposeRaw = purposeRaw; m.clientName = clientName; m.projectName = projectName
        m.notes = notes; m.isReimbursable = isReimbursable; m.isReimbursed = isReimbursed
        m.currency = currency; m.createdAt = createdAt
        context.insert(m)
    }
}
extension MileageTrip {
    var backupDTO: MileageTripDTO {
        MileageTripDTO(id: id, date: date, fromLocation: fromLocation, toLocation: toLocation,
                       distanceKm: distanceKm, ratePerKm: ratePerKm, vehicleTypeRaw: vehicleTypeRaw,
                       purposeRaw: purposeRaw, clientName: clientName, projectName: projectName,
                       notes: notes, isReimbursable: isReimbursable, isReimbursed: isReimbursed,
                       currency: currency, createdAt: createdAt)
    }
}

struct BusinessProjectDTO: BackupDTO {
    var id: UUID
    var name: String
    var clientId: String?
    var clientName: String?
    var projectDescription: String?
    var currency: String
    var budget: Double
    var statusRaw: String
    var startDate: Date
    var endDate: Date?
    var colorHex: String
    var notes: String?
    var tagKey: String
    var createdAt: Date
    var updatedAt: Date

    func insert(into context: ModelContext) {
        let m = BusinessProject()
        m.id = id; m.name = name; m.clientId = clientId; m.clientName = clientName
        m.projectDescription = projectDescription; m.currency = currency; m.budget = budget
        m.statusRaw = statusRaw; m.startDate = startDate; m.endDate = endDate
        m.colorHex = colorHex; m.notes = notes; m.tagKey = tagKey
        m.createdAt = createdAt; m.updatedAt = updatedAt
        context.insert(m)
    }
}
extension BusinessProject {
    var backupDTO: BusinessProjectDTO {
        BusinessProjectDTO(id: id, name: name, clientId: clientId, clientName: clientName,
                           projectDescription: projectDescription, currency: currency, budget: budget,
                           statusRaw: statusRaw, startDate: startDate, endDate: endDate,
                           colorHex: colorHex, notes: notes, tagKey: tagKey,
                           createdAt: createdAt, updatedAt: updatedAt)
    }
}

// MARK: - Family

extension FamilyGroup: BackupIdentifiable {}
extension ChildProfile: BackupIdentifiable {}
extension SharedFamilyGoal: BackupIdentifiable {}

struct FamilyGroupDTO: BackupDTO {
    var id: UUID
    var name: String
    var adminName: String
    var currency: String
    var isActive: Bool
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var membersData: Data

    func insert(into context: ModelContext) {
        let m = FamilyGroup()
        m.id = id; m.name = name; m.adminName = adminName; m.currency = currency
        m.isActive = isActive; m.notes = notes; m.createdAt = createdAt
        m.updatedAt = updatedAt; m.membersData = membersData
        context.insert(m)
    }
}
extension FamilyGroup {
    var backupDTO: FamilyGroupDTO {
        FamilyGroupDTO(id: id, name: name, adminName: adminName, currency: currency,
                       isActive: isActive, notes: notes, createdAt: createdAt,
                       updatedAt: updatedAt, membersData: membersData)
    }
}

struct ChildProfileDTO: BackupDTO {
    var id: UUID
    var name: String
    var dateOfBirth: Date?
    var monthlyAllowance: Double
    var currency: String
    var allowanceFrequencyRaw: String
    var savingsGoalName: String
    var savingsGoalAmount: Double
    var currentSavings: Double
    var colorHex: String
    var icon: String
    var paymentsData: Data
    var isActive: Bool
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    func insert(into context: ModelContext) {
        let m = ChildProfile()
        m.id = id; m.name = name; m.dateOfBirth = dateOfBirth; m.monthlyAllowance = monthlyAllowance
        m.currency = currency; m.allowanceFrequencyRaw = allowanceFrequencyRaw
        m.savingsGoalName = savingsGoalName; m.savingsGoalAmount = savingsGoalAmount
        m.currentSavings = currentSavings; m.colorHex = colorHex; m.icon = icon
        m.paymentsData = paymentsData; m.isActive = isActive; m.notes = notes
        m.createdAt = createdAt; m.updatedAt = updatedAt
        context.insert(m)
    }
}
extension ChildProfile {
    var backupDTO: ChildProfileDTO {
        ChildProfileDTO(id: id, name: name, dateOfBirth: dateOfBirth, monthlyAllowance: monthlyAllowance,
                        currency: currency, allowanceFrequencyRaw: allowanceFrequencyRaw,
                        savingsGoalName: savingsGoalName, savingsGoalAmount: savingsGoalAmount,
                        currentSavings: currentSavings, colorHex: colorHex, icon: icon,
                        paymentsData: paymentsData, isActive: isActive, notes: notes,
                        createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct SharedFamilyGoalDTO: BackupDTO {
    var id: UUID
    var name: String
    var goalDescription: String
    var targetAmount: Double
    var currency: String
    var targetDate: Date?
    var icon: String
    var colorHex: String
    var isCompleted: Bool
    var isArchived: Bool
    var contributionsData: Data
    var createdAt: Date
    var updatedAt: Date

    func insert(into context: ModelContext) {
        let m = SharedFamilyGoal()
        m.id = id; m.name = name; m.goalDescription = goalDescription; m.targetAmount = targetAmount
        m.currency = currency; m.targetDate = targetDate; m.icon = icon; m.colorHex = colorHex
        m.isCompleted = isCompleted; m.isArchived = isArchived; m.contributionsData = contributionsData
        m.createdAt = createdAt; m.updatedAt = updatedAt
        context.insert(m)
    }
}
extension SharedFamilyGoal {
    var backupDTO: SharedFamilyGoalDTO {
        SharedFamilyGoalDTO(id: id, name: name, goalDescription: goalDescription, targetAmount: targetAmount,
                            currency: currency, targetDate: targetDate, icon: icon, colorHex: colorHex,
                            isCompleted: isCompleted, isArchived: isArchived, contributionsData: contributionsData,
                            createdAt: createdAt, updatedAt: updatedAt)
    }
}

// MARK: - Premium

extension RetirementPlan: BackupIdentifiable {}
extension LifeEventPlan: BackupIdentifiable {}
extension AdvisorAccess: BackupIdentifiable {}

struct RetirementPlanDTO: BackupDTO {
    var id: UUID
    var currentAge: Int
    var targetRetirementAge: Int
    var currentSavings: Double
    var monthlyContribution: Double
    var expectedReturnRate: Double
    var expectedInflationRate: Double
    var targetMonthlyIncome: Double
    var currency: String
    var yearsOfServiceUAE: Int
    var monthlyBasicSalary: Double
    var lastUpdated: Date

    func insert(into context: ModelContext) {
        let m = RetirementPlan()
        m.id = id; m.currentAge = currentAge; m.targetRetirementAge = targetRetirementAge
        m.currentSavings = currentSavings; m.monthlyContribution = monthlyContribution
        m.expectedReturnRate = expectedReturnRate; m.expectedInflationRate = expectedInflationRate
        m.targetMonthlyIncome = targetMonthlyIncome; m.currency = currency
        m.yearsOfServiceUAE = yearsOfServiceUAE; m.monthlyBasicSalary = monthlyBasicSalary
        m.lastUpdated = lastUpdated
        context.insert(m)
    }
}
extension RetirementPlan {
    var backupDTO: RetirementPlanDTO {
        RetirementPlanDTO(id: id, currentAge: currentAge, targetRetirementAge: targetRetirementAge,
                          currentSavings: currentSavings, monthlyContribution: monthlyContribution,
                          expectedReturnRate: expectedReturnRate, expectedInflationRate: expectedInflationRate,
                          targetMonthlyIncome: targetMonthlyIncome, currency: currency,
                          yearsOfServiceUAE: yearsOfServiceUAE, monthlyBasicSalary: monthlyBasicSalary,
                          lastUpdated: lastUpdated)
    }
}

struct LifeEventPlanDTO: BackupDTO {
    var id: UUID
    var eventTypeRaw: String
    var title: String
    var targetDate: Date
    var estimatedCost: Double
    var currency: String
    var savedAmount: Double
    var notes: String?
    var isCompleted: Bool
    var checklistData: Data

    func insert(into context: ModelContext) {
        let m = LifeEventPlan()
        m.id = id; m.eventTypeRaw = eventTypeRaw; m.title = title; m.targetDate = targetDate
        m.estimatedCost = estimatedCost; m.currency = currency; m.savedAmount = savedAmount
        m.notes = notes; m.isCompleted = isCompleted; m.checklistData = checklistData
        context.insert(m)
    }
}
extension LifeEventPlan {
    var backupDTO: LifeEventPlanDTO {
        LifeEventPlanDTO(id: id, eventTypeRaw: eventTypeRaw, title: title, targetDate: targetDate,
                         estimatedCost: estimatedCost, currency: currency, savedAmount: savedAmount,
                         notes: notes, isCompleted: isCompleted, checklistData: checklistData)
    }
}

struct AdvisorAccessDTO: BackupDTO {
    var id: UUID
    var advisorName: String
    var advisorEmail: String
    var roleRaw: String
    var invitedDate: Date
    var lastAccessDate: Date?
    var isActive: Bool
    var accessCode: String
    var canViewTransactions: Bool
    var canViewAccounts: Bool
    var canViewGoals: Bool
    var canViewDebts: Bool
    var canAddNotes: Bool
    var notesData: Data

    func insert(into context: ModelContext) {
        let m = AdvisorAccess()
        m.id = id; m.advisorName = advisorName; m.advisorEmail = advisorEmail; m.roleRaw = roleRaw
        m.invitedDate = invitedDate; m.lastAccessDate = lastAccessDate; m.isActive = isActive
        m.accessCode = accessCode; m.canViewTransactions = canViewTransactions
        m.canViewAccounts = canViewAccounts; m.canViewGoals = canViewGoals
        m.canViewDebts = canViewDebts; m.canAddNotes = canAddNotes; m.notesData = notesData
        context.insert(m)
    }
}
extension AdvisorAccess {
    var backupDTO: AdvisorAccessDTO {
        AdvisorAccessDTO(id: id, advisorName: advisorName, advisorEmail: advisorEmail, roleRaw: roleRaw,
                         invitedDate: invitedDate, lastAccessDate: lastAccessDate, isActive: isActive,
                         accessCode: accessCode, canViewTransactions: canViewTransactions,
                         canViewAccounts: canViewAccounts, canViewGoals: canViewGoals,
                         canViewDebts: canViewDebts, canAddNotes: canAddNotes, notesData: notesData)
    }
}

// MARK: - Budget envelopes & templates

extension BudgetEnvelope: BackupIdentifiable {}
extension BudgetTemplate: BackupIdentifiable {}

struct BudgetEnvelopeDTO: BackupDTO {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var allocatedAmount: Double
    var category: TransactionCategory
    var currency: String
    var sortOrder: Int
    var notes: String?
    var createdAt: Date

    func insert(into context: ModelContext) {
        let m = BudgetEnvelope(name: "", allocatedAmount: 0, category: .other)
        m.id = id; m.name = name; m.icon = icon; m.colorHex = colorHex
        m.allocatedAmount = allocatedAmount; m.category = category; m.currency = currency
        m.sortOrder = sortOrder; m.notes = notes; m.createdAt = createdAt
        context.insert(m)
    }
}
extension BudgetEnvelope {
    var backupDTO: BudgetEnvelopeDTO {
        BudgetEnvelopeDTO(id: id, name: name, icon: icon, colorHex: colorHex,
                          allocatedAmount: allocatedAmount, category: category, currency: currency,
                          sortOrder: sortOrder, notes: notes, createdAt: createdAt)
    }
}

struct BudgetTemplateDTO: BackupDTO {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var templateDescription: String
    var seasonRaw: String
    var isBuiltIn: Bool
    var items: [TemplateItem]
    var createdAt: Date

    func insert(into context: ModelContext) {
        let m = BudgetTemplate(name: "", icon: "", description: "")
        m.id = id; m.name = name; m.icon = icon; m.colorHex = colorHex
        m.templateDescription = templateDescription; m.seasonRaw = seasonRaw
        m.isBuiltIn = isBuiltIn; m.items = items; m.createdAt = createdAt
        context.insert(m)
    }
}
extension BudgetTemplate {
    var backupDTO: BudgetTemplateDTO {
        BudgetTemplateDTO(id: id, name: name, icon: icon, colorHex: colorHex,
                          templateDescription: templateDescription, seasonRaw: seasonRaw,
                          isBuiltIn: isBuiltIn, items: items, createdAt: createdAt)
    }
}

// MARK: - Gift cards & loyalty

extension GiftCard: BackupIdentifiable {}
extension LoyaltyProgram: BackupIdentifiable {}

struct GiftCardDTO: BackupDTO {
    var id: UUID
    var merchant: String
    var balance: Double
    var initialBalance: Double
    var currency: String
    var cardNumber: String?
    var pinCode: String?
    var expiryDate: Date?
    var purchaseDate: Date
    var notes: String?
    var color: String
    var isUsedUp: Bool
    var createdAt: Date
    var updatedAt: Date

    func insert(into context: ModelContext) {
        let m = GiftCard(merchant: "", balance: 0)
        m.id = id; m.merchant = merchant; m.balance = balance; m.initialBalance = initialBalance
        m.currency = currency; m.cardNumber = cardNumber; m.pinCode = pinCode
        m.expiryDate = expiryDate; m.purchaseDate = purchaseDate; m.notes = notes
        m.color = color; m.isUsedUp = isUsedUp; m.createdAt = createdAt; m.updatedAt = updatedAt
        context.insert(m)
    }
}
extension GiftCard {
    var backupDTO: GiftCardDTO {
        GiftCardDTO(id: id, merchant: merchant, balance: balance, initialBalance: initialBalance,
                    currency: currency, cardNumber: cardNumber, pinCode: pinCode, expiryDate: expiryDate,
                    purchaseDate: purchaseDate, notes: notes, color: color, isUsedUp: isUsedUp,
                    createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct LoyaltyProgramDTO: BackupDTO {
    var id: UUID
    var name: String
    var programType: LoyaltyProgramType
    var customProgramName: String?
    var points: Double
    var pointsValuePerUnit: Double
    var currency: String
    var membershipNumber: String?
    var tier: String?
    var expiryDate: Date?
    var notes: String?
    var color: String
    var createdAt: Date
    var updatedAt: Date
    var totalPointsEarned: Double
    var totalPointsRedeemed: Double

    func insert(into context: ModelContext) {
        let m = LoyaltyProgram(name: "")
        m.id = id; m.name = name; m.programType = programType; m.customProgramName = customProgramName
        m.points = points; m.pointsValuePerUnit = pointsValuePerUnit; m.currency = currency
        m.membershipNumber = membershipNumber; m.tier = tier; m.expiryDate = expiryDate
        m.notes = notes; m.color = color; m.createdAt = createdAt; m.updatedAt = updatedAt
        m.totalPointsEarned = totalPointsEarned; m.totalPointsRedeemed = totalPointsRedeemed
        context.insert(m)
    }
}
extension LoyaltyProgram {
    var backupDTO: LoyaltyProgramDTO {
        LoyaltyProgramDTO(id: id, name: name, programType: programType, customProgramName: customProgramName,
                          points: points, pointsValuePerUnit: pointsValuePerUnit, currency: currency,
                          membershipNumber: membershipNumber, tier: tier, expiryDate: expiryDate,
                          notes: notes, color: color, createdAt: createdAt, updatedAt: updatedAt,
                          totalPointsEarned: totalPointsEarned, totalPointsRedeemed: totalPointsRedeemed)
    }
}

// MARK: - Net-worth milestones

extension NetWorthMilestone: BackupIdentifiable {}

struct NetWorthMilestoneDTO: BackupDTO {
    var id: UUID
    var amount: Double
    var currency: String
    var achievedAt: Date
    var isAcknowledged: Bool

    func insert(into context: ModelContext) {
        let m = NetWorthMilestone(amount: 0)
        m.id = id; m.amount = amount; m.currency = currency
        m.achievedAt = achievedAt; m.isAcknowledged = isAcknowledged
        context.insert(m)
    }
}
extension NetWorthMilestone {
    var backupDTO: NetWorthMilestoneDTO {
        NetWorthMilestoneDTO(id: id, amount: amount, currency: currency,
                             achievedAt: achievedAt, isAcknowledged: isAcknowledged)
    }
}

// MARK: - Email-import config (mailboxes & bank rules; NOT the transient review queue)

extension EmailAccount: BackupIdentifiable {}
extension BankEmailRule: BackupIdentifiable {}

struct EmailAccountDTO: BackupDTO {
    var id: UUID
    var emailAddress: String
    var providerRaw: String
    var connectedAt: Date
    var lastSyncAt: Date?
    var syncEnabled: Bool
    var totalEmailsScanned: Int
    var totalTransactionsParsed: Int
    var seenMessageIdsData: Data
    var imapHost: String

    func insert(into context: ModelContext) {
        let m = EmailAccount(emailAddress: "", provider: .imap)
        m.id = id; m.emailAddress = emailAddress; m.providerRaw = providerRaw
        m.connectedAt = connectedAt; m.lastSyncAt = lastSyncAt; m.syncEnabled = syncEnabled
        m.totalEmailsScanned = totalEmailsScanned; m.totalTransactionsParsed = totalTransactionsParsed
        m.seenMessageIdsData = seenMessageIdsData; m.imapHost = imapHost
        context.insert(m)
    }
}
extension EmailAccount {
    var backupDTO: EmailAccountDTO {
        EmailAccountDTO(id: id, emailAddress: emailAddress, providerRaw: providerRaw,
                        connectedAt: connectedAt, lastSyncAt: lastSyncAt, syncEnabled: syncEnabled,
                        totalEmailsScanned: totalEmailsScanned, totalTransactionsParsed: totalTransactionsParsed,
                        seenMessageIdsData: seenMessageIdsData, imapHost: imapHost)
    }
}

struct BankEmailRuleDTO: BackupDTO {
    var id: UUID
    var bankName: String
    var nickname: String
    var senderEmail: String
    var senderDomain: String
    var subjectPattern: String
    var keywords: [String]
    var currency: String
    var country: String
    var timezoneIdentifier: String
    var accountTypeRaw: String
    var linkedAccountId: UUID?
    var autoApprove: Bool
    var confidenceThreshold: Double
    var isEnabled: Bool
    var createdAt: Date
    var matchedCount: Int

    func insert(into context: ModelContext) {
        let m = BankEmailRule(bankName: "", senderEmail: "")
        m.id = id; m.bankName = bankName; m.nickname = nickname; m.senderEmail = senderEmail
        m.senderDomain = senderDomain; m.subjectPattern = subjectPattern; m.keywords = keywords
        m.currency = currency; m.country = country; m.timezoneIdentifier = timezoneIdentifier
        m.accountTypeRaw = accountTypeRaw; m.linkedAccountId = linkedAccountId
        m.autoApprove = autoApprove; m.confidenceThreshold = confidenceThreshold
        m.isEnabled = isEnabled; m.createdAt = createdAt; m.matchedCount = matchedCount
        context.insert(m)
    }
}
extension BankEmailRule {
    var backupDTO: BankEmailRuleDTO {
        BankEmailRuleDTO(id: id, bankName: bankName, nickname: nickname, senderEmail: senderEmail,
                         senderDomain: senderDomain, subjectPattern: subjectPattern, keywords: keywords,
                         currency: currency, country: country, timezoneIdentifier: timezoneIdentifier,
                         accountTypeRaw: accountTypeRaw, linkedAccountId: linkedAccountId,
                         autoApprove: autoApprove, confidenceThreshold: confidenceThreshold,
                         isEnabled: isEnabled, createdAt: createdAt, matchedCount: matchedCount)
    }
}

// MARK: - Categorization rules

extension CategorizationRule: BackupIdentifiable {}

struct CategorizationRuleDTO: BackupDTO {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var priority: Int
    var conditionTypeRaw: String
    var conditionValue: String
    var amountMin: Double?
    var amountMax: Double?
    var targetCategoryRaw: String
    var targetCustomCategoryID: UUID?
    var autoTags: [String]
    var createdAt: Date

    func insert(into context: ModelContext) {
        let m = CategorizationRule(name: "")
        m.id = id; m.name = name; m.isEnabled = isEnabled; m.priority = priority
        m.conditionTypeRaw = conditionTypeRaw; m.conditionValue = conditionValue
        m.amountMin = amountMin; m.amountMax = amountMax; m.targetCategoryRaw = targetCategoryRaw
        m.targetCustomCategoryID = targetCustomCategoryID; m.autoTags = autoTags; m.createdAt = createdAt
        context.insert(m)
    }
}
extension CategorizationRule {
    var backupDTO: CategorizationRuleDTO {
        CategorizationRuleDTO(id: id, name: name, isEnabled: isEnabled, priority: priority,
                              conditionTypeRaw: conditionTypeRaw, conditionValue: conditionValue,
                              amountMin: amountMin, amountMax: amountMax, targetCategoryRaw: targetCategoryRaw,
                              targetCustomCategoryID: targetCustomCategoryID, autoTags: autoTags,
                              createdAt: createdAt)
    }
}

// MARK: - Audit log

extension AuditLogEntry: BackupIdentifiable {}

struct AuditLogEntryDTO: BackupDTO {
    var id: UUID
    var timestamp: Date
    var eventTypeRaw: String
    var eventDescription: String
    var deviceName: String

    func insert(into context: ModelContext) {
        let m = AuditLogEntry(eventType: .settingsChanged, description: "")
        m.id = id; m.timestamp = timestamp; m.eventTypeRaw = eventTypeRaw
        m.eventDescription = eventDescription; m.deviceName = deviceName
        context.insert(m)
    }
}
extension AuditLogEntry {
    var backupDTO: AuditLogEntryDTO {
        AuditLogEntryDTO(id: id, timestamp: timestamp, eventTypeRaw: eventTypeRaw,
                         eventDescription: eventDescription, deviceName: deviceName)
    }
}

// MARK: - Import history

extension ImportedFile: BackupIdentifiable {}

struct ImportedFileDTO: BackupDTO {
    var id: UUID
    var fileName: String
    var fileTypeRaw: String
    var statusRaw: String
    var bankName: String?
    var accountName: String?
    var importedAt: Date
    var totalTransactions: Int
    var importedCount: Int
    var skippedCount: Int
    var errorMessage: String?
    var parsedItemsData: Data

    func insert(into context: ModelContext) {
        let m = ImportedFile(fileName: "", fileType: .pdf)
        m.id = id; m.fileName = fileName; m.fileTypeRaw = fileTypeRaw; m.statusRaw = statusRaw
        m.bankName = bankName; m.accountName = accountName; m.importedAt = importedAt
        m.totalTransactions = totalTransactions; m.importedCount = importedCount
        m.skippedCount = skippedCount; m.errorMessage = errorMessage; m.parsedItemsData = parsedItemsData
        context.insert(m)
    }
}
extension ImportedFile {
    var backupDTO: ImportedFileDTO {
        ImportedFileDTO(id: id, fileName: fileName, fileTypeRaw: fileTypeRaw, statusRaw: statusRaw,
                        bankName: bankName, accountName: accountName, importedAt: importedAt,
                        totalTransactions: totalTransactions, importedCount: importedCount,
                        skippedCount: skippedCount, errorMessage: errorMessage, parsedItemsData: parsedItemsData)
    }
}

// MARK: - Remittance

extension RemittanceRecord: BackupIdentifiable {}

struct RemittanceRecordDTO: BackupDTO {
    var id: UUID
    var date: Date
    var providerRaw: String
    var customProviderName: String?
    var senderCurrency: String
    var receiverCurrency: String
    var sentAmount: Double
    var receivedAmount: Double
    var exchangeRate: Double
    var fee: Double
    var recipientName: String
    var recipientCountry: String
    var referenceNumber: String?
    var notes: String?
    var isPending: Bool

    func insert(into context: ModelContext) {
        let m = RemittanceRecord()
        m.id = id; m.date = date; m.providerRaw = providerRaw; m.customProviderName = customProviderName
        m.senderCurrency = senderCurrency; m.receiverCurrency = receiverCurrency
        m.sentAmount = sentAmount; m.receivedAmount = receivedAmount; m.exchangeRate = exchangeRate
        m.fee = fee; m.recipientName = recipientName; m.recipientCountry = recipientCountry
        m.referenceNumber = referenceNumber; m.notes = notes; m.isPending = isPending
        context.insert(m)
    }
}
extension RemittanceRecord {
    var backupDTO: RemittanceRecordDTO {
        RemittanceRecordDTO(id: id, date: date, providerRaw: providerRaw, customProviderName: customProviderName,
                            senderCurrency: senderCurrency, receiverCurrency: receiverCurrency,
                            sentAmount: sentAmount, receivedAmount: receivedAmount, exchangeRate: exchangeRate,
                            fee: fee, recipientName: recipientName, recipientCountry: recipientCountry,
                            referenceNumber: referenceNumber, notes: notes, isPending: isPending)
    }
}

// MARK: - Insurance

extension InsurancePolicy: BackupIdentifiable {}

struct InsurancePolicyDTO: BackupDTO {
    var id: UUID
    var typeRaw: String
    var policyName: String
    var provider: String
    var policyNumber: String?
    var startDate: Date
    var endDate: Date
    var premium: Double
    var premiumCurrency: String
    var premiumFrequencyRaw: String
    var coverageAmount: Double
    var deductible: Double
    var beneficiary: String?
    var notes: String?
    var isActive: Bool

    func insert(into context: ModelContext) {
        let m = InsurancePolicy()
        m.id = id; m.typeRaw = typeRaw; m.policyName = policyName; m.provider = provider
        m.policyNumber = policyNumber; m.startDate = startDate; m.endDate = endDate
        m.premium = premium; m.premiumCurrency = premiumCurrency; m.premiumFrequencyRaw = premiumFrequencyRaw
        m.coverageAmount = coverageAmount; m.deductible = deductible; m.beneficiary = beneficiary
        m.notes = notes; m.isActive = isActive
        context.insert(m)
    }
}
extension InsurancePolicy {
    var backupDTO: InsurancePolicyDTO {
        InsurancePolicyDTO(id: id, typeRaw: typeRaw, policyName: policyName, provider: provider,
                           policyNumber: policyNumber, startDate: startDate, endDate: endDate,
                           premium: premium, premiumCurrency: premiumCurrency,
                           premiumFrequencyRaw: premiumFrequencyRaw, coverageAmount: coverageAmount,
                           deductible: deductible, beneficiary: beneficiary, notes: notes, isActive: isActive)
    }
}

// MARK: - Relationship-backed models (restored with explicit linking, not the generic helper)

/// Self-referential (parent → children). Restore inserts all, then links parents.
struct CustomCategoryDTO: Codable {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var isArchived: Bool
    var sortOrder: Int
    var transactionTypeFilter: String
    var createdAt: Date
    var parentId: UUID?
}
extension CustomCategory {
    var backupDTO: CustomCategoryDTO {
        CustomCategoryDTO(id: id, name: name, icon: icon, colorHex: colorHex, isArchived: isArchived,
                          sortOrder: sortOrder, transactionTypeFilter: transactionTypeFilter,
                          createdAt: createdAt, parentId: parent?.id)
    }
    /// Build a detached instance (no parent yet) with the stored fields.
    static func fromBackup(_ dto: CustomCategoryDTO) -> CustomCategory {
        let m = CustomCategory(name: "")
        m.id = dto.id; m.name = dto.name; m.icon = dto.icon; m.colorHex = dto.colorHex
        m.isArchived = dto.isArchived; m.sortOrder = dto.sortOrder
        m.transactionTypeFilter = dto.transactionTypeFilter; m.createdAt = dto.createdAt
        return m
    }
}

/// Attachment linked to a Transaction (linked back via the transaction map on restore).
struct DocumentAttachmentDTO: Codable {
    var id: UUID
    var data: Data
    var filename: String
    var mimeType: String
    var createdAt: Date
    var transactionId: UUID?
}
extension DocumentAttachment {
    var backupDTO: DocumentAttachmentDTO {
        DocumentAttachmentDTO(id: id, data: data, filename: filename, mimeType: mimeType,
                              createdAt: createdAt, transactionId: transaction?.id)
    }
    static func fromBackup(_ dto: DocumentAttachmentDTO) -> DocumentAttachment {
        let m = DocumentAttachment(data: dto.data, filename: dto.filename, mimeType: dto.mimeType)
        m.id = dto.id; m.createdAt = dto.createdAt
        return m
    }
}
