import SwiftUI
import SwiftData

struct iCloudSyncView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]

    private var settings: AppSettings? { allSettings.first }

    @State private var isSyncing = false
    @State private var lastSyncDate: Date = Date()
    @State private var syncEnabled: Bool = true
    @State private var deviceCount: Int = 3
    @State private var pendingChanges: Int = 0
    @State private var totalSyncedRecords: Int = 847
    @State private var encryptionEnabled = true
    @State private var wifiOnlyEnabled = false
    @State private var showingConflictResolution = false
    @State private var showingDevices = false

    private var syncStatus: SyncPhase {
        if isSyncing { return .syncing }
        if !syncEnabled { return .disabled }
        return pendingChanges > 0 ? .pending : .synced
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
            case .synced:   return "Synced"
            case .pending:  return "Pending Sync"
            case .syncing:  return "Syncing…"
            case .disabled: return "Sync Disabled"
            case .error:    return "Sync Error"
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
        .navigationTitle("iCloud Sync")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CLOUDKIT STATUS").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    if isSyncing {
                        HStack(spacing: FTSpacing.sm) {
                            ProgressView().scaleEffect(0.7).tint(FTColor.catBlue)
                            Text("Syncing…").font(.ftHeadline).foregroundStyle(FTColor.catBlue)
                        }
                    } else {
                        Text(syncStatus.label).font(.ftHeadline).foregroundStyle(syncStatus.color)
                    }
                    Text("Last synced \(lastSyncDate.relativeFormatted)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(syncStatus.color.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: syncStatus.icon).font(.ftTitle).foregroundStyle(syncStatus.color)
                }
            }

            FTToggleRow(symbol: "icloud", tint: FTColor.catBlue, title: "Enable iCloud Sync", isOn: $syncEnabled)
                .onChange(of: syncEnabled) { _, new in
                    settings?.cloudSyncEnabled = new
                    try? context.save()
                }

            if syncEnabled {
                Button {
                    performSync()
                } label: {
                    Label(isSyncing ? "Syncing…" : "Sync Now", systemImage: isSyncing ? "arrow.clockwise" : "icloud.and.arrow.up")
                        .font(.ftBodySemibold)
                        .foregroundStyle(isSyncing ? FTColor.textMuted : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSyncing ? FTColor.catBlue.opacity(0.1) : FTColor.catBlue,
                                    in: RoundedRectangle(cornerRadius: FTRadius.md))
                }
                .disabled(isSyncing)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: FTSpacing.sm) {
            statTile("Records", value: "\(totalSyncedRecords)", icon: "doc.fill", color: FTColor.catBlue)
            statTile("Devices", value: "\(deviceCount)", icon: "devices.fill", color: FTColor.catPurple)
            statTile("Pending", value: "\(pendingChanges)", icon: "clock.fill", color: pendingChanges > 0 ? FTColor.gold : FTColor.textMuted)
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

    // MARK: - Devices Card

    private var devicesCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Text("SYNCED DEVICES").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                Spacer()
                Text("\(deviceCount) devices").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }

            let devices = [
                (name: "iPhone (This device)", icon: "iphone", time: "Just now"),
                (name: "iPad Pro", icon: "ipad", time: "2 hours ago"),
                (name: "MacBook Pro", icon: "laptopcomputer", time: "Yesterday"),
            ]

            ForEach(devices.prefix(deviceCount), id: \.name) { device in
                HStack(spacing: FTSpacing.md) {
                    ZStack {
                        Circle().fill(FTColor.catBlue.opacity(0.1)).frame(width: 40, height: 40)
                        Image(systemName: device.icon).font(.ftCallout).foregroundStyle(FTColor.catBlue)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Text("Last active \(device.time)").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(FTColor.income)
                }
            }
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

    // MARK: - Logic

    private func performSync() {
        isSyncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isSyncing = false
            lastSyncDate = Date()
            pendingChanges = 0
            totalSyncedRecords += Int.random(in: 0...5)
        }
    }
}
