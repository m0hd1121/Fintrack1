import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @Query private var profiles: [UserProfile]
    @Query private var transactions: [Transaction]
    @Query private var exportAccounts: [Account]
    @Query private var budgets: [Budget]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var creditCards: [CreditCard]
    @Query private var loans: [Loan]
    @Query private var bnplPlans: [BNPLPlan]
    @Query private var investments: [Investment]
    @Query private var cryptoHoldings: [CryptoHolding]
    @Query private var goldHoldings: [GoldHolding]
    @Query private var giftCards: [GiftCard]
    @Query private var loyaltyPrograms: [LoyaltyProgram]

    private var setting: AppSettings? { settings.first }
    private var profile: UserProfile? { profiles.first }

    @State private var showingCurrencyPicker = false
    @State private var showingPINSetup = false
    @State private var showingAbout = false
    @State private var showingCategoryManagement = false
    @State private var showingRuleManagement = false

    // Backup import/export
    @State private var showingImporter = false
    @State private var pendingImportURL: URL?
    @State private var showingImportMode = false
    @State private var showingResult = false
    @State private var showingClearConfirm = false
    @State private var resultMessage = ""

    // MARK: - Bindings

    private var biometricsBinding: Binding<Bool> {
        Binding(get: { setting?.useBiometrics ?? true },
                set: { setting?.useBiometrics = $0; try? context.save() })
    }
    private var pinBinding: Binding<Bool> {
        Binding(get: { setting?.usePIN ?? false },
                set: { newValue in
                    setting?.usePIN = newValue
                    if newValue { showingPINSetup = true }
                    try? context.save()
                })
    }
    private var notificationsBinding: Binding<Bool> {
        Binding(get: { setting?.notificationsEnabled ?? true },
                set: { setting?.notificationsEnabled = $0; try? context.save() })
    }
    private var budgetAlertsBinding: Binding<Bool> {
        Binding(get: { setting?.budgetAlertsEnabled ?? true },
                set: { setting?.budgetAlertsEnabled = $0; try? context.save() })
    }
    private var billRemindersBinding: Binding<Bool> {
        Binding(get: { setting?.billRemindersEnabled ?? true },
                set: { setting?.billRemindersEnabled = $0; try? context.save() })
    }
    private var cloudSyncBinding: Binding<Bool> {
        Binding(get: { setting?.cloudSyncEnabled ?? false },
                set: { setting?.cloudSyncEnabled = $0; try? context.save() })
    }
    private var autoLockBinding: Binding<Int> {
        Binding(get: { setting?.autoLockMinutes ?? 5 },
                set: { setting?.autoLockMinutes = $0; try? context.save() })
    }
    private var autoLockText: String {
        switch autoLockBinding.wrappedValue {
        case 0:  return "Never"
        case 1:  return "1 minute"
        default: return "\(autoLockBinding.wrappedValue) minutes"
        }
    }

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    profileCard

                    sectionCard("Premium Features") {
                        NavigationLink(destination: AICFOModeView()) {
                            settingRow(symbol: "brain.head.profile", tint: FTColor.accent,
                                       title: "AI CFO Mode", chevron: true)
                        }
                        rowDivider
                        NavigationLink(destination: RetirementSimulationView()) {
                            settingRow(symbol: "sun.max.fill", tint: FTColor.gold,
                                       title: "Retirement Simulation", chevron: true)
                        }
                        rowDivider
                        NavigationLink(destination: LifeEventPlanningView()) {
                            settingRow(symbol: "star.fill", tint: FTColor.catPurple,
                                       title: "Life Event Planning", chevron: true)
                        }
                        rowDivider
                        NavigationLink(destination: EstatePlanningView()) {
                            settingRow(symbol: "scroll.fill", tint: FTColor.catCoral,
                                       title: "Estate Planning", chevron: true)
                        }
                        rowDivider
                        NavigationLink(destination: InsuranceOptimizerView()) {
                            settingRow(symbol: "shield.fill", tint: FTColor.catTeal,
                                       title: "Insurance Optimizer", chevron: true)
                        }
                        rowDivider
                        NavigationLink(destination: SmartCashAllocationView()) {
                            settingRow(symbol: "lightbulb.fill", tint: FTColor.income,
                                       title: "Smart Cash Allocation", chevron: true)
                        }
                        rowDivider
                        NavigationLink(destination: CollaborativePlannerView()) {
                            settingRow(symbol: "person.3.fill", tint: FTColor.catBlue,
                                       title: "Collaborative Planner", chevron: true)
                        }
                        rowDivider
                        NavigationLink(destination: FinancialEducationView()) {
                            settingRow(symbol: "book.fill", tint: FTColor.catPurple,
                                       title: "Financial Education", chevron: true)
                        }
                        rowDivider
                        NavigationLink(destination: RemittanceTrackerView()) {
                            settingRow(symbol: "arrow.up.right.circle.fill", tint: FTColor.accent,
                                       title: "Remittance Tracker", chevron: true)
                        }
                    }

                    sectionCard("Tax Management") {
                        NavigationLink(destination: TaxManagementView()) {
                            settingRow(symbol: "doc.text.fill", tint: FTColor.catPurple,
                                       title: "Tax Management", chevron: true)
                        }
                    }

                    sectionCard("Family Finance") {
                        NavigationLink(destination: FamilyFinanceView()) {
                            settingRow(symbol: "person.3.fill", tint: FTColor.catTeal,
                                       title: "Family & Shared Finance", chevron: true)
                        }
                    }

                    sectionCard("Business & Freelancer") {
                        NavigationLink(destination: BusinessFreelancerView()) {
                            settingRow(symbol: "briefcase.fill", tint: FTColor.catBlue,
                                       title: "Business & Freelancer", chevron: true)
                        }
                    }

                    sectionCard("Import & Integration") {
                        NavigationLink(destination: ImportIntegrationView()) {
                            settingRow(symbol: "arrow.down.circle.fill", tint: FTColor.catCoral,
                                       title: "Import & Sync", chevron: true)
                        }
                    }

                    sectionCard("Organization") {
                        Button { showingCategoryManagement = true } label: {
                            settingRow(symbol: "folder.badge.gear", tint: FTColor.catTeal,
                                       title: "Custom Categories", chevron: true)
                        }
                        rowDivider
                        Button { showingRuleManagement = true } label: {
                            settingRow(symbol: "text.badge.checkmark", tint: FTColor.catPurple,
                                       title: "Categorization Rules", chevron: true)
                        }
                    }

                    sectionCard("Security & Privacy") {
                        NavigationLink(destination: SecurityPrivacyView()) {
                            settingRow(symbol: "lock.shield.fill", tint: FTColor.accent,
                                       title: "Security & Privacy", chevron: true)
                        }
                        rowDivider
                        FTToggleRow(symbol: BiometricService.shared.biometricIcon, tint: FTColor.accent,
                                    title: BiometricService.shared.biometricTypeName, isOn: biometricsBinding)
                        rowDivider
                        FTToggleRow(symbol: "lock.fill", tint: FTColor.catPurple,
                                    title: "PIN Lock", isOn: pinBinding)
                        rowDivider
                        Menu {
                            Picker("Auto-Lock", selection: autoLockBinding) {
                                Text("1 minute").tag(1)
                                Text("5 minutes").tag(5)
                                Text("15 minutes").tag(15)
                                Text("Never").tag(0)
                            }
                        } label: {
                            settingRow(symbol: "timer", tint: FTColor.catBlue, title: "Auto-Lock",
                                       value: autoLockText, chevron: true)
                        }
                    }

                    sectionCard("Preferences") {
                        Button { showingCurrencyPicker = true } label: {
                            settingRow(symbol: "globe", tint: FTColor.accent, title: "Base Currency",
                                       value: appState.baseCurrency, chevron: true)
                        }
                        .accessibilityLabel("Base Currency: \(appState.baseCurrency)")
                        rowDivider
                        NavigationLink(destination: AppearanceView()) {
                            settingRow(symbol: "paintbrush.fill", tint: FTColor.catPurple,
                                       title: "Appearance & Accessibility",
                                       value: (setting?.theme ?? .system).rawValue, chevron: true)
                        }
                        .accessibilityLabel("Appearance and Accessibility settings")
                        rowDivider
                        NavigationLink(destination: DashboardCustomizerView()) {
                            settingRow(symbol: "square.grid.2x2.fill", tint: FTColor.catTeal,
                                       title: "Dashboard Layout", chevron: true)
                        }
                        .accessibilityLabel("Customize Dashboard Layout")
                        rowDivider
                        NavigationLink(destination: NotificationSettingsView()) {
                            settingRow(symbol: "bell.badge.fill", tint: FTColor.gold,
                                       title: "Notifications", chevron: true)
                        }
                        rowDivider
                        FTToggleRow(symbol: "eye.slash", tint: FTColor.textMuted,
                                    title: "Hide Balances", isOn: $appState.hideBalances)
                    }

                    sectionCard("Data & Privacy") {
                        NavigationLink(destination: iCloudSyncView()) {
                            settingRow(symbol: "icloud.fill", tint: FTColor.catBlue,
                                       title: "iCloud Backup", chevron: true)
                        }
                        rowDivider
                        Button { exportBackup() } label: {
                            settingRow(symbol: "arrow.up.doc.fill", tint: FTColor.accent,
                                       title: "Export Backup", chevron: true)
                        }
                        rowDivider
                        Button { showingImporter = true } label: {
                            settingRow(symbol: "arrow.down.doc.fill", tint: FTColor.income,
                                       title: "Import Backup", chevron: true)
                        }
                        rowDivider
                        Button { exportCSV() } label: {
                            settingRow(symbol: "square.and.arrow.up", tint: FTColor.gold,
                                       title: "Export as CSV", chevron: true)
                        }
                        rowDivider
                        Button(role: .destructive) { showingClearConfirm = true } label: {
                            settingRow(symbol: "trash", tint: FTColor.expense,
                                       title: "Clear All Data", titleColor: FTColor.expense, chevron: true)
                        }
                    }

                    sectionCard("About") {
                        Button { showingAbout = true } label: {
                            settingRow(symbol: "info.circle", tint: FTColor.accent, title: "About FinTrack",
                                       value: "v1.0.0", chevron: true)
                        }
                        rowDivider
                        Link(destination: URL(string: "https://apple.com")!) {
                            settingRow(symbol: "checkmark.shield.fill", tint: FTColor.income,
                                       title: "Privacy Policy", chevron: true)
                        }
                        rowDivider
                        Link(destination: URL(string: "https://apple.com")!) {
                            settingRow(symbol: "doc.text", tint: FTColor.catPurple,
                                       title: "Terms of Service", chevron: true)
                        }
                    }

                    exchangeRatesCard
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.top, FTSpacing.sm)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.accent)
                }
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerView(selectedCurrency: appState.baseCurrency) { currency in
                    appState.baseCurrency = currency
                    UserDefaults.standard.set(currency, forKey: "base_currency")
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingCategoryManagement) {
                CategoryManagementView()
            }
            .sheet(isPresented: $showingRuleManagement) {
                RuleManagementView()
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType(filenameExtension: "fintrack") ?? .json, .json, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    pendingImportURL = url
                    showingImportMode = true
                case .failure(let error):
                    resultMessage = "Could not open file: \(error.localizedDescription)"
                    showingResult = true
                }
            }
            .confirmationDialog("Import Backup", isPresented: $showingImportMode, titleVisibility: .visible) {
                Button("Merge with existing data") { runImport(mode: .merge) }
                Button("Replace all data", role: .destructive) { runImport(mode: .replace) }
                Button("Cancel", role: .cancel) { pendingImportURL = nil }
            } message: {
                Text("Merge keeps your current data and adds new items. Replace deletes everything first, then restores from the backup.")
            }
            .alert("Clear All Data", isPresented: $showingClearConfirm) {
                Button("Delete Everything", role: .destructive) { clearAllData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all transactions, accounts, budgets, loans, and investments. This action cannot be undone.")
            }
            .alert("Backup", isPresented: $showingResult) {
                Button("OK") { }
            } message: {
                Text(resultMessage)
            }
        }
    }

    // MARK: - Profile

    private var profileCard: some View {
        HStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FTColor.heroGradient)
                    .frame(width: 64, height: 64)
                Text(initials)
                    .font(.ftTitle)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("Your Name", text: Binding(
                    get: { profile?.name ?? "" },
                    set: { profile?.name = $0; try? context.save() }
                ))
                .font(.ftHeadline)
                .foregroundStyle(FTColor.textPrimary)

                if let email = profile?.email, !email.isEmpty {
                    Text(email).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                } else {
                    Text("Tap to set your name").font(.ftBody).foregroundStyle(FTColor.textMuted)
                }
            }
            Spacer()
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    private var initials: String {
        let name = profile?.name ?? "FT"
        if name.isEmpty { return "FT" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Exchange rates

    private var exchangeRatesCard: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: "arrow.clockwise", tint: FTColor.accent, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Exchange Rates").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                if let lastUpdated = currencyService.lastUpdated {
                    Text("Updated: \(lastUpdated.relativeFormatted)")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                } else {
                    Text("Using offline rates")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
            }
            Spacer()
            Button("Refresh") {
                Task { await currencyService.fetchLiveRates(baseCurrency: appState.baseCurrency) }
            }
            .font(.ftCallout)
            .buttonStyle(.glass)
            .tint(FTColor.accent)
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Reusable section + rows

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text(title.uppercased())
                .font(.ftLabel).tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)
                .padding(.leading, FTSpacing.xs)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, FTSpacing.lg)
                .ftGlass(FTRadius.md)
        }
    }

    private var rowDivider: some View { Divider().opacity(0.4) }

    private func settingRow(symbol: String, tint: Color, title: String,
                            titleColor: Color = FTColor.textPrimary,
                            value: String? = nil, chevron: Bool = false) -> some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(symbol: symbol, tint: tint, size: 36)
            Text(title).font(.ftBody).foregroundStyle(titleColor)
            Spacer()
            if let value {
                Text(value).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    // #12 – CSV export

    private func exportCSV() {
        var csv = "Date,Title,Type,Category,Amount,Currency,Account,Notes\n"
        let fmt = DateFormatter()
        fmt.dateStyle = .short; fmt.timeStyle = .short
        for tx in transactions {
            let row = [
                fmt.string(from: tx.date),
                tx.title.replacingOccurrences(of: ",", with: ";"),
                tx.type.rawValue,
                tx.category.rawValue,
                String(tx.amount),
                tx.currency,
                tx.account?.name ?? "",
                (tx.notes ?? "").replacingOccurrences(of: ",", with: ";")
            ].joined(separator: ",")
            csv += row + "\n"
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("FinTrack_Export.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        presentShareSheet(for: tempURL)
    }

    // Full-fidelity backup (.fintrack JSON) — round-trips with Import.

    private func exportBackup() {
        do {
            let url = try DataTransferService.shared.exportBackup(context: context)
            presentShareSheet(for: url)
        } catch {
            resultMessage = "Export failed: \(error.localizedDescription)"
            showingResult = true
        }
    }

    private func runImport(mode: DataTransferService.ImportMode) {
        guard let url = pendingImportURL else { return }
        defer { pendingImportURL = nil }

        // Files picked from iCloud/Files are security-scoped.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let summary = try DataTransferService.shared.importBackup(from: url, context: context, mode: mode)
            resultMessage = summary.total > 0 ? "Imported \(summary.description)." : "Nothing new to import."
        } catch {
            resultMessage = "Import failed. Make sure this is a FinTrack backup file.\n\n\(error.localizedDescription)"
        }
        showingResult = true
    }

    /// Presents the iOS share sheet from the front-most controller. Settings is
    /// itself a sheet, so presenting on the window root fails ("already presenting").
    private func presentShareSheet(for url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              var top = keyWindow.rootViewController else { return }

        while let presented = top.presentedViewController { top = presented }

        // iPad: anchor the popover so it doesn't crash on presentation.
        if let pop = av.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }

        top.present(av, animated: true)
    }

    private func clearAllData() {
        for item in transactions   { context.delete(item) }
        for item in exportAccounts { context.delete(item) }
        for item in budgets        { context.delete(item) }
        for item in savingsGoals   { context.delete(item) }
        for item in creditCards    { context.delete(item) }
        for item in loans          { context.delete(item) }
        for item in bnplPlans      { context.delete(item) }
        for item in investments    { context.delete(item) }
        for item in cryptoHoldings { context.delete(item) }
        for item in goldHoldings   { context.delete(item) }
        for item in giftCards      { context.delete(item) }
        for item in loyaltyPrograms { context.delete(item) }
        try? context.save()
    }
}

