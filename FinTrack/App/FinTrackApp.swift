import SwiftUI
import SwiftData
import Observation

@main
struct FinTrackApp: App {
    @State private var appState = AppState()
    @State private var currencyService = CurrencyService.shared

    let modelContainer: ModelContainer = {
        // Bump this string whenever a non-optional property is added to any @Model
        // without a versioned SchemaMigrationPlan. SwiftData's lightweight migrator
        // cannot fill non-optional columns on existing rows, so we wipe the dev store
        // and start fresh. In production you would write a proper MigrationPlan instead.
        let currentSchemaVersion = "v17"
        let versionKey = "fintrack_schema_version"

        if UserDefaults.standard.string(forKey: versionKey) != currentSchemaVersion {
            let fm = FileManager.default
            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                for name in ["default.store", "default.store-shm", "default.store-wal"] {
                    try? fm.removeItem(at: appSupport.appendingPathComponent(name))
                }
            }
            UserDefaults.standard.set(currentSchemaVersion, forKey: versionKey)
        }

        let schema = Schema([
            Account.self,
            Transaction.self,
            DocumentAttachment.self,
            CustomCategory.self,
            CategorizationRule.self,
            Budget.self,
            SavingsGoal.self,
            BudgetEnvelope.self,
            BudgetTemplate.self,
            Bill.self,
            Loan.self,
            CreditCard.self,
            Investment.self,
            CryptoHolding.self,
            Dividend.self,
            BNPLPlan.self,
            UserProfile.self,
            AppSettings.self,
            GoldHolding.self,
            GiftCard.self,
            LoyaltyProgram.self,
            SalaryRecord.self,
            FreelanceProject.self,
            RentalProperty.self,
            MoneyLent.self,
            MoneyBorrowed.self,
            RealEstateProperty.self,
            Vehicle.self,
            PersonalAsset.self,
            DigitalAsset.self,
            NetWorthSnapshot.self,
            NetWorthMilestone.self,
            TaxRecord.self,
            TaxDocument.self,
            ZakatRecord.self,
            TaxConfiguration.self,
            FamilyGroup.self,
            ChildProfile.self,
            SharedFamilyGoal.self,
            ClientProfile.self,
            BusinessInvoice.self,
            MileageTrip.self,
            BusinessProject.self,
            ImportedFile.self,
            AuditLogEntry.self,
            RemittanceRecord.self,
            InsurancePolicy.self,
            RetirementPlan.self,
            LifeEventPlan.self,
            AdvisorAccess.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environment(appState)
                .environment(currencyService)
                .task {
                    await currencyService.fetchLiveRates()
                    _ = await NotificationService.shared.requestPermission()
                }
        }
    }
}

@Observable
@MainActor
final class AppState {
    var isLocked = false
    var isHiddenMode = false
    var hasCompletedOnboarding = false
    var selectedTab: AppTab = .dashboard
    var showingAddTransaction = false
    var baseCurrency = "AED"
    var hideBalances = false

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "has_completed_onboarding")
        baseCurrency = UserDefaults.standard.string(forKey: "base_currency") ?? "AED"
    }

    func completeOnboarding(currency: String) {
        baseCurrency = currency
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        UserDefaults.standard.set(currency, forKey: "base_currency")
    }

    func lock() { isLocked = true }
    func unlock() { isLocked = false }
}

enum AppTab: String, CaseIterable {
    case dashboard    = "Dashboard"
    case transactions = "Transactions"
    case add          = "Add"          // centre button placeholder
    case budget       = "Budget"
    case accounts     = "Accounts"
    case reports      = "Reports"      // not shown in tab bar; navigated to from Budget

    var icon: String {
        switch self {
        case .dashboard:    return "square.grid.2x2"
        case .transactions: return "arrow.left.arrow.right.circle"
        case .add:          return "plus.circle"
        case .budget:       return "chart.pie"
        case .accounts:     return "building.columns"
        case .reports:      return "chart.bar.xaxis"
        }
    }

    var selectedIcon: String {
        switch self {
        case .dashboard:    return "square.grid.2x2.fill"
        case .transactions: return "arrow.left.arrow.right.circle.fill"
        case .add:          return "plus.circle.fill"
        case .budget:       return "chart.pie.fill"
        case .accounts:     return "building.columns.fill"
        case .reports:      return "chart.bar.xaxis"
        }
    }
}
