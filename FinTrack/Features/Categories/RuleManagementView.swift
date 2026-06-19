import SwiftUI
import SwiftData

// MARK: - Rule Management View

struct RuleManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CategorizationRule.priority) private var rules: [CategorizationRule]

    @State private var showingAddSheet   = false
    @State private var editingRule: CategorizationRule? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                Group {
                    if rules.isEmpty {
                        emptyState
                    } else {
                        ruleList
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Categorization Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(FTColor.accent)
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                EditRuleView(rule: nil)
            }
            .sheet(item: $editingRule) { rule in
                EditRuleView(rule: rule)
            }
        }
    }

    // MARK: - List

    private var ruleList: some View {
        ScrollView {
            VStack(spacing: FTSpacing.sm) {
                infoCard

                VStack(spacing: 0) {
                    ForEach(rules) { rule in
                        ruleRow(rule)
                        if rule.id != rules.last?.id { Divider().padding(.leading, 64).opacity(0.4) }
                    }
                }
                .padding(.horizontal, FTSpacing.lg)
                .ftGlass(FTRadius.md)
                .padding(.horizontal, FTSpacing.screen)
            }
            .padding(.top, FTSpacing.sm)
            .padding(.bottom, 40)
        }
    }

    private func ruleRow(_ rule: CategorizationRule) -> some View {
        HStack(spacing: FTSpacing.md) {
            // Priority indicator
            Text("\(rule.priority)")
                .font(.ftLabel.monospacedDigit())
                .foregroundStyle(FTColor.textMuted)
                .frame(width: 28)

            FTIconTile(symbol: rule.conditionType.icon,
                       tint: rule.isEnabled ? FTColor.accent : FTColor.textMuted, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.name)
                    .font(.ftBodySemibold)
                    .foregroundStyle(rule.isEnabled ? FTColor.textPrimary : FTColor.textMuted)
                Text(rule.conditionSummary)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { rule.isEnabled = $0; try? context.save() }
                ))
                .labelsHidden()
                .tint(FTColor.accent)
                .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { editingRule = rule }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                context.delete(rule)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                editingRule = rule
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(FTColor.accent)
        }
    }

    private var infoCard: some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(FTColor.accent)
            Text("Rules apply in priority order (lowest number first) during CSV imports and transaction entry.")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
        .padding(.horizontal, FTSpacing.screen)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: FTSpacing.xl) {
            Spacer()
            FTIconTile(symbol: "text.badge.checkmark", tint: FTColor.catPurple, size: 72)
            VStack(spacing: FTSpacing.sm) {
                Text("No Categorization Rules")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Rules automatically assign categories based on merchant name, keywords, amounts, or currency — applied during CSV imports and new entries.")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FTSpacing.xxl)
            }
            Button {
                showingAddSheet = true
            } label: {
                Label("Create First Rule", systemImage: "plus")
            }
            .buttonStyle(.ftPrimary)
            .padding(.horizontal, FTSpacing.screen)
            Spacer()
        }
    }
}

// MARK: - Edit Rule View

