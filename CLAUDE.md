# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an Xcode project — open `FinTrack.xcodeproj` in Xcode and run on simulator or device. There are no CLI build commands, no Package.swift, and no test targets.

## Schema Versioning

The app uses **wipe-and-recreate** (not migrations). In `FinTrack/App/FinTrackApp.swift`:

```swift
let currentSchemaVersion = "v15"   // ← bump this string
```

Bump whenever adding new `@Model` classes or non-optional properties to existing ones. Also register every new `@Model` in the `Schema([...])` array in `FinTrackApp.swift`. Failing to bump causes a crash on launch.

## Architecture

```
FinTrack/
  App/              FinTrackApp.swift (entry point, schema, AppState, AppTab)
  Features/         One sub-folder per feature (Transactions, Budget, Accounts, Goals, Tax,
                    Family, Business, Import, Settings, AppIntents, LiveActivity…)
  Core/
    Models/         @Model classes + plain Codable structs
    Services/       Singleton services (*.shared)
    Utilities/      Extensions.swift
  UI/
    Theme/          FTDesignSystem.swift, AppTheme.swift (single source of truth for tokens)
FinTrackWidget/     Widget Extension source (WidgetBundle, all widget families, Live Activity UI)
FinTrackWatch/      Apple Watch companion app source
```

`AppState` is `@Observable @MainActor final class` — inject via `.environment(appState)` and read with `@Environment(AppState.self)`. Key fields: `selectedTab`, `isLocked`, `isHiddenMode`, `baseCurrency`, `hideBalances`, `showingAddTransaction`.

**Navigation**: 4 tabs (dashboard, transactions, budget, accounts) + a centre FAB. **The tab bar is full.** Any new top-level module must be reachable via Settings (`FinTrack/Features/Settings/SettingsView.swift`), not a new tab. On iPad (`horizontalSizeClass == .regular`), `RootView` renders a `NavigationSplitView` instead of the tab bar.

## Design System

**Never hardcode colors, spacing, radii, or fonts.** Use only the tokens below.

### Colors (`FTColor` in `FTDesignSystem.swift`)

All brand colors are light/dark adaptive via `Color(light: UInt, dark: UInt)`:

| Token | Purpose |
|---|---|
| `.bgBase` | Page background |
| `.bgElevated` | Card / surface background |
| `.textPrimary` `.textSecondary` `.textMuted` | Text hierarchy |
| `.accent` `.accentDeep` `.accentBright` | Teal brand primary |
| `.gold` | Gold / premium accent |
| `.income` `.expense` | Transaction sentiment |
| `.catBlue` `.catPurple` `.catCoral` `.catTeal` `.catGold` | Category icon tints |
| `.accentGradient` `.heroGradient` `.portfolioGradient` | Named gradients |

`AppColors` in `AppTheme.swift` provides semantic aliases (`AppColors.surface`, `.primaryGradient`, `.incomeGradient`, `.expenseGradient`, `.goldGradient`, `.blueGradient`, `.purpleGradient`).

### Color utilities

```swift
// Adaptive light/dark hex color (defined in FTDesignSystem.swift)
Color(light: 0xF45C43, dark: 0xFF8A80)

// Static hex — two overloads, pick based on context:
Color(hex: 0x0E9C8A)      // FTDesignSystem.swift — UInt, compile-time constant
Color(hex: "#0E9C8A")     // AppTheme.swift — String, for model-driven hex values

// Color from name string (Extensions.swift) — for model color fields
Color.fromString("teal")  // returns SwiftUI Color; default → .blue
```

### Spacing (`FTSpacing`)
`.xs=4` `.sm=8` `.md=12` `.lg=16` `.xl=20` `.xxl=24` `.screen=20`

`AppSpacing` aliases: `.xs=4` `.sm=8` `.md=16` `.lg=24` `.xl=32`

### Radius (`FTRadius`)
`.sm=12` `.md=16` `.lg=22` `.xl=26` `.pill=30`

### Fonts (SwiftUI `.font(...)`)
`.ftDisplay` `.ftAmount` `.ftTitle` `.ftHeadline` `.ftBody` `.ftBodySemibold` `.ftCallout` `.ftCaption` `.ftLabel` (section labels — pair with `.tracking(1.6)`)

### Glass Surfaces
- `.ftGlass(radius)` — standard Liquid Glass card modifier (iOS 26 `glassEffect`)
- `.ftGlassInteractive(radius)` — glass with touch feedback
- `.cardStyle(padding:)` — shorthand for `.padding().ftGlass(FTRadius.md)`
- `FTBackdrop()` — full-screen blurred-blob gradient background; use as `.background { FTBackdrop() }`

### Reusable Components

**FTDesignSystem.swift**
- `FTCard { ... }` — padded glass card
- `FTIconTile(symbol:, tint:, size: = 42)` — SF Symbol in a tinted rounded-rect tile
- `FTChip(symbol:, title:, selected: = false)` — filter chip with glass/accent background
- `FTProgressBar(value:, color:, height:)` — 0…1 progress bar (pass >1 to show over-budget red)
- `FTSegmentedControl(options: [String], selection: Binding<Int>)` — accent-gradient selector
- `FTToggleRow(symbol:, tint:, title:, isOn:)` — labeled toggle row
- `FTTransactionRow(symbol:, tint:, title:, subtitle:, amount:, amountColor:)` — standard list row

