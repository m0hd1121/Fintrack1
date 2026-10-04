# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Xcode project: open `FinTrack.xcodeproj`, scheme `FinTrack`, iOS 26.5. One target only; no Package.swift, no test target, no CLI build. In a Linux/cloud container nothing can be built or run — validate by reading code and say so.

## Project reference docs (read these instead of re-scanning the repo)

- `docs/ai/architecture.md` — system shape, launch/lifecycle, main flows (entry, import → review queue → ledger, backups, intents/snapshots).
- `docs/ai/code-map.md` — one entry per file: responsibility, key symbols, relationships, ⚠ suspected issues.
- `docs/ai/maintenance.md` — change workflow, invariants/conventions, validation, issue register, open questions.
- `docs/ai/review-progress.md` — what was reviewed at which commit, reading method, next steps.
- `docs/DISABLED_FEATURES.md` — modules hidden via `DisableableFeature` (keep in sync with `DisableableFeature.disabled`).

Workflow: locate files via the docs → **read the actual source (and callers) before editing; source wins over docs** → change → validate → update the affected `code-map.md`/`maintenance.md`/`architecture.md` entries in the same commit and mention which docs you updated. If a doc contradicts the code, fix the doc and say so. If many commits have landed since the reviewed commit in `review-progress.md`, warn that the docs may be stale.

## Schema Versioning

Wipe-and-recreate, not migrations. In `FinTrack/App/FinTrackApp.swift`:

```swift
let currentSchemaVersion = "v28"   // ← bump this string
```

Bump whenever adding a new `@Model` class or a non-optional property to an existing one, and register every new `@Model` in `AppSchema.modelTypes` (`FinTrack/Core/Models/AppSchema.swift`) — the one list `FinTrackApp` builds its `Schema` from and `DataResetService` walks for "Clear All Data". A missing registration or bump crashes on launch. **A bump deletes all user data — ask the user before bumping**; prefer side stores when possible. Enum raw values are persisted: never rename them.

## Architecture (summary — details in docs/ai/architecture.md)

```
FinTrack/
  App/              FinTrackApp.swift (entry, schema, AppState, AppTab), RootView.swift (router + lifecycle hub)
  Features/         One folder per module (Transactions, Budget, Accounts, Debt, Import, Settings, …)
  Core/Models/      @Model classes + Codable structs     Core/Services/  singleton services (*.shared)
  Core/Utilities/   Extensions.swift                     UI/             Theme tokens + shared components
FinTrackWidget/, FinTrackWatch/   source only — NOT in any build target
```

- `AppState` is `@Observable @MainActor` — inject via `.environment(appState)`, read with `@Environment(AppState.self)` (`selectedTab`, `isLocked`, `baseCurrency`, `showingAddTransaction`, `popToRootTick`).
- Default actor isolation is MainActor (build setting). Mark pure helpers `nonisolated` when run off the main actor.
- **Navigation**: 4 tabs (dashboard, transactions, budget, accounts) + centre add button. **The tab bar is full** — new modules must be reachable from `Features/Settings/SettingsView.swift`. iPad (`horizontalSizeClass == .regular`) uses a `NavigationSplitView` in `RootView`.
- **No App Group entitlement is active**: `UserDefaults(suiteName: "group.com.fintrack.shared")` is not a reliable store; use `UserDefaults.standard` for in-app queues. App Intents never touch SwiftData — they read `WidgetDataService` snapshots and enqueue work that `RootView` drains.
- **Imports never post to the ledger automatically**: email/SMS/Apple Pay → `PendingEmailTransaction` (via `ImportFiler`) → `EmailReviewQueueView` → `EmailSyncService.approveToLedger` (the only posting path).
- **Balances are stored**: posting, editing or deleting money must adjust `Account.balance` (and linked loan/BNPL/debt/salary state) and reverse it symmetrically.
- Hide modules with `DisableableFeature`, never by deleting code or data.

## Design System

**Never hardcode colors, spacing, radii, or fonts.** Use the tokens in `UI/Theme/FTDesignSystem.swift` (single source of truth) and `UI/Theme/AppTheme.swift`.

