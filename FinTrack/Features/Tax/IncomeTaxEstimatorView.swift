import SwiftUI
import SwiftData
import Charts

struct IncomeTaxEstimatorView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var taxConfigs: [TaxConfiguration]
    @Query private var transactions: [Transaction]

    @State private var selectedCountryCode = "AE"
    @State private var manualAnnualIncome = ""
    @State private var useTransactionIncome = true

    private var config: TaxConfiguration? { taxConfigs.first { $0.countryCode == selectedCountryCode } }

    private var annualIncome: Double {
        if useTransactionIncome {
            let year = Calendar.current.component(.year, from: Date())
            let cal = Calendar.current
            let yearIncome = transactions.filter {
                cal.component(.year, from: $0.date) == year && $0.type == .income
            }.reduce(0) { $0 + $1.amountInBaseCurrency }
            // Annualise based on months elapsed
            let month = cal.component(.month, from: Date())
            return month > 0 ? yearIncome / Double(month) * 12 : yearIncome
        }
        return Double(manualAnnualIncome.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var estimate: IncomeTaxEstimate {
        TaxService.shared.estimateIncomeTax(annualIncome: annualIncome, configuration: config)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                countrySelector
                incomeSection
                estimateResults
                bracketBreakdown
                incomeTaxFootnote
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Income Tax Estimator")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .onAppear { ensureConfig() }
    }

    // MARK: - Country Selector

    private var countrySelector: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("COUNTRY / REGION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    ForEach(TaxConfiguration.supported, id: \.code) { c in
                        Button {
                            withAnimation { selectedCountryCode = c.code }
                            ensureConfig()
                        } label: {
                            VStack(spacing: 4) {
                                Text(flag(for: c.code)).font(.system(size: 24))
                                Text(c.name)
                                    .font(.ftCaption)
                                    .foregroundStyle(selectedCountryCode == c.code ? .white : FTColor.textSecondary)
                            }
                            .padding(.horizontal, FTSpacing.lg)
                            .padding(.vertical, FTSpacing.md)
                            .background(
                                selectedCountryCode == c.code ? AnyShapeStyle(FTColor.accentGradient) : AnyShapeStyle(.ultraThinMaterial),
                                in: RoundedRectangle(cornerRadius: FTRadius.md)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Income Section

    private var incomeSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("ANNUAL INCOME").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                Toggle(isOn: $useTransactionIncome) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use transaction history").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Text("Annualised from current year income")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }
                .tint(FTColor.accent)
                .padding()
                .ftGlass(FTRadius.lg)

                if !useTransactionIncome {
                    HStack {
                        Text(config?.currency ?? appState.baseCurrency)
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        TextField("Annual income", text: $manualAnnualIncome)
                            .keyboardType(.decimalPad)
                            .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    }
                    .padding()
                    .ftGlass(FTRadius.lg)
                } else {
                    HStack {
                        Image(systemName: "chart.bar.fill").foregroundStyle(FTColor.income)
                        Text("Estimated: \(annualIncome.formatted(as: appState.baseCurrency))")
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Spacer()
                        Text("YTD × 12").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    .padding()
                    .background(FTColor.income.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg))
                }
            }
        }
    }

    // MARK: - Estimate Results

    private var estimateResults: some View {
        VStack(spacing: FTSpacing.md) {
            if !estimate.isSubjectToTax {
                noTaxCard
            } else {
                taxResultCard
            }
        }
    }

    private var noTaxCard: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(FTColor.income.opacity(0.12)).frame(width: 56, height: 56)
                Image(systemName: "checkmark.seal.fill").font(.ftTitle).foregroundStyle(FTColor.income)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("No Income Tax").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("\(estimate.countryName) does not levy personal income tax.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if selectedCountryCode == "AE" {
                    Text("Focus on UAE VAT (5%) for business transactions.")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .padding()
        .background(FTColor.income.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: FTRadius.xl).stroke(FTColor.income.opacity(0.2), lineWidth: 1))
    }

    private var taxResultCard: some View {
        VStack(spacing: FTSpacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTIMATED ANNUAL TAX").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(estimate.estimatedTax.formatted(as: config?.currency ?? appState.baseCurrency))
                        .font(.ftAmount).foregroundStyle(FTColor.expense)
                    Text("Effective rate: \(estimate.effectiveRate.asPercentage(decimals: 1))")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Monthly Provision").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    Text(estimate.monthlyProvision.formatted(as: config?.currency ?? appState.baseCurrency))
                        .font(.ftBodySemibold).foregroundStyle(FTColor.catBlue)
                }
            }

            HStack(spacing: FTSpacing.sm) {
                statItem(label: "Gross Income", value: estimate.annualIncome.asCompact(currency: config?.currency ?? appState.baseCurrency), color: FTColor.income)
                statItem(label: "Tax-Free", value: estimate.personalAllowance.asCompact(currency: config?.currency ?? appState.baseCurrency), color: FTColor.textMuted)
                statItem(label: "Taxable", value: estimate.taxableIncome.asCompact(currency: config?.currency ?? appState.baseCurrency), color: FTColor.gold)
                statItem(label: "Tax Due", value: estimate.estimatedTax.asCompact(currency: config?.currency ?? appState.baseCurrency), color: FTColor.expense)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bracket Breakdown

    @ViewBuilder
    private var bracketBreakdown: some View {
        if estimate.isSubjectToTax && !estimate.bracketBreakdown.isEmpty {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("TAX BRACKET BREAKDOWN").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                VStack(spacing: FTSpacing.sm) {
                    ForEach(estimate.bracketBreakdown) { b in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.label).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                Text("Rate: \(b.rate.asPercentage(decimals: 0))")
                                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(b.taxAmount.formatted(as: config?.currency ?? appState.baseCurrency))
                                    .font(.ftCallout).foregroundStyle(FTColor.expense)
                                Text("on \(b.taxableAmount.asCompact(currency: config?.currency ?? appState.baseCurrency))")
                                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            }
                        }
                        .padding()
                        .background(FTColor.expense.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                    }
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    // MARK: - Footnote

    private var incomeTaxFootnote: some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FTColor.gold).font(.ftCaption)
            Text("This is an estimate only, based on simplified tax rules. Consult a qualified tax advisor for your actual liability. Does not account for deductions, credits, or circumstances specific to your situation.")
                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private func flag(for code: String) -> String {
        let base: UInt32 = 127_397
        return code.unicodeScalars.compactMap { Unicode.Scalar(base + $0.value) }.map { String($0) }.joined()
    }

    private func ensureConfig() {
        guard !taxConfigs.contains(where: { $0.countryCode == selectedCountryCode }) else { return }
        let cfg = TaxConfiguration(countryCode: selectedCountryCode)
        context.insert(cfg)
        try? context.save()
    }
}
