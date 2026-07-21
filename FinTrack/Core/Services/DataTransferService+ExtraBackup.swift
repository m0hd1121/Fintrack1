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
