import SwiftUI
import SwiftData

// Offline, on-device backups (replaces the old iCloud sync screen). Backups are
// written to Documents/Backups and are visible in the Files app under
// On My iPhone → FinTrack → Backups.
struct LocalBackupView: View {
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]

    private let service = LocalBackupService.shared

    @State private var backups: [LocalBackupService.BackupFile] = []
    @State private var pendingRestore: LocalBackupService.BackupFile?
    @State private var pendingDelete: LocalBackupService.BackupFile?
    @State private var resultMessage = ""
    @State private var showingResult = false
    @State private var exportURL: URL?

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
                infoCard
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.lg)
            .padding(.bottom, FTSpacing.xxl)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Offline Backup")
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
        .alert("Delete Backup?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let target = pendingDelete { service.deleteBackup(target) }
                pendingDelete = nil
                reload()
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This permanently removes the backup file from this device.")
        }
        .sheet(item: Binding(get: { exportURL.map { ShareItem(url: $0) } },
                             set: { if $0 == nil { exportURL = nil } })) { item in
            ShareSheet(url: item.url)
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
                    Image(systemName: backups.isEmpty ? "internaldrive" : "checkmark.shield.fill")
                        .font(.ftTitle)
                        .foregroundStyle(backups.isEmpty ? FTColor.textMuted : FTColor.income)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(backups.isEmpty ? "No Backups Yet" : "Backed Up on This Device")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text(lastBackupLabel)
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: FTSpacing.sm) {
                statTile("Backups", value: "\(backups.count)", icon: "doc.on.doc.fill", color: FTColor.catBlue)
                statTile("Total Size", value: service.totalSizeLabel, icon: "internaldrive.fill", color: FTColor.accent)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var lastBackupLabel: String {
        guard let date = service.lastBackupDate else {
            return "Create a backup to keep a copy on this device"
        }
        return "Last backup \(date.relativeFormatted)"
    }

    private func statTile(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.ftCaption).foregroundStyle(color)
            Text(value).font(.ftCallout).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
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
                        title: "Automatic Daily Backup",
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
                Text("SAVED BACKUPS")
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
            Menu {
                Button { pendingRestore = backup } label: {
                    Label("Restore", systemImage: "arrow.counterclockwise")
                }
                Button { exportURL = backup.url } label: {
                    Label("Share / Save to Files", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) { pendingDelete = backup } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.ftHeadline).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: Info

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(alignment: .top, spacing: FTSpacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.ftCaption).foregroundStyle(FTColor.catBlue).frame(width: 20)
                Text("Backups are saved on this device and appear in the Files app under On My iPhone → FinTrack → Backups. The 10 most recent are kept automatically.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            HStack(alignment: .top, spacing: FTSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.ftCaption).foregroundStyle(FTColor.gold).frame(width: 20)
                Text("Because they live only on this device, deleting the app removes them too. Use Share to keep a copy somewhere safe.")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }

    // MARK: Operations

    private func reload() {
        backups = service.listBackups()
    }

    private func backUpNow() {
        Task {
            let ok = await service.performBackup(context: context)
            reload()
            resultMessage = ok
                ? "Backup saved to this device."
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

// MARK: - Share sheet plumbing

private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
