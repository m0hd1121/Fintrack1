import SwiftUI
import SwiftData

// MARK: - Contribute / Withdraw Sheet

struct ContributeToGoalView: View {
    @Bindable var goal: SavingsGoal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var amount = ""
    @State private var isWithdrawal = false
    @State private var selectedAccountId: UUID? = nil
    @State private var notes = ""
    @State private var showingConfirmation = false

    private var baseCurrency: String { appState.baseCurrency }
    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }

    private var parsedAmount: Double { Double(amount) ?? 0 }
    private var newBalance: Double {
        isWithdrawal ? max(0, goal.currentAmount - parsedAmount) : goal.currentAmount + parsedAmount
    }
    private var newProgress: Double { min(newBalance / max(goal.targetAmount, 1), 1.0) }
    private var wouldComplete: Bool { !goal.isCompleted && newBalance >= goal.targetAmount }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Hero
                        goalHeroCard

                        // Action type
                        VStack(spacing: 0) {
                            Picker("", selection: $isWithdrawal) {
                                Text("Add Funds").tag(false)
                                Text("Withdraw").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Amount + account
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Amount").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Text(goal.currency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 140)
                            }.padding(.vertical, 13)

                            if !activeAccounts.isEmpty {
                                Divider().opacity(0.4)
                                HStack(spacing: FTSpacing.md) {
                                    Text(isWithdrawal ? "To Account" : "From Account")
                                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    Spacer()
                                    Picker("", selection: Binding<UUID?>(
                                        get: { selectedAccountId ?? goal.linkedAccountId },
                                        set: { selectedAccountId = $0 }
                                    )) {
                                        Text("None").tag(Optional<UUID>(nil))
                                        ForEach(activeAccounts) { acc in
                                            Text(acc.name).tag(Optional(acc.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .accentColor(FTColor.accent)
                                }.padding(.vertical, 13)
                            }

                            Divider().opacity(0.4)
                            HStack(spacing: FTSpacing.md) {
                                Text("Notes").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("Optional", text: $notes)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }.padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Preview
                        if parsedAmount > 0 {
                            previewCard
                        }

                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                let label = isWithdrawal ? "Withdraw Funds" : (wouldComplete ? "Complete Goal!" : "Add to Goal")
                Button { applyContribution() } label: { Text(label) }
                    .buttonStyle(.ftPrimary)
                    .disabled(parsedAmount <= 0 || (isWithdrawal && parsedAmount > goal.currentAmount))
                    .opacity(parsedAmount <= 0 ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle(isWithdrawal ? "Withdraw Funds" : "Add Funds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .dismissKeyboardOnTap()
        }
        .onAppear { selectedAccountId = goal.linkedAccountId }
    }

    // MARK: - Goal Hero Card

    private var goalHeroCard: some View {
        let tint = Color.fromString(goal.effectiveColor)
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: goal.effectiveIcon, tint: tint, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.name).font(.ftHeadline).foregroundStyle(.white)
                    Text("\(Int(goal.progress * 100))% funded")
                        .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(goal.currentAmount.formatted(as: goal.currency))
                        .font(.ftBodySemibold).foregroundStyle(.white)
                    Text("of \(goal.targetAmount.asCompact(currency: goal.currency))")
                        .font(.ftCaption).foregroundStyle(.white.opacity(0.75))
                }
            }
            FTProgressBar(value: goal.progress, color: .white.opacity(0.9))
            HStack {
                Text(goal.remaining.formatted(as: goal.currency) + " remaining")
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                Spacer()
                if let months = goal.monthsRemaining {
                    Text("\(months) months left")
                        .font(.ftCaption).foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(FTSpacing.xl)
        .background(
            LinearGradient(
                colors: [tint, tint.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: FTRadius.xl)
        )
    }

    // MARK: - Preview

    private var previewCard: some View {
        VStack(spacing: FTSpacing.md) {
            Text("AFTER THIS \(isWithdrawal ? "WITHDRAWAL" : "CONTRIBUTION")")
                .font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textSecondary)

            HStack(spacing: FTSpacing.xl) {
                VStack(spacing: 4) {
                    Text(newBalance.asCompact(currency: goal.currency))
                        .font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                    Text("New Balance").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                VStack(spacing: 4) {
                    Text("\(Int(newProgress * 100))%")
                        .font(.ftTitle).foregroundStyle(isWithdrawal ? FTColor.expense : FTColor.income)
                    Text("Progress").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                VStack(spacing: 4) {
                    Text(max(0, goal.targetAmount - newBalance).asCompact(currency: goal.currency))
                        .font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                    Text("Remaining").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }

            FTProgressBar(value: newProgress, color: isWithdrawal ? FTColor.expense : FTColor.income)

            if wouldComplete {
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "star.fill").foregroundStyle(FTColor.gold)
                    Text("Goal complete! Congratulations!")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.income)
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Apply

    private func applyContribution() {
        guard parsedAmount > 0 else { return }
        if isWithdrawal {
            goal.currentAmount = max(0, goal.currentAmount - parsedAmount)
        } else {
            goal.currentAmount += parsedAmount
        }
        goal.updatedAt = Date()
        if goal.currentAmount >= goal.targetAmount {
            goal.isCompleted = true
            NotificationService.shared.sendGoalCompletedAlert(goalName: goal.name, amount: goal.targetAmount, currency: goal.currency)
        }
        let milestones = SavingsGoalService.shared.checkMilestones(goal: goal, context: context)
        for milestone in milestones {
            NotificationService.shared.scheduleSavingsGoalMilestone(goal: goal, milestone: milestone)
        }
        try? context.save()
        dismiss()
    }
}
