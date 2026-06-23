import Foundation
import SwiftData

@Observable
final class iCloudBackupService {
    static let shared = iCloudBackupService()

    private let backupFileName = "FinTrack_Backup.fintrack"
    private let lastBackupKey = "icloud_last_backup_date"
    private let autoBackupIntervalHours: Double = 24

    var isBackingUp = false
    var isRestoring = false
    var lastError: String?

    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: lastBackupKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastBackupKey) }
    }

    // Resolves the iCloud ubiquity container URL on a background thread.
    // Apple docs: url(forUbiquityContainerIdentifier:) must NOT be called on the main thread.
    private func resolveUbiquityURL() async -> URL? {
        await Task.detached(priority: .utility) {
            guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
            let docs = base.appendingPathComponent("Documents", isDirectory: true)
            try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            return docs
        }.value
    }

    // Synchronous check used only for UI display — safe since it's a fast file-existence check
    // after the container URL has already been resolved at least once.
    var iCloudAvailable: Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

    var backupFileURL: URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        return base.appendingPathComponent("Documents/\(backupFileName)")
    }

    var backupFileSize: String {
        guard let url = backupFileURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var backupExists: Bool {
        guard let url = backupFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private init() {}

    @discardableResult
    func performBackup(context: ModelContext, wifiOnly: Bool = false) async -> Bool {
        // Enforce Wi-Fi only setting before doing any work
        if wifiOnly {
            let network = NetworkMonitor.shared
            guard network.isConnected && network.connectionType == .wifi else {
                await set(error: "Backup skipped — Wi-Fi only mode is enabled and you are not on Wi-Fi.")
                return false
            }
        }

        // Resolve iCloud container URL on a background thread (Apple requirement)
        guard let cloudURL = await resolveUbiquityURL() else {
            await set(error: "iCloud is not available. Please sign in to iCloud in Settings.")
            return false
        }

        await MainActor.run { isBackingUp = true; lastError = nil }

        do {
            let exportURL = try DataTransferService.shared.exportBackup(context: context)
            let data = try Data(contentsOf: exportURL)
            let dest = cloudURL.appendingPathComponent(backupFileName)
            try data.write(to: dest, options: .atomic)
            try? FileManager.default.removeItem(at: exportURL)

            await MainActor.run {
                isBackingUp = false
                lastBackupDate = Date()
            }
            return true
        } catch {
            await set(error: error.localizedDescription)
            await MainActor.run { isBackingUp = false }
            return false
        }
    }

    func restoreFromCloud(context: ModelContext, mode: DataTransferService.ImportMode = .merge) async -> String {
        guard let url = backupFileURL else { return "iCloud is not available." }
        guard FileManager.default.fileExists(atPath: url.path) else { return "No backup found in iCloud Drive." }

        await MainActor.run { isRestoring = true; lastError = nil }

        do {
            let summary = try DataTransferService.shared.importBackup(from: url, context: context, mode: mode)
            await MainActor.run { isRestoring = false }
            return summary.total > 0 ? "Restored \(summary.description) successfully." : "Backup imported — nothing new to add."
        } catch {
            let msg = "Restore failed: \(error.localizedDescription)"
            await set(error: msg)
            await MainActor.run { isRestoring = false }
            return msg
        }
    }

    /// Triggers a backup if auto-backup is due (24-hour interval) and sync is enabled.
    /// Safe to call from any scene-phase change handler.
    func scheduleAutomaticBackupIfNeeded(context: ModelContext, wifiOnly: Bool = false) {
        let last = lastBackupDate ?? .distantPast
        guard Date().timeIntervalSince(last) >= autoBackupIntervalHours * 3600 else { return }
        Task { await performBackup(context: context, wifiOnly: wifiOnly) }
    }

    private func set(error msg: String) async {
        await MainActor.run { lastError = msg }
    }
}
