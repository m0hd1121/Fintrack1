# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an Xcode project — open `FinTrack.xcodeproj` in Xcode and run on simulator or device. There are no CLI build commands, no Package.swift, and no test targets.

## Schema Versioning

The app uses **wipe-and-recreate** (not migrations). In `FinTrack/App/FinTrackApp.swift`:

```swift
private let currentSchemaVersion = "v13"   // ← bump this string
```

Bump the string whenever adding new `@Model` classes or non-optional properties to existing ones. Also register every new `@Model` in the `Schema([...])` array in `FinTrackApp.swift`. Failing to bump causes a crash on launch.

## Architecture

```
FinTrack/
  App/              FinTrackApp.swift (entry point, schema, AppState, AppTab)
  Features/         One sub-folder per feature (Transactions, Budget, Accounts, Goals, Tax, Family, Settings…)
  Core/
    Models/         @Model classes + plain Codable structs
    Services/       Singleton services (*.shared)
    Utilities/      Extensions.swift, CurrencyManager, etc.
  UI/
    Theme/          FTDesignSystem.swift, AppTheme.swift, AppColors, reusable components
```

`AppState` is `@Observable @MainActor final class` — inject via `.environment(appState)` and read with `@Environment(AppState.self)`.

Navigation: 4 tabs (dashboard, transactions, budget, accounts) + a center FAB. **The tab bar is full.** Any new top-level module must be reachable via Settings (`FinTrack/Features/Settings/SettingsView.swift`), not a new tab.

## Design System

**Never hardcode colors, spacing, radii, or fonts.** Use only the tokens below.

### Colors (`FTColor` in `FTDesignSystem.swift`)
`.accent`, `.income`, `.expense`, `.gold`, `.catBlue`, `.catPurple`, `.catCoral`, `.catTeal`, `.textPrimary`, `.textSecondary`, `.textMuted`, `.accentGradient`, `.heroGradient`

### Spacing (`FTSpacing`)
`.xs=4` `.sm=8` `.md=12` `.lg=16` `.xl=20` `.xxl=24` `.screen=20`

### Radius (`FTRadius`)
`.sm=12` `.md=16` `.lg=22` `.xl=26` `.pill=30`

### Fonts (SwiftUI `.font(...)`)
`.ftDisplay` `.ftAmount` `.ftTitle` `.ftHeadline` `.ftBody` `.ftBodySemibold` `.ftCallout` `.ftCaption` `.ftLabel` (section labels — pair with `.tracking(1.6)`)

### Glass Surfaces
- `.ftGlass(radius)` — standard glass card modifier
- `.ftGlassInteractive(radius)` — glass with press feedback
- `FTBackdrop()` — full-screen gradient background (use as `.background { FTBackdrop() }`)

### Reusable Components
- `FTIconTile(symbol: String, tint: Color, size: CGFloat = 42)` — icon in a glass tile
- `FTProgressBar(value: Double, color: Color, height: CGFloat)` — 0…1 progress bar
- `FTSegmentedControl(options: [String], selection: Binding<String>)`
- `FilterChip(title: String, isSelected: Bool, action: () -> Void)`
- `FTToggleRow` — labeled toggle in a glass row
- `FTTransactionRow` — standard transaction list row

## Two `Color(hex:)` Overloads

| Overload | File | Input |
|---|---|---|
| `Color(hex: UInt)` | `FTDesignSystem.swift` | e.g. `Color(hex: 0x0E9C8A)` |
| `Color(hex: String)` | `AppTheme.swift` | e.g. `Color(hex: "#0E9C8A")` |

Both exist — use the String form in views where hex comes from model data.

## Data Patterns

**Embedded arrays in `@Model`**: Use `Data` + `JSONEncoder`/`JSONDecoder` rather than SwiftData relationships to avoid migration complexity:

```swift
var itemsData: Data = Data()
var items: [MyStruct] {
    get { (try? JSONDecoder().decode([MyStruct].self, from: itemsData)) ?? [] }
    set { itemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
}
```

Use `@Attribute(.externalStorage)` on `Data` properties that may hold large blobs (receipt images, imported files).

## Core Utilities

`Extensions.swift` adds to `Double`: `.formatted(as: currency)`, `.asPercentage(decimals:)`, `.asCompact(currency:)`  
`Extensions.swift` adds to `Date`: `.monthName`, `.shortMonthName`, `.dayNumber`, `.formatted`, `.relativeFormatted`, `.isSameMonth(as:)`, `.isSameDay(as:)`

## UAE Defaults

VAT = 5%, no personal income tax, Zakat = 2.5% of zakatable wealth above nisab. Default currency: `"AED"`.
