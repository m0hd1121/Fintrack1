import SwiftUI
import SwiftData
import Charts

struct BudgetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \Budget.name) private var budgets: [Budget]
    @Query(sort: \SavingsGoal.name) private var savingsGoals: [SavingsGoal]
    @Query private var transactions: [Transaction]

    @State private var showingAddBudget = false
    @State private var showingAddGoal = false
    @State private var selectedMonth = Date()

    private var baseCurrency: String { appState.baseCurrency }

    /// Single O(n) pass over current-month expenses, keyed by category.
    private var spentByCategory: [TransactionCategory: Double] {
        var result: [TransactionCategory: Double] = [:]
        for tx in transactions where tx.type == .expense && tx.date.isSameMonth(as: selectedMonth) {
            result[tx.category, default: 0] += tx.amountInBaseCurrency
        }
        return result
    }

    private var budgetsWithSpending: [(Budget, Double)] {
        let spentByCategory = self.spentByCategory
        return budgets.filter { $0.isActive }.map { budget in
            (budget, spentByCategory[budget.category] ?? 0)
        }
    }

    private var totalBudgeted: Double {
        budgets.filter { $0.isActive }.reduce(0) { $0 + $1.amount }
    }

    private var totalSpent: Double {
        budgetsWithSpending.reduce(0) { $0 + $1.1 }
    }

    var body: some View {
        NavigationStack {
            List {
                // Overview card
                overviewCard
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                // Budgets
                Section("Monthly Budgets") {
                    if budgets.isEmpty {
                        EmptyStateView(
                            icon: "chart.pie",
                            title: "No Budgets",
                            message: "Create budgets to track your spending by category.",
                            actionTitle: "Add Budget"
                        ) {
                            showingAddBudget = true
                        }
                    } else {
                        ForEach(budgetsWithSpending, id: \.0.id) { (budget, spent) in
                            BudgetProgressRow(budget: budget, spent: spent, currency: baseCurrency)
                                .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .leading) {
                                    NavigationLink(destination: AddBudgetView(editingBudget: budget)) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(FTColor.accent)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        context.delete(budget)
                                        try? context.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                // Add Budget CTA
                Section {
                    Button {
                        showingAddBudget = true
                    } label: {
                        Label("Add Budget", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                }

                // Savings Goals
                Section("Savings Goals") {
                    if savingsGoals.isEmpty {
                        EmptyStateView(
                            icon: "star.fill",
                            title: "No Goals",
                            message: "Set savings goals to work towards what matters.",
                            actionTitle: "Add Goal"
                        ) {
                            showingAddGoal = true
                        }
                    } else {
                        ForEach(savingsGoals) { goal in
                            SavingsGoalRow(goal: goal, currency: baseCurrency)
                                .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        context.delete(goal)
                                        try? context.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                // Add Goal CTA
                Section {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Label("Add Savings Goal", systemImage: "plus.circle.fill")
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FTSpacing.sm)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: FTRadius.md).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: FTRadius.md).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)).padding(.vertical, FTSpacing.xs))
                    .listRowSeparator(.hidden)
                }
            }
            .contentMargins(.bottom, 100, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Budget & Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showingAddBudget = true } label: { Label("Add Budget", systemImage: "chart.pie") }
                        Button { showingAddGoal = true } label: { Label("Add Goal", systemImage: "star") }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBudget) { AddBudgetView() }
            .sheet(isPresented: $showingAddGoal) { AddSavingsGoalView() }
        }
    }

    private var overviewCard: some View {
        let totalSpent = self.totalSpent
        let totalBudgeted = self.totalBudgeted
        let overviewProgress = min(totalSpent / max(totalBudgeted, 1), 1.0)
        return VStack(alignment: .leading, spacing: 14) {
            Text("SPENT THIS MONTH")
                .font(.ftLabel).tracking(1.6)
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(totalSpent.formatted(as: baseCurrency))
                    .font(.ftAmount).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text("/ \(totalBudgeted.formatted(as: baseCurrency))")
                    .font(.ftBodySemibold).foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }

            // White progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white)
                        .frame(width: max(8, geo.size.width * overviewProgress))
                }
            }
            .frame(height: 9)

            HStack {
                Text((totalBudgeted - totalSpent >= 0 ? "" : "-")
                     + abs(totalBudgeted - totalSpent).formatted(as: baseCurrency)
                     + (totalBudgeted - totalSpent >= 0 ? " remaining" : " over"))
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("\(Int(overviewProgress * 100))% used")
                    .font(.ftCaption).foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(FTSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FTColor.heroGradient, in: .rect(cornerRadius: FTRadius.xl))
        .padding(.horizontal, FTSpacing.screen)
        .padding(.top, FTSpacing.sm)
    }
}

