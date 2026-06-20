import Foundation
import SwiftData

enum AuditEventType: String, Codable, CaseIterable {
    case appUnlocked         = "App Unlocked"
    case appLocked           = "App Locked"
    case biometricAuth       = "Biometric Auth"
    case failedAuth          = "Failed Auth"
    case pinChanged          = "PIN Changed"
    case transactionAdded    = "Transaction Added"
    case transactionEdited   = "Transaction Edited"
    case transactionDeleted  = "Transaction Deleted"
    case settingsChanged     = "Settings Changed"
    case dataExported        = "Data Exported"
    case dataImported        = "Data Imported"
    case hiddenModeActivated = "Hidden Mode"
    case twoFAEnabled        = "2FA Enabled"
    case twoFADisabled       = "2FA Disabled"

    var icon: String {
        switch self {
        case .appUnlocked:         return "lock.open.fill"
        case .appLocked:           return "lock.fill"
        case .biometricAuth:       return "faceid"
        case .failedAuth:          return "exclamationmark.shield.fill"
        case .pinChanged:          return "number.square.fill"
        case .transactionAdded:    return "plus.circle.fill"
        case .transactionEdited:   return "pencil.circle.fill"
        case .transactionDeleted:  return "minus.circle.fill"
        case .settingsChanged:     return "gearshape.fill"
        case .dataExported:        return "arrow.up.doc.fill"
        case .dataImported:        return "arrow.down.doc.fill"
        case .hiddenModeActivated: return "eye.slash.fill"
        case .twoFAEnabled:        return "checkmark.shield.fill"
        case .twoFADisabled:       return "xmark.shield.fill"
        }
    }

    var isSecurityEvent: Bool {
        switch self {
        case .failedAuth, .pinChanged, .hiddenModeActivated, .twoFAEnabled, .twoFADisabled:
            return true
        default:
            return false
        }
    }
}

@Model
final class AuditLogEntry {
    var id: UUID
    var timestamp: Date
    var eventTypeRaw: String
    var eventDescription: String
    var deviceName: String

    var eventType: AuditEventType {
        AuditEventType(rawValue: eventTypeRaw) ?? .settingsChanged
    }

    init(
        id: UUID = UUID(),
        eventType: AuditEventType,
        description: String,
        deviceName: String = "iPhone"
    ) {
        self.id = id
        self.timestamp = Date()
        self.eventTypeRaw = eventType.rawValue
        self.eventDescription = description
        self.deviceName = deviceName
    }
}
