import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct TaxDocumentVaultView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var documents: [TaxDocument]

    let taxYear: Int

    @State private var searchText = ""
    @State private var selectedType: TaxDocumentType? = nil
    @State private var showingAdd = false
    @State private var selectedDoc: TaxDocument?

    private var filtered: [TaxDocument] {
        var base = documents.filter { !$0.isArchived }
        if taxYear != 0 { base = base.filter { $0.taxYear == taxYear } }
        if let t = selectedType { base = base.filter { $0.documentType == t } }
        if !searchText.isEmpty {
            base = base.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.taxCategory.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return base.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                typeFilter
                if filtered.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .navigationTitle("Tax Document Vault")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus").font(.ftCallout).foregroundStyle(FTColor.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddTaxDocumentView(defaultYear: taxYear)
            }
            .sheet(item: $selectedDoc) { doc in
                TaxDocumentDetailView(document: doc)
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(FTColor.textMuted)
            TextField("Search documents…", text: $searchText)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(FTColor.textMuted)
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.pill)
        .padding(.horizontal, FTSpacing.screen)
        .padding(.vertical, FTSpacing.sm)
    }

    // MARK: - Type Filter

    private var typeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FilterChip(title: "All", isSelected: selectedType == nil) {
                    withAnimation { selectedType = nil }
                }
                ForEach(TaxDocumentType.allCases, id: \.rawValue) { t in
                    FilterChip(title: t.rawValue, isSelected: selectedType == t) {
                        withAnimation { selectedType = selectedType == t ? nil : t }
                    }
                }
            }
            .padding(.horizontal, FTSpacing.screen)
        }
        .padding(.vertical, FTSpacing.xs)
    }

    // MARK: - Document List

    private var documentList: some View {
        ScrollView {
            LazyVStack(spacing: FTSpacing.sm) {
                // Summary header
                HStack {
                    Text("\(filtered.count) document\(filtered.count == 1 ? "" : "s")")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    Spacer()
                    Text("Tax Year \(taxYear)")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                .padding(.horizontal, FTSpacing.screen)

                ForEach(filtered) { doc in
                    docRow(doc)
                        .padding(.horizontal, FTSpacing.screen)
                        .onTapGesture { selectedDoc = doc }
                }
            }
            .padding(.vertical, FTSpacing.md)
            .padding(.bottom, 40)
        }
    }

    private func docRow(_ doc: TaxDocument) -> some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FTRadius.sm)
                    .fill(FTColor.catTeal.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: doc.documentType.icon)
                    .font(.ftCallout).foregroundStyle(FTColor.catTeal)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary).lineLimit(1)
                HStack(spacing: FTSpacing.sm) {
                    Text(doc.documentType.rawValue).font(.ftCaption).foregroundStyle(FTColor.catTeal)
                    Text("·").foregroundStyle(FTColor.textMuted)
                    Text(String(doc.taxYear)).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    if !doc.taxCategory.isEmpty {
                        Text("·").foregroundStyle(FTColor.textMuted)
                        Text(doc.taxCategory).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
                if !doc.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(doc.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .foregroundStyle(FTColor.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(FTColor.accent.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(doc.fileSizeLabel).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.lg)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(doc)
                try? context.save()
            } label: { Label("Delete", systemImage: "trash") }

            Button {
                doc.isArchived = true
                try? context.save()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(FTColor.gold)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            Spacer()
            Image(systemName: "archivebox.fill").font(.system(size: 44)).foregroundStyle(FTColor.textMuted)
            Text("No Documents").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("Store receipts, invoices, contracts and other tax documents here.")
                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, FTSpacing.xxl)
            Button { showingAdd = true } label: {
                Label("Add Document", systemImage: "plus")
                    .font(.ftCallout).foregroundStyle(.white)
                    .padding().frame(maxWidth: 200)
                    .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }
}

// MARK: - Add Tax Document

struct AddTaxDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let defaultYear: Int

    @State private var name = ""
    @State private var docType: TaxDocumentType = .receipt
    @State private var taxYear: Int
    @State private var taxCategory = ""
    @State private var notes = ""
    @State private var tags = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedData: Data?
    @State private var selectedMIME = "image/jpeg"
    @State private var showingFilePicker = false

    init(defaultYear: Int) {
        self.defaultYear = defaultYear
        _taxYear = State(initialValue: defaultYear)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    // Document Type
                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("DOCUMENT TYPE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.sm) {
                            ForEach(TaxDocumentType.allCases, id: \.rawValue) { t in
                                Button {
                                    docType = t
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: t.icon)
                                            .font(.ftCallout)
                                            .foregroundStyle(docType == t ? FTColor.accent : FTColor.textMuted)
                                        Text(t.rawValue)
                                            .font(.ftCaption).multilineTextAlignment(.center)
                                            .foregroundStyle(docType == t ? FTColor.textPrimary : FTColor.textSecondary)
                                    }
                                    .padding(FTSpacing.md)
                                    .frame(maxWidth: .infinity)
                                    .background(docType == t ? FTColor.accent.opacity(0.12) : FTColor.textMuted.opacity(0.06),
                                                in: RoundedRectangle(cornerRadius: FTRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .ftGlass(FTRadius.xl)

                    // Fields
                    VStack(spacing: FTSpacing.sm) {
                        inputField("Document Name", text: $name, placeholder: "e.g. Q1 2024 Receipt")
                        inputField("Category", text: $taxCategory, placeholder: "e.g. Business, Medical")
                        inputField("Tags (comma separated)", text: $tags, placeholder: "vat, receipt, 2024")

                        HStack {
                            Text("Tax Year").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Picker("Tax Year", selection: $taxYear) {
                                ForEach((2020...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { y in
                                    Text(String(y)).tag(y)
                                }
                            }
                        }
                        .padding().ftGlass(FTRadius.lg)

                        TextEditor(text: $notes)
                            .font(.ftBody).frame(height: 80).padding().ftGlass(FTRadius.lg)
                            .overlay(alignment: .topLeading) {
                                if notes.isEmpty { Text("Notes (optional)")
                                    .font(.ftBody).foregroundStyle(FTColor.textMuted)
                                    .padding(.horizontal, 20).padding(.top, 16).allowsHitTesting(false) }
                            }
                    }

                    // File Picker
                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("ATTACH FILE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack {
                                Image(systemName: selectedData != nil ? "checkmark.circle.fill" : "photo.badge.plus")
                                    .foregroundStyle(selectedData != nil ? FTColor.income : FTColor.accent)
                                Text(selectedData != nil ? "Image Selected" : "Choose from Photos")
                                    .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            }
                            .padding().frame(maxWidth: .infinity).ftGlass(FTRadius.lg)
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    selectedData = data
                                    selectedMIME = "image/jpeg"
                                }
                            }
                        }
                    }

                    Button(action: save) {
                        Text("Save Document")
                            .font(.ftBodySemibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, FTSpacing.lg)
                            .background(FTColor.accentGradient, in: .rect(cornerRadius: FTRadius.pill))
                    }
                    .buttonStyle(.plain).disabled(name.isEmpty)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func inputField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            TextField(placeholder, text: text)
                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
        .padding().ftGlass(FTRadius.lg)
    }

    private func save() {
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let doc = TaxDocument(
            name: name,
            documentType: docType,
            taxYear: taxYear,
            taxCategory: taxCategory,
            fileData: selectedData ?? Data(),
            mimeType: selectedMIME,
            notes: notes.isEmpty ? nil : notes,
            tags: tagList
        )
        context.insert(doc)
        try? context.save()
        dismiss()
    }
}

// MARK: - Tax Document Detail

struct TaxDocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let document: TaxDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    // Preview
                    if document.isImage && !document.fileData.isEmpty,
                       let img = UIImage(data: document.fileData) {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg))
                    } else {
                        VStack(spacing: FTSpacing.md) {
                            Image(systemName: document.documentType.icon)
                                .font(.system(size: 52)).foregroundStyle(FTColor.catTeal)
                            Text(document.fileSizeLabel).font(.ftBody).foregroundStyle(FTColor.textMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .padding()
                        .ftGlass(FTRadius.xl)
                    }

                    VStack(spacing: FTSpacing.sm) {
                        detailRow("Document Type", document.documentType.rawValue)
                        detailRow("Tax Year", String(document.taxYear))
                        if !document.taxCategory.isEmpty { detailRow("Category", document.taxCategory) }
                        detailRow("File Size", document.fileSizeLabel)
                        detailRow("Added", document.createdAt.formatted)
                        if let notes = document.notes, !notes.isEmpty { detailRow("Notes", notes) }
                    }
                    .padding().ftGlass(FTRadius.xl)

                    if !document.tags.isEmpty {
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text("TAGS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                            FlowLayout(spacing: FTSpacing.sm) {
                                ForEach(document.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.ftCallout)
                                        .foregroundStyle(FTColor.accent)
                                        .padding(.horizontal, FTSpacing.md).padding(.vertical, 6)
                                        .background(FTColor.accent.opacity(0.12)).clipShape(Capsule())
                                }
                            }
                        }
                        .padding().ftGlass(FTRadius.lg)
                    }

                    Button(role: .destructive) {
                        context.delete(document)
                        try? context.save()
                        dismiss()
                    } label: {
                        Label("Delete Document", systemImage: "trash")
                            .font(.ftCallout).foregroundStyle(FTColor.expense)
                            .frame(maxWidth: .infinity).padding().ftGlass(FTRadius.lg)
                    }
                    .buttonStyle(.plain)
                }
                .padding(FTSpacing.screen)
            }
            .navigationTitle(document.name)
            .navigationBarTitleDisplayMode(.inline)
            .background { FTBackdrop() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
        }
    }
}

