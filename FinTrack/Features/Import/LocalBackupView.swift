import SwiftUI
import SwiftData

// Backup status + restore. Backups are intentionally read-only from the user's
// side: they live in Application Support (invisible to the Files app) and this
// screen offers no delete, rename or share action — only "Back Up Now" and
// "Restore". See LocalBackupService for the two protection layers.
struct LocalBackupView: View {
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]

    private let service = LocalBackupService.shared

    @State private var backups: [LocalBackupService.BackupFile] = []
    @State private var pendingRestore: LocalBackupService.BackupFile?
    @State private var resultMessage = ""
    @State private var showingResult = false

    private var settings: AppSettings? { allSettings.first }

    /// Reuses the existing `cloudSyncEnabled` field as the automatic-backup
    /// switch — the field's meaning changed with the provider, no schema bump.
    private var autoBackupBinding: Binding<Bool> {
        Binding(
            get: { settings?.cloudSyncEnabled ?? false },
            set: { settings?.cloudSyncEnabled = $0; try? context.save() }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                statusCard
                actionsCard
                backupsList
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.lg)
            .padding(.bottom, FTSpacing.xxl)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .alert("Backup", isPresented: $showingResult) {
            Button("OK") { }
        } message: {
            Text(resultMessage)
        }
        .confirmationDialog(
            "Restore this backup?",
            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
            titleVisibility: .visible
        ) {
            Button("Merge with existing data") { restore(mode: .merge) }
            Button("Replace all data", role: .destructive) { restore(mode: .replace) }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("Merge keeps your current data and adds anything missing. Replace deletes everything first, then restores from this backup.")
        }
    }

    // MARK: Status

    private var statusCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack(spacing: FTSpacing.lg) {
                ZStack {
                    Circle()
                        .fill((backups.isEmpty ? FTColor.textMuted : FTColor.income).opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: backups.isEmpty ? "lock.open" : "lock.shield.fill")
                        .font(.ftTitle)
                        .foregroundStyle(backups.isEmpty ? FTColor.textMuted : FTColor.income)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(backups.isEmpty ? "No Backups Yet" : "Protected")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text(lastBackupLabel)
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: FTSpacing.sm) {
                statTile("Size", value: service.totalSizeLabel, icon: "internaldrive.fill", color: FTColor.accent)
                statTile("Reinstall-safe",
                         value: service.hasDeviceSnapshot ? "Yes" : "No",
                         icon: service.hasDeviceSnapshot ? "checkmark.seal.fill" : "xmark.seal",
                         color: service.hasDeviceSnapshot ? FTColor.income : FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var lastBackupLabel: String {
        guard let date = service.lastBackupDate else {
            return "Create a backup to protect your data"
        }
        return "Last backup \(date.relativeFormatted)"
    }

    private func statTile(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.ftCaption).foregroundStyle(color)
            Text(value).font(.ftCallout).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.md)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    // MARK: Actions

    private var actionsCard: some View {
        VStack(spacing: 0) {
            Button { backUpNow() } label: {
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "arrow.down.circle.fill", tint: FTColor.accent, size: 36)
                    Text(service.isBackingUp ? "Backing Up…" : "Back Up Now")
                        .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    if service.isBackingUp { ProgressView().scaleEffect(0.8) }
                }
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .disabled(service.isBackingUp)

            Divider().opacity(0.4)

            FTToggleRow(symbol: "clock.arrow.circlepath", tint: FTColor.catTeal,
                        title: "Back Up After Every Change",
                        isOn: autoBackupBinding)
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: Backup list

    @ViewBuilder
    private var backupsList: some View {
        if !backups.isEmpty {
            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                Text("LATEST BACKUP")
                    .font(.ftLabel).tracking(1.6).fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(FTColor.textMuted)

                VStack(spacing: 0) {
                    ForEach(Array(backups.enumerated()), id: \.element.id) { index, backup in
                        backupRow(backup)
                        if index < backups.count - 1 { Divider().opacity(0.4) }
                    }
                }
                .padding(.horizontal, FTSpacing.lg)
                .ftGlass(FTRadius.md)
            }
        }
    }

    private func backupRow(_ backup: LocalBackupService.BackupFile) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "doc.fill", tint: FTColor.catBlue, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(backup.date.formatted)
                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Text(backup.sizeLabel)
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            // Restore is the only action — backups can't be deleted or edited.
            Button { pendingRestore = backup } label: {
                Text("Restore")
                    .font(.ftCallout)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(FTColor.accent.opacity(0.14), in: .capsule)
                    .foregroundStyle(FTColor.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
    }

    // MARK: Operations

    private func reload() {
        service.pruneOldBackups()
        backups = service.listBackups()
    }

    private func backUpNow() {
        Task {
            let ok = await service.performBackup(context: context)
            reload()
            resultMessage = ok
                ? "Backup saved and protected on this device."
                : (service.lastError ?? "Backup failed.")
            showingResult = true
        }
    }

    private func restore(mode: DataTransferService.ImportMode) {
        guard let backup = pendingRestore else { return }
        pendingRestore = nil
        Task {
            resultMessage = await service.restore(from: backup, context: context, mode: mode)
            showingResult = true
        }
    }
}
