Last verified: 2026-07-20 @ 77b9dac

# PROJECT_MAP.md

Compressed navigation index for FinTrack. **This is an orientation tool, not a substitute for source code** — always read the actual file before modifying it; this map omits implementation detail by design. If a file contradicts this map, the source code is right — fix the map and flag it.

Codebase size at last verification: 182 Swift files, ~84,000 lines, across `FinTrack/` (iOS app), `FinTrackWidget/` (widget extension), `FinTrackWatch/` (watchOS companion).

Per-module detail lives in `docs/maps/` (this root file stays under 500 lines; the module maps do not):
- **`docs/maps/MAP_Models.md`** — every `@Model`/Codable struct, properties, relationships, cross-cutting data patterns
- **`docs/maps/MAP_Services.md`** — every service in `Core/Services/`, public method signatures, external APIs, error-handling patterns, actor-isolation quirks
- **`docs/maps/MAP_Features.md`** — every file in every `Features/` subfolder (one-line purpose each) + `App/`, `UI/`, `FinTrackWidget/`, `FinTrackWatch/`

## 1. OVERVIEW

FinTrack is a UAE-focused personal/family/business finance iOS app (SwiftUI + SwiftData, iOS 26 Liquid Glass design). Single Xcode project, no Package.swift, no CLI build, no automated test target — see root `CLAUDE.md` for build/run instructions and the design-system token reference. Architecture is a flat MVVM-ish SwiftUI style: `@Model` classes + `@Query` drive views directly, with ~38 singleton `Core/Services` classes doing all business logic/computation/networking (no separate ViewModel layer). Companion targets: a WidgetKit extension (5 widgets + a Live Activity) and a watchOS app, both reading a shared App Group `UserDefaults` snapshot rather than SwiftData directly.

## 2. DIRECTORY STRUCTURE

```
FinTrack/
  App/              Entry point, ModelContainer/Schema, AppState, AppTab, RootView    → MAP_Features.md
  Core/
    Models/         ~50 @Model classes + Codable value types                          → MAP_Models.md
    Services/       ~38 singleton services (business logic, networking, computation)  → MAP_Services.md
    Utilities/      Extensions.swift (Double/Date/View/Array helpers, see CLAUDE.md)
  Features/         24 subfolders, one per feature area (~140 view files)              → MAP_Features.md
  UI/
    Theme/          FTDesignSystem.swift, AppTheme.swift — design token source of truth
    Components/     AmountTextField.swift
FinTrackWidget/     WidgetBundle (5 widgets) + Live Activity UI, single file
FinTrackWatch/      watchOS companion app (3-tab TabView), reads shared App Group
docs/maps/          Per-module detail maps (see above)
```

## 3. DATA MODELS

~50 `@Model` classes, all registered in `Schema([...])` in `FinTrackApp.swift` (verified — no orphans). No `@Attribute(.unique)` anywhere (CloudKit compatibility constraint). Full catalogue with every property: **`docs/maps/MAP_Models.md`**.

Highlights worth knowing before touching the model layer:
- `Transaction` is the central hub model but has only 5 real SwiftData `@Relationship`s (`account`, `toAccount`, `linkedLoan`, `linkedBNPL`, `documents`); every other cross-model reference in the whole schema (Account matching, salary/lent/borrowed/debt links, tax/VAT links, etc.) is a loose `UUID?` foreign key, not a relationship. Follow this convention for new links.
- Embedded-array pattern is inconsistent: most models use the documented `Data + JSONEncoder/Decoder` computed-property pattern, but `Bill.priceHistory`, `BudgetTemplate.items`, and `Transaction.splitItems/recurringRule/tags` are native SwiftData arrays instead. Check the existing model before assuming which pattern applies.
- Every money-holding model carries its own `currency: String`. Summing/comparing these across records without `CurrencyService.convert(_:from:to:)` first is a real, recurring bug class (see STATE below).

## 4. CORE FEATURES

24 feature areas under `Features/`; full file-by-file breakdown in **`docs/maps/MAP_Features.md`**. Condensed map:

