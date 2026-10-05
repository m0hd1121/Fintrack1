import SwiftUI

/// Wraps a screen in its own `NavigationStack` only when it is presented
/// modally (sheet / sidebar tab). A screen pushed onto an existing stack must
/// not create a second one — nested stacks duplicate navigation bars and break
/// Back. Screens that can be both presented and pushed take an
/// `embedInNavigationStack` flag and route their root through this.
struct OptionalNavigationStack<Content: View>: View {
    let embed: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        if embed {
            NavigationStack { content() }
        } else {
            content()
        }
    }
}

/// The screen behind each `DisableableFeature`. One switch for every entry
/// point (Planning Tools, Settings), so a re-enabled feature appears in the
/// right place without another copy of this mapping.
struct FeatureDestinationView: View {
    let feature: DisableableFeature

    var body: some View {
        switch feature {
        case .aiCFOMode:            AICFOModeView()
        case .retirementSimulation: RetirementSimulationView()
        case .lifeEventPlanning:    LifeEventPlanningView()
        case .estatePlanning:       EstatePlanningView()
        case .insuranceOptimizer:   InsuranceOptimizerView()
        case .smartCashAllocation:  SmartCashAllocationView()
        case .collaborativePlanner: CollaborativePlannerView()
        case .financialEducation:   FinancialEducationView()
        case .remittanceTracker:    RemittanceTrackerView()
        case .taxManagement:        TaxManagementView()
        case .businessFreelancer:   BusinessFreelancerView()
        case .auditLog:             AuditLogView()
        case .googleDriveBackup:    GoogleDriveBackupView()
        case .pdfStatementImport:   PDFImportView()
        case .twoFactorAuth:        TwoFactorSetupView()
        }
    }
}

/// Plan → Planning Tools: the longer-term planning modules that used to sit in
/// Settings ("Premium Features", Tax, Business). Only enabled features are
/// listed; a feature switched back on in `DisableableFeature` shows up here.
struct PlanningToolsView: View {
    private var tools: [DisableableFeature] {
        DisableableFeature.allCases.filter {
            ($0.category == .premium || $0.category == .topLevelSection) && $0.isEnabled
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(tools.enumerated()), id: \.element.id) { index, feature in
                    NavigationLink {
                        FeatureDestinationView(feature: feature)
                    } label: {
                        HubRow(symbol: feature.symbol, tint: feature.tint, title: feature.title)
                    }
                    .buttonStyle(.plain)
                    if index < tools.count - 1 { Divider().opacity(0.4) }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .background { FTBackdrop() }
        .navigationTitle("Planning Tools")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if tools.isEmpty {
                EmptyStateView(icon: "compass.drawing", title: "No Planning Tools",
                               message: "Planning tools appear here when they're available.")
            }
        }
    }
}

/// A navigation row used by the Plan, Settings-style hubs: icon tile, title,
/// optional one-line summary and a chevron. Reads as one VoiceOver element.
struct HubRow: View {
    let symbol: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    var value: String? = nil

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: symbol, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
            Spacer(minLength: FTSpacing.sm)
            if let value {
                Text(value).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            }
            Image(systemName: "chevron.forward")
                .font(.ftCaption.weight(.semibold))
                .foregroundStyle(FTColor.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 13)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Section of hub rows with a small uppercase header, matching Settings.
struct HubSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            if let title {
                Text(title.uppercased())
                    .font(.ftLabel).tracking(1.4).fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(FTColor.textSecondary)
                    .padding(.leading, FTSpacing.xs)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content() }
                .padding(.horizontal, FTSpacing.lg)
                .ftGlass(FTRadius.md)
        }
    }
}
