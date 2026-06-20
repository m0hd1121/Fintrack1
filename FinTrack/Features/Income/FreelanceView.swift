import SwiftUI
import SwiftData

// MARK: - FreelanceView

struct FreelanceView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context

    // MARK: Data
    @Query(sort: \FreelanceProject.createdAt, order: .reverse)
    private var allProjects: [FreelanceProject]

    // MARK: State
    @State private var selectedProject: FreelanceProject? = nil
    @State private var showAddProject: Bool = false
    @State private var completedExpanded: Bool = false

    // MARK: - Computed

    private var activeProjects: [FreelanceProject] {
        allProjects.filter { !$0.isArchived && $0.status != .completed && $0.status != .cancelled }
    }

    private var completedProjects: [FreelanceProject] {
        allProjects.filter { !$0.isArchived && ($0.status == .completed || $0.status == .cancelled) }
    }

    private var totalValueUnderContract: Double {
        allProjects.filter { !$0.isArchived }.reduce(0) { $0 + $1.totalValue }
    }

    private var totalReceived: Double {
        allProjects.filter { !$0.isArchived }.reduce(0) { $0 + $1.totalReceived }
    }

    private var totalOverdue: Double {
        allProjects.filter { !$0.isArchived }
            .flatMap { $0.overdueInvoices }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                summaryCard
                activeProjectsSection
                if !completedProjects.isEmpty {
                    completedProjectsSection
                }
                if allProjects.isEmpty {
                    emptyState
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.lg)
        }
        .sheet(item: $selectedProject) { project in
            FreelanceProjectDetailSheet(project: project)
        }
        .sheet(isPresented: $showAddProject) {
            AddFreelanceProjectView()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            Text("FREELANCE OVERVIEW")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            HStack(spacing: 0) {
                metricColumn(
                    title: "Under Contract",
                    value: totalValueUnderContract.asCompact(currency: "AED"),
                    color: FTColor.textPrimary
                )
                dividerLine
                metricColumn(
                    title: "Received",
                    value: totalReceived.asCompact(currency: "AED"),
                    color: FTColor.income
                )
                dividerLine
                metricColumn(
                    title: "Overdue",
                    value: totalOverdue.asCompact(currency: "AED"),
                    color: totalOverdue > 0 ? FTColor.expense : FTColor.textMuted
                )
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    private func metricColumn(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: FTSpacing.xs) {
            Text(value)
                .font(.ftTitle)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.1))
            .frame(width: 0.5, height: 44)
    }

    // MARK: - Active Projects Section

    private var activeProjectsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                Text("ACTIVE PROJECTS")
                    .font(.ftLabel)
                    .tracking(1.6)
                    .foregroundStyle(FTColor.textMuted)
                Spacer()
                Button {
                    showAddProject = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                }
            }
            .padding(.leading, FTSpacing.xs)

            if activeProjects.isEmpty {
                Text("No active projects. Tap + to add one.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                    .padding(.vertical, FTSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                ForEach(activeProjects) { project in
                    ProjectCard(project: project, dimmed: false)
                        .onTapGesture { selectedProject = project }
                }
            }
        }
    }

    // MARK: - Completed Projects Section

    private var completedProjectsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    completedExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("COMPLETED PROJECTS")
                        .font(.ftLabel)
                        .tracking(1.6)
                        .foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Image(systemName: completedExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                }
                .padding(.leading, FTSpacing.xs)
            }
            .buttonStyle(.plain)

            if completedExpanded {
                ForEach(completedProjects) { project in
                    ProjectCard(project: project, dimmed: true)
                        .onTapGesture { selectedProject = project }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            FTIconTile(symbol: "laptopcomputer", tint: FTColor.accent, size: 56)
            VStack(spacing: FTSpacing.xs) {
                Text("No Freelance Projects")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Add your first project to start tracking client work and invoices.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                    .multilineTextAlignment(.center)
            }
            Button("Add Project") { showAddProject = true }
                .buttonStyle(.ftPrimary)
                .frame(maxWidth: 220)
        }
        .padding(FTSpacing.xxl)
        .frame(maxWidth: .infinity)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - ProjectCard

private struct ProjectCard: View {
    let project: FreelanceProject
    let dimmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            // Header row
            HStack(spacing: FTSpacing.md) {
                FTIconTile(
                    symbol: "laptopcomputer",
                    tint: Color.fromString(project.colorName),
                    size: 42
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.projectName)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    Text(project.clientName)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                // Status chip
                statusChip(project.status)
            }

            // Overdue badge
            if !project.overdueInvoices.isEmpty {
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(project.overdueInvoices.count) overdue invoice\(project.overdueInvoices.count > 1 ? "s" : "")")
                        .font(.ftCaption)
                }
                .foregroundStyle(FTColor.expense)
                .padding(.horizontal, FTSpacing.sm)
                .padding(.vertical, 4)
                .background(FTColor.expense.opacity(0.12), in: .capsule)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                HStack {
                    Text("Received")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Text("\(project.totalReceived.formatted(as: project.currency)) / \(project.totalValue.formatted(as: project.currency))")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                FTProgressBar(
                    value: project.completionRate,
                    color: Color.fromString(project.colorName)
                )
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlassInteractive(FTRadius.md)
        .opacity(dimmed ? 0.65 : 1.0)
    }

    private func statusChip(_ status: ProjectStatus) -> some View {
        HStack(spacing: 5) {
            Image(systemName: status.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(status.rawValue)
                .font(.ftCaption)
        }
        .foregroundStyle(Color.fromString(status.color))
        .padding(.horizontal, FTSpacing.sm)
        .padding(.vertical, 4)
        .background(Color.fromString(status.color).opacity(0.14), in: .capsule)
    }
}

// MARK: - FreelanceProjectDetailSheet

struct FreelanceProjectDetailSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let project: FreelanceProject

    @State private var showAddInvoice: Bool = false
    @State private var selectedInvoiceForPayment: FreelanceInvoice? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        headerCard
                        financeSummaryCard
                        invoicesSection
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }
            }
            .navigationTitle(project.projectName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddInvoice = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .tint(FTColor.accent)
                }
            }
            .sheet(isPresented: $showAddInvoice) {
                AddInvoiceSheet(project: project)
            }
            .sheet(item: $selectedInvoiceForPayment) { invoice in
                RecordInvoicePaymentSheet(project: project, invoice: invoice)
            }
        }
    }

    // MARK: Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(
                    symbol: "laptopcomputer",
                    tint: Color.fromString(project.colorName),
                    size: 48
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.clientName)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textSecondary)
                    statusChip(project.status)
                }
                Spacer()
            }

            if let desc = project.projectDescription {
                Text(desc)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }

            HStack(spacing: FTSpacing.md) {
                Label(project.startDate.formatted, systemImage: "calendar")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                if let end = project.endDate {
                    Text("→")
                        .foregroundStyle(FTColor.textMuted)
                    Label(end.formatted, systemImage: "calendar.badge.checkmark")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    // MARK: Finance Summary Card

    private var financeSummaryCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("FINANCIALS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                financeRow("Contract Value", amount: project.totalValue, currency: project.currency, color: FTColor.textPrimary)
                financeRow("Invoiced", amount: project.totalInvoiced, currency: project.currency, color: FTColor.textSecondary)
                financeRow("Received", amount: project.totalReceived, currency: project.currency, color: FTColor.income)
                financeRow("Outstanding", amount: project.totalOutstanding, currency: project.currency, color: project.totalOutstanding > 0 ? FTColor.gold : FTColor.textMuted)
            }

            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                HStack {
                    Text("Completion")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Text((project.completionRate * 100).asPercentage())
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
                FTProgressBar(
                    value: project.completionRate,
                    color: Color.fromString(project.colorName)
                )
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    private func financeRow(_ label: String, amount: Double, currency: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(amount.formatted(as: currency))
                .font(.ftBodySemibold)
                .foregroundStyle(color)
        }
    }

    // MARK: Invoices Section

    private var invoicesSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                Text("INVOICES")
                    .font(.ftLabel)
                    .tracking(1.6)
                    .foregroundStyle(FTColor.textMuted)
                Spacer()
                Button {
                    showAddInvoice = true
                } label: {
                    Label("Add Invoice", systemImage: "plus.circle")
                        .font(.ftCallout)
                        .foregroundStyle(FTColor.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, FTSpacing.xs)

            let invoices = project.invoices.sorted { $0.dueDate < $1.dueDate }

            if invoices.isEmpty {
                Text("No invoices yet. Tap + to add one.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                    .padding(FTSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(invoices.enumerated()), id: \.element.id) { index, invoice in
                        invoiceRow(invoice: invoice)

                        if index < invoices.count - 1 {
                            Rectangle()
                                .fill(FTColor.textPrimary.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.leading, FTSpacing.lg)
                        }
                    }
                }
                .ftGlass(FTRadius.md)
            }
        }
    }

    private func invoiceRow(invoice: FreelanceInvoice) -> some View {
        HStack(spacing: FTSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: FTSpacing.xs) {
                    Text("#\(invoice.invoiceNumber)")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    invoiceStatusChip(invoice.status)
                }
                Text(invoice.description)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
                    .lineLimit(1)
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FTColor.textMuted)
                    Text("Due \(invoice.dueDate.formatted)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(invoice.isOverdue ? FTColor.expense : FTColor.textMuted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.amount.formatted(as: invoice.currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                if !invoice.isPaid {
                    Button("Mark Paid") {
                        selectedInvoiceForPayment = invoice
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FTColor.accent)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(FTSpacing.lg)
    }

    // MARK: Helpers

    private func statusChip(_ status: ProjectStatus) -> some View {
        HStack(spacing: 5) {
            Image(systemName: status.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(status.rawValue)
                .font(.ftCallout)
        }
        .foregroundStyle(Color.fromString(status.color))
        .padding(.horizontal, FTSpacing.sm)
        .padding(.vertical, 4)
        .background(Color.fromString(status.color).opacity(0.14), in: .capsule)
    }

    private func invoiceStatusChip(_ status: InvoiceStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(status.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color.fromString(status.color))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.fromString(status.color).opacity(0.14), in: .capsule)
    }
}

