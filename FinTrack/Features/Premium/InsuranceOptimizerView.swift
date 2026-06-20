import SwiftUI
import SwiftData

struct InsuranceOptimizerView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \InsurancePolicy.endDate) private var policies: [InsurancePolicy]

    @State private var showingAdd = false
    @State private var selectedPolicy: InsurancePolicy?
    @State private var filterType: InsurancePolicyType? = nil

    private var filtered: [InsurancePolicy] {
        guard let f = filterType else { return policies }
        return policies.filter { $0.type == f }
    }

    private var activePolicies: [InsurancePolicy] { filtered.filter { $0.isActive && !$0.isExpired } }
    private var expiringSoon: [InsurancePolicy] { activePolicies.filter(\.isExpiringSoon) }
    private var totalAnnualPremium: Double { activePolicies.reduce(0) { $0 + $1.annualPremium } }
    private var currency: String { appState.baseCurrency }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                summaryCard
                if !expiringSoon.isEmpty { expiringCard }
                typeFilter
                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "shield.fill",
                        title: "No Insurance Policies",
                        message: "Track your health, life, car, and home insurance policies in one place.",
                        actionTitle: "Add Policy"
                    ) { showingAdd = true }
                } else {
                    coverageGaps
                    policyList
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Insurance Optimizer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddInsurancePolicyView() }
        .sheet(item: $selectedPolicy) { InsurancePolicyDetailView(policy: $0) }
    }

    // MARK: – Summary

    private var summaryCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Annual Premiums").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text("\(activePolicies.count) active policies").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                Text(totalAnnualPremium.formatted(as: currency))
                    .font(.ftTitle)
                    .foregroundStyle(FTColor.expense)
            }

            HStack(spacing: 0) {
                ForEach(InsurancePolicyType.allCases.prefix(4), id: \.self) { type in
                    let count = activePolicies.filter { $0.type == type }.count
                    if count > 0 {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.title3)
                                .foregroundStyle(Color.fromString(type.tint))
                            Text("\(count)")
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                            Text(type.rawValue)
                                .font(.system(size: 9))
                                .foregroundStyle(FTColor.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var expiringCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(FTColor.gold)
                Text("Expiring Soon").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            }
            ForEach(expiringSoon) { policy in
                HStack {
                    Text(policy.policyName.isEmpty ? policy.type.rawValue : policy.policyName)
                        .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Text("in \(policy.daysUntilRenewal) days")
                        .font(.ftCaption).foregroundStyle(FTColor.gold)
                }
            }
        }
        .padding(FTSpacing.lg)
        .background(FTColor.gold.opacity(0.08))
        .ftGlass(FTRadius.md)
    }

    private var typeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FTChip(symbol: "square.grid.2x2", title: "All", selected: filterType == nil)
                    .onTapGesture { filterType = nil }
                ForEach(InsurancePolicyType.allCases, id: \.self) { type in
                    FTChip(symbol: type.icon, title: type.rawValue, selected: filterType == type)
                        .onTapGesture { filterType = filterType == type ? nil : type }
                }
            }
            .padding(.horizontal, FTSpacing.xs)
        }
    }

    private var coverageGaps: some View {
        let covered = Set(activePolicies.map(\.type))
        let gaps = InsurancePolicyType.allCases.filter { ![.travel, .disability, .critical, .other].contains($0) && !covered.contains($0) }
        guard !gaps.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                HStack {
                    Image(systemName: "shield.slash.fill").foregroundStyle(FTColor.expense)
                    Text("Coverage Gaps").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                }
                ForEach(gaps, id: \.self) { gap in
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: gap.icon).foregroundStyle(FTColor.expense)
                        Text("\(gap.rawValue) insurance not found")
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Button("Add") { showingAdd = true }
                            .font(.ftCaption).foregroundStyle(FTColor.accent)
                    }
                }
            }
            .padding(FTSpacing.lg)
            .background(FTColor.expense.opacity(0.06))
            .ftGlass(FTRadius.md)
        )
    }

    private var policyList: some View {
        VStack(spacing: FTSpacing.sm) {
            ForEach(filtered) { policy in
                PolicyRow(policy: policy)
                    .onTapGesture { selectedPolicy = policy }
            }
        }
    }
}

