import Foundation
import SwiftData
import SwiftUI

// MARK: - Tax Enums

enum TaxDocumentType: String, Codable, CaseIterable {
    case receipt          = "Receipt"
    case invoice          = "Invoice"
    case contract         = "Contract"
    case vatReturn        = "VAT Return"
    case payslip          = "Payslip"
    case bankStatement    = "Bank Statement"
    case taxCertificate   = "Tax Certificate"
    case zakatCertificate = "Zakat Certificate"
    case other            = "Other"

    var icon: String {
        switch self {
        case .receipt:          return "doc.text.fill"
        case .invoice:          return "doc.badge.plus"
        case .contract:         return "doc.richtext.fill"
        case .vatReturn:        return "percent"
        case .payslip:          return "creditcard.fill"
        case .bankStatement:    return "building.columns.fill"
        case .taxCertificate:   return "rosette"
        case .zakatCertificate: return "star.circle.fill"
        case .other:            return "doc.fill"
        }
    }
}

enum VATRecordType: String, Codable, CaseIterable {
    case paid        = "VAT Paid"
    case collected   = "VAT Collected"
    case exempt      = "VAT Exempt"
    case reclaimable = "Reclaimable"

    var icon: String {
        switch self {
        case .paid:        return "arrow.down.circle.fill"
        case .collected:   return "arrow.up.circle.fill"
        case .exempt:      return "xmark.circle.fill"
        case .reclaimable: return "arrow.counterclockwise.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .paid:        return FTColor.expense
        case .collected:   return FTColor.income
        case .exempt:      return FTColor.textMuted
        case .reclaimable: return FTColor.catBlue
        }
    }

    var isDebit: Bool { self == .paid }
}

enum ZakatNisabBasis: String, Codable, CaseIterable {
    case gold   = "Gold (87.48g)"
    case silver = "Silver (612.36g)"
}

// MARK: - TaxRecord (VAT Entry)

@Model
final class TaxRecord {
    var id: UUID = UUID()
    var title: String = ""
    var vendorOrCustomer: String = ""
    var amount: Double = 0
    var vatAmount: Double = 0
    var vatRate: Double = 5.0
    var vatTypeRaw: String = VATRecordType.paid.rawValue
    var date: Date = Date()
    var invoiceNumber: String?
    var currency: String = "AED"
    var taxYear: Int = Calendar.current.component(.year, from: Date())
    var linkedTransactionId: UUID?
    var notes: String?
    var createdAt: Date = Date()

    init(
        title: String = "",
        vendorOrCustomer: String = "",
        amount: Double = 0,
        vatAmount: Double = 0,
        vatRate: Double = 5.0,
        vatType: VATRecordType = .paid,
        date: Date = Date(),
        invoiceNumber: String? = nil,
        currency: String = "AED",
        taxYear: Int = Calendar.current.component(.year, from: Date()),
        linkedTransactionId: UUID? = nil,
        notes: String? = nil
    ) {
        self.title = title
        self.vendorOrCustomer = vendorOrCustomer
        self.amount = amount
        self.vatAmount = vatAmount
        self.vatRate = vatRate
        self.vatTypeRaw = vatType.rawValue
        self.date = date
        self.invoiceNumber = invoiceNumber
        self.currency = currency
        self.taxYear = taxYear
        self.linkedTransactionId = linkedTransactionId
        self.notes = notes
    }

    var vatType: VATRecordType {
        get { VATRecordType(rawValue: vatTypeRaw) ?? .paid }
        set { vatTypeRaw = newValue.rawValue }
    }

    var totalAmount: Double { amount + vatAmount }
}

// MARK: - TaxDocument

@Model
final class TaxDocument {
    @Attribute(.externalStorage) var fileData: Data = Data()
    var id: UUID = UUID()
    var name: String = ""
    var documentTypeRaw: String = TaxDocumentType.receipt.rawValue
    var taxYear: Int = Calendar.current.component(.year, from: Date())
    var taxCategory: String = ""
    var mimeType: String = "application/pdf"
    var linkedTransactionId: UUID?
    var linkedVATRecordId: UUID?
    var notes: String?
    var tags: [String] = []
    var isArchived: Bool = false
    var createdAt: Date = Date()