**AppTheme.swift**
- `GlassCard { ... }` / `Card { ... }` — alternative card wrappers
- `PrimaryButton(_ title:, icon:, isLoading:, isDestructive:, action:)` — full-width CTA
- `AmountDisplayView(amount:, currency:, isHidden:, style:)` — hides as `••••••` when `isHidden`
- `SectionHeader(title:, action:, onAction:)` — heading with optional trailing button
- `EmptyStateView(icon:, title:, message:, actionTitle:, action:)` — engaging empty state
- `BadgeView(text:, color:)` — compact pill badge
- `IconBadge(icon:, color:, size:)` — alias for `FTIconTile`
- `FilterChip(title:, isSelected:, action:)` — defined in `TransactionsListView.swift`

## Data Patterns

**Embedded arrays in `@Model`**: Use `Data` + `JSONEncoder`/`JSONDecoder` rather than SwiftData relationships:

```swift
var itemsData: Data = Data()
var items: [MyStruct] {
    get { (try? JSONDecoder().decode([MyStruct].self, from: itemsData)) ?? [] }
    set { itemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
}
```

Use `@Attribute(.externalStorage)` on large `Data` properties (receipt images, imported files).

**`AppSettings` fields**: `AppSettings` in `UserProfile.swift` holds all user preferences — security (biometrics, PIN, 2FA, decoy PIN, audit log, encryption), notifications (thresholds, digest schedule), and appearance (theme, accentColor, cloudSyncEnabled). Always read/write through `@Query private var settings: [AppSettings]` and `settings.first`.

**`AuditLogEntry` `@Model`** in `SecurityModels.swift` — immutable security event log. Append-only; read via `@Query(sort: \AuditLogEntry.timestamp, order: .reverse)`.

## Core Utilities (`Extensions.swift`)

`Double`: `.formatted(as: currency)`, `.asPercentage(decimals:)`, `.asCompact(currency:)`

`Date`: `.startOfMonth`, `.endOfMonth`, `.startOfYear`, `.startOfWeek`, `.monthName`, `.shortMonthName`, `.dayNumber`, `.formatted`, `.relativeFormatted`, `.isSameMonth(as:)`, `.isSameDay(as:)`

`View`: `.dismissKeyboardOnTap()`

`Array`: `.chunked(into:)`

## Key Services

| Service | File | Purpose |
|---|---|---|
| `CurrencyService.shared` | `CurrencyService.swift` | FX rates; `.convert(amount, from:, to:)` |
| `NotificationService.shared` | `NotificationService.swift` | Schedule/cancel UNNotifications |
| `SpotlightService.shared` | `SpotlightService.swift` | CoreSpotlight indexing; called from `DashboardView.refreshDashboard()` |
| `WidgetDataService.shared` | `WidgetDataService.swift` | Write App Group UserDefaults for widget; `.updateAll(netWorth:currency:transactions:budgets:bills:)` called from `DashboardView.pushWidgetData()` |
| `LiveActivityService.shared` | `BudgetLiveActivityService.swift` | Start/update/end `Activity<BudgetActivityAttributes>` |
| `BiometricService` | `BiometricService.swift` | Face ID / Touch ID |
| `AICategorizationService.shared` | `AICategorizationService.swift` | Auto-categorization + insight generation |

## Platform Extensions

### Widgets (FinTrackWidget/)
Three widget types in a `WidgetBundle`: `FinTrackBalanceWidget` (sm/md/lg + all accessory lock screen families), `FinTrackBudgetWidget` (sm/md/lg), `FinTrackBillsWidget` (md/lg). Live Activity UI (`BudgetLiveActivityAttributes`) is also rendered here. All data comes from `UserDefaults(suiteName: "group.com.fintrack.shared")` via the keys written by `WidgetDataService`.

### App Intents / Siri (FinTrack/Features/AppIntents/)
`FinTrackIntents.swift` — `LogExpenseIntent`, `LogIncomeIntent`, `GetBalanceIntent`, `GetBudgetStatusIntent`, `FinTrackShortcuts: AppShortcutsProvider`. Intents enqueue a `PendingWidgetTransaction` into the shared App Group; `RootView` drains the queue via `drainPendingIntentQueue()` on `onAppear` and `.active` scene phase.

### Apple Watch (FinTrackWatch/)
Standalone Watch app reading from the same App Group. `WatchRootView` → `TabView` with `WatchBalanceView`, `WatchTransactionsView`, `WatchQuickExpenseView` (Digital Crown amount entry). Quick-add entries are queued to the same `pending_transactions` key that Siri uses.

### iPad Layout
`RootView` detects `@Environment(\.horizontalSizeClass) == .regular` and renders `NavigationSplitView` (sidebar + detail) instead of `MainTabView`.

### Spotlight Deep Linking
`RootView` handles `.onContinueUserActivity(CSSearchableItemActionType)` and calls `SpotlightService.shared.handleUserActivity(_:)` which returns a `SpotlightDeepLink` enum (`.transaction(UUID)`, `.account(UUID)`, `.unknown(UUID)`).

## UAE Defaults

VAT = 5%, no personal income tax, Zakat = 2.5% of zakatable wealth above nisab. Default currency: `"AED"`.
