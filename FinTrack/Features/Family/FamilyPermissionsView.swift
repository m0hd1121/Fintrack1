import SwiftUI
import SwiftData

struct FamilyPermissionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let group: FamilyGroup

    @State private var members: [FamilyMemberData] = []
    @State private var selectedMember: FamilyMemberData?
    @State private var showingPermissionEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                permissionLegend
                membersPermissionList
                resourceAccessMatrix
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .onAppear { members = group.members }
        .sheet(item: $selectedMember) { member in
            MemberPermissionEditorSheet(
                member: member,
                onSave: { updated in
                    if let idx = members.firstIndex(where: { $0.id == updated.id }) {
                        members[idx] = updated
                    }
                    group.members = members
                    try? context.save()
                }
            )
        }
    }

    // MARK: - Permission Legend

    private var permissionLegend: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("PERMISSION LEVELS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ForEach(FamilyPermissionLevel.allCases, id: \.rawValue) { level in
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: level.icon)
                            .font(.ftCallout).foregroundStyle(level.color)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.rawValue).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                            Text(level.description).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                        Circle().fill(level.color).frame(width: 10, height: 10)
                    }
                    .padding(.horizontal, FTSpacing.md).padding(.vertical, FTSpacing.sm)
                    .background(level.color.opacity(0.05), in: RoundedRectangle(cornerRadius: FTRadius.sm))
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Members Permission List

    private var membersPermissionList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("MEMBER PERMISSIONS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ForEach(members, id: \.id) { member in
                    memberPermissionRow(member)
                }
            }
        }
    }

    private func memberPermissionRow(_ member: FamilyMemberData) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(member.initials)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color(hex: member.avatarColorHex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: FTSpacing.sm) {
                    Text(member.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    if member.isCurrentUser {
                        Text("You").font(.ftCaption).foregroundStyle(FTColor.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(FTColor.accent.opacity(0.1)).clipShape(Capsule())
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: member.role.icon).font(.system(size: 10)).foregroundStyle(member.role.color)
                    Text(member.role.rawValue).font(.ftCaption).foregroundStyle(member.role.color)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: member.defaultPermission.icon)
                        .font(.system(size: 10)).foregroundStyle(member.defaultPermission.color)
                    Text(member.defaultPermission.rawValue)
                        .font(.ftCaption).foregroundStyle(member.defaultPermission.color)
                }
                Text("\(member.permissions.count) overrides")
                    .font(.system(size: 10)).foregroundStyle(FTColor.textMuted)
            }

            if !member.isCurrentUser {
                Button {
                    selectedMember = member
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.md)
        .contentShape(Rectangle())
        .onTapGesture {
            if !member.isCurrentUser { selectedMember = member }
        }
    }

    // MARK: - Resource Access Matrix

    private var resourceAccessMatrix: some View {
        let resourceTypes = ["transactions", "accounts", "budget", "investments", "reports", "settings"]
        return VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("ACCESS MATRIX").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            Text("Effective access per member for key resources")
                .font(.ftCaption).foregroundStyle(FTColor.textMuted)

            VStack(spacing: 0) {
                matrixHeader(resourceTypes: resourceTypes)
                Divider().opacity(0.3)
                ForEach(members, id: \.id) { member in
                    matrixRow(member: member, resourceTypes: resourceTypes)
                    Divider().opacity(0.2)
                }
            }
            .ftGlass(FTRadius.lg)
        }
    }

    private func matrixHeader(resourceTypes: [String]) -> some View {
        HStack(spacing: 0) {
            Text("Member").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                .frame(width: 80, alignment: .leading)
            ForEach(resourceTypes, id: \.self) { rt in
                Text(rt.prefix(3).uppercased())
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(FTColor.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, FTSpacing.md).padding(.vertical, FTSpacing.sm)
    }

    private func matrixRow(member: FamilyMemberData, resourceTypes: [String]) -> some View {
        HStack(spacing: 0) {
            Text(member.initials)
                .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color(hex: member.avatarColorHex))
                .clipShape(Circle())
                .frame(width: 80, alignment: .leading)

            ForEach(resourceTypes, id: \.self) { rt in
                let level = member.permissionFor(resourceType: rt, resourceId: nil)
                Image(systemName: permissionDotIcon(level))
                    .font(.system(size: 10))
                    .foregroundStyle(level.color)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, FTSpacing.md).padding(.vertical, FTSpacing.sm)
    }

    private func permissionDotIcon(_ level: FamilyPermissionLevel) -> String {
        switch level {
        case .viewOnly: return "eye.fill"
        case .edit: return "pencil.circle.fill"
        case .admin: return "shield.fill"
        }
    }
}

// MARK: - Member Permission Editor Sheet

struct MemberPermissionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let member: FamilyMemberData
    let onSave: (FamilyMemberData) -> Void

    @State private var defaultPermission: FamilyPermissionLevel
    @State private var permissionOverrides: [String: FamilyPermissionLevel] = [:]

    private let resourceTypes: [(key: String, label: String, icon: String)] = [
        ("transactions", "Transactions", "arrow.left.arrow.right.circle"),
        ("accounts", "Accounts", "building.columns"),
        ("budget", "Budget", "chart.pie"),
        ("investments", "Investments", "chart.line.uptrend.xyaxis"),
        ("reports", "Reports", "chart.bar.xaxis"),
        ("settings", "Settings", "gear"),
        ("family", "Family", "person.3"),
        ("tax", "Tax", "doc.text"),
    ]

    init(member: FamilyMemberData, onSave: @escaping (FamilyMemberData) -> Void) {
        self.member = member
        self.onSave = onSave
        _defaultPermission = State(initialValue: member.defaultPermission)
        var overrides: [String: FamilyPermissionLevel] = [:]
        for perm in member.permissions {
            overrides[perm.resourceType] = perm.level
        }
        _permissionOverrides = State(initialValue: overrides)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    memberHeader

                    defaultPermissionSection

                    overridesSection

                    Button(action: save) {
                        Text("Save Permissions")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
                    }
                    .buttonStyle(.plain)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Edit Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var memberHeader: some View {
        HStack(spacing: FTSpacing.md) {
            Text(member.initials)
                .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color(hex: member.avatarColorHex))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name).font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text(member.role.rawValue).font(.ftCaption).foregroundStyle(member.role.color)
            }
            Spacer()
        }
        .padding()
        .ftGlass(FTRadius.lg)
    }

    private var defaultPermissionSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("DEFAULT PERMISSION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            Text("Applies to all resources unless overridden below")
                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            ForEach(FamilyPermissionLevel.allCases, id: \.rawValue) { level in
                Button { defaultPermission = level } label: {
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: level.icon).foregroundStyle(level.color).font(.ftCallout).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.rawValue).font(.ftBody)
                                .foregroundStyle(defaultPermission == level ? FTColor.textPrimary : FTColor.textSecondary)
                            Text(level.description).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        Spacer()
                        if defaultPermission == level {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(FTColor.accent)
                        }
                    }
                    .padding()
                    .background(
                        defaultPermission == level ? FTColor.accent.opacity(0.06) : FTColor.textMuted.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: FTRadius.sm)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var overridesSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("RESOURCE OVERRIDES").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            Text("Override default permission for specific sections")
                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            VStack(spacing: FTSpacing.sm) {
                ForEach(resourceTypes, id: \.key) { resource in
                    resourceOverrideRow(resource)
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func resourceOverrideRow(_ resource: (key: String, label: String, icon: String)) -> some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: resource.icon)
                .font(.ftCallout).foregroundStyle(FTColor.accent).frame(width: 28)

            Text(resource.label).font(.ftBody).foregroundStyle(FTColor.textPrimary)
            Spacer()

            Menu {
                Button("Use Default") { permissionOverrides.removeValue(forKey: resource.key) }
                Divider()
                ForEach(FamilyPermissionLevel.allCases, id: \.rawValue) { level in
                    Button { permissionOverrides[resource.key] = level } label: {
                        Label(level.rawValue, systemImage: level.icon)
                    }
                }
            } label: {
                let effective = permissionOverrides[resource.key] ?? defaultPermission
                HStack(spacing: 4) {
                    if permissionOverrides[resource.key] != nil {
                        Circle().fill(effective.color).frame(width: 6, height: 6)
                    }
                    Text(permissionOverrides[resource.key]?.rawValue ?? "Default")
                        .font(.ftCaption)
                        .foregroundStyle(permissionOverrides[resource.key] != nil ? effective.color : FTColor.textMuted)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9)).foregroundStyle(FTColor.textMuted)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(FTColor.textMuted.opacity(0.08), in: RoundedRectangle(cornerRadius: FTRadius.sm))
            }
        }
    }

    private func save() {
        var updated = member
        updated.defaultPermission = defaultPermission
        updated.permissions = permissionOverrides.map { key, level in
            FamilyPermissionRecord(resourceType: key, resourceId: nil, level: level)
        }
        onSave(updated)
        dismiss()
    }
}
