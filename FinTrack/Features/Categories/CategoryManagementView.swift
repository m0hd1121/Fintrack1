import SwiftUI
import SwiftData

// MARK: - Category Management View

struct CategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomCategory.sortOrder) private var allCategories: [CustomCategory]

    @State private var showingAddSheet   = false
    @State private var editingCategory: CustomCategory? = nil
    @State private var showingArchived   = false
    @State private var searchText        = ""

    private var rootCategories: [CustomCategory] {
        allCategories.filter { $0.isRoot && !$0.isArchived }
    }

    private var archivedCategories: [CustomCategory] {
        allCategories.filter { $0.isArchived }
    }

    private var filtered: [CustomCategory] {
        guard !searchText.isEmpty else { return rootCategories }
        return allCategories.filter {
            !$0.isArchived &&
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                Group {
                    if rootCategories.isEmpty && searchText.isEmpty {
                        emptyState
                    } else {
                        categoryList
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search categories…")
            .scrollContentBackground(.hidden)
            .navigationTitle("Custom Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(FTColor.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: FTSpacing.sm) {
                        if !archivedCategories.isEmpty {
                            Button {
                                showingArchived.toggle()
                            } label: {
                                Image(systemName: showingArchived ? "archivebox.fill" : "archivebox")
                                    .foregroundStyle(FTColor.textSecondary)
                            }
                        }
                        Button {
                            editingCategory = nil
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(FTColor.accent)
                                .font(.system(size: 20))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                EditCategoryView(category: nil, parentCategory: nil)
            }
            .sheet(item: $editingCategory) { cat in
                EditCategoryView(category: cat, parentCategory: cat.parent)
            }
        }
    }

    // MARK: - List

    private var categoryList: some View {
        ScrollView {
            VStack(spacing: FTSpacing.sm) {
                if !filtered.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(filtered) { cat in
                            categorySection(cat)
                        }
                    }
                    .ftGlass(FTRadius.md)
                    .padding(.horizontal, FTSpacing.screen)
                }

                if showingArchived && !archivedCategories.isEmpty {
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("ARCHIVED")
                            .font(.ftLabel).tracking(1.4)
                            .foregroundStyle(FTColor.textMuted)
                            .padding(.horizontal, FTSpacing.screen)

                        VStack(spacing: 0) {
                            ForEach(archivedCategories) { cat in
                                archivedRow(cat)
                                if cat.id != archivedCategories.last?.id { Divider().opacity(0.4) }
                            }
                        }
                        .padding(.horizontal, FTSpacing.lg)
                        .ftGlass(FTRadius.md)
                        .padding(.horizontal, FTSpacing.screen)
                    }
                }
            }
            .padding(.top, FTSpacing.sm)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func categorySection(_ cat: CustomCategory) -> some View {
        let isLast = filtered.last?.id == cat.id && cat.sortedActiveChildren.isEmpty

        categoryRow(cat, isChild: false)
        if cat.id != filtered.last?.id || !cat.sortedActiveChildren.isEmpty {
            Divider().padding(.leading, 64).opacity(0.4)
        }

        ForEach(cat.sortedActiveChildren) { child in
            subcategoryRow(child, isLast: isLast && child.id == cat.sortedActiveChildren.last?.id)
        }
    }

    private func categoryRow(_ cat: CustomCategory, isChild: Bool) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: cat.icon, tint: cat.color, size: isChild ? 34 : 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(cat.name)
                    .font(isChild ? .ftCallout : .ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                if !cat.sortedActiveChildren.isEmpty {
                    Text("\(cat.sortedActiveChildren.count) subcategories")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                } else if cat.transactionTypeFilter != "any" {
                    Text(cat.transactionTypeFilter == "expense" ? "Expenses only" : "Income only")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FTColor.textMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, FTSpacing.lg)
        .contentShape(Rectangle())
        .onTapGesture { editingCategory = cat }
        .contextMenu {
            Button { editingCategory = cat } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                let sub = CustomCategory(name: "Subcategory", icon: cat.icon, colorHex: cat.colorHex,
                                        transactionTypeFilter: cat.transactionTypeFilter, parent: cat)
                context.insert(sub)
                try? context.save()
                editingCategory = sub
            } label: {
                Label("Add Subcategory", systemImage: "plus")
            }
            Divider()
            Button(role: .destructive) { archiveCategory(cat) } label: {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive) { deleteCategory(cat) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func subcategoryRow(_ child: CustomCategory, isLast: Bool) -> some View {
        HStack(spacing: FTSpacing.md) {
            Color.clear.frame(width: 20)
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FTColor.textMuted)
                .frame(width: 16)
            FTIconTile(symbol: child.icon, tint: child.color, size: 30)
            Text(child.name)
                .font(.ftCallout)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FTColor.textMuted)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, FTSpacing.lg)
        .contentShape(Rectangle())
        .onTapGesture { editingCategory = child }
        .contextMenu {
            Button { editingCategory = child } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) { archiveCategory(child) } label: {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive) { deleteCategory(child) } label: {
                Label("Delete", systemImage: "trash")
            }
        }

        if !isLast { Divider().padding(.leading, 72).opacity(0.3) }
    }

    private func archivedRow(_ cat: CustomCategory) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: cat.icon, tint: cat.color.opacity(0.5), size: 36)
            Text(cat.name)
                .font(.ftBody)
                .foregroundStyle(FTColor.textMuted)
            Spacer()
            Button {
                cat.isArchived = false
                try? context.save()
            } label: {
                Text("Restore")
                    .font(.ftCallout)
                    .foregroundStyle(FTColor.accent)
            }
        }
        .padding(.vertical, 11)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: FTSpacing.xl) {
            Spacer()
            FTIconTile(symbol: "tag.circle.fill", tint: FTColor.accent, size: 72)
            VStack(spacing: FTSpacing.sm) {
                Text("No Custom Categories")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Create categories with custom icons and colors to better organize your transactions.")
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FTSpacing.xxl)
            }
            Button {
                showingAddSheet = true
            } label: {
                Label("Create First Category", systemImage: "plus")
            }
            .buttonStyle(.ftPrimary)
            .padding(.horizontal, FTSpacing.screen)
            Spacer()
        }
    }

    // MARK: - Actions

    private func archiveCategory(_ cat: CustomCategory) {
        withAnimation { cat.isArchived = true }
        try? context.save()
    }

    private func deleteCategory(_ cat: CustomCategory) {
        withAnimation { context.delete(cat) }
        try? context.save()
    }
}

