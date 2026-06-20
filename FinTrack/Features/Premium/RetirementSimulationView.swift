import SwiftUI
import SwiftData

struct RetirementSimulationView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var plans: [RetirementPlan]

    @State private var showingEdit = false

    private var plan: RetirementPlan? { plans.first }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                if let plan {
                    readinessCard(plan)
                    projectionCard(plan)
                    gratuityCard(plan)
                    milestoneCard(plan)
                    assumptionsCard(plan)
                } else {
                    EmptyStateView(
                        icon: "sun.max.fill",
                        title: "Plan Your Retirement",
                        message: "Enter your details to see your UAE retirement projection with gratuity, savings, and investment growth.",
                        actionTitle: "Get Started"
                    ) { createPlan() }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Retirement Simulation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if plan != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showingEdit = true }
                        .foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let plan { RetirementEditView(plan: plan) }
        }
    }

    // MARK: – Cards

    private func readinessCard(_ plan: RetirementPlan) -> some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Retirement Readiness")
                        .font(.ftHeadline)
                        .foregroundStyle(FTColor.textPrimary)
                    Text("\(plan.yearsToRetirement) years until retirement at \(plan.targetRetirementAge)")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                readinessRing(plan.readinessScore)
            }

            FTProgressBar(
                value: plan.readinessScore,
                color: readinessColor(plan.readinessScore),
                height: 10
            )

            HStack(spacing: 0) {
                statPill("Projected", plan.projectedFutureValue.asCompact(currency: plan.currency), FTColor.income)
                Spacer()
                statPill("Required", plan.requiredNestEgg.asCompact(currency: plan.currency), FTColor.accent)
                Spacer()
                statPill("Gap", abs(plan.requiredNestEgg - plan.projectedFutureValue).asCompact(currency: plan.currency),
                         plan.projectedFutureValue >= plan.requiredNestEgg ? FTColor.income : FTColor.expense)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    @ViewBuilder
    private func readinessRing(_ score: Double) -> some View {
        ZStack {
            Circle()
                .stroke(FTColor.bgElevated, lineWidth: 6)
                .frame(width: 64, height: 64)
            Circle()
                .trim(from: 0, to: score)
                .stroke(readinessColor(score), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(-90))
            Text("\(Int(score * 100))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(FTColor.textPrimary)
        }
    }

    private func projectionCard(_ plan: RetirementPlan) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Growth Projection").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            let rows: [(String, String, Color)] = [
                ("Current Savings", plan.currentSavings.formatted(as: plan.currency), FTColor.accent),
                ("Monthly Contribution", plan.monthlyContribution.formatted(as: plan.currency), FTColor.catBlue),
                ("Expected Return", "\(String(format: "%.1f", plan.expectedReturnRate))% p.a.", FTColor.income),
                ("Inflation Rate", "\(String(format: "%.1f", plan.expectedInflationRate))% p.a.", FTColor.gold),
                ("UAE Gratuity", plan.projectedGratuity.formatted(as: plan.currency), FTColor.catPurple),
                ("Projected Total", plan.projectedFutureValue.formatted(as: plan.currency), FTColor.income),
            ]

            ForEach(rows, id: \.0) { label, value, color in
                HStack {
                    Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(value).font(.ftBodySemibold).foregroundStyle(color)
                }
                if label != rows.last?.0 { Divider().opacity(0.4) }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private func gratuityCard(_ plan: RetirementPlan) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                FTIconTile(symbol: "building.columns.fill", tint: FTColor.catPurple, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("UAE End-of-Service Gratuity").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text("\(plan.yearsOfServiceUAE) years of service").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Text(plan.projectedGratuity.formatted(as: plan.currency))
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.catPurple)
            }

            Text("Based on 21 days/year for first 5 years, 30 days/year thereafter, using your basic salary.")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private func milestoneCard(_ plan: RetirementPlan) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Retirement Income").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            let inflationAdjusted = plan.inflationAdjustedIncome
            let safeWithdrawal = plan.projectedFutureValue * 0.04 / 12

            HStack {
                milestoneCell("Target Income Today", plan.targetMonthlyIncome.formatted(as: plan.currency), FTColor.accent)
                Divider().frame(height: 50)
                milestoneCell("Inflation-Adjusted", inflationAdjusted.formatted(as: plan.currency), FTColor.gold)
                Divider().frame(height: 50)
                milestoneCell("Safe Withdrawal (4%)", safeWithdrawal.formatted(as: plan.currency),
                              safeWithdrawal >= inflationAdjusted ? FTColor.income : FTColor.expense)
            }

            if safeWithdrawal < plan.targetMonthlyIncome {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(FTColor.gold)
                    Text("Increase monthly contribution by \(((plan.requiredNestEgg - plan.projectedFutureValue) * 0.04 / 12 / max(1, Double(plan.yearsToRetirement) * 12)).formatted(as: plan.currency))/month to close the gap.")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                .padding(FTSpacing.sm)
                .background(FTColor.gold.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private func assumptionsCard(_ plan: RetirementPlan) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("Assumptions").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("• 25 years in retirement (4% safe withdrawal rate)\n• UAE gratuity paid as lump sum at retirement\n• Monthly contributions continue until retirement age\n• Returns compound monthly\n• All amounts in \(plan.currency)")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
                .lineSpacing(4)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.sm)
    }

    // MARK: – Helpers

    private func statPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
    }

    private func milestoneCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.ftBodySemibold).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func readinessColor(_ score: Double) -> Color {
        score < 0.5 ? FTColor.expense : score < 0.8 ? FTColor.gold : FTColor.income
    }

    private func createPlan() {
        let p = RetirementPlan()
        context.insert(p)
        try? context.save()
        showingEdit = true
    }
}

// MARK: – Edit Sheet

struct RetirementEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var plan: RetirementPlan

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal") {
                    Stepper("Current Age: \(plan.currentAge)", value: $plan.currentAge, in: 18...80)
                    Stepper("Retirement Age: \(plan.targetRetirementAge)", value: $plan.targetRetirementAge, in: plan.currentAge + 1...80)
                    Stepper("UAE Service Years: \(plan.yearsOfServiceUAE)", value: $plan.yearsOfServiceUAE, in: 0...50)
                }
                Section("Savings") {
                    HStack {
                        Text("Current Savings")
                        Spacer()
                        TextField("0", value: $plan.currentSavings, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Monthly Contribution")
                        Spacer()
                        TextField("0", value: $plan.monthlyContribution, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Basic Monthly Salary")
                        Spacer()
                        TextField("0", value: $plan.monthlyBasicSalary, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("Target") {
                    HStack {
                        Text("Monthly Income in Retirement")
                        Spacer()
                        TextField("0", value: $plan.targetMonthlyIncome, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("Assumptions") {
                    HStack {
                        Text("Expected Return (%)")
                        Spacer()
                        TextField("7.0", value: $plan.expectedReturnRate, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Inflation Rate (%)")
                        Spacer()
                        TextField("3.0", value: $plan.expectedInflationRate, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Retirement Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        plan.lastUpdated = Date()
                        try? context.save()
                        dismiss()
                    }
                    .foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
            }
        }
    }
}
