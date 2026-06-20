import SwiftUI
import SwiftData

struct CollaborativePlannerView: View {
    @Environment(\.modelContext) private var context
    @Query private var advisors: [AdvisorAccess]

    @State private var showingInvite = false
    @State private var selectedAdvisor: AdvisorAccess?

    private var activeAdvisors: [AdvisorAccess] { advisors.filter(\.isActive) }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                headerCard
                if advisors.isEmpty {
                    EmptyStateView(
                        icon: "person.badge.shield.checkmark",
                        title: "Invite a Financial Advisor",
                        message: "Share controlled access to your financial data with a trusted advisor, accountant, or family member.",
                        actionTitle: "Invite Advisor"
                    ) { showingInvite = true }
                    .padding(.top, 40)
                } else {
                    advisorsList
                    auditNote
                }
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Collaborative Planner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingInvite = true } label: {
                    Image(systemName: "person.badge.plus").foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingInvite) { InviteAdvisorView() }
        .sheet(item: $selectedAdvisor) { AdvisorDetailView(advisor: $0) }
    }

    private var headerCard: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                FTIconTile(symbol: "person.3.fill", tint: FTColor.catBlue, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collaborative Finance").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text("\(activeAdvisors.count) active advisor\(activeAdvisors.count == 1 ? "" : "s")")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
            }
            Text("You control exactly what each advisor can see. All access is read-only by default with a full audit trail.")
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var advisorsList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Your Advisors").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            ForEach(advisors) { advisor in
                AdvisorCard(advisor: advisor)
                    .onTapGesture { selectedAdvisor = advisor }
            }
        }
    }

    private var auditNote: some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: "lock.shield.fill").foregroundStyle(FTColor.accent)
            Text("All advisor sessions are logged in your Security Audit Log.")
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.sm)
    }
}

// MARK: – Advisor Card

struct AdvisorCard: View {
    let advisor: AdvisorAccess

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle()
                    .fill(advisor.isActive ? FTColor.accentGradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 44)
                Text(String(advisor.advisorName.prefix(2)).uppercased())
                    .font(.ftBodySemibold).foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(advisor.advisorName).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(advisor.advisorEmail).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                BadgeView(text: advisor.role.rawValue, color: advisor.isActive ? FTColor.accent : .gray)
                if let last = advisor.lastAccessDate {
                    Text("Last: \(last.relativeFormatted)").font(.system(size: 9)).foregroundStyle(FTColor.textMuted)
                } else {
                    Text("Never accessed").font(.system(size: 9)).foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
        .opacity(advisor.isActive ? 1 : 0.6)
    }
}

// MARK: – Advisor Detail

struct AdvisorDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var advisor: AdvisorAccess
    @State private var noteText = ""
    @State private var showingRevoke = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    profileSection
                    permissionsCard
                    accessCodeCard
                    notesCard
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.vertical, FTSpacing.lg)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle(advisor.advisorName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Revoke", role: .destructive) { showingRevoke = true }
                        .foregroundStyle(FTColor.expense)
                }
            }
            .confirmationDialog("Revoke Access?", isPresented: $showingRevoke, titleVisibility: .visible) {
                Button("Revoke Access", role: .destructive) {
                    advisor.isActive = false
                    try? context.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(advisor.advisorName) will immediately lose access to your financial data.")
            }
        }
    }

    private var profileSection: some View {
        VStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(FTColor.accentGradient).frame(width: 72, height: 72)
                Text(String(advisor.advisorName.prefix(2)).uppercased())
                    .font(.ftTitle).foregroundStyle(.white)
            }
            Text(advisor.advisorName).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
            Text(advisor.advisorEmail).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: advisor.role.icon).foregroundStyle(FTColor.accent)
                Text(advisor.role.description).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FTSpacing.xl)
        .ftGlass(FTRadius.lg)
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Access Permissions").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            permissionToggle("Transactions", "arrow.left.arrow.right.circle.fill", $advisor.canViewTransactions)
            Divider().opacity(0.4)
            permissionToggle("Accounts", "building.columns.fill", $advisor.canViewAccounts)
            Divider().opacity(0.4)
            permissionToggle("Goals", "star.fill", $advisor.canViewGoals)
            Divider().opacity(0.4)
            permissionToggle("Debts & Loans", "banknote.fill", $advisor.canViewDebts)
            Divider().opacity(0.4)
            permissionToggle("Can Add Notes", "pencil.circle.fill", $advisor.canAddNotes)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private func permissionToggle(_ label: String, _ icon: String, _ binding: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(FTColor.accent).frame(width: 20)
            Text(label).font(.ftBody).foregroundStyle(FTColor.textPrimary)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .onChange(of: binding.wrappedValue) { _, _ in try? context.save() }
        }
        .padding(.vertical, 4)
    }

    private var accessCodeCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Share Access Code").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("Share this code with your advisor to link their view.")
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            HStack {
                Text(advisor.accessCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(FTColor.accent)
                    .tracking(4)
                Spacer()
                Button {
                    UIPasteboard.general.string = advisor.accessCode
                } label: {
                    Image(systemName: "doc.on.doc").foregroundStyle(FTColor.accent)
                }
            }
            .padding(FTSpacing.md)
            .background(FTColor.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Advisor Notes").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            let notes = advisor.notes
            if notes.isEmpty {
                Text("No notes yet.").font(.ftBody).foregroundStyle(FTColor.textMuted)
            } else {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(note.advisorName).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Spacer()
                            Text(note.date.relativeFormatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        Text(note.content).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    }
                    .padding(FTSpacing.sm)
                    .background(FTColor.bgElevated.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
                }
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }
}

// MARK: – Invite Advisor

struct InviteAdvisorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var email = ""
    @State private var role: AdvisorRole = .readOnly
    @State private var canViewDebts = false
    @State private var canAddNotes = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Advisor Details") {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("Access Level") {
                    Picker("Role", selection: $role) {
                        ForEach(AdvisorRole.allCases, id: \.self) { r in
                            Label(r.rawValue, systemImage: r.icon).tag(r)
                        }
                    }
                    Text(role.description).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Section("Additional Permissions") {
                    Toggle("View Debts & Loans", isOn: $canViewDebts)
                    Toggle("Add Notes", isOn: $canAddNotes)
                }
                Section {
                    Text("The advisor will receive a unique access code to view your data. They cannot make changes. You can revoke access at any time.")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .navigationTitle("Invite Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send Invite") { save() }
                        .foregroundStyle(FTColor.accent)
                        .disabled(name.isEmpty || email.isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
            }
        }
    }

    private func save() {
        let advisor = AdvisorAccess(
            advisorName: name,
            advisorEmail: email,
            role: role,
            canViewDebts: canViewDebts,
            canAddNotes: canAddNotes
        )
        advisor.canAddNotes = canAddNotes
        context.insert(advisor)
        try? context.save()
        dismiss()
    }
}
