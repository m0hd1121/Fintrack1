import SwiftUI
import SwiftData

// MARK: - Invoice Creator (New/Edit Invoice)

struct InvoiceCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \ClientProfile.name) private var clients: [ClientProfile]
    @Query private var projects: [BusinessProject]

    let invoice: BusinessInvoice?

    @State private var invoiceNumber = ""
    @State private var selectedClientId = ""
    @State private var selectedClientName = ""
    @State private var selectedClientEmail = ""
    @State private var currency = "AED"
    @State private var issueDate = Date()
    @State private var dueDate = Date().addingTimeInterval(30 * 86400)
    @State private var projectName = ""
    @State private var notes = ""
    @State private var vatIncluded = true
    @State private var lineItems: [InvoiceLineItem] = [InvoiceLineItem()]
    @State private var showingClientPicker = false

    private var isEditing: Bool { invoice != nil }

    private var subtotal: Double { lineItems.reduce(0) { $0 + $1.subtotal } }
    private var totalVAT: Double { lineItems.reduce(0) { $0 + $1.vatAmount } }
    private var totalAmount: Double { vatIncluded ? lineItems.reduce(0) { $0 + $1.total } : subtotal }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    headerSection
                    clientSection
                    lineItemsSection
                    totalsCard
                    optionsSection
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle(isEditing ? "Edit Invoice" : "New Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                        .disabled(selectedClientName.isEmpty || lineItems.isEmpty)
                }
            }
            .sheet(isPresented: $showingClientPicker) {
                clientPickerSheet
            }
            .onAppear { populate() }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: FTSpacing.md) {
            Text("INVOICE DETAILS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: FTSpacing.sm) {
                rowField("Invoice #") {
                    TextField("e.g. INV-001", text: $invoiceNumber)
                        .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                }
                rowField("Issue Date") {
                    DatePicker("", selection: $issueDate, displayedComponents: .date)
                        .labelsHidden()
                }
                rowField("Due Date") {
                    DatePicker("", selection: $dueDate, in: issueDate..., displayedComponents: .date)
                        .labelsHidden()
                }
                rowField("Project") {
                    TextField("Project name (optional)", text: $projectName)
                        .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    // MARK: - Client Section

    private var clientSection: some View {
        VStack(spacing: FTSpacing.md) {
            Text("CLIENT").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { showingClientPicker = true } label: {
                HStack {
                    Image(systemName: "person.fill").foregroundStyle(FTColor.accent)
                    if selectedClientName.isEmpty {
                        Text("Select client…").font(.ftBody).foregroundStyle(FTColor.textMuted)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedClientName).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            if !selectedClientEmail.isEmpty {
                                Text(selectedClientEmail).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                .padding()
                .ftGlass(FTRadius.md)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Line Items Section

    private var lineItemsSection: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                Text("LINE ITEMS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                Spacer()
                Button {
                    lineItems.append(InvoiceLineItem())
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.ftCaption).foregroundStyle(FTColor.accent)
                }
            }

            VStack(spacing: FTSpacing.sm) {
                ForEach($lineItems) { $item in
                    LineItemRow(item: $item, vatIncluded: vatIncluded, currency: currency) {
                        lineItems.removeAll { $0.id == item.id }
                    }
                }
            }
        }
    }

    // MARK: - Totals Card

    private var totalsCard: some View {
        VStack(spacing: FTSpacing.sm) {
            HStack {
                Text("Subtotal").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text(subtotal.formatted(as: currency)).font(.ftCallout).foregroundStyle(FTColor.textPrimary)
            }
            if vatIncluded {
                HStack {
                    Text("VAT (5%)").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(totalVAT.formatted(as: currency)).font(.ftCallout).foregroundStyle(FTColor.textMuted)
                }
            }
            Divider().background(FTColor.textMuted.opacity(0.3))
            HStack {
                Text("Total").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Text(totalAmount.formatted(as: currency))
                    .font(.ftAmount).foregroundStyle(FTColor.accent)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(spacing: FTSpacing.sm) {
            FTToggleRow(symbol: "percent", tint: FTColor.catPurple, title: "Include VAT (5%)", isOn: $vatIncluded)
            Divider().background(FTColor.textMuted.opacity(0.3))
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                TextEditor(text: $notes)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Client Picker Sheet

    private var clientPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(clients) { client in
                    Button {
                        selectedClientId = client.id.uuidString
                        selectedClientName = client.name
                        selectedClientEmail = client.email ?? ""
                        showingClientPicker = false
                    } label: {
                        HStack(spacing: FTSpacing.md) {
                            Text(client.initials)
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color(hex: client.colorHex))
                                .clipShape(Circle())
                            VStack(alignment: .leading) {
                                Text(client.name).foregroundStyle(.primary)
                                if let email = client.email {
                                    Text(email).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingClientPicker = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func rowField<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary).frame(width: 90, alignment: .leading)
            Spacer()
            content()
        }
    }

    private func populate() {
        guard let inv = invoice else {
            let count = (try? context.fetchCount(FetchDescriptor<BusinessInvoice>())) ?? 0
            invoiceNumber = "INV-\(String(format: "%03d", count + 1))"
            return
        }
        invoiceNumber = inv.invoiceNumber
        selectedClientId = inv.clientId
        selectedClientName = inv.clientName
        selectedClientEmail = inv.clientEmail ?? ""
        currency = inv.currency
        issueDate = inv.issueDate
        dueDate = inv.dueDate
        projectName = inv.projectName ?? ""
        notes = inv.notes ?? ""
        vatIncluded = inv.vatIncluded
        lineItems = inv.lineItems
    }

    private func save() {
        let inv = invoice ?? {
            let i = BusinessInvoice(
                invoiceNumber: invoiceNumber,
                clientId: selectedClientId,
                clientName: selectedClientName,
                clientEmail: selectedClientEmail.isEmpty ? nil : selectedClientEmail,
                currency: currency,
                dueDate: dueDate,
                notes: notes.isEmpty ? nil : notes,
                vatIncluded: vatIncluded,
                projectName: projectName.isEmpty ? nil : projectName
            )
            context.insert(i)
            return i
        }()
        inv.invoiceNumber = invoiceNumber
        inv.clientId = selectedClientId
        inv.clientName = selectedClientName
        inv.clientEmail = selectedClientEmail.isEmpty ? nil : selectedClientEmail
        inv.currency = currency
        inv.issueDate = issueDate
        inv.dueDate = dueDate
        inv.projectName = projectName.isEmpty ? nil : projectName
        inv.notes = notes.isEmpty ? nil : notes
        inv.vatIncluded = vatIncluded
        inv.lineItems = lineItems
        inv.updatedAt = Date()
        try? context.save()
        dismiss()
    }
}

// MARK: - Line Item Row

struct LineItemRow: View {
    @Binding var item: InvoiceLineItem
    let vatIncluded: Bool
    let currency: String
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: FTSpacing.sm) {
            HStack {
                TextField("Description", text: $item.description)
                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill").foregroundStyle(FTColor.expense)
                }
            }
            HStack(spacing: FTSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Qty").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    TextField("1", value: $item.quantity, format: .number)
                        .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                        .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unit Price").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    TextField("0.00", value: $item.unitPrice, format: .number)
                        .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                        .keyboardType(.decimalPad)
                }
                if vatIncluded {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VAT %").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        TextField("5", value: Binding(get: { item.vatRate * 100 }, set: { item.vatRate = $0 / 100 }),
                                  format: .number)
                            .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                            .keyboardType(.decimalPad)
                    }
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    Text((vatIncluded ? item.total : item.subtotal).formatted(as: currency))
                        .font(.ftCallout).foregroundStyle(FTColor.accent)
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.sm)
    }
}

// MARK: - Invoice List View

struct InvoiceListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \BusinessInvoice.issueDate, order: .reverse) private var invoices: [BusinessInvoice]

    @State private var statusFilter: BusinessInvoiceStatus? = nil
    @State private var showingCreate = false
    @State private var selectedInvoice: BusinessInvoice?
    @State private var showingPayment = false

    private var filtered: [BusinessInvoice] {
        guard let f = statusFilter else { return invoices }
        return invoices.filter { $0.status == f }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                statusSummary
                filterRow
                if filtered.isEmpty {
                    Text("No invoices found.").font(.ftBody).foregroundStyle(FTColor.textMuted).padding()
                } else {
                    VStack(spacing: FTSpacing.sm) {
                        ForEach(filtered) { inv in
                            invoiceRow(inv)
                        }
                    }
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Invoices")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingCreate = true } label: {
                    Image(systemName: "plus").foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            InvoiceCreatorView(invoice: nil)
        }
        .sheet(item: $selectedInvoice) { inv in
            InvoiceDetailSheet(invoice: inv)
        }
    }

    private var statusSummary: some View {
        HStack(spacing: FTSpacing.sm) {
            let outstanding = invoices.filter { $0.status.isOpen }.reduce(0) { $0 + $1.balanceDue }
            let overdue = invoices.filter { $0.isOverdue }.reduce(0) { $0 + $1.balanceDue }
            statusTile("Outstanding", value: outstanding, color: FTColor.gold)
            statusTile("Overdue", value: overdue, color: FTColor.expense)
            let paid = invoices.filter { $0.status == .paid }.reduce(0) { $0 + $1.totalAmount }
            statusTile("Paid", value: paid, color: FTColor.income)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func statusTile(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value.asCompact(currency: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.sm)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FilterChip(title: "All", isSelected: statusFilter == nil) { statusFilter = nil }
                ForEach(BusinessInvoiceStatus.allCases, id: \.self) { s in
                    FilterChip(title: s.rawValue, isSelected: statusFilter == s) {
                        statusFilter = statusFilter == s ? nil : s
                    }
                }
            }
        }
    }

    private func invoiceRow(_ inv: BusinessInvoice) -> some View {
        Button { selectedInvoice = inv } label: {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    Circle().fill(inv.status.color.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: inv.status.icon).font(.ftCaption).foregroundStyle(inv.status.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(inv.invoiceNumber.isEmpty ? "Invoice" : inv.invoiceNumber)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text(inv.clientName).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    Text(inv.issueDate.formatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(inv.totalAmount.formatted(as: appState.baseCurrency))
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if inv.balanceDue > 0 && inv.status != .paid {
                        Text("Due: " + inv.balanceDue.formatted(as: appState.baseCurrency))
                            .font(.ftCaption).foregroundStyle(inv.isOverdue ? FTColor.expense : FTColor.gold)
                    }
                    Label(inv.status.rawValue, systemImage: inv.status.icon)
                        .font(.ftCaption).foregroundStyle(inv.status.color)
                }
            }
            .padding()
            .ftGlass(FTRadius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invoice Detail Sheet

struct InvoiceDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    let invoice: BusinessInvoice

    @State private var showingPayment = false
    @State private var paymentAmount = ""
    @State private var paymentMethod = "Bank Transfer"
    @State private var paymentNotes = ""

    private let paymentMethods = ["Bank Transfer", "Cash", "Cheque", "Card", "Online", "Other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    statusCard
                    lineItemsCard
                    paymentsCard
                    if invoice.status != .paid && invoice.status != .cancelled {
                        recordPaymentButton
                    }
                    statusActions
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle(invoice.invoiceNumber.isEmpty ? "Invoice" : invoice.invoiceNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(FTColor.accent)
                }
            }
            .sheet(isPresented: $showingPayment) {
                recordPaymentSheet
            }
        }
    }

    private var statusCard: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoice.clientName).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    if let proj = invoice.projectName { Text(proj).font(.ftCaption).foregroundStyle(FTColor.textMuted) }
                    Text("Due: \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.ftCaption)
                        .foregroundStyle(invoice.isOverdue ? FTColor.expense : FTColor.textSecondary)
                }
                Spacer()
                Label(invoice.status.rawValue, systemImage: invoice.status.icon)
                    .font(.ftCallout).foregroundStyle(invoice.status.color)
                    .padding(.horizontal, FTSpacing.sm)
                    .padding(.vertical, 4)
                    .background(invoice.status.color.opacity(0.1), in: Capsule())
            }
            if invoice.isOverdue {
                Label("\(invoice.daysOverdue) days overdue", systemImage: "exclamationmark.triangle.fill")
                    .font(.ftCaption).foregroundStyle(FTColor.expense)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                amountTile("Total", value: invoice.totalAmount, color: FTColor.textPrimary)
                amountTile("Paid", value: invoice.totalPaid, color: FTColor.income)
                amountTile("Balance", value: invoice.balanceDue, color: invoice.balanceDue > 0 ? FTColor.gold : FTColor.income)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func amountTile(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value.formatted(as: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var lineItemsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("LINE ITEMS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            ForEach(invoice.lineItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.description.isEmpty ? "Item" : item.description)
                            .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                        Text("\(String(format: "%.0f", item.quantity)) × \(item.unitPrice.formatted(as: invoice.currency))")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.total.formatted(as: invoice.currency))
                            .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                        if invoice.vatIncluded {
                            Text("VAT \(item.vatAmount.formatted(as: invoice.currency))")
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
            }
            Divider().background(FTColor.textMuted.opacity(0.3))
            if invoice.vatIncluded {
                HStack {
                    Text("VAT Total").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(invoice.totalVAT.formatted(as: invoice.currency)).font(.ftCallout).foregroundStyle(FTColor.textMuted)
                }
            }
            HStack {
                Text("Total").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Spacer()
                Text(invoice.totalAmount.formatted(as: invoice.currency)).font(.ftBodySemibold).foregroundStyle(FTColor.accent)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var paymentsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("PAYMENT HISTORY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if invoice.invoicePayments.isEmpty {
                Text("No payments recorded.").font(.ftBody).foregroundStyle(FTColor.textMuted)
            } else {
                ForEach(invoice.invoicePayments) { payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(payment.method).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            Text(payment.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        Spacer()
                        Text(payment.amount.formatted(as: invoice.currency))
                            .font(.ftCallout).foregroundStyle(FTColor.income)
                    }
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var recordPaymentButton: some View {
        Button { showingPayment = true } label: {
            Label("Record Payment", systemImage: "plus.circle.fill")
                .font(.ftBodySemibold).foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(FTColor.income, in: RoundedRectangle(cornerRadius: FTRadius.md))
        }
    }

    private var statusActions: some View {
        VStack(spacing: FTSpacing.sm) {
            Text("UPDATE STATUS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    ForEach(BusinessInvoiceStatus.allCases.filter { $0 != invoice.status }, id: \.self) { s in
                        Button {
                            invoice.status = s
                            try? context.save()
                        } label: {
                            Label(s.rawValue, systemImage: s.icon)
                                .font(.ftCaption)
                                .foregroundStyle(s.color)
                                .padding(.horizontal, FTSpacing.md)
                                .padding(.vertical, FTSpacing.sm)
                                .background(s.color.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var recordPaymentSheet: some View {
        NavigationStack {
            VStack(spacing: FTSpacing.xl) {
                VStack(spacing: FTSpacing.sm) {
                    Text("Balance Due").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    Text(invoice.balanceDue.formatted(as: invoice.currency))
                        .font(.ftAmount).foregroundStyle(FTColor.gold)
                }
                .padding()
                .ftGlass(FTRadius.xl)

                VStack(spacing: FTSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        TextField("0.00", text: $paymentAmount)
                            .keyboardType(.decimalPad).font(.ftBody)
                            .padding(FTSpacing.md).ftGlass(FTRadius.sm)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Method").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        Menu {
                            Picker("Method", selection: $paymentMethod) {
                                ForEach(paymentMethods, id: \.self) { Text($0).tag($0) }
                            }
                        } label: {
                            HStack {
                                Text(paymentMethod).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                            }
                            .padding(FTSpacing.md).ftGlass(FTRadius.sm)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        TextField("Optional notes", text: $paymentNotes)
                            .font(.ftBody).padding(FTSpacing.md).ftGlass(FTRadius.sm)
                    }
                }

                Spacer()
            }
            .padding(FTSpacing.screen)
            .background { FTBackdrop() }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingPayment = false }.foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amt = Double(paymentAmount), amt > 0 else { return }
                        invoice.recordPayment(amount: amt, method: paymentMethod, notes: paymentNotes.isEmpty ? nil : paymentNotes)
                        try? context.save()
                        showingPayment = false
                    }
                    .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                    .disabled(Double(paymentAmount) == nil || paymentAmount.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