struct BudgetProgressRow: View {
    let budget: Budget
    let spent: Double
    let currency: String
    @State private var showingAlert = false

    private var progress: Double { min(spent / max(budget.amount, 1), 1.0) }
    private var isOverBudget: Bool { spent > budget.amount }
    private var isNearLimit: Bool { progress >= budget.alertThreshold && !isOverBudget }

    private var tint: Color {
        isOverBudget ? FTColor.expense : isNearLimit ? FTColor.gold : Color.fromString(budget.category.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: FTSpacing.sm) {
                FTIconTile(symbol: budget.category.icon, tint: Color.fromString(budget.category.color), size: 36)
                Text(budget.name)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)

                Spacer()

                if isOverBudget {
                    BadgeView(text: "Over Budget", color: FTColor.expense)
                } else if isNearLimit {
                    BadgeView(text: "Near Limit", color: FTColor.gold)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text(spent.formatted(as: currency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(isOverBudget ? FTColor.expense : FTColor.textPrimary)
                    Text("of \(budget.amount.formatted(as: currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }

            FTProgressBar(value: progress, color: tint)
        }
        .padding(.vertical, 6)
    }
}

struct SavingsGoalRow: View {
    @Bindable var goal: SavingsGoal
    let currency: String
    @Environment(\.modelContext) private var context
    @State private var showingAddFunds = false
    @State private var addAmount = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: FTSpacing.sm) {
                FTIconTile(symbol: goal.icon, tint: Color.fromString(goal.color), size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if let targetDate = goal.targetDate {
                        Text("Target: \(targetDate.formatted)")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(goal.currentAmount.formatted(as: currency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(Color.fromString(goal.color))
                    Text("of \(goal.targetAmount.formatted(as: currency))")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }

            FTProgressBar(value: goal.progress, color: Color.fromString(goal.color))

            HStack {
                Text("\(Int(goal.progress * 100))% complete")
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Button("Add Funds") {
                    showingAddFunds = true
                }
                .font(.ftCallout)
                .foregroundStyle(FTColor.accent)
            }
        }
        .padding(.vertical, 6)
        .alert("Add Funds", isPresented: $showingAddFunds) {
            TextField("Amount", text: $addAmount)
                .keyboardType(.decimalPad)
            Button("Add") {
                if let amount = Double(addAmount) {
                    goal.currentAmount += amount
                    if goal.currentAmount >= goal.targetAmount { goal.isCompleted = true }
                    try? context.save()
                }
                addAmount = ""
            }
            Button("Cancel", role: .cancel) { addAmount = "" }
        } message: {
            Text("How much would you like to add to \(goal.name)?")
        }
    }
}

// MARK: – Add / Edit Budget (#17 #18)
struct AddBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    var editingBudget: Budget? = nil   // #17

    @State private var name = ""
    @State private var category: TransactionCategory = .food
    @State private var amount = ""
    @State private var period: BudgetPeriod = .monthly
    @State private var alertThreshold = 0.8
    @State private var hasExpiration = false          // #18
    @State private var expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    private var isEditing: Bool { editingBudget != nil }

    private let expenseCategories: [TransactionCategory] = [
        .food, .shopping, .transportation, .fuel, .utilities, .rent, .mortgage,
        .education, .medical, .entertainment, .travel, .insurance, .subscriptions,
        .gifts, .personalCare, .other
    ]

    var body: some View {
        let content = ZStack(alignment: .bottom) {
            FTBackdrop()

            ScrollView {
                VStack(spacing: FTSpacing.lg) {
                    // Budget Details
                    VStack(spacing: 0) {
                        HStack(spacing: FTSpacing.md) {
                            Text("Budget Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            TextField("e.g. Groceries", text: $name)
                                .multilineTextAlignment(.trailing)
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        }
                        .padding(.vertical, 13)

                        Divider().opacity(0.4)

                        Menu {
                            Picker("Category", selection: $category) {
                                ForEach(expenseCategories, id: \.self) { cat in
                                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                                }
                            }
                        } label: {
                            HStack(spacing: FTSpacing.md) {
                                Text("Category").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Label(category.rawValue, systemImage: category.icon)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                            }
                            .padding(.vertical, 13)
                        }

                        Divider().opacity(0.4)

                        Menu {
                            Picker("Period", selection: $period) {
                                ForEach(BudgetPeriod.allCases, id: \.self) { p in Text(p.rawValue).tag(p) }
                            }
                        } label: {
                            HStack(spacing: FTSpacing.md) {
                                Text("Period").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Text(period.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(FTColor.textMuted)
                            }
                            .padding(.vertical, 13)
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    // Amount Limit
                    VStack(spacing: 0) {
                        HStack(spacing: FTSpacing.md) {
                            Text("Amount Limit").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                .frame(maxWidth: 120)
                        }
                        .padding(.vertical, 13)
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    // Alert Threshold
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("Alert at \(Int(alertThreshold * 100))% of budget")
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Slider(value: $alertThreshold, in: 0.5...0.95, step: 0.05)
                            .tint(FTColor.gold)
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    // Expiration
                    VStack(spacing: 0) {
                        Toggle(isOn: $hasExpiration) {
                            Text("Set Expiration Date").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        }
                        .tint(FTColor.accent)
                        .padding(.vertical, 13)

                        if hasExpiration {
                            Divider().opacity(0.4)
                            HStack {
                                DatePicker("Expires On", selection: $expirationDate, in: Date()..., displayedComponents: .date)
                                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                    .tint(FTColor.accent)
                            }
                            .padding(.vertical, 9)
                        }
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    Text("Budget will deactivate automatically after this date. Useful for gym memberships, annual plans, etc.")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, FTSpacing.xs)

                    Color.clear.frame(height: 70)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.sm)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)

            Button { save() } label: {
                Text(isEditing ? "Update Budget" : "Add Budget")
            }
            .buttonStyle(.ftPrimary)
            .disabled(name.isEmpty || amount.isEmpty)
            .opacity(name.isEmpty || amount.isEmpty ? 0.55 : 1)
            .padding(.horizontal, FTSpacing.screen)
            .padding(.bottom, FTSpacing.sm)
        }
        .navigationTitle(isEditing ? "Edit Budget" : "Add Budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
        }
        .onAppear(perform: loadEditing)
        .dismissKeyboardOnTap()

        if isEditing {
            return AnyView(content)
        } else {
            return AnyView(NavigationStack { content })
        }
    }

    private func loadEditing() {
        guard let b = editingBudget else { return }
        name = b.name; category = b.category
        amount = String(b.amount); period = b.period
        alertThreshold = b.alertThreshold
        if let end = b.endDate { hasExpiration = true; expirationDate = end }
    }

    private func save() {
        if let b = editingBudget {
            b.name = name; b.category = b.category
            b.amount = Double(amount) ?? 0; b.period = period
            b.alertThreshold = alertThreshold
            b.endDate = hasExpiration ? expirationDate : nil
            b.color = category.color
        } else {
            let budget = Budget(
                name: name, category: category,
                amount: Double(amount) ?? 0, currency: appState.baseCurrency,
                period: period,
                endDate: hasExpiration ? expirationDate : nil,
                alertThreshold: alertThreshold,
                color: category.color
            )
            context.insert(budget)
        }
        try? context.save()
        dismiss()
    }
}

struct AddSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var name = ""
    @State private var targetAmount = ""
    @State private var currentAmount = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedIcon = "star"
    @State private var selectedColor = "blue"

    private let icons = ["star", "house", "car", "airplane", "graduationcap", "heart", "gift", "gamecontroller", "laptop", "bag"]
    private let colors = ["blue", "green", "purple", "orange", "red", "teal", "indigo", "pink"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        // Goal Details
                        VStack(spacing: 0) {
                            HStack(spacing: FTSpacing.md) {
                                Text("Goal Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                TextField("e.g. New Car", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Target Amount").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                TextField("0.00", text: $targetAmount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)

                            Divider().opacity(0.4)

                            HStack(spacing: FTSpacing.md) {
                                Text("Current Savings").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                Spacer()
                                Text(appState.baseCurrency).font(.ftBody).foregroundStyle(FTColor.textMuted)
                                TextField("0.00", text: $currentAmount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                                    .frame(maxWidth: 120)
                            }
                            .padding(.vertical, 13)
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Target Date
                        VStack(spacing: 0) {
                            Toggle(isOn: $hasTargetDate) {
                                Text("Set Target Date").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }
                            .tint(FTColor.accent)
                            .padding(.vertical, 13)

                            if hasTargetDate {
                                Divider().opacity(0.4)
                                HStack {
                                    DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                                        .tint(FTColor.accent)
                                }
                                .padding(.vertical, 9)
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)

                        // Icon
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("ICON")
                                .font(.ftLabel).tracking(1.6)
                                .foregroundStyle(FTColor.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(icons, id: \.self) { icon in
                                        Button { selectedIcon = icon } label: {
                                            Image(systemName: icon)
                                                .font(.title2)
                                                .foregroundStyle(selectedIcon == icon ? FTColor.accent : FTColor.textSecondary)
                                                .frame(width: 44, height: 44)
                                                .background(selectedIcon == icon ? FTColor.accent.opacity(0.15) : Color.clear)
                                                .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: FTRadius.sm)
                                                        .strokeBorder(selectedIcon == icon ? FTColor.accent : Color.clear, lineWidth: 1.5)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(FTSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        // Color
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("COLOR")
                                .font(.ftLabel).tracking(1.6)
                                .foregroundStyle(FTColor.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(colors, id: \.self) { color in
                                        Circle()
                                            .fill(Color.fromString(color))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .font(.caption).fontWeight(.bold).foregroundColor(.white)
                                                    .opacity(selectedColor == color ? 1 : 0)
                                            )
                                            .overlay(
                                                Circle().strokeBorder(.white.opacity(selectedColor == color ? 0.6 : 0), lineWidth: 2)
                                            )
                                            .onTapGesture { selectedColor = color }
                                    }
                                }
                            }
                        }
                        .padding(FTSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ftGlass(FTRadius.md)

                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button { save() } label: { Text("Add Goal") }
                    .buttonStyle(.ftPrimary)
                    .disabled(name.isEmpty || targetAmount.isEmpty)
                    .opacity(name.isEmpty || targetAmount.isEmpty ? 0.55 : 1)
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.bottom, FTSpacing.sm)
            }
            .navigationTitle("Add Savings Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .dismissKeyboardOnTap()
        }
    }

    private func save() {
        let goal = SavingsGoal(
            name: name,
            targetAmount: Double(targetAmount) ?? 0,
            currentAmount: Double(currentAmount) ?? 0,
            currency: appState.baseCurrency,
            targetDate: hasTargetDate ? targetDate : nil,
            icon: selectedIcon,
            color: selectedColor
        )
        context.insert(goal)
        try? context.save()
        dismiss()
    }
}
