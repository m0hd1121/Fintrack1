import Foundation
import SwiftData
import Observation

// MARK: - LocalBackupService
//
// On-device backups, deliberately NOT user-visible.
//
// Two layers:
//
// 1. Backup files — encrypted `.fintrack` snapshots in
//    Application Support/Backups. That directory is inside the app sandbox and
//    is *not* exposed to the Files app (Documents would be, which is why
//    UIFileSharingEnabled / LSSupportsOpeningDocumentsInPlace are deliberately
//    absent from FinTrack-Info.plist). The user cannot browse, edit or delete
//    these; the app offers no delete/share affordance either.
//
// 2. Device snapshot — the same payload (minus heavy binary blobs) stored as a
//    Keychain item. iOS erases the whole app container on delete, so files
//    CANNOT survive an uninstall; Keychain items can, and are reclaimed by the
//    same bundle id on reinstall. `restoreFromDeviceSnapshotIfNeeded` runs at
//    launch and rehydrates an empty store automatically.
//
// Both layers use the app's mandatory backup encryption, whose key also lives in
// the Keychain — so the snapshot stays readable after a reinstall.
@Observable
final class LocalBackupService {
    static let shared = LocalBackupService()

    private let lastBackupKey = "local_last_backup_date"
    private let autoBackupIntervalHours: Double = 24
    /// Auto-pruning keeps this many newest backup files.
    private let maxKeptBackups = 10

    /// Keychain item holding the uninstall-proof snapshot.
    private let snapshotKeychainKey = "ft_device_snapshot_v1"
    /// Keychain is meant for small secrets; refuse to store anything larger so we
    /// never bloat it. Financial records compress well under this; receipts and
    /// documents are stripped out before we get here.
    private let maxSnapshotBytes = 2 * 1024 * 1024

    var isBackingUp = false
    var isRestoring = false
    var lastError: String?

