import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PDFImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var accounts: [Account]

    @State private var step: ImportStep = .upload
    @State private var showingFilePicker = false
    @State private var selectedFileName = ""
    @State private var selectedBankName = ""
    @State private var isParsingFile = false
    @State private var parsedItems: [ParsedTransactionItem] = []
    @State private var currentImport: ImportedFile?
    @State private var selectedAccountId: String = ""
    @State private var showingSuccess = false
    @State private var importedCount = 0

    enum ImportStep {
        case upload, review, done
    }

    private let supportedBanks = [
        "Emirates NBD", "FAB (First Abu Dhabi Bank)", "ADCB", "Dubai Islamic Bank",
        "Mashreq", "RAK Bank", "HSBC UAE", "Standard Chartered UAE", "Other"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                stepIndicator
                switch step {
                case .upload: uploadSection
                case .review: reviewSection
                case .done:   successSection
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("PDF Import")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                selectedFileName = url.lastPathComponent
                simulateAIParsing(fileName: url.lastPathComponent)
            case .failure:
                break
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            stepDot(n: 1, label: "Upload", active: step == .upload, done: step == .review || step == .done)
            stepLine(done: step == .review || step == .done)
            stepDot(n: 2, label: "Review", active: step == .review, done: step == .done)
            stepLine(done: step == .done)
            stepDot(n: 3, label: "Done", active: step == .done, done: false)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func stepDot(n: Int, label: String, active: Bool, done: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(active ? FTColor.accent : done ? FTColor.income : FTColor.textMuted.opacity(0.3))
                    .frame(width: 28, height: 28)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(n)").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                }
            }
            Text(label).font(.ftCaption).foregroundStyle(active ? FTColor.accent : FTColor.textMuted)
        }
    }

    private func stepLine(done: Bool) -> some View {
        Rectangle()
            .fill(done ? FTColor.income : FTColor.textMuted.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
    }

    // MARK: - Upload Section

    private var uploadSection: some View {
        VStack(spacing: FTSpacing.xl) {
            infoCard
            bankSelector
            accountSelector
            uploadButton
        }
    }

    private var infoCard: some View {
        VStack(spacing: FTSpacing.md) {
            Image(systemName: "brain.fill")
                .font(.system(size: 44)).foregroundStyle(FTColor.accent)
            Text("AI-Powered Statement Parsing").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Text("Upload your PDF bank statement. Our AI engine will automatically detect transactions, dates, and categories — then let you review before importing.")
                .font(.ftBody).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var bankSelector: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("BANK").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            Menu {
                ForEach(supportedBanks, id: \.self) { bank in
                    Button(bank) { selectedBankName = bank }
                }
            } label: {
                HStack {
                    Image(systemName: "building.2.fill").foregroundStyle(FTColor.catBlue)
                    Text(selectedBankName.isEmpty ? "Select bank…" : selectedBankName)
                        .font(.ftBody).foregroundStyle(selectedBankName.isEmpty ? FTColor.textMuted : FTColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                .padding()
                .ftGlass(FTRadius.md)
            }
        }
    }

    private var accountSelector: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("IMPORT TO ACCOUNT").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if accounts.isEmpty {
                Text("No accounts found. Add an account first.").font(.ftBody).foregroundStyle(FTColor.textMuted)
            } else {
                Menu {
                    ForEach(accounts) { acc in
                        Button(acc.name) { selectedAccountId = acc.id.uuidString }
                    }
                } label: {
                    HStack {
                        Image(systemName: "building.columns.fill").foregroundStyle(FTColor.accent)
                        let name = accounts.first(where: { $0.id.uuidString == selectedAccountId })?.name ?? "Select account…"
                        Text(name)
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

    private var uploadButton: some View {
        Group {
            if isParsingFile {
                VStack(spacing: FTSpacing.md) {
                    ProgressView().tint(FTColor.accent)
                    Text("AI is parsing your statement…").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    Text(selectedFileName).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .ftGlass(FTRadius.xl)
            } else {
                Button { showingFilePicker = true } label: {
                    VStack(spacing: FTSpacing.md) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 36)).foregroundStyle(FTColor.accent)
                        Text("Choose PDF Statement").font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                        Text("Supports all major UAE banks").font(.ftCaption).foregroundStyle(FTColor.textMuted)
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
            reviewSummary
            reviewList
            importActionBar
        }
    }

    private var reviewSummary: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PARSED TRANSACTIONS").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text("\(parsedItems.filter { $0.isSelected }.count) of \(parsedItems.count) selected")
                        .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text(selectedFileName).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                Spacer()
                Button {
                    let allSelected = parsedItems.allSatisfy { $0.isSelected }
                    for i in parsedItems.indices { parsedItems[i].isSelected = !allSelected }
                } label: {
                    Text(parsedItems.allSatisfy { $0.isSelected } ? "Deselect All" : "Select All")
                        .font(.ftCaption).foregroundStyle(FTColor.accent)
                }
            }
            let selectedTotal = parsedItems.filter { $0.isSelected && $0.transactionType == "expense" }
                                          .reduce(0) { $0 + $1.amount }
            let selectedIncome = parsedItems.filter { $0.isSelected && $0.transactionType == "income" }
                                           .reduce(0) { $0 + $1.amount }
            HStack(spacing: FTSpacing.sm) {
                reviewTile("Expense", value: selectedTotal, color: FTColor.expense)
                reviewTile("Income", value: selectedIncome, color: FTColor.income)
                reviewTile("Duplicates", raw: "\(parsedItems.filter { $0.isDuplicate }.count)", color: FTColor.gold)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func reviewTile(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value.asCompact(currency: appState.baseCurrency)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.sm)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    private func reviewTile(_ label: String, raw: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(raw).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.sm)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    private var reviewList: some View {
        VStack(spacing: FTSpacing.sm) {
            ForEach($parsedItems) { $item in
                parsedItemRow(item: $item)
            }
        }
    }

    private func parsedItemRow(item: Binding<ParsedTransactionItem>) -> some View {
        HStack(spacing: FTSpacing.md) {
            Button {
                item.wrappedValue.isSelected.toggle()
            } label: {
                Image(systemName: item.wrappedValue.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.wrappedValue.isSelected ? FTColor.accent : FTColor.textMuted)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.wrappedValue.description).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                HStack(spacing: FTSpacing.xs) {
                    Text(item.wrappedValue.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    Text(item.wrappedValue.suggestedCategory).font(.ftCaption).foregroundStyle(FTColor.catBlue)
                        .padding(.horizontal, 4).background(FTColor.catBlue.opacity(0.1), in: Capsule())
                    if item.wrappedValue.isDuplicate {
                        Text("Duplicate").font(.ftCaption).foregroundStyle(FTColor.gold)
                            .padding(.horizontal, 4).background(FTColor.gold.opacity(0.1), in: Capsule())
                    }
                }
            }

            Spacer()

            Text(item.wrappedValue.amount.formatted(as: item.wrappedValue.currency))
                .font(.ftCallout)
                .foregroundStyle(item.wrappedValue.transactionType == "income" ? FTColor.income : FTColor.expense)
        }
        .padding()
        .ftGlass(FTRadius.md)
        .opacity(item.wrappedValue.isSelected ? 1 : 0.5)
    }

    private var importActionBar: some View {
        HStack(spacing: FTSpacing.md) {
            Button { step = .upload; parsedItems = [] } label: {
                Text("Back").font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .ftGlass(FTRadius.md)
            }
            Button { performImport() } label: {
                Text("Import \(parsedItems.filter { $0.isSelected }.count) Transactions")
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(FTColor.accent, in: RoundedRectangle(cornerRadius: FTRadius.md))
            }
            .disabled(parsedItems.filter { $0.isSelected }.isEmpty)
        }
    }

    // MARK: - Success Section

    private var successSection: some View {
        VStack(spacing: FTSpacing.xl) {
            VStack(spacing: FTSpacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64)).foregroundStyle(FTColor.income)
                Text("Import Complete!").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("\(importedCount) transactions imported successfully.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
            }
            .padding()
            .ftGlass(FTRadius.xl)

            Button {
                step = .upload
                selectedFileName = ""
                selectedBankName = ""
                parsedItems = []
                importedCount = 0
            } label: {
                Text("Import Another File")
                    .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .ftGlass(FTRadius.md)
            }
        }
    }

    // MARK: - Logic

    private func simulateAIParsing(fileName: String) {
        isParsingFile = true
        let file = ImportedFile(fileName: fileName, fileType: .pdf, bankName: selectedBankName.isEmpty ? nil : selectedBankName)
        context.insert(file)
        currentImport = file

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let generated = generateSampleParsedItems()
            parsedItems = generated
            file.parsedItems = generated
            file.totalTransactions = generated.count
            file.status = .review
            try? context.save()
            isParsingFile = false
            step = .review
        }
    }

    private func generateSampleParsedItems() -> [ParsedTransactionItem] {
        let cal = Calendar.current
        let now = Date()
        return [
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -2, to: now) ?? now, description: "CARREFOUR HYPERMARKET", amount: 345.50, currency: "AED", transactionType: "expense", suggestedCategory: "Groceries"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -3, to: now) ?? now, description: "SALARY CREDIT", amount: 15000, currency: "AED", transactionType: "income", suggestedCategory: "Salary"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -5, to: now) ?? now, description: "ETISALAT PAYMENT", amount: 299, currency: "AED", transactionType: "expense", suggestedCategory: "Utilities"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -6, to: now) ?? now, description: "AMAZON.AE", amount: 189.99, currency: "AED", transactionType: "expense", suggestedCategory: "Shopping"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -8, to: now) ?? now, description: "DEWA ELECTRICITY", amount: 412, currency: "AED", transactionType: "expense", suggestedCategory: "Utilities"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -10, to: now) ?? now, description: "TALABAT ORDER", amount: 85.75, currency: "AED", transactionType: "expense", suggestedCategory: "Food & Drink"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -12, to: now) ?? now, description: "DUBAI MALL PARKING", amount: 20, currency: "AED", transactionType: "expense", suggestedCategory: "Transport"),
            ParsedTransactionItem(date: cal.date(byAdding: .day, value: -15, to: now) ?? now, description: "NETFLIX SUBSCRIPTION", amount: 49.99, currency: "AED", transactionType: "expense", suggestedCategory: "Entertainment"),
        ]
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
                notes: "Imported from PDF: \(selectedFileName)",
                isVerified: false,
                isPending: false
            )
            tx.account = account
            context.insert(tx)
        }
        currentImport?.importedCount = selected.count
        currentImport?.status = .imported
        try? context.save()
        importedCount = selected.count
        step = .done
    }
}
