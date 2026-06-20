import SwiftUI
import SwiftData

struct FTAVATReportView: View {
    @Environment(AppState.self) private var appState
    @Query private var taxRecords: [TaxRecord]

    let taxYear: Int

    @State private var selectedQuarter = 1

    private var report: FTAQuarterReport {
        TaxService.shared.ftaReport(records: taxRecords, year: taxYear, quarter: selectedQuarter)
    }

    private var summary: VATSummary {
        TaxService.shared.vatSummary(records: taxRecords, taxYear: taxYear)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                quarterSelector
                reportCard
                annualSummary
                ftaDeadlines
                ftaDisclaimer
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("FTA VAT Report \(taxYear)")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
    }

    // MARK: - Quarter Selector

    private var quarterSelector: some View {
        HStack(spacing: FTSpacing.sm) {
            ForEach(1...4, id: \.self) { q in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedQuarter = q }
                } label: {
                    Text("Q\(q)")
                        .font(.ftCallout)
                        .foregroundStyle(selectedQuarter == q ? .white : FTColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FTSpacing.md)
                        .background(selectedQuarter == q ? AnyShapeStyle(FTColor.accentGradient) : AnyShapeStyle(.ultraThinMaterial), in: .rect(cornerRadius: FTRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Report Card

    private var reportCard: some View {
        VStack(spacing: FTSpacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Q\(selectedQuarter) \(taxYear) VAT RETURN")
                        .font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(abs(report.netVAT).formatted(as: appState.baseCurrency))
                        .font(.ftAmount)
                        .foregroundStyle(report.isPayable ? FTColor.expense : FTColor.income)
                    Text(report.ftaNote)
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(report.isPayable ? FTColor.expense.opacity(0.1) : FTColor.income.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: report.isPayable ? "arrow.up.forward.circle.fill" : "arrow.down.backward.circle.fill")
                        .font(.ftTitle)
                        .foregroundStyle(report.isPayable ? FTColor.expense : FTColor.income)
                }
            }

            Divider().opacity(0.3)

            HStack {
                vatLine(label: "Standard-Rated Sales", amount: report.outputVAT / 0.05, vat: report.outputVAT, color: FTColor.income)
                Spacer()
                vatLine(label: "Standard-Rated Purchases", amount: report.inputVAT / 0.05, vat: report.inputVAT, color: FTColor.expense)
            }

            Divider().opacity(0.3)

            HStack {
                Text("Net VAT Position")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Text((report.netVAT >= 0 ? "+" : "") + report.netVAT.formatted(as: appState.baseCurrency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(report.isPayable ? FTColor.expense : FTColor.income)
            }

            HStack {
                Image(systemName: "calendar").foregroundStyle(FTColor.textMuted).font(.ftCaption)
                Text("Due: \(quarterDeadline(year: taxYear, quarter: selectedQuarter))")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func vatLine(label: String, amount: Double, vat: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            Text(amount.asCompact(currency: appState.baseCurrency))
                .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
            Text("VAT: \(vat.formatted(as: appState.baseCurrency))")
                .font(.ftCaption).foregroundStyle(color)
        }
    }

    // MARK: - Annual Summary

    private var annualSummary: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("ANNUAL SUMMARY \(taxYear)").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            HStack(spacing: FTSpacing.sm) {
                annualStat(label: "Total Output", value: summary.totalVATCollected, color: FTColor.income)
                annualStat(label: "Total Input", value: summary.totalVATPaid, color: FTColor.expense)
                annualStat(label: "Reclaimable", value: summary.totalReclaimable, color: FTColor.catBlue)
                annualStat(label: "Net", value: summary.netVATPosition, color: summary.netVATPosition >= 0 ? FTColor.expense : FTColor.income)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func annualStat(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value.asCompact(currency: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - FTA Deadlines

    private var ftaDeadlines: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("FTA FILING DEADLINES \(taxYear)").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ForEach(1...4, id: \.self) { q in
                    let dl = quarterDeadline(year: taxYear, quarter: q)
                    let isPast = isDeadlinePast(year: taxYear, quarter: q)
                    HStack {
                        Image(systemName: isPast ? "checkmark.circle.fill" : "calendar.circle")
                            .foregroundStyle(isPast ? FTColor.income : FTColor.textMuted).font(.ftCallout)
                        Text("Q\(q) \(taxYear) Return").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Spacer()
                        Text(dl).font(.ftCallout).foregroundStyle(isPast ? FTColor.income : FTColor.gold)
                    }
                    .padding()
                    .background((isPast ? FTColor.income : FTColor.gold).opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Disclaimer

    private var ftaDisclaimer: some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(FTColor.gold).font(.ftCaption)
            Text("This report is for reference only. Official VAT returns must be filed through the FTA's EmaraTax portal. Consult a UAE-registered tax agent for compliance advice.")
                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
    }

    // MARK: - Helpers

    private func quarterDeadline(year: Int, quarter: Int) -> String {
        // UAE FTA: VAT return due 28 days after quarter end
        let endMonths = [3, 6, 9, 12]
        let endMonth = endMonths[quarter - 1]
        var comps = DateComponents()
        comps.year = year; comps.month = endMonth
        comps.day = Calendar.current.range(of: .day, in: .month, for: Calendar.current.date(from: comps) ?? Date())?.count ?? 28
        let quarterEnd = Calendar.current.date(from: comps) ?? Date()
        let deadline = Calendar.current.date(byAdding: .day, value: 28, to: quarterEnd) ?? quarterEnd
        let fmt = DateFormatter(); fmt.dateFormat = "d MMM yyyy"
        return fmt.string(from: deadline)
    }

    private func isDeadlinePast(year: Int, quarter: Int) -> Bool {
        let endMonths = [3, 6, 9, 12]
        let endMonth = endMonths[quarter - 1]
        var comps = DateComponents(); comps.year = year; comps.month = endMonth; comps.day = 28
        let approxDeadline = Calendar.current.date(from: comps) ?? Date()
        return Date() > approxDeadline
    }
}
