import SwiftUI
import SwiftData
import Observation
import UserNotifications

@main
struct FinTrackApp: App {
    @State private var appState = AppState()
    @State private var currencyService = CurrencyService.shared
    @State private var cryptoPriceService = CryptoPriceService.shared
    @State private var stockPriceService = StockPriceService.shared

    let modelContainer: ModelContainer = {
        // Bump this string whenever a non-optional property is added to any @Model
        // without a versioned SchemaMigrationPlan. SwiftData's lightweight migrator
        // cannot fill non-optional columns on existing rows, so we wipe the dev store
        // and start fresh. In production you would write a proper MigrationPlan instead.
        let currentSchemaVersion = "v28"
        let versionKey = "fintrack_schema_version"

        if UserDefaults.standard.string(forKey: versionKey) != currentSchemaVersion {
            let fm = FileManager.default
            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                for name in ["default.store", "default.store-shm", "default.store-wal"] {
                    try? fm.removeItem(at: appSupport.appendingPathComponent(name))
                }
            }
            UserDefaults.standard.set(currentSchemaVersion, forKey: versionKey)
            // A wipe deletes every record, but previously scheduled local
            // notifications (bill/BNPL/loan reminders, etc.) live in the
            // system notification center, not the store — they'd otherwise
            // keep firing for entities that no longer exist.
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }

        let schema = Schema(AppSchema.modelTypes)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        EmailSyncService.registerBackgroundSync(container: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environment(appState)
                .environment(currencyService)
                .environment(cryptoPriceService)
                .environment(stockPriceService)
                .task {
                    await currencyService.fetchLiveRates()
                    await cryptoPriceService.fetchPrices()
                    _ = await NotificationService.shared.requestPermission()
                }
        }
    }
}

@Observable
@MainActor
final class AppState {
    var isLocked = false
    var hasCompletedOnboarding = false
    var selectedTab: AppTab = .dashboard
    var showingAddTransaction = false
    var baseCurrency = "AED"
    /// Bumped every time a tab is selected (including re-selecting the
    /// current one). Each tab's root view watches this and pops its pushed
    /// screens back to the main page, so choosing a tab always lands there.
    var popToRootTick = 0

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

/// Top-level destinations. The first five are the bottom bar's destinations
/// (Home, Activity, Plan, Wealth, Search — see `AppTabBar`); `newTransaction`
/// is an action item; the rest only appear in the sidebar on regular width
/// (iPad, a foldable's inner display). Case names are kept from the old tabs
/// (`dashboard`, `transactions`, `budget`, `accounts`) because
/// `PendingNavigationTarget` maps Siri's "Open…" intents onto them. Raw values
/// are display names only and are never persisted.
enum AppTab: String, CaseIterable, Hashable {
    case dashboard     = "Home"
    case transactions  = "Activity"
    case budget        = "Plan"
    case accounts      = "Wealth"
    case search        = "Search"
    /// Not a destination: selecting it opens the New Transaction sheet and
    /// leaves the current selection unchanged (see `MainTabView.selection`).
    case newTransaction = "New Transaction"

    // Sidebar-only (regular width)
    case budgets       = "Budgets"
    case bills         = "Bills & Payments"
    case goals         = "Goals"
    case income        = "Income"
    case debt          = "Debt"
    case household     = "Household"
    case planningTools = "Planning Tools"
    case netWorth      = "Net Worth"
    case investments   = "Investments"
    case assets        = "Property & Assets"
    case insights      = "Insights"
    case reports       = "Reports"
    case importSync    = "Import & Sync"
    case settings      = "Settings"

    var icon: String {
        switch self {
        case .dashboard:     return "house"
        case .transactions:  return "list.bullet.rectangle.portrait"
        case .budget:        return "chart.pie"
        case .accounts:      return "building.columns"
        case .search:        return "magnifyingglass"
        case .newTransaction: return "plus.circle"
        case .budgets:       return "chart.pie.fill"
        case .bills:         return "calendar.badge.clock"
        case .goals:         return "star"
        case .income:        return "banknote"
        case .debt:          return "creditcard"
        case .household:     return "person.3"
        case .planningTools: return "compass.drawing"
        case .netWorth:      return "chart.line.uptrend.xyaxis"
        case .investments:   return "chart.bar.xaxis.ascending"
        case .assets:        return "house.lodge"
        case .insights:      return "sparkles"
        case .reports:       return "doc.text.magnifyingglass"
        case .importSync:    return "arrow.down.circle"
        case .settings:      return "gearshape"
        }
    }

    /// The tab-bar tab that owns a sidebar-only destination. Used when the
    /// window narrows to compact width (Split View, folding a foldable) while
    /// a sidebar-only destination is selected.
    var compactParent: AppTab {
        switch self {
        case .dashboard, .transactions, .budget, .accounts, .search: return self
        case .newTransaction: return .dashboard
        case .budgets, .bills, .goals, .income, .debt, .household, .planningTools: return .budget
        case .netWorth, .investments, .assets: return .accounts
        case .importSync: return .transactions
        case .insights, .reports, .settings: return .dashboard
        }
    }
}
