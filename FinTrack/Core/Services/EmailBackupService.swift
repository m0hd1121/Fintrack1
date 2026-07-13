import Foundation
import SwiftData
import Observation

// MARK: - EmailBackupService
//
// Automatic backup via plain email — sends the (compressed, optionally
// encrypted) .fintrack backup file to your own inbox over SMTP, and restores
// it by searching that same inbox over IMAP for the most recent backup
// email. Signs in with a real email address + app-specific password, exactly
// like the existing IMAP email-import flow — no OAuth, no developer setup,
// no Google Cloud Console client ID.
//
// Pipeline: export JSON → zlib-compress → encrypt (if a Backup Passphrase is
// set) → attach to an SMTP message. Restore reverses it: decrypt (if
// encrypted) → decompress (if compressed) → import. Compression always runs
// on backup; decompression detects a magic header so older, uncompressed
// backup emails still restore correctly.
enum EmailBackupError: LocalizedError {
    case notConnected
    case noBackupFound
    case attachmentUnreadable

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to Email Backup."
        case .noBackupFound: return "No backup email found in your inbox."
        case .attachmentUnreadable: return "Found a backup email but couldn't read its attachment."
        }
    }
}

@Observable
@MainActor
final class EmailBackupService {
    static let shared = EmailBackupService()

    private let backupFileName = "FinTrack_Backup.fintrack"
    private let subjectPrefix = "FinTrack Backup"

    private let connectedEmailKey = "email_backup_connected_email"
    private let smtpHostKey = "email_backup_smtp_host"
    private let imapHostKey = "email_backup_imap_host"
    private let lastBackupKey = "email_backup_last_date"
    private let enabledKey = "email_backup_enabled"
    private let wifiOnlyKey = "email_backup_wifi_only"
    private let credentialsKeychainKey = "ft_email_backup_credentials"

    var isBackingUp = false
    var isRestoring = false
    var isConnecting = false
    var lastError: String?

    private init() {}

    struct Credentials: Codable {
        let email: String
        let password: String
    }

    var connectedEmail: String? {
        get { UserDefaults.standard.string(forKey: connectedEmailKey) }
        set { UserDefaults.standard.set(newValue, forKey: connectedEmailKey) }
    }

    var isConnected: Bool { connectedEmail != nil }

    var smtpHost: String {
        get { UserDefaults.standard.string(forKey: smtpHostKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: smtpHostKey) }
    }

    var imapHost: String {
        get { UserDefaults.standard.string(forKey: imapHostKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: imapHostKey) }
    }