- Colors `FTColor`: `.bgBase` `.bgElevated` `.textPrimary` `.textSecondary` `.textMuted` `.accent` `.accentDeep` `.accentBright` `.gold` `.income` `.expense` `.catBlue` `.catPurple` `.catCoral` `.catTeal` `.catGold`; gradients `.accentGradient` `.heroGradient` `.portfolioGradient`. `AppColors` aliases (`.surface`, `.primaryGradient`, `.incomeGradient`, …).
- Color helpers: `Color(light:dark:)`, `Color(hex: UInt)` (constants), `Color(hex: String)` (model values), `Color.fromString("teal")` (model color names; default blue).
- Spacing `FTSpacing`: `.xs=4 .sm=8 .md=12 .lg=16 .xl=20 .xxl=24 .screen=20` (`AppSpacing` differs: `.md=16 .lg=24 .xl=32`).
- Radius `FTRadius`: `.sm=12 .md=16 .lg=22 .xl=26 .pill=30`.
- Fonts: `.ftDisplay .ftAmount .ftTitle .ftHeadline .ftBody .ftBodySemibold .ftCallout .ftCaption .ftLabel` (section labels: pair with `.tracking(1.6).fixedSize(horizontal: true, vertical: false)` or the first glyph clips).
- Glass: `.ftGlass(radius)`, `.ftGlassInteractive(radius)`, `.cardStyle(padding:)`, `FTBackdrop()` used as `.background { FTBackdrop() }` (never as a `ZStack` sibling of the screen's `ScrollView`; pin CTAs with `.safeAreaInset`).
- Components: `FTCard`, `FTIconTile`, `FTChip`, `FTProgressBar`, `FTSegmentedControl`, `FTToggleRow`, `FTTransactionRow`, `GlassCard`/`Card`, `PrimaryButton`, `AmountDisplayView`, `SectionHeader`, `EmptyStateView`, `BadgeView`, `IconBadge`, `FilterChip` (in `TransactionsListView.swift`), `AmountTextField` (amount input; parse with `AmountTextField.double(from:)`, never `Double(text)`).
- `.swipeActions` only works inside a `List` — rows in a `ScrollView`/`VStack` use `.contextMenu`. A `Button` wrapping a glass card needs `.contentShape(Rectangle())`.

## Data Patterns

- Embedded arrays in `@Model`: store `Data` + JSON computed accessor (`itemsData` / `items { get set }`); use `@Attribute(.externalStorage)` for large blobs (receipts, files).
- Cross-model links default to loose `UUID?` (`linked*Id`), not `@Relationship`.
- Any sum/comparison across records with their own `currency` must go through `CurrencyService.shared.convert(_:from:to:)`; `Transaction.amountInBaseCurrency` is locked at entry time.
- Income/expense totals skip `Transaction.isPrincipalMovement` (person-to-person lending). A posted expense with `linkedBNPL` = one installment: use `BNPLPlan.applyInstallmentPayment`/`reverseInstallmentPayment`. VAT maths go through `UAEVAT` (`TaxService.swift`).
- `AppSettings` (in `Core/Models/UserProfile.swift`) holds all preferences; read/write via `@Query private var settings: [AppSettings]` and `settings.first`.
- Local data encryption is always on and not configurable: **never add a toggle for it and never name the encryption algorithm in user-facing text** (code comments only).
- `AuditLogEntry` (`SecurityModels.swift`) is append-only; read with `@Query(sort: \AuditLogEntry.timestamp, order: .reverse)`.
- Anything stored outside SwiftData must also be cleared in `DataResetService.wipeDerivedData`.
- Never write credentials, tokens or other secrets into code comments or docs.

## Core Utilities (`Extensions.swift`)

`Double`: `.formatted(as:)`, `.asPercentage(decimals:)` (**does not multiply by 100** — pass percent values), `.asCompact(currency:)`. `Date`: `.startOfMonth`, `.endOfMonth`, `.startOfYear`, `.startOfWeek` (honours the first-day-of-week setting via `Calendar.app`), `.monthName` ("MMMM yyyy"), `.shortMonthName`, `.dayNumber`, `.formatted`, `.relativeFormatted`, `.isSameMonth(as:)`, `.isSameDay(as:)`. `View.dismissKeyboardOnTap()`. `Array.chunked(into:)`.

## Key Services

`CurrencyService` (FX, `.convert`), `NotificationService` (send everything through `deliver(_:)` so settings apply), `NetWorthService` (the only net-worth definition), `PINService`, `SpotlightService`, `WidgetDataService` (snapshots + queues), `AICategorizationService` (rules → learned → keywords), `EmailSyncService` (mail sync, review-queue posting, `KeychainStore`), `SMSIngestService`/`BankSMSParser`, `ImportFiler`/`ImportDeduper`/`ImportLearningService`, `DataTransferService` + `BackupEncryptionService` + `LocalBackupService`/`EmailBackupService` (backups), `DataResetService` (Clear All Data), `BiometricService`. Full list in `docs/ai/code-map.md`.

## UAE Defaults

VAT = 5%, no personal income tax, Zakat = 2.5% of zakatable wealth above nisab. Default currency: `"AED"`.