    init(
        name: String = "",
        documentType: TaxDocumentType = .receipt,
        taxYear: Int = Calendar.current.component(.year, from: Date()),
        taxCategory: String = "",
        fileData: Data = Data(),
        mimeType: String = "application/pdf",
        linkedTransactionId: UUID? = nil,
        notes: String? = nil,
        tags: [String] = []
    ) {
        self.name = name
        self.documentTypeRaw = documentType.rawValue
        self.taxYear = taxYear
        self.taxCategory = taxCategory
        self.fileData = fileData
        self.mimeType = mimeType
        self.linkedTransactionId = linkedTransactionId
        self.notes = notes
        self.tags = tags
    }

    var documentType: TaxDocumentType {
        get { TaxDocumentType(rawValue: documentTypeRaw) ?? .other }
        set { documentTypeRaw = newValue.rawValue }
    }

    var fileSizeLabel: String {
        let b = fileData.count
        if b < 1024 { return "\(b) B" }
        if b < 1_048_576 { return String(format: "%.1f KB", Double(b) / 1_024) }
        return String(format: "%.1f MB", Double(b) / 1_048_576)
    }

    var isImage: Bool { mimeType.hasPrefix("image/") }
    var isPDF:   Bool { mimeType == "application/pdf" }
}

// MARK: - ZakatRecord

@Model
final class ZakatRecord {
    var id: UUID = UUID()
    var taxYear: Int = Calendar.current.component(.year, from: Date())
    // Assets (in base currency AED)
    var cashAndSavings: Double = 0
    var goldValueAED: Double = 0
    var silverValueAED: Double = 0
    var investmentsValue: Double = 0
    var businessInventory: Double = 0
    var receivablesValue: Double = 0
    // Deductions
    var immediateDebts: Double = 0
    var basicExpenses: Double = 0
    // Nisab
    var nisabBasisRaw: String = ZakatNisabBasis.gold.rawValue
    var goldNisabGrams: Double = 87.48
    var silverNisabGrams: Double = 612.36
    var goldPricePerGramAED: Double = 220
    var silverPricePerGramAED: Double = 2.8
    // Manual override
    var useManualOverride: Bool = false
    var manualZakatAmount: Double = 0
    // Payment
    var isPaid: Bool = false
    var paidDate: Date?
    var paidAmount: Double = 0
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(taxYear: Int = Calendar.current.component(.year, from: Date())) {
        self.taxYear = taxYear
    }

    var nisabBasis: ZakatNisabBasis {
        get { ZakatNisabBasis(rawValue: nisabBasisRaw) ?? .gold }
        set { nisabBasisRaw = newValue.rawValue }
    }

    var nisabThresholdAED: Double {
        switch nisabBasis {
        case .gold:   return goldNisabGrams * goldPricePerGramAED
        case .silver: return silverNisabGrams * silverPricePerGramAED
        }
    }

    var totalZakatableAssets: Double {
        cashAndSavings + goldValueAED + silverValueAED + investmentsValue + businessInventory + receivablesValue
    }

    var netZakatableWealth: Double {
        max(0, totalZakatableAssets - immediateDebts - basicExpenses)
    }

    var isAboveNisab: Bool { netZakatableWealth >= nisabThresholdAED }

    var zakatDue: Double {
        guard isAboveNisab else { return 0 }
        return useManualOverride ? manualZakatAmount : netZakatableWealth * 0.025
    }

    var remainingZakat: Double { max(0, zakatDue - paidAmount) }
    var progress: Double { zakatDue > 0 ? min(1, paidAmount / zakatDue) : 0 }
}

// MARK: - Tax Bracket (Codable struct, not @Model)

struct TaxBracket: Codable {
    var minIncome: Double
    var maxIncome: Double?
    var rate: Double
    var label: String
}

// MARK: - TaxConfiguration

@Model
final class TaxConfiguration {
    var id: UUID = UUID()
    var countryCode: String = "AE"
    var countryName: String = "UAE"
    var isSubjectToIncomeTax: Bool = false
    var vatRate: Double = 5.0
    var personalAllowance: Double = 0
    var fiscalYearStartMonth: Int = 1
    var currency: String = "AED"
    var bracketsData: Data = Data()
    var updatedAt: Date = Date()