| Area | Primary files |
|---|---|
| Transactions (manual/receipt/voice/CSV) | `Transactions/AddTransactionView.swift`, `TransactionsListView.swift`, `CSVImportView.swift` |
| Email bank-alert ingestion | `Import/EmailImportView.swift`, `BankSetupWizardView.swift`, `EmailReviewQueueView.swift` + `EmailSyncService` |
| Budgets (monthly/annual/envelope/zero-based) | `Budget/BudgetView.swift` + `BudgetService` |
| Savings goals | `SavingsGoals/*` + `SavingsGoalService` |
| Debt (loans/cards/BNPL/lent/borrowed) | `Debt/DebtManagementView.swift`, `Accounts/AddAccountView.swift` (Add forms) + `DebtService` |
| Backup/restore (3 providers) | `Import/iCloudSyncView.swift`, `EmailBackupView.swift`, `GoogleDriveBackupView.swift` + `DataTransferService`/`BackupEncryptionService` |
| Net worth & assets | `NetWorth/NetWorthDashboardView.swift`, `Assets/*` + `NetWorthService` |
| Investments (stocks/crypto/gold) | `Investments/*` + `InvestmentService`, `CryptoPriceService`, `StockPriceService` |
| Income (salary/freelance/rental/dividends) | `Income/*` + `IncomeService` |
| Business/freelance (invoices, clients, mileage) | `Business/*` |
| UAE tax (VAT/FTA/Zakat/income tax) | `Tax/*` + `TaxService` |
| Family/household sharing | `Family/*` + `FamilyService` |
| AI analytics suite (on-device, no LLM) | `AIAssistant/*`, `Intelligence/*` + `AIAnalyticsService`/`FinancialIntelligenceService` |
| Premium advisory tools | `Premium/*` |
| Reports/PDF/CSV export | `Reports/ReportsView.swift` + `ReportExportService` |
| Security & settings | `Settings/*` + `BiometricService` |
| Siri/Widget/Watch quick-add | `AppIntents/FinTrackIntents.swift`, `FinTrackWidget/`, `FinTrackWatch/` + `WidgetDataService` |

## 5. KEY FLOWS

1. **Manual transaction entry**: `AddTransactionView` (+ optional `ReceiptScannerService`/`SpeechTransactionService` capture) → `AICategorizationService.predictCategory` → `Transaction` inserted → `Account.balance` adjusted → `WidgetDataService.updateAll` → `SpotlightService.indexTransactions`.

2. **Email bank-alert ingestion**: `EmailSyncService.runSyncPass`/`startAutoSync` (or `BGTaskScheduler` background) → IMAP fetch or Gmail/Outlook API → `BankEmailParser.parse` → `ImportLearningService` dedup/rename → `AICategorizationService` category guess → `PendingEmailTransaction` enqueued → `EmailReviewQueueView` (approve/reject) or auto-approve (confidence + `BankEmailRule.autoApprove`) → `EmailSyncService.approveToLedger` → real `Transaction` created, `Account.balance` adjusted, linked `BNPLPlan` advanced if applicable.

