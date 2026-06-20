import SwiftUI
import SwiftData

struct iCloudSyncView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]

    private var settings: AppSettings? { allSettings.first }

    @State private var syncEnabled: Bool = true
    @State private var encryptionEnabled = true
    @State private var wifiOnlyEnabled = false
    @State private var showingRestoreConfirm = false
    @State private var resultMessage = ""
    @State private var showingResult = false

    private let backup = iCloudBackupService.shared
    private let network = NetworkMonitor.shared

    private var syncStatus: SyncPhase {
        if backup.isBackingUp { return .syncing }
        if !syncEnabled || !backup.iCloudAvailable { return .disabled }
        if backup.lastError != nil { return .error }
        return backup.backupExists ? .synced : .pending
    }

    enum SyncPhase {
        case synced, pending, syncing, disabled, error

        var icon: String {
            switch self {
            case .synced:   return "icloud.fill"
            case .pending:  return "icloud.and.arrow.up"
            case .syncing:  return "arrow.clockwise.icloud"
            case .disabled: return "icloud.slash.fill"
            case .error:    return "exclamationmark.icloud.fill"
            }
        }

        var color: Color {
            switch self {
            case .synced:   return FTColor.income
            case .pending:  return FTColor.gold
            case .syncing:  return FTColor.catBlue
            case .disabled: return FTColor.textMuted
            case .error:    return FTColor.expense
            }
        }

        var label: String {
            switch self {
            case .synced:   return "Backed Up to iCloud"
            case .pending:  return "No Backup Yet"
            case .syncing:  return "Backing Up…"
            case .disabled: return "Backup Disabled"
            case .error:    return "Backup Error"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                statusCard
                statsStrip
                devicesCard
                settingsCard
                conflictCard
                encryptionCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("iCloud Backup")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .scrollContentBackground(.hidden)
        .confirmationDialog("Restore from iCloud?", isPresented: $showingRestoreConfirm, titleVisibility: .visible) {
            Button("Merge with current data") {
                Task {
                    let msg = await backup.restoreFromCloud(context: context, mode: .merge)
                    resultMessage = msg
                    showingResult = true
                }
            }
            Button("Replace all data", role: .destructive) {
                Task {
                    let msg = await backup.restoreFromCloud(context: context, mode: .replace)
                    resultMessage = msg
                    showingResult = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how to restore: merge adds new items without removing existing ones, replace deletes everything first.")
        }
        .alert("iCloud Backup", isPresented: $showingResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
        .onAppear {
            syncEnabled = settings?.cloudSyncEnabled ?? false
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ICLOUD BACKUP").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    if backup.isBackingUp {
                        HStack(spacing: FTSpacing.sm) {
                            ProgressView().scaleEffect(0.7).tint(FTColor.catBlue)
                            Text("Backing up…").font(.ftHeadline).foregroundStyle(FTColor.catBlue)
                        }
                    } else {
                        Text(syncStatus.label).font(.ftHeadline).foregroundStyle(syncStatus.color)
                    }
                    if let last = backup.lastBackupDate {
                        Text("Last backup: \(last.relativeFormatted)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    } else {
                        Text("No backup found").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle().fill(syncStatus.color.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: syncStatus.icon).font(.ftTitle).foregroundStyle(syncStatus.color)
                }
            }

            FTToggleRow(symbol: "icloud", tint: FTColor.catBlue, title: "Enable Automatic Backup", isOn: $syncEnabled)
                .onChange(of: syncEnabled) { _, new in
                    settings?.cloudSyncEnabled = new
                    try? context.save()
                }

            if !backup.iCloudAvailable {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(FTColor.gold)
                    Text("Sign in to iCloud in Settings to enable backup.")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }

            HStack(spacing: FTSpacing.md) {
                Button {
                    Task {
                        let ok = await backup.performBackup(context: context)
                        if !ok {
                            resultMessage = backup.lastError ?? "Backup failed."
                            showingResult = true
                        }
                    }
                } label: {
                    Label(backup.isBackingUp ? "Backing Up…" : "Back Up Now",
                          systemImage: backup.isBackingUp ? "arrow.clockwise" : "icloud.and.arrow.up")
                        .font(.ftBodySemibold)
                        .foregroundStyle(backup.isBackingUp ? FTColor.textMuted : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(backup.isBackingUp ? FTColor.catBlue.opacity(0.1) : FTColor.catBlue,
                                    in: RoundedRectangle(cornerRadius: FTRadius.md))
                }
                .disabled(backup.isBackingUp || !backup.iCloudAvailable)

                Button {
                    showingRestoreConfirm = true
                } label: {
                    Label("Restore", systemImage: "icloud.and.arrow.down")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.catBlue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(FTColor.catBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: FTRadius.md))
                }
                .disabled(backup.isRestoring || !backup.backupExists)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: FTSpacing.sm) {
            statTile("File Size", value: backup.backupFileSize, icon: "doc.fill", color: FTColor.catBlue)
            statTile("Connection", value: network.connectionType.rawValue, icon: network.connectionType.icon, color: network.isConnected ? FTColor.income : FTColor.expense)
            statTile("Status", value: network.isConnected ? "Online" : "Offline", icon: "wifi", color: network.isConnected ? FTColor.income : FTColor.expense)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func statTile(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.ftCaption).foregroundStyle(color)
            Text(value).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.md)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    // MARK: - Backup Info Card

    private var devicesCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("BACKUP LOCATION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            HStack(spacing: FTSpacing.md) {
                ZStack {
                    Circle().fill(FTColor.catBlue.opacity(0.1)).frame(width: 40, height: 40)
                    Image(systemName: "icloud.fill").font(.ftCallout).foregroundStyle(FTColor.catBlue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("iCloud Drive / FinTrack").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Text("FinTrack_Backup.fintrack").font(.ftCaption).foregroundStyle(FTColor.textMuted).monospaced()
                }
                Spacer()
                if backup.backupExists {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(FTColor.income)
                } else {
                    Image(systemName: "circle").foregroundStyle(FTColor.textMuted)
                }
            }

            Text("Backup is stored in your personal iCloud Drive and is only accessible by you. It can be restored on any device signed into the same Apple ID.")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(spacing: FTSpacing.sm) {
            FTToggleRow(symbol: "wifi", tint: FTColor.catTeal,
                        title: "Sync on Wi-Fi only",
                        isOn: $wifiOnlyEnabled)
            Divider().background(FTColor.textMuted.opacity(0.3))
            FTToggleRow(symbol: "lock.fill", tint: FTColor.catPurple,
                        title: "End-to-end encryption",
                        isOn: $encryptionEnabled)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Conflict Resolution

    private var conflictCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("CONFLICT RESOLUTION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Strategy").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Text("Conflicts are resolved using the most recently modified version.")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                Spacer()
                Text("Last Wins").font(.ftCaption).foregroundStyle(FTColor.catBlue)
                    .padding(.horizontal, FTSpacing.sm).padding(.vertical, 4)
                    .background(FTColor.catBlue.opacity(0.1), in: Capsule())
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Encryption Info

    private var encryptionCard: some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: "checkmark.shield.fill").font(.ftCallout).foregroundStyle(FTColor.income)
            VStack(alignment: .leading, spacing: 4) {
                Text("Encrypted at Rest & In Transit").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("Your financial data is encrypted using AES-256 before being stored in iCloud. Apple cannot read your data.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

}