struct CurrencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyService.self) private var currencyService
    let selectedCurrency: String
    let onSelect: (String) -> Void
    @State private var search = ""

    private var filtered: [CurrencyInfo] {
        if search.isEmpty { return currencyService.supportedCurrencies }
        return currencyService.supportedCurrencies.filter {
            $0.code.localizedCaseInsensitiveContains(search) ||
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { currency in
                Button {
                    onSelect(currency.code)
                    dismiss()
                } label: {
                    HStack {
                        Text(currency.flag)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currency.code)
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                            Text(currency.name)
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                        if currency.code == selectedCurrency {
                            Image(systemName: "checkmark")
                                .foregroundStyle(FTColor.accent)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .searchable(text: $search, prompt: "Search currencies...")
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: FTSpacing.lg) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(FTColor.heroGradient)
                                .frame(width: 100, height: 100)
                            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }

                        Text("FinTrack")
                            .font(.ftDisplay)
                            .foregroundStyle(FTColor.textPrimary)

                        Text("Version 1.0.0")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                    }

                    VStack(spacing: FTSpacing.sm) {
                        Text("Personal Finance & Accounting")
                            .font(.ftHeadline)
                            .foregroundStyle(FTColor.textPrimary)
                        Text("Built for the UAE and global markets.\nTrack income, expenses, investments, crypto, loans, and more — all in one place.")
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    VStack(spacing: FTSpacing.md) {
                        HStack(spacing: 32) {
                            FeatureBadge(icon: "lock.shield", label: "Secure")
                            FeatureBadge(icon: "brain.head.profile", label: "AI-Powered")
                            FeatureBadge(icon: "globe", label: "Multi-Currency")
                        }
                        HStack(spacing: 32) {
                            FeatureBadge(icon: "chart.pie.fill", label: "Analytics")
                            FeatureBadge(icon: "bell.fill", label: "Reminders")
                            FeatureBadge(icon: "icloud.fill", label: "iCloud")
                        }
                    }

                    Spacer()

                    Text("Made with ❤️ for Financial Clarity")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FeatureBadge: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(FTColor.accent)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
        }
    }
}
