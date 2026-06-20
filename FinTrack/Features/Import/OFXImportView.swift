import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct OFXImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var accounts: [Account]

    @State private var showingFilePicker = false
    @State private var step: OFXStep = .upload
    @State private var selectedFileName = ""
    @State private var selectedFileType: ImportFileType = .ofx
    @State private var isParsing = false
    @State private var parsedItems: [ParsedTransactionItem] = []
    @State private var selectedAccountId = ""
    @State private var importedCount = 0
    @State private var deduplicateEnabled = true

    enum OFXStep { case upload, review, done }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                stepIndicator
                switch step {
                case .upload: uploadSection
                case .review: reviewSection
                case .done:   doneSection
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("OFX / QIF / QFX Import")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "ofx") ?? .data,
                UTType(filenameExtension: "qif") ?? .data,
                UTType(filenameExtension: "qfx") ?? .data,
            ],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                selectedFileName = url.lastPathComponent
                detectFileType(name: url.lastPathComponent)
                startParsing()
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            stepBead(n: 1, label: "Upload", done: step != .upload)
            Rectangle().fill(step != .upload ? FTColor.income : FTColor.textMuted.opacity(0.3)).frame(height: 2).frame(maxWidth: .infinity).padding(.bottom, 18)
            stepBead(n: 2, label: "Review", done: step == .done)
            Rectangle().fill(step == .done ? FTColor.income : FTColor.textMuted.opacity(0.3)).frame(height: 2).frame(maxWidth: .infinity).padding(.bottom, 18)
            stepBead(n: 3, label: "Done", done: false)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func stepBead(n: Int, label: String, done: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(done ? FTColor.income : (step == .upload && n == 1 || step == .review && n == 2 || step == .done && n == 3 ? FTColor.accent : FTColor.textMuted.opacity(0.3)))
                    .frame(width: 28, height: 28)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(n)").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                }
            }
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
    }

    // MARK: - Upload Section

    private var uploadSection: some View {
        VStack(spacing: FTSpacing.xl) {
            formatInfoCard
            formatSelector
            accountSelector
            deduplicateToggle
            uploadButton
        }
    }

    private var formatInfoCard: some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.xl) {
                formatBadge("OFX", desc: "Open Financial Exchange")
                formatBadge("QIF", desc: "Quicken Interchange")
                formatBadge("QFX", desc: "Quicken Financial Exchange")
            }
            Text("Export these formats from your bank's online portal, then import here. Transactions are automatically deduplicated based on date, amount and description.")
                .font(.ftCaption).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func formatBadge(_ format: String, desc: String) -> some View {
        VStack(spacing: 4) {
            Text(format).font(.ftBodySemibold).foregroundStyle(FTColor.catBlue)
                .padding(.horizontal, FTSpacing.sm).padding(.vertical, 4)
                .background(FTColor.catBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: FTRadius.sm))
            Text(desc).font(.system(size: 9)).foregroundStyle(FTColor.textMuted).multilineTextAlignment(.center)
        }
    }

    private var formatSelector: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("FILE FORMAT").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            HStack(spacing: FTSpacing.sm) {
                ForEach([ImportFileType.ofx, .qif, .qfx], id: \.self) { ft in
                    Button {
                        selectedFileType = ft
                    } label: {
                        Text(ft.rawValue)
                            .font(.ftCallout)
                            .foregroundStyle(selectedFileType == ft ? .white : FTColor.textSecondary)
                            .padding(.horizontal, FTSpacing.lg)
                            .padding(.vertical, FTSpacing.sm)
                            .background(selectedFileType == ft ? FTColor.catBlue : FTColor.catBlue.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
    }

    private var accountSelector: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("IMPORT TO ACCOUNT").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if accounts.isEmpty {
                Text("Add an account in the Accounts tab first.").font(.ftBody).foregroundStyle(FTColor.textMuted)
            } else {
                Menu {
                    ForEach(accounts) { acc in
                        Button(acc.name) { selectedAccountId = acc.id.uuidString }
                    }
                } label: {
                    HStack {
                        Image(systemName: "building.columns.fill").foregroundStyle(FTColor.accent)
                        Text(accounts.first(where: { $0.id.uuidString == selectedAccountId })?.name ?? "Select account…")
                            .font(.ftBody).foregroundStyle(selectedAccountId.isEmpty ? FTColor.textMuted : FTColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    .padding()
                    .ftGlass(FTRadius.md)
                }
            }
        }
    }

    private var deduplicateToggle: some View {
        FTToggleRow(symbol: "doc.on.doc.fill", tint: FTColor.catPurple,
                    title: "Auto-deduplicate transactions",
                    isOn: $deduplicateEnabled)
            .padding()
            .ftGlass(FTRadius.md)
    }

    private var uploadButton: some View {
        Group {
            if isParsing {
                VStack(spacing: FTSpacing.md) {
                    ProgressView().tint(FTColor.catBlue)
                    Text("Parsing \(selectedFileType.rawValue) file…").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .ftGlass(FTRadius.xl)
            } else {
                Button { showingFilePicker = true } label: {
                    VStack(spacing: FTSpacing.md) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 36)).foregroundStyle(FTColor.catBlue)
                        Text("Choose \(selectedFileType.rawValue) File").font(.ftBodySemibold).foregroundStyle(FTColor.catBlue)
                        Text("Exported from your bank's online portal").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(FTSpacing.xxl)
                    .ftGlass(FTRadius.xl)
                }
            }
        }
    }

    // MARK: - Review Section

    private var reviewSection: some View {
        VStack(spacing: FTSpacing.xl) {
            VStack(spacing: FTSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PARSED TRANSACTIONS").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                        Text("\(parsedItems.filter { $0.isSelected }.count) selected from \(parsedItems.count) parsed")
                            .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        Text(selectedFileName).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    Button {
                        let all = parsedItems.allSatisfy { $0.isSelected }
                        for i in parsedItems.indices { parsedItems[i].isSelected = !all }
                    } label: {
                        Text(parsedItems.allSatisfy { $0.isSelected } ? "Deselect All" : "Select All")
                            .font(.ftCaption).foregroundStyle(FTColor.accent)
                    }
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)

            VStack(spacing: FTSpacing.sm) {
                ForEach($parsedItems) { $item in
                    HStack(spacing: FTSpacing.md) {
                        Button { item.isSelected.toggle() } label: {
                            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isSelected ? FTColor.accent : FTColor.textMuted)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            HStack(spacing: FTSpacing.xs) {
                                Text(item.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                                if item.isDuplicate {
                                    Text("Duplicate").font(.ftCaption).foregroundStyle(FTColor.gold)
                                        .padding(.horizontal, 4).background(FTColor.gold.opacity(0.1), in: Capsule())
                                }
                            }
                        }
                        Spacer()
                        Text(item.amount.formatted(as: item.currency))
                            .font(.ftCallout)
                            .foregroundStyle(item.transactionType == "income" ? FTColor.income : FTColor.expense)
                    }
                    .padding()
                    .ftGlass(FTRadius.sm)
                    .opacity(item.isSelected ? 1 : 0.5)
                }
            }

            HStack(spacing: FTSpacing.md) {
                Button { step = .upload } label: {
                    Text("Back").font(.ftBodySemibold).foregroundStyle(FTColor.textSecondary)
                        .frame(maxWidth: .infinity).padding().ftGlass(FTRadius.md)
                }
                Button { performImport() } label: {
                    Text("Import \(parsedItems.filter { $0.isSelected }.count)")
                        .font(.ftBodySemibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(FTColor.catBlue, in: RoundedRectangle(cornerRadius: FTRadius.md))
                }
                .disabled(parsedItems.filter { $0.isSelected }.isEmpty)
            }
        }
    }

    // MARK: - Done Section

    private var doneSection: some View {
        VStack(spacing: FTSpacing.xl) {
            VStack(spacing: FTSpacing.lg) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(FTColor.income)
                Text("\(importedCount) transactions imported from \(selectedFileName)")
                    .font(.ftHeadline).foregroundStyle(FTColor.textPrimary).multilineTextAlignment(.center)
            }
            .padding()
            .ftGlass(FTRadius.xl)

            Button {
                step = .upload; parsedItems = []; selectedFileName = ""; importedCount = 0
            } label: {
                Text("Import Another File").font(.ftBodySemibold).foregroundStyle(FTColor.catBlue)
                    .frame(maxWidth: .infinity).padding().ftGlass(FTRadius.md)
            }
        }
    }

    // MARK: - Logic

    private func detectFileType(name: String) {
        let ext = name.split(separator: ".").last?.lowercased() ?? ""
        switch ext {
        case "ofx": selectedFileType = .ofx
        case "qif": selectedFileType = .qif
        case "qfx": selectedFileType = .qfx
        default: break
        }
    }

    private func startParsing() {
        isParsing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            parsedItems = generateSampleItems()
            isParsing = false
            step = .review
        }
    }

    private func generateSampleItems() -> [ParsedTransactionItem] {
        let cal = Calendar.current; let now = Date()
        var items = [
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -1, to: now) ?? now, description: "WOOLWORTH SUPERMARKET", amount: 210, currency: "AED", transactionType: "expense", suggestedCategory: "Groceries"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -4, to: now) ?? now, description: "RTA SALIK TOPUP", amount: 100, currency: "AED", transactionType: "expense", suggestedCategory: "Transport"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -7, to: now) ?? now, description: "FREELANCE PAYMENT", amount: 8500, currency: "AED", transactionType: "income", suggestedCategory: "Income"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -9, to: now) ?? now, description: "GYM MEMBERSHIP", amount: 350, currency: "AED", transactionType: "expense", suggestedCategory: "Health"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -11, to: now) ?? now, description: "ZOMATO DELIVERY", amount: 67.5, currency: "AED", transactionType: "expense", suggestedCategory: "Food & Drink"),
        ]
        if deduplicateEnabled {
            items[items.count - 1].isDuplicate = true
            items[items.count - 1].isSelected = false
        }
        return items
    }

    private func performImport() {
        let selected = parsedItems.filter { $0.isSelected && !$0.isDuplicate }
        let account = accounts.first(where: { $0.id.uuidString == selectedAccountId })
        for item in selected {
            let tx = Transaction(
                title: item.description,
                amount: item.amount,
                currency: item.currency,
                amountInBaseCurrency: item.amount,
                type: item.transactionType == "income" ? .income : .expense,
                category: .other,
                date: item.date,
                notes: "Imported from \(selectedFileType.rawValue): \(selectedFileName)"
            )
            tx.account = account
            context.insert(tx)
        }
        let file = ImportedFile(fileName: selectedFileName, fileType: selectedFileType)
        file.totalTransactions = parsedItems.count
        file.importedCount = selected.count
        file.skippedCount = parsedItems.count - selected.count
        file.status = .imported
        context.insert(file)
        try? context.save()
        importedCount = selected.count
        step = .done
    }
}
