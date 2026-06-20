import SwiftUI
import SwiftData
import Charts

struct ProjectProfitabilityView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \BusinessProject.startDate, order: .reverse) private var projects: [BusinessProject]
    @Query private var invoices: [BusinessInvoice]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var showingAdd = false
    @State private var statusFilter: ProjectStatus? = nil
    @State private var selectedProject: BusinessProject?

    private var filtered: [BusinessProject] {
        guard let f = statusFilter else { return projects }
        return projects.filter { $0.status == f }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                overallSummary
                filterRow
                projectList
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Project Profitability")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus").foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddBusinessProjectSheet()
        }
        .sheet(item: $selectedProject) { proj in
            ProjectDetailSheet(project: proj,
                               invoices: invoices.filter { $0.projectName == proj.name || $0.clientId == (proj.clientId ?? "") },
                               transactions: transactions.filter { $0.tags.contains(proj.tagKey) })
        }
    }

    // MARK: - Overall Summary

    private var overallSummary: some View {
        let totalRevenue = projects.reduce(0.0) { sum, proj in
            sum + invoices.filter { $0.projectName == proj.name }.reduce(0) { $0 + $1.totalPaid }
        }
        let totalExpenses = projects.reduce(0.0) { sum, proj in
            sum + transactions.filter { $0.tags.contains(proj.tagKey) && $0.type == .expense }
                              .reduce(0) { $0 + $1.amountInBaseCurrency }
        }
        let netProfit = totalRevenue - totalExpenses

        return VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PORTFOLIO OVERVIEW").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(netProfit.formatted(as: appState.baseCurrency))
                        .font(.ftAmount).foregroundStyle(netProfit >= 0 ? FTColor.income : FTColor.expense)
                    Text("Net profit · \(projects.count) projects").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(FTColor.catPurple.opacity(0.1)).frame(width: 52, height: 52)
                    Image(systemName: "chart.bar.fill").font(.ftTitle).foregroundStyle(FTColor.catPurple)
                }
            }
            HStack(spacing: FTSpacing.sm) {
                summaryTile("Revenue", value: totalRevenue, color: FTColor.income)
                summaryTile("Expenses", value: totalExpenses, color: FTColor.expense)
                let margin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0
                summaryTile("Margin", raw: String(format: "%.1f%%", margin), color: margin >= 0 ? FTColor.income : FTColor.expense)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func summaryTile(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value.asCompact(currency: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.sm)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    private func summaryTile(_ label: String, raw: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(raw).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.sm)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FilterChip(title: "All", isSelected: statusFilter == nil) { statusFilter = nil }
                ForEach(ProjectStatus.allCases, id: \.self) { s in
                    FilterChip(title: s.rawValue, isSelected: statusFilter == s) {
                        statusFilter = statusFilter == s ? nil : s
                    }
                }
            }
        }
    }

    // MARK: - Project List

    private var projectList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("PROJECTS (\(filtered.count))").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if filtered.isEmpty {
                Text("No projects found. Create your first project to track profitability.")
                    .font(.ftBody).foregroundStyle(FTColor.textMuted)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(filtered) { proj in
                        projectRow(proj)
                    }
                }
            }
        }
    }

    private func projectRow(_ proj: BusinessProject) -> some View {
        let projInvoices = invoices.filter { $0.projectName == proj.name || $0.clientId == (proj.clientId ?? "") }
        let revenue  = projInvoices.reduce(0) { $0 + $1.totalPaid }
        let expenses = transactions.filter { $0.tags.contains(proj.tagKey) && $0.type == .expense }
                                   .reduce(0) { $0 + $1.amountInBaseCurrency }
        let profit = revenue - expenses
        let margin = revenue > 0 ? (profit / revenue) * 100 : 0

        return Button { selectedProject = proj } label: {
            VStack(spacing: FTSpacing.md) {
                HStack(spacing: FTSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: proj.colorHex).opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "folder.fill")
                            .font(.ftHeadline)
                            .foregroundStyle(Color(hex: proj.colorHex))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(proj.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        if let client = proj.clientName { Text(client).font(.ftCaption).foregroundStyle(FTColor.textMuted) }
                        Label(proj.status.rawValue, systemImage: proj.status.icon)
                            .font(.ftCaption).foregroundStyle(Color.fromString(proj.status.color))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(profit.formatted(as: appState.baseCurrency))
                            .font(.ftCallout).foregroundStyle(profit >= 0 ? FTColor.income : FTColor.expense)
                        Text(String(format: "%.1f%% margin", margin))
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                }

                if proj.budget > 0 {
                    VStack(spacing: 4) {
                        HStack {
                            Text("Budget").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            Spacer()
                            Text(String(format: "%.0f%%", min(100, expenses / proj.budget * 100)))
                                .font(.ftCaption).foregroundStyle(expenses > proj.budget ? FTColor.expense : FTColor.textSecondary)
                        }
                        FTProgressBar(
                            value: proj.budget > 0 ? min(1.0, expenses / proj.budget) : 0,
                            color: expenses > proj.budget ? FTColor.expense : FTColor.catBlue,
                            height: 4
                        )
                    }
                }
            }
            .padding()
            .ftGlass(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Business Project Sheet

struct AddBusinessProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ClientProfile.name) private var clients: [ClientProfile]

    @State private var name = ""
    @State private var selectedClientId = ""
    @State private var selectedClientName = ""
    @State private var description = ""
    @State private var budget = ""
    @State private var status: ProjectStatus = .active
    @State private var startDate = Date()
    @State private var endDate: Date? = nil
    @State private var hasEndDate = false
    @State private var colorHex = "#4A90D9"
    @State private var notes = ""
    @State private var currency = "AED"

    private let colorOptions = ["#4A90D9", "#0E9C8A", "#E74C3C", "#9B59B6", "#E8963C", "#1B8B4B", "#E84393", "#8B4513"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    colorPickerCard
                    detailsCard
                    if !clients.isEmpty { clientCard }
                    datesCard
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var colorPickerCard: some View {
        VStack(spacing: FTSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FTRadius.md).fill(Color(hex: colorHex).opacity(0.2)).frame(width: 72, height: 72)
                Image(systemName: "folder.fill").font(.system(size: 28)).foregroundStyle(Color(hex: colorHex))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 32, height: 32)
                            .overlay(Circle().stroke(.white, lineWidth: colorHex == hex ? 3 : 0))
                            .onTapGesture { colorHex = hex }
                    }
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var detailsCard: some View {
        VStack(spacing: FTSpacing.sm) {
            inputField("Project Name *", text: $name)
            inputField("Description", text: $description)
            inputField("Budget (\(currency))", text: $budget, keyboardType: .decimalPad)
            inputField("Notes", text: $notes)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var clientCard: some View {
        Menu {
            Button("No Client") { selectedClientId = ""; selectedClientName = "" }
            Divider()
            ForEach(clients) { c in
                Button(c.name) { selectedClientId = c.id.uuidString; selectedClientName = c.name }
            }
        } label: {
            HStack {
                Image(systemName: "person.fill").foregroundStyle(FTColor.accent)
                Text(selectedClientName.isEmpty ? "Assign Client (optional)" : selectedClientName)
                    .font(.ftBody).foregroundStyle(selectedClientName.isEmpty ? FTColor.textMuted : FTColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            .padding()
            .ftGlass(FTRadius.md)
        }
    }

    private var datesCard: some View {
        VStack(spacing: FTSpacing.sm) {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                .font(.ftBody)
                .padding(FTSpacing.md)
                .ftGlass(FTRadius.sm)
            Toggle("Has End Date", isOn: $hasEndDate)
                .font(.ftBody)
                .padding(FTSpacing.md)
                .ftGlass(FTRadius.sm)
            if hasEndDate {
                DatePicker("End Date", selection: Binding(
                    get: { endDate ?? Date().addingTimeInterval(90 * 86400) },
                    set: { endDate = $0 }
                ), in: startDate..., displayedComponents: .date)
                    .font(.ftBody)
                    .padding(FTSpacing.md)
                    .ftGlass(FTRadius.sm)
            }
        }
    }

    private func inputField(_ label: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        TextField(label, text: text)
            .keyboardType(keyboardType)
            .font(.ftBody)
            .padding(FTSpacing.md)
            .ftGlass(FTRadius.sm)
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        let proj = BusinessProject(
            name: n,
            clientId: selectedClientId.isEmpty ? nil : selectedClientId,
            clientName: selectedClientName.isEmpty ? nil : selectedClientName,
            projectDescription: description.isEmpty ? nil : description,
            currency: currency,
            budget: Double(budget) ?? 0,
            status: status,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            colorHex: colorHex,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(proj)
        try? context.save()
        dismiss()
    }
}

// MARK: - Project Detail Sheet

struct ProjectDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let project: BusinessProject
    let invoices: [BusinessInvoice]
    let transactions: [Transaction]

    private var revenue: Double  { invoices.reduce(0) { $0 + $1.totalPaid } }
    private var expenses: Double { transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInBaseCurrency } }
    private var profit: Double   { revenue - expenses }
    private var margin: Double   { revenue > 0 ? profit / revenue * 100 : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    headerCard
                    profitCard
                    if !invoices.isEmpty { invoiceList }
                    if !transactions.isEmpty { expenseList }
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(FTColor.accent)
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: FTSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: FTRadius.md).fill(Color(hex: project.colorHex).opacity(0.2)).frame(width: 56, height: 56)
                Image(systemName: "folder.fill").font(.ftTitle).foregroundStyle(Color(hex: project.colorHex))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                if let c = project.clientName { Text(c).font(.ftCaption).foregroundStyle(FTColor.textMuted) }
                Label(project.status.rawValue, systemImage: project.status.icon)
                    .font(.ftCaption).foregroundStyle(Color.fromString(project.status.color))
                Text("\(project.startDate.formatted) →")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
            Spacer()
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var profitCard: some View {
        VStack(spacing: FTSpacing.lg) {
            VStack(spacing: 4) {
                Text("NET PROFIT").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                Text(profit.formatted(as: appState.baseCurrency))
                    .font(.ftAmount).foregroundStyle(profit >= 0 ? FTColor.income : FTColor.expense)
                Text(String(format: "%.1f%% profit margin", margin))
                    .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            HStack(spacing: FTSpacing.sm) {
                pTile("Revenue", value: revenue, color: FTColor.income)
                pTile("Expenses", value: expenses, color: FTColor.expense)
                if project.budget > 0 {
                    pTile("Budget", value: project.budget, color: FTColor.catBlue)
                }
            }
            if project.budget > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Text("Budget Usage").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        Spacer()
                        Text(String(format: "%.1f%%", min(100, expenses / project.budget * 100)))
                            .font(.ftCaption).foregroundStyle(expenses > project.budget ? FTColor.expense : FTColor.textSecondary)
                    }
                    FTProgressBar(
                        value: min(1.0, expenses / project.budget),
                        color: expenses > project.budget ? FTColor.expense : FTColor.income,
                        height: 6
                    )
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func pTile(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value.asCompact(currency: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.sm)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    private var invoiceList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("INVOICES (\(invoices.count))").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            ForEach(invoices.sorted { $0.issueDate > $1.issueDate }) { inv in
                HStack {
                    Text(inv.invoiceNumber.isEmpty ? "Invoice" : inv.invoiceNumber)
                        .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Text(inv.totalAmount.formatted(as: appState.baseCurrency))
                        .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                    Label(inv.status.rawValue, systemImage: inv.status.icon)
                        .font(.ftCaption).foregroundStyle(inv.status.color)
                }
                .padding()
                .ftGlass(FTRadius.sm)
            }
        }
    }

    private var expenseList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            let expenses = transactions.filter { $0.type == .expense }
            Text("EXPENSES (\(expenses.count))").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            ForEach(expenses.sorted { $0.date > $1.date }.prefix(10), id: \.id) { tx in
                HStack {
                    Text(tx.title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Text(tx.amountInBaseCurrency.formatted(as: appState.baseCurrency))
                        .font(.ftCallout).foregroundStyle(FTColor.expense)
                }
                .padding()
                .ftGlass(FTRadius.sm)
            }
        }
    }
}