    private init() {}

    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: lastBackupKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastBackupKey) }
    }

    // MARK: Location

    /// Application Support/Backups — sandboxed and invisible to the Files app.
    var backupsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        migrateLegacyDocumentsBackupsIfNeeded(into: dir)
        return dir
    }

    /// Earlier builds wrote backups to Documents/Backups, which the Files app
    /// exposed. Move any leftovers into the protected directory (and delete the
    /// old, user-visible folder) the first time we need the location.
    private func migrateLegacyDocumentsBackupsIfNeeded(into dir: URL) {
        let fm = FileManager.default
        let legacy = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups", isDirectory: true)
        guard fm.fileExists(atPath: legacy.path) else { return }

        if let files = try? fm.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "fintrack" {
                let dest = dir.appendingPathComponent(file.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: file)
                } else {
                    try? fm.moveItem(at: file, to: dest)
                }
            }
        }
        try? fm.removeItem(at: legacy)
    }

    // MARK: Listing

    struct BackupFile: Identifiable {
        let url: URL
        let date: Date
        let size: Int64
        var id: URL { url }

        var sizeLabel: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }

    /// All backups on disk, newest first.
    func listBackups() -> [BackupFile] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .filter { $0.pathExtension == "fintrack" }
            .compactMap { url -> BackupFile? in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                return BackupFile(
                    url: url,
                    date: values?.contentModificationDate ?? .distantPast,
                    size: Int64(values?.fileSize ?? 0)
                )
            }
            .sorted { $0.date > $1.date }
    }

    var totalSizeLabel: String {
        let total = listBackups().reduce(Int64(0)) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    /// True when an uninstall-proof snapshot is present in the Keychain.
    var hasDeviceSnapshot: Bool {
        let stored: Data? = KeychainStore.load(key: snapshotKeychainKey)
        return stored != nil
    }

    // MARK: Backup

    @discardableResult
    func performBackup(context: ModelContext) async -> Bool {
        await MainActor.run { isBackingUp = true; lastError = nil }

        do {
            let exportURL = try DataTransferService.shared.exportBackup(context: context)
            let plainJSON = try Data(contentsOf: exportURL)
            try? FileManager.default.removeItem(at: exportURL)

            // Layer 1 — encrypted file in the hidden backups directory.
            let finalData = try await BackupEncryptionService.encryptIfEnabled(plainJSON)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let dest = backupsDirectory
                .appendingPathComponent("FinTrack_Backup_\(formatter.string(from: Date())).fintrack")
            try finalData.write(to: dest, options: .atomic)
            pruneOldBackups()

            // Layer 2 — Keychain snapshot that outlives an uninstall.
            await updateDeviceSnapshot(from: plainJSON)

            await MainActor.run {
                isBackingUp = false
                lastBackupDate = Date()
            }
            return true
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isBackingUp = false
            }
            return false
        }
    }

    /// Keep only the newest `maxKeptBackups` files.
    private func pruneOldBackups() {
        let backups = listBackups()
        guard backups.count > maxKeptBackups else { return }
        for old in backups.dropFirst(maxKeptBackups) {
            try? FileManager.default.removeItem(at: old.url)
        }
    }

    // MARK: Restore (from a backup file)

    func restore(from backup: BackupFile, context: ModelContext,
                 mode: DataTransferService.ImportMode = .merge) async -> String {
        await MainActor.run { isRestoring = true; lastError = nil }

        do {
            let rawData = try Data(contentsOf: backup.url)
            let plainData = try await decodePayload(rawData)
            let summary = try importPayload(plainData, context: context, mode: mode)
            await MainActor.run { isRestoring = false }
            return summary.total > 0 ? "Restored \(summary.description) successfully." : "Backup imported — nothing new to add."
        } catch {
            let msg = "Restore failed: \(error.localizedDescription)"
            await MainActor.run { lastError = msg; isRestoring = false }
            return msg
        }
    }

    // MARK: Device snapshot (survives app deletion)

    /// Store a slimmed copy of the backup in the Keychain. Keychain items are not
    /// part of the app container, so iOS keeps them when the app is deleted and
    /// hands them back to the same bundle id on reinstall.
    private func updateDeviceSnapshot(from plainJSON: Data) async {
        do {
            let slim = slimPayload(plainJSON)
            let compressed = try EmailBackupService.compressForSnapshot(slim)
            let encrypted = try await BackupEncryptionService.encryptIfEnabled(compressed)
            guard encrypted.count <= maxSnapshotBytes else {
                // Too big for the Keychain — drop any stale snapshot rather than
                // leaving an out-of-date one that could overwrite newer data.
                KeychainStore.delete(key: snapshotKeychainKey)
                return
            }
            try KeychainStore.save(encrypted, key: snapshotKeychainKey)
        } catch {
            // Snapshot is a safety net; never fail the real backup because of it.
        }
    }

    /// Drops the heavy base64 blobs (receipt images, tax documents, attachments)
    /// so the snapshot fits in the Keychain. All financial records are kept.
    private func slimPayload(_ json: Data) -> Data {
        guard var root = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return json }
        func strip(_ collection: String, _ field: String) {
            guard var rows = root[collection] as? [[String: Any]] else { return }
            for i in rows.indices { rows[i].removeValue(forKey: field) }
            root[collection] = rows
        }
        strip("transactions", "receiptImageData")
        strip("taxDocuments", "fileData")
        strip("documentAttachments", "data")
        return (try? JSONSerialization.data(withJSONObject: root)) ?? json
    }

    /// Rehydrates an empty store from the Keychain snapshot after a reinstall.
    /// Returns true when data was actually restored.
    @discardableResult
    func restoreFromDeviceSnapshotIfNeeded(container: ModelContainer) async -> Bool {
        guard let stored: Data = KeychainStore.load(key: snapshotKeychainKey) else { return false }

        let context = ModelContext(container)
        // Only ever auto-restore into a genuinely empty store, so this can never
        // clobber data the user already has.
        let existing = (try? context.fetchCount(FetchDescriptor<Transaction>())) ?? 0
        let accounts = (try? context.fetchCount(FetchDescriptor<Account>())) ?? 0
        guard existing == 0, accounts == 0 else { return false }

        do {
            let plain = try await decodePayload(stored)
            let summary = try importPayload(plain, context: context, mode: .replace)
            return summary.total > 0
        } catch {
            return false
        }
    }

    // MARK: Shared payload helpers

    /// decrypt → decompress (both no-ops when the markers are absent).
    private func decodePayload(_ raw: Data) async throws -> Data {
        let decrypted = try await BackupEncryptionService.decryptIfNeeded(raw)
        return try EmailBackupService.decompressIfNeeded(decrypted)
    }

    private func importPayload(_ plain: Data, context: ModelContext,
                               mode: DataTransferService.ImportMode) throws -> ImportSummary {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinTrack_Restore_\(UUID().uuidString).fintrack")
        try plain.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try DataTransferService.shared.importBackup(from: tempURL, context: context, mode: mode)
    }

    // MARK: Automatic backups

    /// Triggers a backup if the daily interval has elapsed. Callers gate this on
    /// the user's automatic-backup toggle (`AppSettings.cloudSyncEnabled`).
    func scheduleAutomaticBackupIfNeeded(context: ModelContext) {
        let last = lastBackupDate ?? .distantPast
        guard Date().timeIntervalSince(last) >= autoBackupIntervalHours * 3600 else { return }
        Task { await performBackup(context: context) }
    }

    @MainActor func clearError() { lastError = nil }
}
