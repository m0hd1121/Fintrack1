import SwiftUI
import SwiftData

struct ImportIntegrationView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \ImportedFile.importedAt, order: .reverse) private var importHistory: [ImportedFile]

    private var lastImport: ImportedFile? { importHistory.first }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                statusCard
                importMethods
                if !importHistory.isEmpty { historyCard }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Import & Integration")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DATA SYNC STATUS").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    if let last = lastImport {
                        Text("Last Import: \(last.importedAt.relativeFormatted)")
                            .font(.ftHeadline).foregroundStyle(FTColor.income)
                        Text("\(last.importedCount) transactions from \(last.fileName)")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    } else {
                        Text("Ready to Import")
                            .font(.ftHeadline).foregroundStyle(FTColor.textSecondary)
                        Text("Import bank statements or OFX files to get started")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill((lastImport != nil ? FTColor.income : FTColor.textMuted).opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: lastImport != nil ? "checkmark.icloud.fill" : "icloud.fill")
                        .font(.ftTitle)
                        .foregroundStyle(lastImport != nil ? FTColor.income : FTColor.textMuted)
                }
            }
            HStack(spacing: FTSpacing.sm) {
                statTile("Imports", value: "\(importHistory.count)", icon: "arrow.down.doc.fill", color: FTColor.catBlue)
                statTile("Transactions", value: "\(importHistory.reduce(0) { $0 + $1.importedCount })", icon: "list.bullet", color: FTColor.accent)
                statTile("Last File", value: lastImport?.fileName ?? "—", icon: "doc.fill", color: FTColor.textSecondary)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
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

    // MARK: - Import Methods

    private var importMethods: some View {
        VStack(spacing: FTSpacing.md) {
            Text("IMPORT METHODS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink(destination: PDFImportView()) {
                methodRow(icon: "doc.fill", color: FTColor.expense,
                          title: "PDF Bank Statement",
                          subtitle: "AI-powered parsing · ENBD, FAB, ADCB and more")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: OFXImportView()) {
                methodRow(icon: "arrow.down.doc.fill", color: FTColor.catBlue,
                          title: "OFX / QIF / QFX",
                          subtitle: "Standard banking formats · Auto dedup")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: iCloudSyncView()) {
                methodRow(icon: "icloud.fill", color: FTColor.accent,
                          title: "iCloud & CloudKit Sync",
                          subtitle: "End-to-end encrypted · All your Apple devices")
            }
            .buttonStyle(.plain)
        }
    }

    private func methodRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: FTSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: FTRadius.sm).fill(color.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.ftHeadline).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(subtitle).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .padding()
        .ftGlass(FTRadius.md)
    }

    // MARK: - History Card

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("IMPORT HISTORY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            ForEach(importHistory.prefix(5)) { file in
                HStack(spacing: FTSpacing.md) {
                    ZStack {
                        Circle().fill(statusColor(file.status).opacity(0.12)).frame(width: 36, height: 36)
                        Image(systemName: file.status.icon).font(.ftCaption).foregroundStyle(statusColor(file.status))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(file.fileName).font(.ftBody).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                        Text("\(file.importedCount) of \(file.totalTransactions) imported · \(file.fileType.rawValue)")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    Text(file.importedAt.relativeFormatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func statusColor(_ status: ImportStatus) -> Color {
        switch status {
        case .imported: return FTColor.income
        case .failed:   return FTColor.expense
        case .review:   return FTColor.gold
        case .parsing:  return FTColor.catBlue
        case .pending:  return FTColor.textMuted
        }
    }
}
