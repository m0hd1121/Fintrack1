import SwiftUI
import SwiftData

struct ClientManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \ClientProfile.name) private var clients: [ClientProfile]
    @Query private var invoices: [BusinessInvoice]

    @State private var showingAdd = false
    @State private var selectedClient: ClientProfile?
    @State private var searchText = ""
    @State private var statusFilter: ClientStatus? = nil

    private var filtered: [ClientProfile] {
        clients.filter { client in
            let matchesSearch = searchText.isEmpty ||
                client.name.localizedCaseInsensitiveContains(searchText) ||
                (client.company?.localizedCaseInsensitiveContains(searchText) == true) ||
                (client.email?.localizedCaseInsensitiveContains(searchText) == true)
            let matchesStatus = statusFilter == nil || client.status == statusFilter!
            return matchesSearch && matchesStatus
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                searchBar
                statusFilters
                if filtered.isEmpty {
                    emptyState
                } else {
                    clientList
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Clients")
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
            AddEditClientSheet(client: nil)
        }
        .sheet(item: $selectedClient) { client in
            ClientDetailSheet(client: client, invoices: invoices.filter { $0.clientId == client.id.uuidString })
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(FTColor.textMuted)
            TextField("Search clients…", text: $searchText)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Status Filters

    private var statusFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FilterChip(title: "All", isSelected: statusFilter == nil) {
                    statusFilter = nil
                }
                ForEach(ClientStatus.allCases, id: \.self) { s in
                    FilterChip(title: s.rawValue, isSelected: statusFilter == s) {
                        statusFilter = statusFilter == s ? nil : s
                    }
                }
            }
        }
    }

    // MARK: - Client List

    private var clientList: some View {
        VStack(spacing: FTSpacing.sm) {
            ForEach(filtered) { client in
                clientRow(client)
                    .onTapGesture { selectedClient = client }
            }
        }
    }

    private func clientRow(_ client: ClientProfile) -> some View {
        let clientInvoices = invoices.filter { $0.clientId == client.id.uuidString }
        let outstanding = clientInvoices.filter { $0.status.isOpen }.reduce(0) { $0 + $1.balanceDue }
        return HStack(spacing: FTSpacing.md) {
            Text(client.initials)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color(hex: client.colorHex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                if let company = client.company { Text(company).font(.ftCaption).foregroundStyle(FTColor.textMuted) }
                if let email = client.email { Text(email).font(.ftCaption).foregroundStyle(FTColor.textSecondary) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Label(client.status.rawValue, systemImage: client.status.icon)
                    .font(.ftCaption).foregroundStyle(client.status.color)
                if outstanding > 0 {
                    Text(outstanding.formatted(as: appState.baseCurrency))
                        .font(.ftCaption).foregroundStyle(FTColor.gold)
                }
                Text("\(clientInvoices.count) invoices").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.md)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48)).foregroundStyle(FTColor.textMuted)
            Text("No clients yet").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("Add your first client to start tracking invoices and projects.")
                .font(.ftBody).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
            Button { showingAdd = true } label: {
                Label("Add Client", systemImage: "plus")
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .padding(.horizontal, FTSpacing.xl)
                    .padding(.vertical, FTSpacing.md)
                    .background(FTColor.accent, in: Capsule())
            }
        }
        .padding(FTSpacing.xxl)
        .ftGlass(FTRadius.xl)
    }
}

// MARK: - Add/Edit Client Sheet

