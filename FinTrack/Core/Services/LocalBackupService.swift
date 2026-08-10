import Foundation
import SwiftData
import Observation

// MARK: - LocalBackupService
//
// Offline, on-device backups — replaces the old iCloud backup. Writes
// timestamped, encrypted `.fintrack` files into Documents/Backups, which the
// user can browse in the Files app (On My iPhone → FinTrack → Backups) thanks
// to UIFileSharingEnabled / LSSupportsOpeningDocumentsInPlace in
// FinTrack-Info.plist. Same pipeline as every other backup provider:
// DataTransferService.exportBackup → BackupEncryptionService → disk.
//
// The automatic daily backup reuses `AppSettings.cloudSyncEnabled` as its
// on/off switch (the field simply changed meaning from "iCloud sync" to
// "automatic offline backups") — no schema change.
@Observable
final class LocalBackupService {
    static let shared = LocalBackupService()

    private let lastBackupKey = "local_last_backup_date"
    private let autoBackupIntervalHours: Double = 24
    /// Auto-pruning keeps this many newest backups.
    private let maxKeptBackups = 10

    var isBackingUp = false
    var isRestoring = false
    var lastError: String?

    private init() {}

    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: lastBackupKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastBackupKey) }
    }

    // MARK: Location

    /// Documents/Backups — created on demand. Documents is what the Files app
    /// exposes, so backups are user-visible and survive independent of the app UI.
    var backupsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
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

    /// All .fintrack backups on disk, newest first.
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

    // MARK: Backup

    @discardableResult
    func performBackup(context: ModelContext) async -> Bool {
        await MainActor.run { isBackingUp = true; lastError = nil }

        do {
            let exportURL = try DataTransferService.shared.exportBackup(context: context)
            let data = try Data(contentsOf: exportURL)
            try? FileManager.default.removeItem(at: exportURL)
            let finalData = try await BackupEncryptionService.encryptIfEnabled(data)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let dest = backupsDirectory
                .appendingPathComponent("FinTrack_Backup_\(formatter.string(from: Date())).fintrack")
            try finalData.write(to: dest, options: .atomic)

            pruneOldBackups()
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

    func deleteBackup(_ backup: BackupFile) {
        try? FileManager.default.removeItem(at: backup.url)
    }

    // MARK: Restore

    func restore(from backup: BackupFile, context: ModelContext,
                 mode: DataTransferService.ImportMode = .merge) async -> String {
        await MainActor.run { isRestoring = true; lastError = nil }

        do {
            let rawData = try Data(contentsOf: backup.url)
            let decrypted = try await BackupEncryptionService.decryptIfNeeded(rawData)
            // Passes plain data straight through; also lets a compressed
            // email-backup file dropped into the folder restore correctly.
            let plainData = try EmailBackupService.decompressIfNeeded(decrypted)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("FinTrack_Local_\(UUID().uuidString).fintrack")
            try plainData.write(to: tempURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let summary = try DataTransferService.shared.importBackup(from: tempURL, context: context, mode: mode)
            await MainActor.run { isRestoring = false }
            return summary.total > 0 ? "Restored \(summary.description) successfully." : "Backup imported — nothing new to add."
        } catch {
            let msg = "Restore failed: \(error.localizedDescription)"
            await MainActor.run { lastError = msg; isRestoring = false }
            return msg
        }
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
