import SwiftUI
import SwiftData

struct FamilySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let group: FamilyGroup?

    @State private var groupName = ""
    @State private var adminName = ""
    @State private var members: [FamilyMemberData] = []
    @State private var showingAddMember = false
    @State private var editingMember: FamilyMemberData?

    var isNew: Bool { group == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    groupInfoSection
                    membersSection
                    if !isNew { dangerZone }
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .navigationTitle(isNew ? "Set Up Family Group" : "Manage Family")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: isNew ? .topBarTrailing : .topBarTrailing) {
                    Button(isNew ? "Create" : "Save", action: save)
                        .disabled(groupName.isEmpty || adminName.isEmpty)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                }
                if isNew {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .onAppear {
                if let g = group {
                    groupName = g.name
                    adminName = g.adminName
                    members = g.members
                } else {
                    // Pre-populate with current user
                    members = [FamilyMemberData(
                        name: "Me",
                        role: .parent,
                        defaultPermission: .admin,
                        avatarColorHex: "#0E9C8A",
                        isCurrentUser: true
                    )]
                }
            }
            .sheet(isPresented: $showingAddMember) {
                AddFamilyMemberSheet(currency: appState.baseCurrency) { newMember in
                    members.append(newMember)
                }
            }
            .sheet(item: $editingMember) { member in
                EditFamilyMemberSheet(member: member) { updated in
                    if let idx = members.firstIndex(where: { $0.id == updated.id }) {
                        members[idx] = updated
                    }
                }
            }
        }
    }

    // MARK: - Group Info

    private var groupInfoSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("FAMILY GROUP").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.sm) {
                inputRow("Family Name", text: $groupName, placeholder: "e.g. The Smith Family")
                inputRow("Your Name (Admin)", text: $adminName, placeholder: "Your full name")
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    private func inputRow(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            TextField(placeholder, text: text)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Text("MEMBERS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                Spacer()
                Button { showingAddMember = true } label: {
                    Label("Add", systemImage: "plus")
                        .font(.ftCallout).foregroundStyle(FTColor.accent)
                }
            }

            VStack(spacing: FTSpacing.sm) {
                ForEach($members) { $member in
                    memberRow(member: $member)
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    private func memberRow(member: Binding<FamilyMemberData>) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(member.wrappedValue.initials)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: member.wrappedValue.avatarColorHex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: FTSpacing.sm) {
                    Text(member.wrappedValue.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if member.wrappedValue.isCurrentUser {
                        Text("You").font(.ftCaption).foregroundStyle(FTColor.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(FTColor.accent.opacity(0.1)).clipShape(Capsule())
                    }
                }
                Text(member.wrappedValue.role.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Text(member.wrappedValue.defaultPermission.rawValue)
                    .font(.ftCaption)
                    .foregroundStyle(member.wrappedValue.defaultPermission.color)
            }
            Spacer()
            if !member.wrappedValue.isCurrentUser {
                Button {
                    editingMember = member.wrappedValue
                } label: {
                    Image(systemName: "pencil").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if !member.wrappedValue.isCurrentUser {
                Button(role: .destructive) {
                    members.removeAll { $0.id == member.wrappedValue.id }
                } label: { Label("Remove", systemImage: "person.fill.xmark") }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("DANGER ZONE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.expense)
            Button(role: .destructive) {
                if let g = group { context.delete(g); try? context.save(); dismiss() }
            } label: {
                Label("Dissolve Family Group", systemImage: "person.fill.xmark")
                    .font(.ftBody).foregroundStyle(FTColor.expense)
                    .frame(maxWidth: .infinity).padding()
                    .background(FTColor.expense.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .overlay(RoundedRectangle(cornerRadius: FTRadius.xl).stroke(FTColor.expense.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.xl))
    }

    // MARK: - Save

    private func save() {
        if let g = group {
            g.name = groupName
            g.adminName = adminName
            g.members = members
            g.updatedAt = Date()
        } else {
            let g = FamilyGroup(name: groupName, adminName: adminName, currency: appState.baseCurrency)
            g.members = members
            context.insert(g)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Add Family Member Sheet

struct AddFamilyMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currency: String
    let onAdd: (FamilyMemberData) -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var role: FamilyMemberRole = .partner
    @State private var permission: FamilyPermissionLevel = .edit
    @State private var colorHex = "#4A90D9"

    private let colors = ["#0E9C8A", "#4A90D9", "#E8963C", "#9B59B6", "#E74C3C", "#1B8B4B", "#E67E22"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    // Avatar Preview
                    Text(name.isEmpty ? "?" : name.split(separator: " ").prefix(2).map { String($0.prefix(1)) }.joined())
                        .font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Color(hex: colorHex))
                        .clipShape(Circle())
                        .frame(maxWidth: .infinity)

                    VStack(spacing: FTSpacing.sm) {
                        formField("Full Name", text: $name, placeholder: "e.g. Sarah")
                        formField("Email (optional)", text: $email, placeholder: "member@email.com", keyboard: .emailAddress)
                    }
                    .padding().ftGlass(FTRadius.xl)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("ROLE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.sm) {
                            ForEach(FamilyMemberRole.allCases, id: \.rawValue) { r in
                                Button { role = r; permission = r.defaultPermission } label: {
                                    HStack {
                                        Image(systemName: r.icon).foregroundStyle(r.color).font(.ftCallout)
                                        Text(r.rawValue).font(.ftCallout)
                                            .foregroundStyle(role == r ? FTColor.textPrimary : FTColor.textSecondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(role == r ? r.color.opacity(0.12) : FTColor.textMuted.opacity(0.06),
                                                in: RoundedRectangle(cornerRadius: FTRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding().ftGlass(FTRadius.xl)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("DEFAULT PERMISSION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        ForEach(FamilyPermissionLevel.allCases, id: \.rawValue) { p in
                            Button { permission = p } label: {
                                HStack {
                                    Image(systemName: p.icon).foregroundStyle(p.color).font(.ftCallout).frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.rawValue).font(.ftBody)
                                            .foregroundStyle(permission == p ? FTColor.textPrimary : FTColor.textSecondary)
                                        Text(p.description).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                    }
                                    Spacer()
                                    if permission == p {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(FTColor.accent)
                                    }
                                }
                                .padding()
                                .background(permission == p ? FTColor.accent.opacity(0.06) : FTColor.textMuted.opacity(0.04),
                                            in: RoundedRectangle(cornerRadius: FTRadius.sm))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding().ftGlass(FTRadius.xl)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("AVATAR COLOR").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        HStack(spacing: FTSpacing.md) {
                            ForEach(colors, id: \.self) { c in
                                Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(.white, lineWidth: colorHex == c ? 3 : 0))
                                    .onTapGesture { colorHex = c }
                            }
                        }
                    }
                    .padding().ftGlass(FTRadius.lg)

                    Button(action: addMember) {
                        Text("Add Member")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
                    }
                    .buttonStyle(.plain).disabled(name.isEmpty)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func formField(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            TextField(placeholder, text: text).keyboardType(keyboard)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
    }

    private func addMember() {
        var member = FamilyMemberData(
            name: name,
            email: email.isEmpty ? nil : email,
            role: role,
            defaultPermission: permission,
            avatarColorHex: colorHex
        )
        member.permissions = FamilyService.shared.defaultPermissions(for: role)
        onAdd(member)
        dismiss()
    }
}

// MARK: - Edit Family Member Sheet

struct EditFamilyMemberSheet: View {
    @Environment(\.dismiss) private var dismiss

    let member: FamilyMemberData
    let onSave: (FamilyMemberData) -> Void

    @State private var name: String
    @State private var role: FamilyMemberRole
    @State private var permission: FamilyPermissionLevel
    @State private var colorHex: String

    init(member: FamilyMemberData, onSave: @escaping (FamilyMemberData) -> Void) {
        self.member = member
        self.onSave = onSave
        _name = State(initialValue: member.name)
        _role = State(initialValue: member.role)
        _permission = State(initialValue: member.defaultPermission)
        _colorHex = State(initialValue: member.avatarColorHex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    Text(name.isEmpty ? "?" : name.split(separator: " ").prefix(2).map { String($0.prefix(1)) }.joined())
                        .font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Color(hex: colorHex))
                        .clipShape(Circle())
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        TextField("Full Name", text: $name).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    }
                    .padding().ftGlass(FTRadius.lg)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("ROLE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        Picker("Role", selection: $role) {
                            ForEach(FamilyMemberRole.allCases, id: \.rawValue) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }.pickerStyle(.segmented).padding().ftGlass(FTRadius.lg)
                    }

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("DEFAULT PERMISSION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        Picker("Permission", selection: $permission) {
                            ForEach(FamilyPermissionLevel.allCases, id: \.rawValue) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }.pickerStyle(.segmented).padding().ftGlass(FTRadius.lg)
                    }

                    Button(action: save) {
                        Text("Save Changes")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
                    }
                    .buttonStyle(.plain).disabled(name.isEmpty)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Edit Member")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() {
        var updated = member
        updated.name = name; updated.role = role; updated.defaultPermission = permission
        onSave(updated); dismiss()
    }
}