struct AddEditClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let client: ClientProfile?

    @State private var name = ""
    @State private var company = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var vatNumber = ""
    @State private var notes = ""
    @State private var status: ClientStatus = .active
    @State private var colorHex = "#0E9C8A"

    private let colorOptions = ["#0E9C8A", "#4A90D9", "#E74C3C", "#9B59B6", "#E8963C", "#1B8B4B", "#E84393", "#8B4513"]

    var isEditing: Bool { client != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    colorPicker
                    VStack(spacing: FTSpacing.sm) {
                        field("Name *", text: $name)
                        field("Company", text: $company)
                        field("Email", text: $email, keyboardType: .emailAddress)
                        field("Phone", text: $phone, keyboardType: .phonePad)
                        field("Address", text: $address)
                        field("VAT Number", text: $vatNumber)
                        field("Notes", text: $notes)
                    }
                    statusPicker
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle(isEditing ? "Edit Client" : "New Client")
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
            .onAppear { populate() }
        }
    }

    private func field(_ label: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted).padding(.leading, 4)
            TextField(label, text: text)
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .sentences)
                .font(.ftBody)
                .padding(FTSpacing.md)
                .ftGlass(FTRadius.sm)
        }
    }

    private var colorPicker: some View {
        VStack(spacing: FTSpacing.md) {
            Text(name.isEmpty ? "NEW" : String(name.prefix(2)).uppercased())
                .font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Color(hex: colorHex))
                .clipShape(Circle())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Circle().fill(Color(hex: hex))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(.white, lineWidth: colorHex == hex ? 3 : 0))
                            .onTapGesture { colorHex = hex }
                    }
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var statusPicker: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("STATUS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            HStack(spacing: FTSpacing.sm) {
                ForEach(ClientStatus.allCases, id: \.self) { s in
                    Button {
                        status = s
                    } label: {
                        Label(s.rawValue, systemImage: s.icon)
                            .font(.ftCaption)
                            .foregroundStyle(status == s ? .white : FTColor.textSecondary)
                            .padding(.horizontal, FTSpacing.md)
                            .padding(.vertical, FTSpacing.sm)
                            .background(status == s ? s.color : s.color.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
    }

    private func populate() {
        guard let c = client else { return }
        name = c.name
        company = c.company ?? ""
        email = c.email ?? ""
        phone = c.phone ?? ""
        address = c.address ?? ""
        vatNumber = c.vatNumber ?? ""
        notes = c.notes ?? ""
        status = c.status
        colorHex = c.colorHex
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        if let c = client {
            c.name = n
            c.company = company.isEmpty ? nil : company
            c.email = email.isEmpty ? nil : email
            c.phone = phone.isEmpty ? nil : phone
            c.address = address.isEmpty ? nil : address
            c.vatNumber = vatNumber.isEmpty ? nil : vatNumber
            c.notes = notes.isEmpty ? nil : notes
            c.status = status
            c.colorHex = colorHex
            c.updatedAt = Date()
        } else {
            let c = ClientProfile(
                name: n,
                company: company.isEmpty ? nil : company,
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone,
                address: address.isEmpty ? nil : address,
                vatNumber: vatNumber.isEmpty ? nil : vatNumber,
                notes: notes.isEmpty ? nil : notes,
                colorHex: colorHex
            )
            c.status = status
            context.insert(c)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Client Detail Sheet

struct ClientDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    let client: ClientProfile
    let invoices: [BusinessInvoice]

    @State private var showingEdit = false

    private var totalBilled: Double { invoices.reduce(0) { $0 + $1.totalAmount } }
    private var totalPaid: Double { invoices.reduce(0) { $0 + $1.totalPaid } }
    private var outstanding: Double { invoices.reduce(0) { $0 + $1.balanceDue } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    headerCard
                    financeCard
                    invoiceList
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingEdit = true } label: {
                        Image(systemName: "pencil").foregroundStyle(FTColor.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(FTColor.accent)
                }
            }
            .sheet(isPresented: $showingEdit) {
                AddEditClientSheet(client: client)
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: FTSpacing.lg) {
            Text(client.initials)
                .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color(hex: client.colorHex))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(client.name).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                if let co = client.company { Text(co).font(.ftBody).foregroundStyle(FTColor.textSecondary) }
                if let em = client.email { Text(em).font(.ftCaption).foregroundStyle(FTColor.textMuted) }
                if let ph = client.phone { Text(ph).font(.ftCaption).foregroundStyle(FTColor.textMuted) }
            }
            Spacer()
            Label(client.status.rawValue, systemImage: client.status.icon)
                .font(.ftCaption).foregroundStyle(client.status.color)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var financeCard: some View {
        HStack(spacing: FTSpacing.sm) {
            financeTile("Billed", value: totalBilled, color: FTColor.catBlue)
            financeTile("Paid", value: totalPaid, color: FTColor.income)
            financeTile("Outstanding", value: outstanding, color: outstanding > 0 ? FTColor.gold : FTColor.textMuted)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func financeTile(_ label: String, value: Double, color: Color) -> some View {
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
            Text("INVOICES").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if invoices.isEmpty {
                Text("No invoices for this client.").font(.ftBody).foregroundStyle(FTColor.textMuted).padding()
            } else {
                ForEach(invoices.sorted { $0.issueDate > $1.issueDate }) { inv in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(inv.invoiceNumber.isEmpty ? "Invoice" : inv.invoiceNumber)
                                .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Text(inv.issueDate.formatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(inv.totalAmount.formatted(as: appState.baseCurrency))
                                .font(.ftCallout).foregroundStyle(FTColor.textPrimary)
                            Label(inv.status.rawValue, systemImage: inv.status.icon)
                                .font(.ftCaption).foregroundStyle(inv.status.color)
                        }
                    }
                    .padding()
                    .ftGlass(FTRadius.md)
                }
            }
        }
    }
}
