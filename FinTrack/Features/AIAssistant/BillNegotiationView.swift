import SwiftUI
import SwiftData

struct BillNegotiationView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]

    @State private var tips: [BillNegotiationTip] = []
    @State private var selectedTip: BillNegotiationTip? = nil
    @State private var showScript = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    if tips.isEmpty {
                        emptyState
                    } else {
                        potentialSavingsCard
                        tipsGrid
                        negotiationGuide
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.bottom, 32)
            }
            .navigationTitle("Bill Negotiation")
            .background { FTBackdrop() }
            .onAppear { generate() }
            .sheet(item: $selectedTip) { tip in
                scriptSheet(tip)
            }
        }
    }

    // MARK: - Potential Savings Card

    private var potentialSavingsCard: some View {
        let total = tips.reduce(0.0) { $0 + $1.potentialSaving }
        return VStack(spacing: FTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEGOTIATION POTENTIAL")
                        .font(.ftLabel)
                        .tracking(1.6)
                        .foregroundStyle(FTColor.textMuted)
                    Text(total.formatted(as: appState.baseCurrency) + "/mo")
                        .font(.ftAmount)
                        .foregroundStyle(FTColor.income)
                    Text(String(format: "Up to %.0f savings per year", total * 12))
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Image(systemName: "phone.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(FTColor.income.opacity(0.8))
            }
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                Text("Estimates based on typical 10-25% savings from negotiation. Your results may vary.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .background(FTColor.income.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: FTRadius.xl).stroke(FTColor.income.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Tips Grid

    private var tipsGrid: some View {
        VStack(spacing: FTSpacing.md) {
            ForEach(tips) { tip in
                tipCard(tip)
            }
        }
    }

    private func tipCard(_ tip: BillNegotiationTip) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FTRadius.sm)
                        .fill(FTColor.accent.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: tip.icon)
                        .font(.ftHeadline)
                        .foregroundStyle(FTColor.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(tip.title)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text(tip.merchantName)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Save up to")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                    Text(tip.potentialSaving.formatted(as: appState.baseCurrency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.income)
                }
            }

            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                Text("NEGOTIATION TIPS")
                    .font(.ftLabel)
                    .tracking(1.4)
                    .foregroundStyle(FTColor.textMuted)
                ForEach(Array(tip.tips.enumerated()), id: \.offset) { i, t in
                    HStack(alignment: .top, spacing: FTSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.income)
                            .frame(width: 18)
                        Text(t)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button {
                selectedTip = tip
                showScript = true
            } label: {
                HStack {
                    Image(systemName: "text.quote")
                    Text("View Call Script")
                }
                .font(.ftCallout)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FTSpacing.md)
                .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Script Sheet

    private func scriptSheet(_ tip: BillNegotiationTip) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FTSpacing.xxl) {
                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("CALL SCRIPT")
                            .font(.ftLabel)
                            .tracking(1.6)
                            .foregroundStyle(FTColor.textMuted)
                        Text("Read this script when calling \(tip.merchantName):")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)

                        Text(tip.script)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textPrimary)
                            .padding()
                            .background(FTColor.accent.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                    }

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("BEFORE YOU CALL")
                            .font(.ftLabel)
                            .tracking(1.6)
                            .foregroundStyle(FTColor.textMuted)
                        VStack(spacing: FTSpacing.sm) {
                            checkItem("Have your account number or customer ID ready")
                            checkItem("Know how long you've been a customer")
                            checkItem("Have at least one competitor quote in mind")
                            checkItem("Be polite but willing to escalate")
                            checkItem("Take notes and confirm any deal via email")
                        }
                    }

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("POTENTIAL SAVING")
                            .font(.ftLabel)
                            .tracking(1.6)
                            .foregroundStyle(FTColor.textMuted)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Monthly saving")
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textMuted)
                                Text(tip.potentialSaving.formatted(as: appState.baseCurrency))
                                    .font(.ftHeadline)
                                    .foregroundStyle(FTColor.income)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Annual saving")
                                    .font(.ftCaption)
                                    .foregroundStyle(FTColor.textMuted)
                                Text((tip.potentialSaving * 12).formatted(as: appState.baseCurrency))
                                    .font(.ftHeadline)
                                    .foregroundStyle(FTColor.income)
                            }
                        }
                        .padding()
                        .background(FTColor.income.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                    }
                }
                .padding()
            }
            .navigationTitle(tip.title)
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedTip = nil }
                }
            }
        }
    }

    private func checkItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Image(systemName: "checkmark.square.fill")
                .foregroundStyle(FTColor.accent)
                .font(.ftCallout)
            Text(text)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Negotiation Guide

    private var negotiationGuide: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("NEGOTIATION PRINCIPLES")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                ForEach(principles, id: \.title) { p in
                    HStack(alignment: .top, spacing: FTSpacing.md) {
                        Image(systemName: p.icon)
                            .foregroundStyle(FTColor.catBlue)
                            .font(.ftCallout)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title)
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                            Text(p.detail)
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .ftGlass(FTRadius.md)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            Image(systemName: "phone.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(FTColor.textMuted)
            Text("No Bills to Negotiate")
                .font(.ftHeadline)
                .foregroundStyle(FTColor.textPrimary)
            Text("Add recurring bills and transactions to get personalized negotiation tips.")
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FTSpacing.xxl)
        }
        .padding(.top, 60)
    }

    // MARK: - Generate

    private func generate() {
        tips = AIAnalyticsService.shared.generateBillNegotiationTips(
            transactions: transactions, bills: bills, currency: appState.baseCurrency
        )
    }

    private let principles: [(title: String, detail: String, icon: String)] = [
        ("Research First", "Know competitor prices before you call — it's your strongest card.", "magnifyingglass"),
        ("Be Loyal & Firm", "Mention tenure as a customer, then state you're considering alternatives.", "person.badge.clock.fill"),
        ("Ask for Retention", "Specifically ask to speak with the 'retention department' — they have better offers.", "phone.fill"),
        ("Get It in Writing", "Any deal offered verbally should be confirmed via email before hanging up.", "envelope.fill"),
        ("Best Time to Call", "Month-end and mid-week — agents are more flexible when meeting monthly targets.", "clock.fill"),
    ]
}
