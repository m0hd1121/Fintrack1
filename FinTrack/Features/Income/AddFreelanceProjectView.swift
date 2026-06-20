import SwiftUI
import SwiftData

// MARK: - AddFreelanceProjectView

struct AddFreelanceProjectView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // MARK: Editing target
    var editingProject: FreelanceProject? = nil

    // MARK: Form State

    // Section 1: Project Info
    @State private var projectName: String = ""
    @State private var clientName: String = ""
    @State private var projectDescription: String = ""

    // Section 2: Financials
    @State private var contractValueText: String = ""
    @State private var currency: String = "AED"

    // Section 3: Timeline
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    // Section 4: Status
    @State private var projectStatus: ProjectStatus = .active

    // Section 5: Appearance
    @State private var selectedColorName: String = "teal"

    // Section 6: Notes
    @State private var notes: String = ""

    // Validation
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    // MARK: Constants

    private let currencies = ["AED", "USD", "EUR", "GBP", "SAR"]

    private let availableColors: [(name: String, color: Color)] = [
        ("teal",   .teal),
        ("blue",   .blue),
        ("purple", .purple),
        ("orange", .orange),
        ("red",    .red),
        ("green",  .green),
        ("mint",   .mint),
        ("cyan",   .cyan)
    ]

    // MARK: - Init

    init(editingProject: FreelanceProject? = nil) {
        self.editingProject = editingProject
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        projectInfoSection
                        financialsSection
                        timelineSection
                        statusSection
                        appearanceSection
                        notesSection
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle(editingProject == nil ? "New Project" : "Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Sections

    // MARK: Section 1 — Project Info

    private var projectInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("PROJECT INFO")

            VStack(spacing: 0) {
                formTextField(label: "Project Name", placeholder: "e.g. Brand Identity Redesign", text: $projectName)
                rowDivider
                formTextField(label: "Client Name", placeholder: "e.g. Acme Corp", text: $clientName)
                rowDivider

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Description")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                    TextEditor(text: $projectDescription)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .frame(minHeight: 72)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 2 — Financials

    private var financialsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("FINANCIALS")

            VStack(spacing: 0) {
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Contract Value")
                    Spacer()
                    TextField("0.00", text: $contractValueText)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                .padding(.vertical, FTSpacing.md)

                rowDivider

                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Currency")
                    Spacer()
                    Menu {
                        ForEach(currencies, id: \.self) { code in
                            Button(code) { currency = code }
                        }
                    } label: {
                        HStack(spacing: FTSpacing.xs) {
                            Text(currency)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FTColor.textMuted)
                        }
                    }
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 3 — Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("TIMELINE")

            VStack(spacing: 0) {
                HStack(spacing: FTSpacing.md) {
                    fieldLabel("Start Date")
                    Spacer()
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.sm)

                rowDivider

                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "calendar.badge.checkmark", tint: FTColor.accent, size: 36)
                    Text("Has End Date")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                    Spacer()
                    Toggle("", isOn: $hasEndDate)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.md)

                if hasEndDate {
                    rowDivider

                    HStack(spacing: FTSpacing.md) {
                        fieldLabel("End Date")
                        Spacer()
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .labelsHidden()
                            .tint(FTColor.accent)
                    }
                    .padding(.vertical, FTSpacing.sm)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 4 — Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("STATUS")

            VStack(spacing: 0) {
                ForEach(Array(ProjectStatus.allCases.enumerated()), id: \.element) { index, status in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { projectStatus = status }
                    } label: {
                        HStack(spacing: FTSpacing.md) {
                            FTIconTile(
                                symbol: status.icon,
                                tint: Color.fromString(status.color),
                                size: 36
                            )
                            Text(status.rawValue)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                            Spacer()
                            if projectStatus == status {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(FTColor.accent)
                            }
                        }
                        .padding(.vertical, FTSpacing.md)
                    }
                    .buttonStyle(.plain)

                    if index < ProjectStatus.allCases.count - 1 {
                        rowDivider
                    }
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 5 — Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("APPEARANCE")

            VStack(alignment: .leading, spacing: FTSpacing.md) {
                Text("Color")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)

                colorSwatches

                // Preview tile
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(
                        symbol: "laptopcomputer",
                        tint: Color.fromString(selectedColorName),
                        size: 42
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(projectName.isEmpty ? "Project Name" : projectName)
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                        Text(clientName.isEmpty ? "Client Name" : clientName)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                }
                .padding(.top, FTSpacing.xs)
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    // MARK: Section 6 — Notes

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

    // MARK: Save Button Area

    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showValidationError {
                Text(validationMessage)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(editingProject == nil ? "Save Project" : "Update Project") {
                save()
            }
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

    // MARK: - Sub-views

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.ftLabel)
            .tracking(1.6)
            .foregroundStyle(FTColor.textMuted)
            .padding(.leading, FTSpacing.xs)
            .padding(.bottom, FTSpacing.xs)
    }

    private func formTextField(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: FTSpacing.md) {
            fieldLabel(label)
            TextField(placeholder, text: text)
                .font(.ftBody)
                .foregroundStyle(FTColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, FTSpacing.md)
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

    private var colorSwatches: some View {
        HStack(spacing: FTSpacing.sm) {
            ForEach(availableColors, id: \.name) { item in
                let isSelected = selectedColorName == item.name
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selectedColorName = item.name }
                } label: {
                    ZStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 30, height: 30)
                        if isSelected {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2.5)
                                .frame(width: 30, height: 30)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .animation(.snappy(duration: 0.2), value: isSelected)
            }
            Spacer()
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let proj = editingProject else { return }
        projectName        = proj.projectName
        clientName         = proj.clientName
        projectDescription = proj.projectDescription ?? ""
        contractValueText  = proj.totalValue > 0 ? String(format: "%.2f", proj.totalValue) : ""
        currency           = proj.currency
        startDate          = proj.startDate
        hasEndDate         = proj.endDate != nil
        endDate            = proj.endDate ?? Calendar.current.date(byAdding: .month, value: 3, to: proj.startDate) ?? Date()
        projectStatus      = proj.status
        selectedColorName  = proj.colorName
        notes              = proj.notes ?? ""
    }

    private func save() {
        let trimmedName   = projectName.trimmingCharacters(in: .whitespaces)
        let trimmedClient = clientName.trimmingCharacters(in: .whitespaces)
        let contractValue = Double(contractValueText.replacingOccurrences(of: ",", with: ".")) ?? 0

        guard !trimmedName.isEmpty else {
            validationMessage = "Project name is required"
            withAnimation { showValidationError = true }
            return
        }
        guard !trimmedClient.isEmpty else {
            validationMessage = "Client name is required"
            withAnimation { showValidationError = true }
            return
        }
        guard contractValue > 0 else {
            validationMessage = "Please enter a valid contract value"
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        let trimmedDesc  = projectDescription.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        if let project = editingProject {
            project.projectName        = trimmedName
            project.clientName         = trimmedClient
            project.projectDescription = trimmedDesc.isEmpty ? nil : trimmedDesc
            project.totalValue         = contractValue
            project.currency           = currency
            project.startDate          = startDate
            project.endDate            = hasEndDate ? endDate : nil
            project.statusRaw          = projectStatus.rawValue
            project.colorName          = selectedColorName
            project.notes              = trimmedNotes.isEmpty ? nil : trimmedNotes
            project.updatedAt          = Date()
        } else {
            let project = FreelanceProject(
                projectName:        trimmedName,
                clientName:         trimmedClient,
                projectDescription: trimmedDesc.isEmpty ? nil : trimmedDesc,
                currency:           currency,
                totalValue:         contractValue,
                statusRaw:          projectStatus.rawValue,
                startDate:          startDate,
                endDate:            hasEndDate ? endDate : nil,
                notes:              trimmedNotes.isEmpty ? nil : trimmedNotes,
                colorName:          selectedColorName
            )
            context.insert(project)
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("New Project") {
    AddFreelanceProjectView()
        .modelContainer(for: FreelanceProject.self, inMemory: true)
}

#Preview("Edit Project") {
    let project = FreelanceProject(
        projectName: "Brand Identity",
        clientName: "Acme Corp",
        projectDescription: "Full brand redesign including logo, colors, and typography.",
        currency: "AED",
        totalValue: 25000,
        statusRaw: ProjectStatus.active.rawValue,
        startDate: Date(),
        colorName: "teal"
    )
    return AddFreelanceProjectView(editingProject: project)
        .modelContainer(for: FreelanceProject.self, inMemory: true)
}
