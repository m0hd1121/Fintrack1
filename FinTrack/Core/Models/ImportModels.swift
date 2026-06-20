import Foundation
import SwiftData

// MARK: - Enums

enum ImportFileType: String, Codable, CaseIterable {
    case pdf    = "PDF"
    case ofx    = "OFX"
    case qif    = "QIF"
    case qfx    = "QFX"
    case csv    = "CSV"

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .ofx: return "arrow.down.doc.fill"
        case .qif: return "arrow.down.doc.fill"
        case .qfx: return "arrow.down.doc.fill"
        case .csv: return "tablecells.fill"
        }
    }

    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .ofx: return "application/x-ofx"
        case .qif: return "application/x-qif"
        case .qfx: return "application/x-qfx"
        case .csv: return "text/csv"
        }
    }
}

enum ImportStatus: String, Codable {
    case pending  = "Pending"
    case parsing  = "Parsing"
    case review   = "Review"
    case imported = "Imported"
    case failed   = "Failed"

    var icon: String {
        switch self {
        case .pending:  return "clock"
        case .parsing:  return "gearshape.fill"
        case .review:   return "eye.fill"
        case .imported: return "checkmark.circle.fill"
        case .failed:   return "xmark.circle.fill"
        }
    }
}

// MARK: - ParsedTransactionItem (Codable, not @Model)

struct ParsedTransactionItem: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var description: String
    var amount: Double
    var currency: String = "AED"
    var transactionType: String = "expense"
    var suggestedCategory: String = "Other"
    var isSelected: Bool = true
    var isDuplicate: Bool = false
    var notes: String?
}

// MARK: - ImportedFile @Model

@Model
final class ImportedFile {
    var id: UUID = UUID()
    var fileName: String = ""
    var fileTypeRaw: String = ImportFileType.pdf.rawValue
    var statusRaw: String = ImportStatus.pending.rawValue
    var bankName: String?
    var accountName: String?
    var importedAt: Date = Date()
    var totalTransactions: Int = 0
    var importedCount: Int = 0
    var skippedCount: Int = 0
    var errorMessage: String?
    var parsedItemsData: Data = Data()

    init(
        fileName: String,
        fileType: ImportFileType,
        bankName: String? = nil,
        accountName: String? = nil
    ) {
        self.fileName = fileName
        self.fileTypeRaw = fileType.rawValue
        self.bankName = bankName
        self.accountName = accountName
    }

    var fileType: ImportFileType {
        ImportFileType(rawValue: fileTypeRaw) ?? .pdf
    }

    var status: ImportStatus {
        get { ImportStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var parsedItems: [ParsedTransactionItem] {
        get { (try? JSONDecoder().decode([ParsedTransactionItem].self, from: parsedItemsData)) ?? [] }
        set { parsedItemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var successRate: Double {
        guard totalTransactions > 0 else { return 0 }
        return Double(importedCount) / Double(totalTransactions)
    }
}