// MARK: - Edit Category View

struct EditCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<CustomCategory> { !$0.isArchived }, sort: \CustomCategory.sortOrder)
    private var allActiveCategories: [CustomCategory]

    let category: CustomCategory?
    let parentCategory: CustomCategory?

    @State private var name = ""
    @State private var icon = "tag"
    @State private var colorHex = "#0E9C8A"
    @State private var typeFilter = "any"
    @State private var selectedParentID: UUID? = nil
    @State private var showingIconPicker = false

    private var isEditing: Bool { category != nil }
    private var title: String { isEditing ? "Edit Category" : "New Category" }

    private var rootCandidates: [CustomCategory] {
        allActiveCategories.filter { $0.isRoot && $0.id != category?.id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        previewCard
                        formCard
                        if isEditing { deleteCard }
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
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
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $icon, tintColor: Color(hex: colorHex))
            }
            .onAppear(perform: loadData)
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: icon, tint: Color(hex: colorHex), size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Category Name" : name)
                    .font(.ftHeadline)
                    .foregroundStyle(name.isEmpty ? FTColor.textMuted : FTColor.textPrimary)
                if let pid = selectedParentID,
                   let parent = allActiveCategories.first(where: { $0.id == pid }) {
                    Text("Subcategory of \(parent.name)")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            Spacer()
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(spacing: 0) {
            // Name
            HStack(spacing: FTSpacing.md) {
                Text("Name").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                Spacer()
                TextField("Category name", text: $name)
                    .multilineTextAlignment(.trailing)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
            }
            .padding(.vertical, 13)

            Divider().opacity(0.4)

            // Icon picker button
            Button { showingIconPicker = true } label: {
                HStack(spacing: FTSpacing.md) {
                    Text("Icon").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: colorHex))
                        .frame(width: 28, height: 28)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                }
                .padding(.vertical, 13)
            }

            Divider().opacity(0.4)

            // Color palette
            VStack(alignment: .leading, spacing: FTSpacing.sm) {
                Text("Color")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.sm) {
                        ForEach(CustomCategory.paletteColors, id: \.hex) { palette in
                            Button {
                                colorHex = palette.hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: palette.hex))
                                        .frame(width: 32, height: 32)
                                    if colorHex.uppercased() == palette.hex.uppercased() {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(.vertical, 12)

            Divider().opacity(0.4)

            // Transaction type filter
            Menu {
                Picker("Type", selection: $typeFilter) {
                    Text("Any Transaction").tag("any")
                    Text("Expenses Only").tag("expense")
                    Text("Income Only").tag("income")
                }
            } label: {
                HStack(spacing: FTSpacing.md) {
                    Text("Show For").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Spacer()
                    Text(typeFilterLabel)
                        .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                }
                .padding(.vertical, 13)
            }

            // Parent category (for subcategories)
            if !rootCandidates.isEmpty {
                Divider().opacity(0.4)
                Menu {
                    Button("None (root category)") { selectedParentID = nil }
                    ForEach(rootCandidates) { candidate in
                        Button {
                            selectedParentID = candidate.id
                        } label: {
                            Label(candidate.name, systemImage: candidate.icon)
                        }
                    }
                } label: {
                    HStack(spacing: FTSpacing.md) {
                        Text("Parent").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        Text(parentLabel)
                            .font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FTColor.textMuted)
                    }
                    .padding(.vertical, 13)
                }
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    private var typeFilterLabel: String {
        switch typeFilter {
        case "expense": return "Expenses Only"
        case "income":  return "Income Only"
        default:        return "Any Transaction"
        }
    }

    private var parentLabel: String {
        if let pid = selectedParentID,
           let p = allActiveCategories.first(where: { $0.id == pid }) {
            return p.name
        }
        return "None"
    }

    // MARK: - Delete card

    private var deleteCard: some View {
        Button(role: .destructive) {
            if let cat = category { context.delete(cat) }
            try? context.save()
            dismiss()
        } label: {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(symbol: "trash", tint: FTColor.expense, size: 36)
                Text("Delete Category")
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
        guard let cat = category else {
            selectedParentID = parentCategory?.id
            return
        }
        name = cat.name
        icon = cat.icon
        colorHex = cat.colorHex
        typeFilter = cat.transactionTypeFilter
        selectedParentID = cat.parent?.id
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let parent = selectedParentID.flatMap { pid in allActiveCategories.first(where: { $0.id == pid }) }

        if let cat = category {
            cat.name = trimmed
            cat.icon = icon
            cat.colorHex = colorHex
            cat.transactionTypeFilter = typeFilter
            cat.parent = parent
        } else {
            let maxOrder = allActiveCategories.filter { $0.parent?.id == parent?.id }.map(\.sortOrder).max() ?? -1
            let newCat = CustomCategory(
                name: trimmed, icon: icon, colorHex: colorHex,
                sortOrder: maxOrder + 1, transactionTypeFilter: typeFilter, parent: parent
            )
            context.insert(newCat)
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Icon Picker View

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String
    let tintColor: Color
    @State private var search = ""

    private var filteredSections: [(section: String, icons: [String])] {
        guard !search.isEmpty else { return CustomCategory.iconSections }
        let q = search.lowercased()
        return CustomCategory.iconSections.compactMap { sec in
            let matched = sec.icons.filter { $0.contains(q) }
            return matched.isEmpty ? nil : (sec.section, matched)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: FTSpacing.xl, pinnedViews: .sectionHeaders) {
                        ForEach(filteredSections, id: \.section) { section in
                            iconSection(section)
                        }
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.sm)
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
            }
            .searchable(text: $search, prompt: "Search icons…")
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(FTColor.accent)
                }
            }
        }
    }

    private func iconSection(_ section: (section: String, icons: [String])) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text(section.section.uppercased())
                .font(.ftLabel).tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: FTSpacing.md) {
                ForEach(section.icons, id: \.self) { iconName in
                    Button {
                        selectedIcon = iconName
                        dismiss()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedIcon == iconName
                                      ? tintColor.opacity(0.2)
                                      : FTColor.textPrimary.opacity(0.05))
                            Image(systemName: iconName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(selectedIcon == iconName ? tintColor : FTColor.textSecondary)
                        }
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(selectedIcon == iconName ? tintColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
