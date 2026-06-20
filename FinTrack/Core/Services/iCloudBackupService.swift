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

    private var ubiquityDocumentsURL: URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let docs = base.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs
    }

    var backupFileURL: URL? { ubiquityDocumentsURL?.appendingPathComponent(backupFileName) }

    var iCloudAvailable: Bool { ubiquityDocumentsURL != nil }

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
    func performBackup(context: ModelContext) async -> Bool {
        guard let cloudURL = ubiquityDocumentsURL else {
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

    func scheduleAutomaticBackupIfNeeded(context: ModelContext) {
        let last = lastBackupDate ?? .distantPast
        guard Date().timeIntervalSince(last) >= autoBackupIntervalHours * 3600 else { return }
        guard iCloudAvailable else { return }
        Task { await performBackup(context: context) }
    }

    private func set(error msg: String) async {
        await MainActor.run { lastError = msg }
    }
}