// MARK: - AddInvoiceSheet

struct AddInvoiceSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let project: FreelanceProject

    @State private var invoiceNumber: String = ""
    @State private var description: String = ""
    @State private var amountText: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var notes: String = ""
    @State private var showValidationError: Bool = false

    private var suggestedNumber: String {
        let count = project.invoices.count + 1
        return String(format: "%03d", count)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        invoiceDetailsSection
                        notesSection
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle("New Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear {
                if invoiceNumber.isEmpty {
                    invoiceNumber = suggestedNumber
                }
            }
        }
    }

    private var invoiceDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("INVOICE DETAILS")
            VStack(spacing: 0) {
                formRow {
                    fieldLabel("Invoice #")
                    Spacer()
                    TextField(suggestedNumber, text: $invoiceNumber)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 160)
                }
                rowDivider
                formRow {
                    fieldLabel("Description")
                    Spacer()
                    TextField("e.g. Website Design Phase 1", text: $description)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 200)
                }
                rowDivider
                formRow {
                    fieldLabel("Amount")
                    Spacer()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                rowDivider
                formRow {
                    fieldLabel("Due Date")
                    Spacer()
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("NOTES")
            VStack(alignment: .leading) {
                TextEditor(text: $notes)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showValidationError {
                Text("Description and a valid amount are required")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Button("Save Invoice") { save() }
                .buttonStyle(.ftPrimary)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, FTSpacing.xl)
        .padding(.top, FTSpacing.md)
        .background {
            LinearGradient(
                colors: [FTColor.bgBase.opacity(0), FTColor.bgBase],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
        guard !trimmedDesc.isEmpty, amount > 0 else {
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        let numStr = invoiceNumber.trimmingCharacters(in: .whitespaces).isEmpty ? suggestedNumber : invoiceNumber
        let invoice = FreelanceInvoice(
            invoiceNumber: numStr,
            description: trimmedDesc,
            amount: amount,
            currency: project.currency,
            issueDate: Date(),
            dueDate: dueDate,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )
        project.invoices.append(invoice)
        project.updatedAt = Date()
        try? context.save()
        dismiss()
    }

    // MARK: Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.ftLabel)
            .tracking(1.6)
            .foregroundStyle(FTColor.textMuted)
            .padding(.leading, FTSpacing.xs)
            .padding(.bottom, FTSpacing.xs)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.ftBody)
            .foregroundStyle(FTColor.textSecondary)
            .fixedSize()
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.06))
            .frame(height: 0.5)
    }

    private func formRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: FTSpacing.md) { content() }
            .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - RecordInvoicePaymentSheet