3. **Budget tracking**: `Transaction.spendingPairs` (base-currency, per category) aggregated by `BudgetView.spending(for:in:)` → compared against `Budget.amount`/`.rolloverAmount` (in the budget's own currency, converted via `CurrencyService`) → `BudgetService.checkAndSendAlerts`/`forecastEndOfMonth` → `NotificationService` fires threshold alerts; `BudgetLiveActivityService` can mirror progress to a Live Activity.

4. **Debt repayment** (Loan / BNPL / MoneyLent / MoneyBorrowed — all four follow the identical pattern): `RecordXPaymentSheet` creates a linked `Transaction` (`linkedLoan`/`linkedBNPL`/`linkedMoneyLentId`/`linkedMoneyBorrowedId`) → deducts the chosen `Account.balance` → updates the debt record's own progress fields (`outstandingBalance`/`paidInstallments`/`repayments` array). Deleting a single payment or the whole debt record **must** reverse the `Account.balance` delta first, or the deduction is orphaned — this exact bug was found and fixed for every one of the four debt types this session.

5. **Backup/restore** (3 provider paths converge on one substrate): `DataTransferService.exportBackup` (JSON of every `@Model`) → `BackupEncryptionService.encryptIfEnabled` (optional AES-GCM, passphrase Keychain-only, never synced) → delivered via `iCloudBackupService` (ubiquity container, needs paid dev account) / `GoogleDriveBackupService` (OAuth+PKCE, `drive.file` scope) / `EmailBackupService` (SMTP to self, no OAuth). Restore reverses the pipeline: fetch → `BackupEncryptionService.decryptIfNeeded` → `DataTransferService.importBackup(mode: .merge/.replace)`.

6. **Siri/Watch quick-add**: `FinTrackIntents` (`LogExpenseIntent` etc.) or `WatchQuickExpenseView` → enqueue a pending-transaction into the shared App Group `UserDefaults` (key `pending_transactions`) → `RootView.drainPendingIntentQueue()` on app foreground/active → creates a real `Transaction`.

## 6. SERVICES & PUBLIC INTERFACES

~38 singleton services under `Core/Services/`, almost all `final class X { static let shared }`. Full catalogue with method signatures, external APIs touched, and per-service actor-isolation notes: **`docs/maps/MAP_Services.md`**.

External network surfaces (all raw `URLSession` or hand-rolled sockets, no third-party networking SDK): `open.er-api.com` + 5 IRR fallback sources (FX rates), `api.binance.com`/CryptoCompare (crypto prices), `query1.finance.yahoo.com` (stock prices), Gmail REST / Microsoft Graph (OAuth email), Google Drive v3 REST (OAuth backup), `places.googleapis.com`/Nominatim (merchant category fallback), plus hand-rolled `IMAPClient`/`SMTPClient` over `Network.framework` for app-password email backup/import.

## 7. ERROR HANDLING & TESTING

**No automated test target exists in the Xcode project** — QA is manual/in-simulator only.

Error handling has three co-existing patterns (detail + file:line examples in `MAP_Services.md`):
1. Silent `try?` swallowing — dominant for persistence (`context.save()`) and notification scheduling.
2. Typed `LocalizedError` enums + `async throws`, caught at the service boundary and turned into a published `lastError: String?` for the UI — never re-thrown to SwiftUI. Used by backup/sync services (`BackupEncryptionError`, `EmailSyncError`, `DriveBackupError`, `EmailBackupError`).
3. Best-effort fallback chains instead of propagation, for external data fetching (FX rates, crypto/stock prices) — silently keep stale/cached data if every source fails.

## 8. CONVENTIONS & CONSTRAINTS

(Design-system tokens, spacing/radius/font rules, and the `Data`+`JSONEncoder` embedded-array convention are already documented in root `CLAUDE.md` — not repeated here.)

- **Schema versioning is wipe-and-recreate, not migration.** Bump `currentSchemaVersion` in `FinTrackApp.swift` (currently `"v28"` — CLAUDE.md's example of `"v15"` is stale) whenever adding a new `@Model` class or a **non-optional** property to an existing one; new **optional** properties (e.g. `Transaction.linkedBNPL` added this session) have not required a bump in practice. **Never bump without explicit user confirmation** — it wipes all local data on next launch.
- **Cross-model references default to a loose `UUID?`, not a `@Relationship`.** Only 6 true relationships exist in the entire schema (see §3). Follow this when linking a new model to an existing one.
- **Currency correctness**: any code that sums or compares two currency-tagged fields (`Budget.amount`, `SavingsGoal.targetAmount`, `Account.balance`, etc.) across records must call `CurrencyService.convert(_:from:to:)` first. Grep for raw `.reduce(0) { $0 + $1.amount }`-style sums on currency-tagged fields as a red flag — several real bugs of this shape were found and fixed in Budget/SavingsGoal/BudgetEnvelope totals across sessions (`BudgetView.swift`, `ReportsView.SavingsGoalsReport`, `AddSavingsGoalView`'s emergency-fund suggestion, `SmartCashAllocationView`'s goal-funding calc). `BudgetEnvelope` now has a working currency picker (`AddEnvelopeView`) — `EnvelopeRow` takes a pre-converted `allocatedAmount` param, `envelopeOverviewCard`/`EnvelopeDetailView` convert before combining with `spent` (always base-currency), and the envelope-to-envelope Transfer sheet converts into the destination's own currency. **Not yet fixed**: `SmartCashAllocationView.totalCash` (sums `Account.balance` across accounts, no conversion).
- **Debt repayment pattern** (Loan/BNPL/MoneyLent/MoneyBorrowed): recording a payment must create a linked `Transaction` AND deduct the paying `Account`'s balance; deleting that payment or the parent record must reverse the balance delta. Established across `DebtManagementView.swift`/`AccountDetailView.swift` after real "orphaned deduction" bugs were found and fixed for every one of the four types.
- **When deleting a whole MoneyLent/MoneyBorrowed record, reverse each linked `Transaction` by its own `.type`, never a single hardcoded direction.** Both `linkedMoneyLentId`/`linkedMoneyBorrowedId` now tag *two* kinds of linked transaction with opposite signs: the initial lend/borrow (created by `AddMoneyLentView`/`AddMoneyBorrowedView` — `.expense` for lending, `.income` for borrowing) and repayments (the reverse of each). `deleteLentItem`/`deleteBorrowedItem` (`DebtManagementView.swift`) and the duplicate `MoneyLentDetailSheet`/`MoneyBorrowedDetailSheet.deleteEntireRecord()` all originally reversed every linked transaction with one hardcoded `+=`/`-=`, correct only for repayments — fixed to `switch tx.type { case .expense: += ; case .income: -= }` per transaction. Per-repayment `deleteRepayment`/`updateRepayment` (scoped by `linkedDebtRepaymentId`, never matching the initial transaction) didn't have this bug and were left alone.
- **`.swipeActions` silently does nothing outside a `List`.** Several feature screens (`BudgetView.swift`'s tabs, `DebtManagementView.swift`'s tabs, `AccountsView.swift`'s tab list) use `ScrollView` + `VStack` instead of `List` for custom row styling, and `.swipeActions` on a row in that context never renders — no crash, no warning, just a dead no-op. Every row that needs swipe-style actions in a non-`List` container must use `.contextMenu` (long-press) instead; this is the established working pattern across Loans/BNPL/Lent/Borrowed/Budget/Goals/Envelopes/Accounts. When adding a new delete/edit/archive action to a row, check the enclosing container before reaching for `.swipeActions`.
- **`.gridCellColumns(_:)` only works inside `Grid`, not `LazyVGrid`.** If a `LazyVGrid` needs one cell to span full width (e.g. a "wide" card in a 2-column grid), render it as a separate full-width view below/outside the `LazyVGrid` instead — the modifier is silently ignored in a `LazyVGrid` context (see `AccountsView.moduleGrid`).
- **`Button` wrapping a card styled with `.ftGlassInteractive`/`.ftGlass` (`glassEffect()`) needs an explicit `.contentShape(Rectangle())`.** Without it, taps only register on the card's actual content glyphs (icon/text) — not on `Spacer()` gaps or padding, which is most of a typical card. This produced real "tapping does nothing" bugs on the Accounts module grid and the Loan/BNPL/Lent/Borrowed cards in `DebtManagementView.swift`. Any new `Button { ... } label: { ...ftGlassInteractive... }` card needs `.contentShape(Rectangle())` (or a matching rounded shape) added.
- **Actor isolation**: Xcode project has Default Actor Isolation = MainActor, so plain classes/enums are implicitly MainActor-isolated. Mark pure-computation types `nonisolated` explicitly when they run via `Task.detached` (`BackupEncryptionService`, `KeychainStore`) or are short-lived non-UI network clients not meant to be actor-isolated at all (`IMAPClient`, `SMTPClient`, both `@unchecked Sendable`).
- **Tab bar is full** (4 tabs + centre FAB). New top-level modules must be reachable via `Settings/SettingsView.swift`, not a new tab (per CLAUDE.md).
- **FinTrackWidget has 5 widgets, not 3** — CLAUDE.md's "Platform Extensions" section is stale on this count (`FinTrackBalanceWidget`, `FinTrackBudgetWidget`, `FinTrackBillsWidget`, `FinTrackPaymentsWidget`, plus the Live Activity configuration).
- **Email account sign-in: OAuth (`ASWebAuthenticationSession`) for every provider that has one, password-IMAP only where OAuth is impossible.** `EmailProvider.supportsOAuthSync` is `true` only for `.gmail`/`.outlook` — both go through the single `EmailSyncService.connect(provider:context:)` OAuth+PKCE flow (`ASWebAuthenticationSession`); `EmailImportView.connect(_:)` no longer has a Gmail-specific password-IMAP fallback (removed — previously fell back to `IMAPSignInSheet` when no client ID was configured, now always opens `OAuthSetupSheet` like Outlook). `.icloud`/`.imap` stay on `IMAPSignInSheet` (app-specific password) because there is no public third-party OAuth authorization flow for iCloud Mail, and `.imap` is an arbitrary user-supplied host with no known OAuth endpoint — this is a protocol constraint, not a gap to close.
- **`GmailOAuthClientID` is baked into `FinTrack-Info.plist`** (real iOS-type OAuth client ID, safe to commit — Google treats native-app client IDs as non-confidential, PKCE covers the security). `EmailSyncService.storedClientId(for:)` checks this Info.plist key before the UserDefaults-backed manual-paste fallback, so Gmail sign-in requires zero setup for anyone building/running this repo: tap Gmail → straight to Google's real login page. No `CFBundleURLTypes` entry is needed for the reversed-client-ID redirect scheme — `ASWebAuthenticationSession` intercepts its own callback without app-level URL-scheme registration. Outlook has no equivalent baked-in client ID yet (still requires the one-time `OAuthSetupSheet` paste) since Microsoft Entra app registration wasn't done this session.
- **Before editing a form struct, grep for its call sites, not just trust that its file is the live one.** `AddMoneyLentView.swift`/`AddMoneyBorrowedView.swift` had a working account picker + linked-`Transaction`/balance logic added across two earlier sessions — invisible the whole time, because `DebtManagementView.swift`'s actual `.sheet(...)` presentations all called a separate, private, dead-simple `AddMoneyLentSheet`/`AddMoneyBorrowedSheet` (no account picker, free-text currency field, and — worse — no linked `Transaction`/balance deduction on the *initial* lend/borrow at all). Both files were only ever exercised by their own `#Preview` blocks. Fixed by repointing all 6 call sites in `DebtManagementView.swift` to the real `AddMoneyLentView`/`AddMoneyBorrowedView` and deleting the two dead private structs outright. **When a user reports a UI/behavior bug that contradicts source you just read, grep `StructName(` across the whole target (not just the definition site) before concluding it's a stale-build issue** — a same-named-but-different or a second, unwired struct is a real, recurring failure mode in this codebase.
- **`.tracking(1.6)` on an uppercase section-header `Text` clips its leading glyph unless paired with `.fixedSize(horizontal: true, vertical: false)`.** CLAUDE.md's own documented convention ("`.ftLabel` — section labels — pair with `.tracking(1.6)`") was copy-pasted into 68 files without this — every section header app-wide rendered with its first letter cut off ("PERSON INFO" → "ERSON INFO", "AMOUNT & DATES" → "MOUNT & DATES", etc.), confirmed identically on the Lend/Borrow Money screens and swept everywhere in one pass (229 occurrences). **Any new `.tracking(1.6)` label must add `.fixedSize(horizontal: true, vertical: false)` immediately after it** — this is now the required pairing, not just `.tracking(1.6)` alone.
- **Hiding a Premium Feature must never delete its code, model, or data — use the `DisableableFeature` system.** `AppSettings.disabledFeatures: String?` (comma-separated raw values, `nil` = `DisableableFeature.disabledByDefault`) is read/written only through `AppSettings.disabledFeatureSet`/`.isFeatureEnabled(_:)` in `DisableableFeature.swift`, mirroring the pre-existing `dashboardHiddenWidgets` comma-separated-`String` convention rather than inventing a new storage mechanism. `SettingsView`'s "Premium Features" card filters `DisableableFeature.allCases` through this before rendering `NavigationLink`s (`visibleFeatures` + `destinationView(for:)` switch) and always shows a "Manage Features" row → `DisabledFeaturesView` (toggle list, no own `NavigationStack` since it's pushed). Collaborative Planner ships disabled-by-default through this mechanism (`disabledByDefault = [.collaborativePlanner]`), not a code comment-out. **Any future "disable feature X" request should add a case to `DisableableFeature` and nothing else** — never comment out or delete the feature's `NavigationLink`/view/model.
- **A `Budget.category` match is not enough to identify *which* budget a transaction belongs to once two budgets share a category** (e.g. "Netflix Budget" + "Spotify Budget", both `.subscriptions`). `BudgetView.swift` already had a keyword-disambiguation system for this (`Budget.merchantFilter`, or an auto-derived keyword from `Budget.name`) but it only ran Budget→spending, privately, inside that one file — `AddTransactionView.fireBudgetAlertIfNeeded` used a naive `budgets.first(where: { $0.category == category })` (ignoring `isActive` too) and summed the *entire* category's spend against whichever budget won that ordering, so multi-budget categories could alert against the wrong budget with the wrong total. Fixed by moving the matching logic into `BudgetService` (`autoKeyword`/`effectiveKeyword`/new `matchingBudget(...)`/`spending(...)`) as the single source of truth — `BudgetView.swift` now delegates to it, and `AddTransactionView` uses it both for the alert and for a live "Budget" indicator row. **Any new code that needs to know which budget a transaction affects must go through `BudgetService.matchingBudget(...)`, never a raw category `.first(where:)`.**

## 9. STATE

Active branch: `claude/finance-app-features-f1fo3p`. No release/version tags found in this pass.

**Recently completed** (most recent commits, newest first):
- General "Disabled Features" system (`DisableableFeature` enum + `AppSettings.disabledFeatures` + `DisabledFeaturesView`) replacing one-off feature disabling; Collaborative Planner ships disabled-by-default through it with all code/data intact.
- Bills tab in Debt Management (`SubscriptionsTabContent` embedded), Bill payment "Pay From" account picker with linked `Transaction`/balance deduction (`RecordPaymentSheet`), and `AddTransactionView` auto-linking a paying transaction to its `Bill` by title/merchant match.
- Budget AI-recognition: `AddTransactionView` shows a live read-only "Budget" row and `fireBudgetAlertIfNeeded` now routes through `BudgetService.matchingBudget`/`.spending` instead of a naive category `.first(where:)`.
- Accounts & Assets redesign (per a claude.ai/design mockup, imported via the `DesignSync` MCP tool): `AccountsView.swift` rebuilt with a net-worth hero, a 5-card module grid (Income/Investments/Goals/Assets & Liabilities/Debt), and a segmented Accounts/Investments/Crypto/Assets tab list. Income Management, Investment Portfolio, Savings Goals, Assets & Liabilities, Net Worth, and Debt Management are no longer on `DashboardView` — their sheets are now opened from the Accounts page's module cards instead, reusing the same underlying feature views unchanged. `DashboardWidget`'s now-dead `.income`/`.investments`/`.goals`/`.debt` cases were removed from `DashboardCustomizerView` accordingly.
- BNPL parity with Loan: edit, currency picker, delete-with-cleanup, and a full Record Payment flow (new `linkedBNPL` relationship + `bnplRepayment` category on `Transaction`).
- Cross-currency conversion fixes across Budget/SavingsGoal totals, rollover processing, forecasts, and alerts (`BudgetService`, `BudgetView`, `ReportsView`, `AddSavingsGoalView`, `SmartCashAllocationView` partially).
- Loan detail sheet + discoverable Record Payment button (previously buried in a long-press menu); swipe-to-delete removed in favor of the same long-press context-menu pattern used by Lent/Borrowed.
- Full 24-currency picker rolled out to every remaining truncated currency list app-wide.
- Email/SMTP backup (no-OAuth alternative to Google Drive/iCloud) with hourly auto-backup via a real foreground polling loop.
- AES-256-GCM backup encryption (passphrase Keychain-only, `BackupEncryptionService`).
- `AmountTextField` (thousands-separator input) rolled out to 35+ files app-wide.
- Google Drive backup upgraded to two-way "gossip" sync.
- Various Debt Management edit/delete fixes (orphaned account-deduction bugs across Lent/Borrowed/Loan).
- Section-header clipping fix app-wide (`.tracking(1.6)` needs `.fixedSize(horizontal: true, vertical: false)`, 229 occurrences/67 files).
- `AddMoneyBorrowedView` account picker + linked-`Transaction` logic (was missing entirely; `AddMoneyLentView` had it, `AddMoneyBorrowedView` didn't) + the per-transaction-type delete-reversal fix it exposed.
- `AddEnvelopeView` currency picker + the cross-currency correctness fixes it required (`EnvelopeRow`, `envelopeOverviewCard`, `EnvelopeDetailView`, envelope-to-envelope Transfer).

**Known TODOs / dormant issues** (flagged during this mapping pass, not yet fixed):
- `SmartCashAllocationView.totalCash` sums `Account.balance` across accounts without currency conversion.
- No automated test suite exists at all.
