import Foundation
import SwiftData

@Model
final class DocumentAttachment {
    var id: UUID
    @Attribute(.externalStorage) var data: Data
    var filename: String
    var mimeType: String
    var createdAt: Date

    var transaction: Transaction?

    init(data: Data, filename: String, mimeType: String) {
        self.id = UUID()
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
        self.createdAt = Date()
    }

    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }

    var isPDF: Bool {
        mimeType == "application/pdf"
    }

    var displayIcon: String {
        if isImage { return "photo" }
        if isPDF   { return "doc.richtext" }
        return "doc"
    }

    var fileSizeLabel: String {
        let bytes = Double(data.count)
        if bytes < 1024 { return "\(Int(bytes)) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", bytes / 1024) }
        return String(format: "%.1f MB", bytes / 1_048_576)
    }
}
