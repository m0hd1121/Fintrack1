import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(CurrencyService.self) private var currencyService
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @Query private var profiles: [UserProfile]

    private var setting: AppSettings? { settings.first }
    private var profile: UserProfile? { profiles.first }
    private var visibleFeatures: [DisableableFeature] {
        DisableableFeature.allCases.filter { $0.category == .premium && $0.isEnabled }
    }

    @State private var showingCurrencyPicker = false
    @State private var showingPINSetup = false
    @State private var showingAbout = false
    @State private var showingCategoryManagement = false
    @State private var showingRuleManagement = false

    @State private var showingClearConfirm = false

    // Backup import
    @State private var showingImporter = false
    @State private var pendingImportURL: URL?
    @State private var showingImportMode = false
    @State private var showingResult = false
    @State private var resultMessage = ""
    @State private var clearFailureMessage: String? = nil
    /// Import and Clear All Data run for seconds (key derivation, full
    /// import/wipe). Shown as a blocking overlay so they can't be started twice.
    @State private var busyMessage: String? = nil

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(version)"
    }

    // MARK: - Bindings

    private var biometricsBinding: Binding<Bool> {
        Binding(get: { setting?.useBiometrics ?? true },
                set: { setting?.useBiometrics = $0; try? context.save() })
    }
    private var pinBinding: Binding<Bool> {
        Binding(get: { setting?.usePIN ?? false },
                set: { newValue in
                    // Turning PIN on opens setup; `PINSetupSheet` enables it once a PIN
                    // is saved. Turning it off also forgets the stored hash.
                    if newValue {
                        showingPINSetup = true
                    } else {
                        setting?.usePIN = false
                        setting?.pinHash = nil
                        try? context.save()
                    }
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
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                profileCard

                if !visibleFeatures.isEmpty {
                    sectionCard("Premium Features") {
                        ForEach(Array(visibleFeatures.enumerated()), id: \.element.id) { index, feature in
                            NavigationLink(destination: LazyView { destinationView(for: feature) }) {
                                settingRow(symbol: feature.symbol, tint: feature.tint,
                                           title: feature.title, chevron: true)
                            }
                            if index < visibleFeatures.count - 1 {
                                rowDivider
                            }
                        }
                    }
                }

                sectionCard("Financial Intelligence") {
                    NavigationLink(destination: LazyView { FinancialIntelligenceView() }) {
                        settingRow(symbol: "brain.head.profile", tint: FTColor.gold,
                                   title: "Health Score & Insights", chevron: true)
                    }
                }

                if DisableableFeature.taxManagement.isEnabled {
                    sectionCard("Tax Management") {
                        NavigationLink(destination: LazyView { TaxManagementView() }) {
                            settingRow(symbol: "doc.text.fill", tint: FTColor.catPurple,
                                       title: "Tax Management", chevron: true)
                        }
                    }
                }

                sectionCard("Family Finance") {
                    NavigationLink(destination: LazyView { FamilyFinanceView() }) {
                        settingRow(symbol: "person.3.fill", tint: FTColor.catTeal,
                                   title: "Family & Shared Finance", chevron: true)
                    }
                }

                if DisableableFeature.businessFreelancer.isEnabled {
                    sectionCard("Business & Freelancer") {
                        NavigationLink(destination: LazyView { BusinessFreelancerView() }) {
                            settingRow(symbol: "briefcase.fill", tint: FTColor.catBlue,
                                       title: "Business & Freelancer", chevron: true)
                        }
                    }
                }

                sectionCard("Import & Integration") {
                    NavigationLink(destination: LazyView { ImportIntegrationView() }) {
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
                    NavigationLink(destination: LazyView { SecurityPrivacyView() }) {
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
                    NavigationLink(destination: LazyView { AppearanceView() }) {
                        settingRow(symbol: "paintbrush.fill", tint: FTColor.catPurple,
                                   title: "Appearance & Accessibility",
                                   value: (setting?.theme ?? .system).rawValue, chevron: true)
                    }
                    .accessibilityLabel("Appearance and Accessibility settings")
                    rowDivider
                    NavigationLink(destination: LazyView { DashboardCustomizerView() }) {
                        settingRow(symbol: "square.grid.2x2.fill", tint: FTColor.catTeal,
                                   title: "Dashboard Layout", chevron: true)
                    }
                    .accessibilityLabel("Customize Dashboard Layout")
                    rowDivider
                    NavigationLink(destination: LazyView { NotificationSettingsView() }) {
                        settingRow(symbol: "bell.badge.fill", tint: FTColor.gold,
                                   title: "Notifications", chevron: true)
                    }
                }

                sectionCard("Data & Privacy") {
                    NavigationLink(destination: LazyView { LocalBackupView() }) {
                        settingRow(symbol: "internaldrive.fill", tint: FTColor.catBlue,
                                   title: "Backup", chevron: true)
                    }
                    rowDivider
                    if DisableableFeature.googleDriveBackup.isEnabled {
                        NavigationLink(destination: LazyView { GoogleDriveBackupView() }) {
                            settingRow(symbol: "doc.badge.gearshape.fill", tint: FTColor.income,
                                       title: "Google Drive Backup", chevron: true)
                        }
                        rowDivider
                    }
                    NavigationLink(destination: LazyView { EmailBackupView() }) {
                        settingRow(symbol: "envelope.badge.shield.half.filled.fill", tint: FTColor.catCoral,
                                   title: "Email Backup", chevron: true)
                    }
                    rowDivider
                    Button { showingImporter = true } label: {
                        settingRow(symbol: "arrow.down.doc.fill", tint: FTColor.income,
                                   title: "Import Backup", chevron: true)
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
                                   value: appVersion, chevron: true)
                    }
                    rowDivider
                    NavigationLink(destination: LazyView { PrivacyPolicyView() }) {
                        settingRow(symbol: "checkmark.shield.fill", tint: FTColor.income,
                                   title: "Privacy Policy", chevron: true)
                    }
                    rowDivider
                    NavigationLink(destination: LazyView { TermsOfServiceView() }) {
                        settingRow(symbol: "doc.text", tint: FTColor.catPurple,
                                   title: "Terms of Service", chevron: true)
                    }
                }

                exchangeRatesCard
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.sm)
            .padding(.bottom, 120)   // clear the floating tab bar (Settings is now a pushed screen)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .overlay {
            if let busyMessage {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: FTSpacing.md) {
                        ProgressView()
                        Text(busyMessage).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    }
                    .padding(FTSpacing.xxl)
                    .ftGlass(FTRadius.lg)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .disabled(busyMessage != nil)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerView(selectedCurrency: appState.baseCurrency) { currency in
                let previous = appState.baseCurrency
                appState.baseCurrency = currency
                UserDefaults.standard.set(currency, forKey: "base_currency")
                if previous != currency { rebaseTransactions(to: currency) }
            }
        }
        .sheet(isPresented: $showingPINSetup) {
            PINSetupSheet()
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
        .alert("Clear All Data", isPresented: $showingClearConfirm) {
            Button("Delete Everything", role: .destructive) { clearAllData() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all financial data — transactions, accounts, budgets, investments, debts, tax records, bills, assets, imported items waiting for review, and more — along with the backup copies stored on this device. Backups you sent to Google Drive or email aren't affected. Your app settings, preferences and connected mailboxes will be kept. This action cannot be undone.")
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
        .alert("Backup", isPresented: $showingResult) {
            Button("OK") { }
        } message: {
            Text(resultMessage)
        }
        .alert("Some data wasn't deleted", isPresented: Binding(
            get: { clearFailureMessage != nil },
            set: { if !$0 { clearFailureMessage = nil } }
        )) {
            Button("OK", role: .cancel) { clearFailureMessage = nil }
        } message: {
            Text(clearFailureMessage ?? "")
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
                // Saved on Return (and by SwiftData's autosave) rather than a
                // store save on every keystroke.
                TextField("Your Name", text: Binding(
                    get: { profile?.name ?? "" },
                    set: { profile?.name = $0 }
                ))
                .font(.ftHeadline)
                .foregroundStyle(FTColor.textPrimary)
                .textContentType(.name)
                .submitLabel(.done)
                .onSubmit { try? context.save() }

                if let email = profile?.email, !email.isEmpty {
                    Text(email).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                } else if (profile?.name ?? "").isEmpty {
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
            if currencyService.isLoading {
                ProgressView()
                    .accessibilityLabel("Refreshing exchange rates")
            } else {
                Button("Refresh") {
                    Task { await currencyService.fetchLiveRates(baseCurrency: appState.baseCurrency) }
                }
                .font(.ftCallout)
                .buttonStyle(.glass)
                .tint(FTColor.accent)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.md)
    }

    // MARK: - Reusable section + rows

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text(title.uppercased())
                .font(.ftLabel).tracking(1.4).fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(FTColor.textSecondary)
                .padding(.leading, FTSpacing.xs)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, FTSpacing.lg)
                .ftGlass(FTRadius.md)
        }
    }

    private var rowDivider: some View { Divider().opacity(0.4) }

    @ViewBuilder
    private func destinationView(for feature: DisableableFeature) -> some View {
        switch feature {
        case .aiCFOMode:            AICFOModeView()
        case .retirementSimulation: RetirementSimulationView()
        case .lifeEventPlanning:    LifeEventPlanningView()
        case .estatePlanning:       EstatePlanningView()
        case .insuranceOptimizer:   InsuranceOptimizerView()
        case .smartCashAllocation:  SmartCashAllocationView()
        case .collaborativePlanner: CollaborativePlannerView()
        case .financialEducation:   FinancialEducationView()
        case .remittanceTracker:    RemittanceTrackerView()
        case .taxManagement:        TaxManagementView()
        case .businessFreelancer:   BusinessFreelancerView()
        case .auditLog:             AuditLogView()
        case .googleDriveBackup:    GoogleDriveBackupView()
        case .pdfStatementImport:   PDFImportView()
        case .twoFactorAuth:        TwoFactorSetupView()
        }
    }

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

    // Restore a .fintrack backup (JSON, transparently decrypted). Merge adds new
    // items; Replace wipes first, then restores.

    private func runImport(mode: DataTransferService.ImportMode) {
        guard busyMessage == nil else { return }
        busyMessage = "Restoring backup…"
        Task {
            await runImportAsync(mode: mode)
            busyMessage = nil
        }
    }

    private func runImportAsync(mode: DataTransferService.ImportMode) async {
        guard let url = pendingImportURL else { return }
        defer { pendingImportURL = nil }

        // Files picked from iCloud/Files are security-scoped.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let rawData = try Data(contentsOf: url)
            let decrypted = try await BackupEncryptionService.decryptIfNeeded(rawData)
            // Email backups are zlib-compressed (FTGZ1 header) before encryption;
            // manual/iCloud/Drive backups are not. decompressIfNeeded passes
            // uncompressed data straight through, so this handles every source.
            let plainData = try EmailBackupService.decompressIfNeeded(decrypted)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("FinTrack_Import_\(UUID().uuidString).fintrack")
            try plainData.write(to: tempURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let summary = try DataTransferService.shared.importBackup(from: tempURL, context: context, mode: mode)
            resultMessage = summary.total > 0 ? "Imported \(summary.description)." : "Nothing new to import."
        } catch {
            resultMessage = "Import failed. Make sure this is a FinTrack backup file.\n\n\(error.localizedDescription)"
        }
        showingResult = true
    }

    /// Everything is in `DataResetService`, which walks the schema rather than a
    /// list kept here (that list had fallen behind) and also clears what lives
    /// outside the database — Spotlight, Siri/widget snapshots, learned
    /// merchants, on-device backups. It reports anything it couldn't delete, so
    /// a partial clear is never mistaken for a complete one.
    /// Every report sums `amountInBaseCurrency` and labels it with the base
    /// currency, so after a base-currency change the stored values must be
    /// re-expressed in the new currency (at today's rates — the original
    /// transaction-time rate isn't stored separately).
    private func rebaseTransactions(to newBase: String) {
        let all = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for tx in all {
            tx.amountInBaseCurrency = tx.currency == newBase
                ? tx.amount
                : currencyService.convert(tx.amount, from: tx.currency, to: newBase)
        }
        if let profile { profile.baseCurrency = newBase }
        try? context.save()
    }

    private func clearAllData() {
        guard busyMessage == nil else { return }
        busyMessage = "Deleting data…"
        Task {
            let leftover = await DataResetService.clearAll(context: context)
            busyMessage = nil
            if !leftover.isEmpty {
                clearFailureMessage = "These couldn't be deleted: \(leftover.joined(separator: ", ")). Try again, and if it keeps happening, restart the app first."
            } else {
                // Was silent on success.
                resultMessage = "All financial data was deleted."
                showingResult = true
            }
        }
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
                .accessibilityAddTraits(currency.code == selectedCurrency ? [.isSelected] : [])
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
                // Scrolls when it doesn't fit (small phones, large text).
                ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: FTSpacing.lg)

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

                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
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
                            FeatureBadge(icon: "internaldrive.fill", label: "Backup")
                        }
                    }

                    Spacer()

                    Text("Made with ❤️ for Financial Clarity")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)

                    Spacer(minLength: FTSpacing.lg)
                }
                .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { FTBackdrop() }
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

// Defers destination view init until navigation occurs, preventing eager
// instantiation of all NavigationLink destinations in the same render pass.
private struct LazyView<Content: View>: View {
    let build: () -> Content
    var body: some View { build() }
}