    var backupEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    var wifiOnly: Bool {
        get { UserDefaults.standard.bool(forKey: wifiOnlyKey) }
        set { UserDefaults.standard.set(newValue, forKey: wifiOnlyKey) }
    }

    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: lastBackupKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastBackupKey) }
    }

    // MARK: - Host suggestions

    static func suggestedSMTPHost(for email: String) -> String {
        let domain = email.components(separatedBy: "@").last?.lowercased() ?? ""
        switch domain {
        case "gmail.com", "googlemail.com":       return "smtp.gmail.com"
        case "icloud.com", "me.com", "mac.com":   return "smtp.mail.me.com"
        case "yahoo.com", "ymail.com":            return "smtp.mail.yahoo.com"
        case "aol.com":                           return "smtp.aol.com"
        case "fastmail.com", "fastmail.fm":       return "smtp.fastmail.com"
        default:                                  return domain.isEmpty ? "" : "smtp.\(domain)"
        }
    }

    // MARK: - Connect / Disconnect

    /// Verifies both directions up front (SMTP for backup, IMAP for restore)
    /// so a bad password/host surfaces immediately instead of during the
    /// first real backup attempt.
    func connect(email: String, password: String, smtpHost: String, imapHost: String) async throws {
        isConnecting = true
        defer { isConnecting = false }

        let smtp = SMTPClient(host: smtpHost)
        try await smtp.connect()
        try await smtp.ehlo()
        try await smtp.authLogin(user: email, password: password)
        try? await smtp.quit()

        let imap = IMAPClient(host: imapHost)
        try await imap.connect()
        try await imap.login(user: email, password: password)
        try? await imap.logout()

        try KeychainStore.save(Credentials(email: email, password: password), key: credentialsKeychainKey)
        connectedEmail = email
        self.smtpHost = smtpHost
        self.imapHost = imapHost
    }

    func disconnect() {
        KeychainStore.delete(key: credentialsKeychainKey)
        connectedEmail = nil
        lastBackupDate = nil
    }

    // MARK: - Backup / Restore

    @discardableResult
    func performBackup(context: ModelContext) async -> Bool {
        guard isConnected, let creds: Credentials = KeychainStore.load(key: credentialsKeychainKey) else {
            await set(error: EmailBackupError.notConnected.localizedDescription)
            return false
        }
        if wifiOnly {
            let network = NetworkMonitor.shared
            guard network.isConnected && network.connectionType == .wifi else {
                await set(error: "Backup skipped — Wi-Fi only mode is enabled and you are not on Wi-Fi.")
                return false
            }
        }

        isBackingUp = true
        lastError = nil
        defer { isBackingUp = false }

        do {
            let exportURL = try DataTransferService.shared.exportBackup(context: context)
            let data = try Data(contentsOf: exportURL)
            try? FileManager.default.removeItem(at: exportURL)
            let compressedData = try Self.compress(data)
            let finalData = try await BackupEncryptionService.encryptIfEnabled(compressedData)

            let smtp = SMTPClient(host: smtpHost)
            try await smtp.connect()
            try await smtp.ehlo()
            try await smtp.authLogin(user: creds.email, password: creds.password)
            try await smtp.sendMessage(
                from: creds.email, to: creds.email,
                subject: "\(subjectPrefix) — \(Self.dateStamp(Date()))",
                textBody: "This is an automatic backup from FinTrack. Restore it from Settings → Email Backup → Restore on any device signed into this same email account.",
                attachment: finalData, attachmentFilename: backupFileName
            )
            try await smtp.quit()

            lastBackupDate = Date()
            return true
        } catch {
            await set(error: error.localizedDescription)
            return false
        }
    }

    func restoreFromEmail(context: ModelContext, mode: DataTransferService.ImportMode = .merge) async -> String {
        guard isConnected, let creds: Credentials = KeychainStore.load(key: credentialsKeychainKey) else {
            return EmailBackupError.notConnected.localizedDescription
        }
        isRestoring = true
        lastError = nil
        defer { isRestoring = false }

        do {
            let imap = IMAPClient(host: imapHost)
            try await imap.connect()
            try await imap.login(user: creds.email, password: creds.password)
            try await imap.selectInbox()

            let uids = try await imap.uidSearch("SUBJECT \"\(subjectPrefix)\"")
            guard let latestUid = uids.sorted().last else {
                try? await imap.logout()
                return EmailBackupError.noBackupFound.localizedDescription
            }

            let raw = try await imap.fetchRawMessage(uid: latestUid)
            try? await imap.logout()

            guard let rawData = MIMEDecoder.extractAttachment(from: raw, filenameContains: backupFileName) else {
                return EmailBackupError.attachmentUnreadable.localizedDescription
            }
            let decryptedData = try await BackupEncryptionService.decryptIfNeeded(rawData)
            let plainData = try Self.decompressIfNeeded(decryptedData)

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(backupFileName)
            try plainData.write(to: tempURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let summary = try DataTransferService.shared.importBackup(from: tempURL, context: context, mode: mode)
            return summary.total > 0 ? "Restored \(summary.description) successfully." : "Backup imported — nothing new to add."
        } catch {
            let msg = "Restore failed: \(error.localizedDescription)"
            await set(error: msg)
            return msg
        }
    }

    private let autoBackupInterval: TimeInterval = 3600   // hourly

    /// Triggers a backup if auto-backup is due (hourly interval) and enabled.
    /// Safe to call from any scene-phase change handler.
    func scheduleAutomaticBackupIfNeeded(context: ModelContext) {
        guard backupEnabled, isConnected else { return }
        let last = lastBackupDate ?? .distantPast
        guard Date().timeIntervalSince(last) >= autoBackupInterval else { return }
        Task { await performBackup(context: context) }
    }

    private var autoBackupTask: Task<Void, Never>?

    /// Scene-phase transitions alone (launch/background/resume) may not fire
    /// for hours if the app just stays open — this keeps checking every few
    /// minutes so an hourly interval is actually honored while the app is in
    /// the foreground, not just at transition points. Call once on launch.
    func startAutoBackup(context: ModelContext) {
        guard autoBackupTask == nil else { return }
        autoBackupTask = Task {
            while !Task.isCancelled {
                scheduleAutomaticBackupIfNeeded(context: context)
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    func stopAutoBackup() {
        autoBackupTask?.cancel()
        autoBackupTask = nil
    }

    @MainActor func clearError() { lastError = nil }

    private func set(error msg: String) async {
        await MainActor.run { lastError = msg }
    }

    // MARK: - Compression
    //
    // Runs before encryption (compressing ciphertext gains nothing — AES
    // output is high-entropy) and is undone after decryption. A magic header
    // lets restore tell a compressed backup apart from an older, plain one.

    private static let compressionMagic = Data("FTGZ1".utf8)

    private static func compress(_ data: Data) throws -> Data {
        let compressed = try (data as NSData).compressed(using: .zlib) as Data
        return compressionMagic + compressed
    }

    private static func decompressIfNeeded(_ data: Data) throws -> Data {
        guard data.starts(with: compressionMagic) else { return data }
        let payload = data.suffix(from: compressionMagic.count)
        return try (Data(payload) as NSData).decompressed(using: .zlib) as Data
    }

    private static func dateStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