struct EditRuleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let rule: CategorizationRule?

    @State private var name = ""
    @State private var conditionType: RuleConditionType = .merchantContains
    @State private var conditionValue = ""
    @State private var amountMin = ""
    @State private var amountMax = ""
    @State private var targetCategory: TransactionCategory = .other
    @State private var priority = 100
    @State private var autoTagsInput = ""
    @State private var autoTags: [String] = []
    @State private var isEnabled = true

    private var isEditing: Bool { rule != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        basicCard
                        conditionCard
                        actionCard
                        if isEditing { deleteCard }
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEditing ? "Edit Rule" : "New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadData)
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (conditionType.requiresAmountRange || !conditionValue.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Basic card

    private var basicCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: FTSpacing.md) {
                Text("Rule Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                TextField("e.g. Carrefour Groceries", text: $name)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            }
            .padding(.vertical, 13)

            Divider().opacity(0.4)

            HStack(spacing: FTSpacing.md) {
                Text("Priority").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Stepper("\(priority)", value: $priority, in: 1...999)
                    .labelsHidden()
                Text("\(priority)")
                    .font(.ftBodySemibold.monospacedDigit())
                    .foregroundStyle(FTColor.textPrimary)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.vertical, 9)

            Divider().opacity(0.4)

            Toggle(isOn: $isEnabled) {
                Text("Enabled").font(.ftBody).foregroundStyle(FTColor.textPrimary)
            }
            .tint(FTColor.accent)
            .padding(.vertical, 13)
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Condition card

    private var conditionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONDITION")
                .font(.ftLabel).tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
                .padding(.bottom, FTSpacing.sm)
                .padding(.horizontal, FTSpacing.sm)

            VStack(spacing: 0) {
                // Condition type
                Menu {
                    Picker("Condition Type", selection: $conditionType) {
                        ForEach(RuleConditionType.allCases, id: \.self) { ct in
                            Label(ct.rawValue, systemImage: ct.icon).tag(ct)
                        }
                    }
                } label: {
                    HStack(spacing: FTSpacing.md) {
                        FTIconTile(symbol: conditionType.icon, tint: FTColor.accent, size: 32)
                        Text(conditionType.rawValue)
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FTColor.textMuted)
                    }
                    .padding(.vertical, 13)
                }

                if conditionType.requiresTextValue {
                    Divider().opacity(0.4)
                    HStack(spacing: FTSpacing.md) {
                        Text("Value").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        TextField(conditionType.placeholder, text: $conditionValue)
                            .multilineTextAlignment(.trailing)
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 13)
                }

                if conditionType.requiresAmountRange {
                    Divider().opacity(0.4)
                    HStack(spacing: FTSpacing.md) {
                        Text("Min Amount").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        TextField("0", text: $amountMin)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            .frame(maxWidth: 100)
                    }
                    .padding(.vertical, 13)

                    Divider().opacity(0.4)
                    HStack(spacing: FTSpacing.md) {
                        Text("Max Amount").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        TextField("∞", text: $amountMax)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            .frame(maxWidth: 100)
                    }
                    .padding(.vertical, 13)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Action card

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ACTION")
                .font(.ftLabel).tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
                .padding(.bottom, FTSpacing.sm)
                .padding(.horizontal, FTSpacing.sm)

            VStack(spacing: 0) {
                // Target category
                Menu {
                    Picker("Category", selection: $targetCategory) {
                        ForEach(TransactionCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                } label: {
                    HStack(spacing: FTSpacing.md) {
                        Text("Set Category").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Label(targetCategory.rawValue, systemImage: targetCategory.icon)
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FTColor.textMuted)
                    }
                    .padding(.vertical, 13)
                }

                // Auto-tags
                Divider().opacity(0.4)
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Add Tags (optional)")
                        .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    if !autoTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: FTSpacing.xs) {
                                ForEach(autoTags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text("#\(tag)").font(.ftCaption).foregroundStyle(FTColor.accent)
                                        Button { autoTags.removeAll { $0 == tag } } label: {
                                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(FTColor.textMuted)
                                        }
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(.regularMaterial, in: Capsule())
                                }
                            }
                        }
                    }
                    HStack(spacing: FTSpacing.sm) {
                        Image(systemName: "tag")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        TextField("Add tag and press return…", text: $autoTagsInput)
                            .font(.ftCaption)
                            .submitLabel(.done)
                            .onSubmit {
                                let t = autoTagsInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                if !t.isEmpty && !autoTags.contains(t) { autoTags.append(t) }
                                autoTagsInput = ""
                            }
                    }
                }
                .padding(.vertical, 13)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Delete card

    private var deleteCard: some View {
        Button(role: .destructive) {
            if let r = rule { context.delete(r) }
            try? context.save()
            dismiss()
        } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "trash", tint: FTColor.expense, size: 36)
                Text("Delete Rule")
                    .font(.ftBody).foregroundStyle(FTColor.expense)
                Spacer()
            }
            .padding(.horizontal, FTSpacing.lg)
            .padding(.vertical, 13)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: - Load / Save

    private func loadData() {
        guard let r = rule else { return }
        name           = r.name
        conditionType  = r.conditionType
        conditionValue = r.conditionValue
        amountMin      = r.amountMin.map { String($0) } ?? ""
        amountMax      = r.amountMax.map { String($0) } ?? ""
        targetCategory = r.targetCategory
        priority       = r.priority
        autoTags       = r.autoTags
        isEnabled      = r.isEnabled
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedValue = conditionValue.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let minAmt = Double(amountMin.trimmingCharacters(in: .whitespaces))
        let maxAmt = Double(amountMax.trimmingCharacters(in: .whitespaces))

        if let r = rule {
            r.name = trimmedName
            r.conditionType = conditionType
            r.conditionValue = trimmedValue
            r.amountMin = conditionType.requiresAmountRange ? minAmt : nil
            r.amountMax = conditionType.requiresAmountRange ? maxAmt : nil
            r.targetCategory = targetCategory
            r.priority = priority
            r.autoTags = autoTags
            r.isEnabled = isEnabled
        } else {
            let newRule = CategorizationRule(
                name: trimmedName,
                isEnabled: isEnabled,
                priority: priority,
                conditionType: conditionType,
                conditionValue: trimmedValue,
                amountMin: conditionType.requiresAmountRange ? minAmt : nil,
                amountMax: conditionType.requiresAmountRange ? maxAmt : nil,
                targetCategory: targetCategory,
                autoTags: autoTags
            )
            context.insert(newRule)
        }

        try? context.save()
        dismiss()
    }
}