    init(countryCode: String = "AE") {
        self.countryCode = countryCode
        applyDefaults(for: countryCode)
    }

    private func applyDefaults(for code: String) {
        switch code {
        case "AE":
            countryName = "UAE"
            isSubjectToIncomeTax = false
            vatRate = 5.0
            currency = "AED"
        case "SA":
            countryName = "Saudi Arabia"
            isSubjectToIncomeTax = false
            vatRate = 15.0
            currency = "SAR"
        case "GB":
            countryName = "United Kingdom"
            isSubjectToIncomeTax = true
            vatRate = 20.0
            personalAllowance = 12_570
            fiscalYearStartMonth = 4
            currency = "GBP"
            let b = [
                TaxBracket(minIncome: 0, maxIncome: 12_570, rate: 0, label: "Personal Allowance"),
                TaxBracket(minIncome: 12_571, maxIncome: 50_270, rate: 0.20, label: "Basic Rate"),
                TaxBracket(minIncome: 50_271, maxIncome: 125_140, rate: 0.40, label: "Higher Rate"),
                TaxBracket(minIncome: 125_141, maxIncome: nil, rate: 0.45, label: "Additional Rate"),
            ]
            bracketsData = (try? JSONEncoder().encode(b)) ?? Data()
        case "US":
            countryName = "United States"
            isSubjectToIncomeTax = true
            vatRate = 0
            personalAllowance = 13_850
            currency = "USD"
            let b = [
                TaxBracket(minIncome: 0, maxIncome: 11_000, rate: 0.10, label: "10%"),
                TaxBracket(minIncome: 11_001, maxIncome: 44_725, rate: 0.12, label: "12%"),
                TaxBracket(minIncome: 44_726, maxIncome: 95_375, rate: 0.22, label: "22%"),
                TaxBracket(minIncome: 95_376, maxIncome: 182_050, rate: 0.24, label: "24%"),
                TaxBracket(minIncome: 182_051, maxIncome: 231_250, rate: 0.32, label: "32%"),
                TaxBracket(minIncome: 231_251, maxIncome: 578_125, rate: 0.35, label: "35%"),
                TaxBracket(minIncome: 578_126, maxIncome: nil, rate: 0.37, label: "37%"),
            ]
            bracketsData = (try? JSONEncoder().encode(b)) ?? Data()
        case "AU":
            countryName = "Australia"
            isSubjectToIncomeTax = true
            vatRate = 10.0
            personalAllowance = 18_200
            fiscalYearStartMonth = 7
            currency = "AUD"
            let b = [
                TaxBracket(minIncome: 0, maxIncome: 18_200, rate: 0, label: "Tax Free"),
                TaxBracket(minIncome: 18_201, maxIncome: 45_000, rate: 0.19, label: "19%"),
                TaxBracket(minIncome: 45_001, maxIncome: 120_000, rate: 0.325, label: "32.5%"),
                TaxBracket(minIncome: 120_001, maxIncome: 180_000, rate: 0.37, label: "37%"),
                TaxBracket(minIncome: 180_001, maxIncome: nil, rate: 0.45, label: "45%"),
            ]
            bracketsData = (try? JSONEncoder().encode(b)) ?? Data()
        default:
            countryName = code
        }
    }

    var brackets: [TaxBracket] {
        (try? JSONDecoder().decode([TaxBracket].self, from: bracketsData)) ?? []
    }

    func estimatedIncomeTax(annualIncome: Double) -> Double {
        guard isSubjectToIncomeTax, annualIncome > 0 else { return 0 }
        let taxable = max(0, annualIncome - personalAllowance)
        var total = 0.0
        for b in brackets where b.rate > 0 {
            let hi = b.maxIncome ?? Double.infinity
            if taxable > b.minIncome {
                total += (min(taxable, hi) - b.minIncome) * b.rate
            }
        }
        return total
    }

    func effectiveTaxRate(annualIncome: Double) -> Double {
        guard annualIncome > 0 else { return 0 }
        return estimatedIncomeTax(annualIncome: annualIncome) / annualIncome
    }

    static let supported: [(code: String, name: String)] = [
        ("AE", "UAE"), ("SA", "Saudi Arabia"), ("GB", "United Kingdom"),
        ("US", "United States"), ("AU", "Australia"),
    ]
}