struct PolicyRow: View {
    let policy: InsurancePolicy

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: policy.type.icon, tint: Color.fromString(policy.type.tint), size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(policy.policyName.isEmpty ? policy.type.rawValue : policy.policyName)
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(policy.provider).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(policy.annualPremium.formatted(as: policy.premiumCurrency) + "/yr")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                if policy.isExpiringSoon {
                    Text("Expiring soon").font(.ftCaption).foregroundStyle(FTColor.gold)
                } else if policy.isExpired {
                    Text("Expired").font(.ftCaption).foregroundStyle(FTColor.expense)
                } else {
                    Text("Until \(policy.endDate, style: .date)").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}

struct InsurancePolicyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let policy: InsurancePolicy
    @State private var showingEdit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    VStack(spacing: FTSpacing.md) {
                        FTIconTile(symbol: policy.type.icon, tint: Color.fromString(policy.type.tint), size: 56)
                        Text(policy.policyName.isEmpty ? policy.type.rawValue : policy.policyName)
                            .font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                        Text(policy.provider).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(FTSpacing.xl)
                    .ftGlass(FTRadius.lg)

                    detailCard("Coverage", [
                        ("Coverage Amount", policy.coverageAmount.formatted(as: policy.premiumCurrency)),
                        ("Deductible", policy.deductible.formatted(as: policy.premiumCurrency)),
                        ("Beneficiary", policy.beneficiary ?? "—"),
                    ])

                    detailCard("Premiums", [
                        ("Premium", policy.premium.formatted(as: policy.premiumCurrency) + " / " + policy.premiumFrequency.rawValue),
                        ("Annual Cost", policy.annualPremium.formatted(as: policy.premiumCurrency)),
                        ("Policy No.", policy.policyNumber ?? "—"),
                    ])

                    detailCard("Dates", [
                        ("Start", policy.startDate.formatted),
                        ("End / Renewal", policy.endDate.formatted),
                        ("Days Until Renewal", "\(max(0, policy.daysUntilRenewal))"),
                    ])

                    if let notes = policy.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("Notes").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                            Text(notes).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        }
                        .padding(FTSpacing.lg)
                        .ftGlass(FTRadius.md)
                    }
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.vertical, FTSpacing.lg)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle(policy.type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showingEdit = true }.foregroundStyle(FTColor.accent)
                }
            }
            .sheet(isPresented: $showingEdit) { AddInsurancePolicyView(editing: policy) }
        }
    }

    private func detailCard(_ title: String, _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text(title).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            ForEach(rows, id: \.0) { label, value in
                HStack {
                    Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                }
                if label != rows.last?.0 { Divider().opacity(0.4) }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

struct AddInsurancePolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var editing: InsurancePolicy?

    @State private var policyType: InsurancePolicyType = .health
    @State private var policyName = ""
    @State private var provider = ""
    @State private var policyNumber = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var premium = 0.0
    @State private var frequency: PremiumFrequency = .annual
    @State private var coverageAmount = 0.0
    @State private var deductible = 0.0
    @State private var beneficiary = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Policy Details") {
                    Picker("Type", selection: $policyType) {
                        ForEach(InsurancePolicyType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    TextField("Policy Name (optional)", text: $policyName)
                    TextField("Provider / Insurer", text: $provider)
                    TextField("Policy Number (optional)", text: $policyNumber)
                }
                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End / Renewal", selection: $endDate, displayedComponents: .date)
                }
                Section("Premium") {
                    HStack {
                        Text("Premium Amount")
                        Spacer()
                        TextField("0", value: $premium, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(PremiumFrequency.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                }
                Section("Coverage") {
                    HStack {
                        Text("Coverage Amount")
                        Spacer()
                        TextField("0", value: $coverageAmount, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Deductible")
                        Spacer()
                        TextField("0", value: $deductible, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    TextField("Beneficiary", text: $beneficiary)
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
            }
            .navigationTitle(editing == nil ? "Add Insurance" : "Edit Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }.foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        guard let e = editing else { return }
        policyType = e.type
        policyName = e.policyName
        provider = e.provider
        policyNumber = e.policyNumber ?? ""
        startDate = e.startDate
        endDate = e.endDate
        premium = e.premium
        frequency = e.premiumFrequency
        coverageAmount = e.coverageAmount
        deductible = e.deductible
        beneficiary = e.beneficiary ?? ""
        notes = e.notes ?? ""
    }

    private func save() {
        if let e = editing {
            e.typeRaw = policyType.rawValue
            e.policyName = policyName
            e.provider = provider
            e.policyNumber = policyNumber.isEmpty ? nil : policyNumber
            e.startDate = startDate
            e.endDate = endDate
            e.premium = premium
            e.premiumFrequencyRaw = frequency.rawValue
            e.coverageAmount = coverageAmount
            e.deductible = deductible
            e.beneficiary = beneficiary.isEmpty ? nil : beneficiary
            e.notes = notes.isEmpty ? nil : notes
        } else {
            let policy = InsurancePolicy(
                type: policyType, policyName: policyName, provider: provider,
                policyNumber: policyNumber.isEmpty ? nil : policyNumber,
                startDate: startDate, endDate: endDate,
                premium: premium, premiumFrequency: frequency,
                coverageAmount: coverageAmount, deductible: deductible,
                beneficiary: beneficiary.isEmpty ? nil : beneficiary,
                notes: notes.isEmpty ? nil : notes
            )
            context.insert(policy)
        }
        try? context.save()
        dismiss()
    }
}