struct RecordInvoicePaymentSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let project: FreelanceProject
    let invoice: FreelanceInvoice

    @State private var paidAmountText: String = ""
    @State private var paymentDate: Date = Date()
    @State private var showValidationError: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        invoiceSummaryCard
                        paymentFormSection
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear {
                paidAmountText = String(format: "%.2f", invoice.amount)
            }
        }
    }

    // MARK: Invoice Summary Card

    private var invoiceSummaryCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("INVOICE")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(invoice.invoiceNumber)")
                        .font(.ftHeadline)
                        .foregroundStyle(FTColor.textPrimary)
                    Text(invoice.description)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                    Text("Due \(invoice.dueDate.formatted)")
                        .font(.ftCaption)
                        .foregroundStyle(invoice.isOverdue ? FTColor.expense : FTColor.textMuted)
                }
                Spacer()
                Text(invoice.amount.formatted(as: invoice.currency))
                    .font(.ftTitle)
                    .foregroundStyle(FTColor.textPrimary)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    // MARK: Payment Form

    private var paymentFormSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAYMENT DETAILS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)
                .padding(.leading, FTSpacing.xs)
                .padding(.bottom, FTSpacing.xs)

            VStack(spacing: 0) {
                HStack(spacing: FTSpacing.md) {
                    Text("Amount Received")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    TextField("0.00", text: $paidAmountText)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                .padding(.vertical, FTSpacing.md)

                Rectangle()
                    .fill(FTColor.textPrimary.opacity(0.06))
                    .frame(height: 0.5)

                HStack(spacing: FTSpacing.md) {
                    Text("Payment Date")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    DatePicker("", selection: $paymentDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.sm)

                // Variance hint
                if let paid = Double(paidAmountText.replacingOccurrences(of: ",", with: ".")), paid > 0 {
                    Rectangle()
                        .fill(FTColor.textPrimary.opacity(0.06))
                        .frame(height: 0.5)

                    HStack {
                        Text("Variance")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        let variance = paid - invoice.amount
                        Text((variance >= 0 ? "+" : "") + variance.formatted(as: invoice.currency))
                            .font(.ftBodySemibold)
                            .foregroundStyle(variance >= 0 ? FTColor.income : FTColor.expense)
                    }
                    .padding(.vertical, FTSpacing.md)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showValidationError {
                Text("Please enter a valid payment amount")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Button("Record Payment") { save() }
                .buttonStyle(.ftPrimary)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, FTSpacing.xl)
        .padding(.top, FTSpacing.md)
        .background {
            LinearGradient(
                colors: [FTColor.bgBase.opacity(0), FTColor.bgBase],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func save() {
        let paid = Double(paidAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard paid > 0 else {
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        var mutableProject = project
        IncomeService.shared.recordInvoicePayment(
            project: &mutableProject,
            invoiceId: invoice.id,
            amount: paid,
            date: paymentDate
        )

        // Mirror to project (SwiftData object is reference type; mutation via inout copy requires re-assigning fields)
        // Since FreelanceProject is a class (@Model), we mutate it directly as well
        if let idx = project.invoices.firstIndex(where: { $0.id == invoice.id }) {
            project.invoices[idx].paidDate = paymentDate
            project.invoices[idx].paidAmount = paid
            project.invoices[idx].statusRaw = InvoiceStatus.paid.rawValue
        }
        project.updatedAt = Date()

        // Create income transaction
        let tx = Transaction(
            title: "Invoice #\(invoice.invoiceNumber) — \(project.clientName)",
            amount: paid,
            currency: project.currency,
            type: .income,
            category: .freelance,
            date: paymentDate,
            incomeSource: project.clientName
        )
        context.insert(tx)

        try? context.save()
        dismiss()
    }
}
