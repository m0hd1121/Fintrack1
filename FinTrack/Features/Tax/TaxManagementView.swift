import SwiftUI
import SwiftData

struct TaxManagementView: View {
    @Environment(AppState.self) private var appState
    @Query private var taxRecords: [TaxRecord]
    @Query private var taxDocuments: [TaxDocument]
    @Query private var zakatRecords: [ZakatRecord]
    @Query private var transactions: [Transaction]
    @Query private var taxConfigs: [TaxConfiguration]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var vatSummary: VATSummary {
        TaxService.shared.vatSummary(records: taxRecords, taxYear: selectedYear)
    }

    private var deductibles: DeductiblesSummary {
        TaxService.shared.deductiblesSummary(transactions: transactions, taxYear: selectedYear)
    }

    private var currentZakat: ZakatRecord? {
        zakatRecords.first { $0.taxYear == selectedYear }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    yearPicker
                    summaryStrip
                    featuresGrid
                    quickInsights
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .navigationTitle("Tax Management")
            .background { FTBackdrop() }
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        let years = TaxService.shared.availableTaxYears(records: taxRecords, transactions: transactions)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(years, id: \.self) { y in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedYear = y }
                    } label: {
                        Text(String(y))
                            .font(.ftCallout)
                            .foregroundStyle(selectedYear == y ? .white : FTColor.textSecondary)
                            .padding(.horizontal, FTSpacing.lg)
                            .padding(.vertical, FTSpacing.sm)
                            .background(selectedYear == y ? FTColor.accentGradient : AnyShapeStyle(.ultraThinMaterial), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: FTSpacing.sm) {
            summaryTile(
                icon: "percent",
                color: FTColor.expense,
                label: "VAT Paid",
                value: vatSummary.totalVATPaid.asCompact(currency: appState.baseCurrency)
            )
            summaryTile(
                icon: "doc.text.fill",
                color: FTColor.income,
                label: "Deductible",
                value: deductibles.totalDeductible.asCompact(currency: appState.baseCurrency)
            )
            summaryTile(
                icon: "star.circle.fill",
                color: FTColor.gold,
                label: "Zakat Due",
                value: (currentZakat?.zakatDue ?? 0).asCompact(currency: appState.baseCurrency)
            )
        }
    }

    private func summaryTile(icon: String, color: Color, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.ftCallout).foregroundStyle(color)
            }
            Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Features Grid

    private var featuresGrid: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TAX TOOLS")
                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.md) {
                taxFeatureCard(
                    icon: "percent",
                    title: "UAE VAT Tracker",
                    subtitle: "Track input & output VAT",
                    color: FTColor.accent,
                    badge: taxRecords.filter { $0.taxYear == selectedYear }.count,
                    destination: AnyView(VATTrackerView(taxYear: selectedYear))
                )
                taxFeatureCard(
                    icon: "doc.text.magnifyingglass",
                    title: "Income Tax",
                    subtitle: "Annual tax estimation",
                    color: FTColor.catBlue,
                    badge: nil,
                    destination: AnyView(IncomeTaxEstimatorView())
                )
                taxFeatureCard(
                    icon: "moon.stars.fill",
                    title: "Zakat Calculator",
                    subtitle: "Annual zakat obligations",
                    color: FTColor.gold,
                    badge: currentZakat?.isPaid == false && (currentZakat?.zakatDue ?? 0) > 0 ? 1 : nil,
                    destination: AnyView(ZakatCalculatorView(taxYear: selectedYear))
                )
                taxFeatureCard(
                    icon: "archivebox.fill",
                    title: "Document Vault",
                    subtitle: "Secure document storage",
                    color: FTColor.catTeal,
                    badge: taxDocuments.filter { $0.taxYear == selectedYear && !$0.isArchived }.count,
                    destination: AnyView(TaxDocumentVaultView(taxYear: selectedYear))
                )
                taxFeatureCard(
                    icon: "tag.fill",
                    title: "Transaction Tags",
                    subtitle: "Tag deductibles & VAT",
                    color: FTColor.catPurple,
                    badge: deductibles.transactionCount,
                    destination: AnyView(TaxTransactionTagView(taxYear: selectedYear))
                )
                taxFeatureCard(
                    icon: "doc.badge.clock.fill",
                    title: "FTA Report",
                    subtitle: "Quarterly VAT filing",
                    color: FTColor.catCoral,
                    badge: nil,
                    destination: AnyView(FTAVATReportView(taxYear: selectedYear))
                )
            }
        }
    }

    private func taxFeatureCard(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        badge: Int?,
        destination: AnyView
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: FTRadius.sm)
                            .fill(color.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: icon).font(.ftCallout).foregroundStyle(color)
                    }
                    Spacer()
                    if let b = badge, b > 0 {
                        Text("\(b)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(color).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                Text(title)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .ftGlassInteractive(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Insights

    private var quickInsights: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TAX INSIGHTS")
                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                insightRow(
                    icon: "info.circle.fill",
                    color: FTColor.accent,
                    text: "UAE has no personal income tax. Focus on UAE VAT (5%) tracking for business/freelance use."
                )

                if deductibles.transactionCount > 0 {
                    insightRow(
                        icon: "checkmark.circle.fill",
                        color: FTColor.income,
                        text: "\(deductibles.transactionCount) transactions tagged as tax-deductible totalling \(deductibles.totalDeductible.formatted(as: appState.baseCurrency))."
                    )
                }

                if vatSummary.netVATPosition > 0 {
                    insightRow(
                        icon: "exclamationmark.circle.fill",
                        color: FTColor.gold,
                        text: "Net VAT position: \(vatSummary.netVATPosition.formatted(as: appState.baseCurrency)) payable to FTA this year."
                    )
                } else if vatSummary.netVATPosition < 0 {
                    insightRow(
                        icon: "arrow.counterclockwise.circle.fill",
                        color: FTColor.income,
                        text: "You may be entitled to a VAT refund of \((-vatSummary.netVATPosition).formatted(as: appState.baseCurrency)) from FTA."
                    )
                }

                if let zakat = currentZakat, !zakat.isPaid, zakat.zakatDue > 0 {
                    insightRow(
                        icon: "moon.stars.fill",
                        color: FTColor.gold,
                        text: "Zakat due for \(selectedYear): \(zakat.zakatDue.formatted(as: appState.baseCurrency)). Remaining: \(zakat.remainingZakat.formatted(as: appState.baseCurrency))."
                    )
                }
            }
        }
    }

    private func insightRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            Image(systemName: icon).foregroundStyle(color).font(.ftCallout)
            Text(text).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
    }
}
