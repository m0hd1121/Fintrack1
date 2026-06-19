import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var existingTransactions: [Transaction]
    @Query private var accounts: [Account]

    enum ImportStep { case upload, map, preview }
    @State private var step: ImportStep = .upload

    @State private var csvHeaders: [String] = []
    @State private var csvRows: [[String: String]] = []
    @State private var mapping = CSVColumnMapping()
    @State private var importResult: CSVImportResult? = nil
    @State private var skipDuplicates = true
    @State private var selectedAccountID: UUID? = nil
    @State private var showingFilePicker = false
    @State private var isImporting = false
    @State private var importedCount: Int? = nil
    @State private var fileError: String? = nil

    private let service = CSVImportService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                Group {
                    switch step {
                    case .upload:  uploadStep
                    case .map:     mappingStep
                    case .preview: previewStep
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .data],
                allowsMultipleSelection: false
            ) { handleFileImport($0) }
        }
    }

    private var stepTitle: String {
        switch step {
        case .upload:  return "Import CSV"
        case .map:     return "Map Columns"
        case .preview: return "Preview & Import"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if step == .upload {
                Button("Cancel") { dismiss() }
            } else {
                Button {
                    withAnimation { step = step == .preview ? .map : .upload }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        if step == .map {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Preview") { buildPreview() }
                    .font(.ftBodySemibold)
                    .foregroundStyle(mapping.isValid ? FTColor.accent : FTColor.textMuted)
                    .disabled(!mapping.isValid)
            }
        }
    }

    // MARK: - Step 1: Upload

    private var uploadStep: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                VStack(spacing: FTSpacing.lg) {
                    Image(systemName: "doc.text.below.ecg")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(FTColor.accent)
                        .padding(.top, FTSpacing.xl)

                    Text("Import Transactions from CSV")
                        .font(.ftHeadline)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Upload a CSV exported from your bank or another app. FinTrack will auto-detect the column layout.")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, FTSpacing.screen)

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("SUPPORTED FORMATS")
                        .font(.ftLabel).tracking(1.4)
                        .foregroundStyle(FTColor.textSecondary)
                    formatNote(icon: "comma", text: "Comma-separated (.csv)")
                    formatNote(icon: "tablecells", text: "Tab-separated (.tsv)")
                    formatNote(icon: "doc.plaintext", text: "Pipe / semicolon delimited (.txt)")
                }
                .padding(FTSpacing.lg)
                .ftGlass(FTRadius.md)
                .padding(.horizontal, FTSpacing.screen)

                if let error = fileError {
                    HStack(spacing: FTSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(FTColor.expense)
                        Text(error)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.expense)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(FTSpacing.md)
                    .background(FTColor.expense.opacity(0.1), in: .rect(cornerRadius: FTRadius.md))
                    .padding(.horizontal, FTSpacing.screen)
                }

                Button { showingFilePicker = true } label: {
                    Label("Choose File", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.ftPrimary)
                .padding(.horizontal, FTSpacing.screen)

                Color.clear.frame(height: 60)
            }
        }
    }

    private func formatNote(icon: String, text: String) -> some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(FTColor.accent)
                .frame(width: 20)
            Text(text)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
    }

    // MARK: - Step 2: Map Columns

    private var mappingStep: some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(csvHeaders.count) columns · \(csvRows.count) rows detected")
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                        Text("Map each field. Required fields are marked *")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, FTSpacing.screen)

                // Required
                columnGroup(title: "REQUIRED", rows: [
                    ("Date *",                $mapping.dateColumn),
                    ("Title / Description *",  $mapping.titleColumn),
                    ("Amount *",               $mapping.amountColumn),
                ])

                // Optional
                columnGroup(title: "OPTIONAL", rows: [
                    ("Category",              $mapping.categoryColumn),
                    ("Merchant / Payee",       $mapping.merchantColumn),
                    ("Notes / Memo",           $mapping.notesColumn),
                    ("Currency",               $mapping.currencyColumn),
                    ("Transaction Type",       $mapping.typeColumn),
                    ("Tags",                   $mapping.tagsColumn),
                ])

                // Date format
                VStack(alignment: .leading, spacing: 0) {
                    sectionLabel("DATE FORMAT")
                    HStack {
                        Text("Format string")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        TextField("yyyy-MM-dd", text: $mapping.dateFormat)
                            .font(.ftBodySemibold)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .padding(.vertical, 13)
                }
                .ftGlass(FTRadius.md)
                .padding(.horizontal, FTSpacing.screen)

                // Defaults
                VStack(alignment: .leading, spacing: 0) {
                    sectionLabel("DEFAULTS")
                    HStack {
                        Text("Default Currency")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                        Spacer()
                        TextField("AED", text: $mapping.currencyDefault)
                            .font(.ftBodySemibold)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                    }
                    .padding(.horizontal, FTSpacing.lg)
                    .padding(.vertical, 13)
                }
                .ftGlass(FTRadius.md)
                .padding(.horizontal, FTSpacing.screen)

                Button("Preview Import") { buildPreview() }
                    .buttonStyle(.ftPrimary)
                    .disabled(!mapping.isValid)
                    .opacity(mapping.isValid ? 1 : 0.5)
                    .padding(.horizontal, FTSpacing.screen)

                Color.clear.frame(height: 80)
            }
            .padding(.top, FTSpacing.sm)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.ftLabel).tracking(1.4)
            .foregroundStyle(FTColor.textSecondary)
            .padding(.horizontal, FTSpacing.lg)
            .padding(.top, FTSpacing.md)
            .padding(.bottom, FTSpacing.sm)
    }

    private func columnGroup(title: String, rows: [(String, Binding<String?>)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(title)
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                columnPicker(label: row.0, selection: row.1)
                if idx < rows.count - 1 {
                    Divider().padding(.leading, FTSpacing.lg)
                }
            }
        }
        .ftGlass(FTRadius.md)
        .padding(.horizontal, FTSpacing.screen)
    }

    private func columnPicker(label: String, selection: Binding<String?>) -> some View {
        HStack(spacing: FTSpacing.md) {
            Text(label)
                .font(.ftBody)
                .foregroundStyle(FTColor.textSecondary)
                .layoutPriority(1)
            Spacer()
            Menu {
                Button("None") { selection.wrappedValue = nil }
                ForEach(csvHeaders, id: \.self) { header in
                    Button(header) { selection.wrappedValue = header }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selection.wrappedValue ?? "None")
                        .font(.ftBodySemibold)
                        .foregroundStyle(selection.wrappedValue != nil ? FTColor.textPrimary : FTColor.textMuted)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FTColor.textMuted)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.vertical, 13)
    }

    // MARK: - Step 3: Preview

    @ViewBuilder
    private var previewStep: some View {
        if let result = importResult {
            previewContent(result: result)
        }
    }

    private func previewContent(result: CSVImportResult) -> some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                // Summary tiles
                VStack(spacing: FTSpacing.md) {
                    HStack(spacing: FTSpacing.md) {
                        summaryTile(count: result.validRows.count, label: "To Import", color: FTColor.income)
                        summaryTile(count: result.duplicates.count, label: "Duplicates", color: FTColor.gold)
                        summaryTile(count: result.skippedCount, label: "Skipped", color: FTColor.expense)
                    }

                    if !result.duplicates.isEmpty {
                        Toggle(isOn: $skipDuplicates) {
                            Text("Skip duplicate transactions")
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                        }
                        .tint(FTColor.accent)
                    }

                    // Account assignment
                    if !accounts.filter({ !$0.isArchived }).isEmpty {
                        HStack {
                            Text("Assign to account")
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Menu {
                                Button("None") { selectedAccountID = nil }
                                ForEach(accounts.filter { !$0.isArchived }) { acc in
                                    Button(acc.name) { selectedAccountID = acc.id }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(accounts.first(where: { $0.id == selectedAccountID })?.name ?? "None")
                                        .font(.ftBodySemibold)
                                        .foregroundStyle(FTColor.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(FTColor.textMuted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(FTSpacing.lg)
                .ftGlass(FTRadius.md)
                .padding(.horizontal, FTSpacing.screen)

                // Preview rows
                if !result.rows.isEmpty {
                    let previewRows = Array(result.rows.prefix(5))
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("PREVIEW (first \(previewRows.count) of \(result.rows.count))")
                            .font(.ftLabel).tracking(1.4)
                            .foregroundStyle(FTColor.textSecondary)

                        VStack(spacing: 0) {
                            ForEach(Array(previewRows.enumerated()), id: \.element.id) { idx, row in
                                HStack(spacing: FTSpacing.sm) {
                                    FTIconTile(symbol: row.category.icon,
                                               tint: Color.fromString(row.category.color),
                                               size: 34)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(row.title)
                                                .font(.ftCallout)
                                                .foregroundStyle(FTColor.textPrimary)
                                                .lineLimit(1)
                                            if row.isDuplicate {
                                                Text("DUP")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                                    .background(FTColor.gold, in: Capsule())
                                            }
                                        }
                                        Text(row.date.formatted + " · " + row.category.rawValue)
                                            .font(.ftCaption)
                                            .foregroundStyle(FTColor.textSecondary)
                                    }

                                    Spacer()

                                    Text((row.type == .expense ? "-" : "+") + row.amount.formatted(as: row.currency))
                                        .font(.ftCallout)
                                        .foregroundStyle(row.type == .expense ? FTColor.expense : FTColor.income)
                                }
                                .padding(.vertical, FTSpacing.sm)

                                if idx < previewRows.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.md)
                    .padding(.horizontal, FTSpacing.screen)
                }

                // Import result confirmation
                if let count = importedCount {
                    Label("\(count) transactions imported successfully.", systemImage: "checkmark.circle.fill")
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.income)
                        .padding(FTSpacing.lg)
                        .frame(maxWidth: .infinity)
                        .background(FTColor.income.opacity(0.1), in: .rect(cornerRadius: FTRadius.md))
                        .padding(.horizontal, FTSpacing.screen)
                }

                let rowsToImport = skipDuplicates ? result.validRows : result.rows
                if importedCount == nil {
                    Button {
                        performImport(rows: rowsToImport)
                    } label: {
                        if isImporting {
                            HStack(spacing: FTSpacing.sm) {
                                ProgressView().tint(.white)
                                Text("Importing…")
                            }
                        } else {
                            Text("Import \(rowsToImport.count) Transaction\(rowsToImport.count == 1 ? "" : "s")")
                        }
                    }
                    .buttonStyle(.ftPrimary)
                    .disabled(isImporting || rowsToImport.isEmpty)
                    .padding(.horizontal, FTSpacing.screen)
                } else {
                    Button("Done") { dismiss() }
                        .buttonStyle(.ftPrimary)
                        .padding(.horizontal, FTSpacing.screen)
                }

                Color.clear.frame(height: 80)
            }
            .padding(.top, FTSpacing.sm)
        }
    }

    private func summaryTile(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.ftAmount)
                .foregroundStyle(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.sm)
        .background(color.opacity(0.08), in: .rect(cornerRadius: FTRadius.md))
    }

    // MARK: - File Import Handler

    private func handleFileImport(_ result: Result<[URL], Error>) {
        fileError = nil
        switch result {
        case .failure(let err):
            fileError = err.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else {
                fileError = "Failed to read the selected file."
                return
            }

            let (headers, rows) = service.parseCSV(data: data)
            guard !headers.isEmpty, !rows.isEmpty else {
                fileError = "The file appears to be empty or could not be parsed."
                return
            }

            csvHeaders = headers
            csvRows = rows
            mapping = service.suggestMapping(for: headers)

            if let dateCol = mapping.dateColumn {
                let samples = rows.prefix(10).compactMap { $0[dateCol] }
                mapping.dateFormat = service.detectDateFormat(samples: Array(samples))
            }
            mapping.currencyDefault = appState.baseCurrency

            withAnimation { step = .map }
        }
    }

    private func buildPreview() {
        let mapped = service.mapRows(csvRows, mapping: mapping, existingTransactions: existingTransactions)
        importResult = CSVImportResult(rows: mapped, skippedCount: csvRows.count - mapped.count, headers: csvHeaders)
        withAnimation { step = .preview }
    }

    private func performImport(rows: [CSVImportRow]) {
        isImporting = true
        let targetAccount = accounts.first(where: { $0.id == selectedAccountID })

        Task {
            var count = 0
            for row in rows {
                let tx = Transaction(
                    title: row.title,
                    amount: row.amount,
                    currency: row.currency,
                    amountInBaseCurrency: row.amount,
                    type: row.type,
                    category: row.category,
                    date: row.date,
                    notes: row.notes,
                    merchant: row.merchant,
                    tags: row.tags,
                    isDuplicate: row.isDuplicate
                )
                tx.account = targetAccount
                context.insert(tx)
                count += 1
            }
            try? context.save()
            await MainActor.run {
                importedCount = count
                isImporting = false
            }
        }
    }
}
