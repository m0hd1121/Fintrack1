import SwiftUI
import SwiftData

struct AnomalyDetectionView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]

    @State private var anomalies: [SpendingAnomaly] = []
    @State private var selectedSeverity: SpendingAnomaly.AnomalySeverity? = nil
    @State private var isLoading = true

    private var filtered: [SpendingAnomaly] {
        guard let s = selectedSeverity else { return anomalies }
        return anomalies.filter { $0.severity == s }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if anomalies.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(spacing: FTSpacing.xxl) {
                            summaryCard
                            filterRow
                            anomalyList
                        }
                        .padding(.horizontal, FTSpacing.screen)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Anomaly Detection")
            .background { FTBackdrop() }
            .onAppear { detect() }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let high   = anomalies.filter { $0.severity == .high }.count
        let medium = anomalies.filter { $0.severity == .medium }.count
        let low    = anomalies.filter { $0.severity == .low }.count

        return HStack(spacing: 0) {
            summaryPill(count: high,   label: "High",   color: FTColor.expense)
            Divider().frame(height: 32)
            summaryPill(count: medium, label: "Medium", color: FTColor.gold)
            Divider().frame(height: 32)
            summaryPill(count: low,    label: "Low",    color: FTColor.income)
        }
        .ftGlass(FTRadius.lg)
    }

    private func summaryPill(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.ftHeadline)
                .foregroundStyle(color)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.lg)
    }

    // MARK: - Filters

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FilterChip(title: "All", isSelected: selectedSeverity == nil) { selectedSeverity = nil }
                FilterChip(title: "High", isSelected: selectedSeverity == .high) { selectedSeverity = .high }
                FilterChip(title: "Medium", isSelected: selectedSeverity == .medium) { selectedSeverity = .medium }
                FilterChip(title: "Low", isSelected: selectedSeverity == .low) { selectedSeverity = .low }
            }
        }
    }

    // MARK: - Anomaly List

    private var anomalyList: some View {
        VStack(spacing: FTSpacing.sm) {
            ForEach(filtered) { anomaly in
                anomalyCard(anomaly)
            }
        }
    }

    private func anomalyCard(_ anomaly: SpendingAnomaly) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    Circle()
                        .fill(anomaly.severity.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: anomaly.severity.icon)
                        .font(.ftHeadline)
                        .foregroundStyle(anomaly.severity.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(anomaly.title)
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                        Spacer()
                        severityBadge(anomaly.severity)
                    }
                    Text(anomaly.date.formatted)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }
            }

            Text(anomaly.description)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if let cat = anomaly.category {
                    Label(cat.rawValue, systemImage: cat.icon)
                        .font(.ftCaption)
                        .foregroundStyle(Color.fromString(cat.color))
                }
                Spacer()
                Text(anomaly.amount.formatted(as: appState.baseCurrency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(anomaly.severity.color)
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private func severityBadge(_ severity: SpendingAnomaly.AnomalySeverity) -> some View {
        let label: String
        switch severity { case .high: label = "HIGH"; case .medium: label = "MED"; case .low: label = "LOW" }
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(severity.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(severity.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: FTSpacing.lg) {
            ProgressView().scaleEffect(1.4)
            Text("Analyzing spending patterns…")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: FTSpacing.lg) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(FTColor.income)
            Text("No Anomalies Detected")
                .font(.ftHeadline)
                .foregroundStyle(FTColor.textPrimary)
            Text("Your spending patterns look normal this month. Keep it up!")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FTSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Compute

    private func detect() {
        anomalies = AIAnalyticsService.shared.detectAnomalies(
            transactions: transactions,
            currency: appState.baseCurrency
        )
        isLoading = false
    }
}
