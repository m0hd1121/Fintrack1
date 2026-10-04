# Architecture

Verified by reading the source at commit `3411a90` (see `review-progress.md`). Symbols are named so you can grep; line numbers are deliberately avoided because they drift.

## Shape of the system
- **One iOS target** (`FinTrack`, iOS 26.5, Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). The project uses a file-system-synchronised group, so every file under `FinTrack/` is compiled and nothing else is. No SPM packages, no tests, no CI.
- **SwiftUI + SwiftData, local-first.** All user data lives in one SwiftData store (53 `@Model` types listed in `Core/Models/AppSchema.swift`). There is no server. Network use: FX rates, crypto (Binance) and stock (Yahoo) prices, merchant lookups (`MerchantCategoryService`), email (Gmail/Outlook REST or IMAP), SMTP for email backup, Google Drive (disabled feature).
- **Layers**: `App/` (entry + root router) → `Features/<Module>/` (SwiftUI screens; much business logic still lives in views) → `Core/Services/` (mostly `.shared` singletons, `@MainActor` by default) → `Core/Models/` (`@Model` classes + Codable structs). UI tokens/components in `UI/`.
- **Navigation**: 4 tabs (Dashboard, Transactions, Budget, Accounts) + centre add button (`MainTabView` + `CustomTabBar` in `RootView.swift`); iPad uses a `NavigationSplitView`. Every other module is reached from `SettingsView` (pushed from the Dashboard profile button) or from toolbar/menu links inside the tab screens (Budget → Income/Debt/Bills; Accounts → Net Worth, Portfolio, Goals, assets). `DisableableFeature` hides modules in code (Settings checks `isEnabled`).
- **Not built**: `FinTrackWidget/` and `FinTrackWatch/` are source-only (no targets), and the App Group entitlement is not wired into the build, so `UserDefaults(suiteName: "group.com.fintrack.shared")` silently doesn't persist. In-app queues therefore use `UserDefaults.standard`.

## Launch and lifecycle (`App/FinTrackApp.swift`, `App/RootView.swift`)
1. `FinTrackApp` compares UserDefaults `fintrack_schema_version` with `currentSchemaVersion` ("v28"); on mismatch it **deletes the store files** and pending notifications (wipe-and-recreate, no migrations), then builds the `ModelContainer` (`fatalError` on failure). Injects `AppState`, `CurrencyService`, `CryptoPriceService` into the environment.
2. `RootView` routes: Keychain device-snapshot restore offer (fresh install + snapshot exists) → `OnboardingView` → `LockScreenView` (device biometrics/passcode only) → main UI.
3. **On appear and every `.active`**: `ensureDefaults` (creates `UserProfile`/`AppSettings`), lock if configured, process recurring and scheduled transactions, bill/income/debt alerts, drain queues (Siri/Watch `pending_transactions`, SMS texts, Apple Pay, navigation requests), backup triggers; `.active` also runs an email sync pass. `.background` schedules the BG refresh task and locks. A `.task` starts auto email sync, change-driven local backup, Drive/email auto-backup and price refreshes.

## Main flows
- **Manual entry**: `AddTransactionView.commitSave` inserts a `Transaction` and mutates `Account.balance` directly (balances are stored, not derived), plus loyalty/bill/cheque side effects. Every other screen that posts or deletes money (Debt, Income, Savings… sheets, `TransactionsListView.deleteTransaction`) repeats the "post tx + adjust balance / reverse on delete" pattern inline, converting with **live** FX rates.
- **Import → review queue → ledger** (the core pipeline):
  - Email: `EmailSyncService.runSyncPass` → provider fetch → `BankEmailParser` → `ImportLearningService`/`ImportDeduper` scoring → `ImportFiler.file` creates a `PendingEmailTransaction`.
  - SMS: Shortcuts automation → `LogTransactionFromText` intent → queued text → `RootView.drainPendingSMSTexts` → `SMSIngestService.ingest` → `BankSMSParser` (bank templates, then on-device Foundation Models fallback with evidence grounding) → same filer.
  - Apple Pay: Shortcuts "Transaction" automation → intent → queue → `ApplePayIngestService` → same filer.
  - Review: `EmailReviewQueueView` (approve/reject/edit; gates for loan choice, BNPL plan allocation, possible duplicates) → `EmailSyncService.approveToLedger` is the **only** path from the queue to the ledger (creates txs, adjusts the account, advances BNPL plans / loans, creates `MoneyLent` shares).
  - CSV import (`CSVImportView` → `CSVImportService`) inserts directly (no queue). The PDF and OFX screens are simulations (see maintenance).
- **Backups**: `DataTransferService` (DTO export/import JSON) is the single engine; `BackupEncryptionService` encrypts with a device-bound Keychain key. Channels: `LocalBackupService` (Application Support file + Keychain snapshot that survives uninstall), `EmailBackupService` (SMTP to self, IMAP restore), `GoogleDriveBackupService` (disabled), manual import in Settings. Restore = merge (skip existing ids) or replace.
- **Snapshots for intents/widgets**: `DashboardView.pushWidgetData` → `WidgetDataService.updateAll` writes JSON snapshots; App Intents (`Features/AppIntents`) read snapshots, never SwiftData, and write work into queues drained by `RootView`.
- **Notifications**: `NotificationService` schedules reminders for bills, loans, BNPL, debts, cheques, salary, goals, budgets, digests. The Notification settings toggles are not consulted by these calls.
- **Clear All Data**: `DataResetService.clearAll` wipes every schema type except settings/profile/email account/bank rules, plus Spotlight, snapshots, queues, learned data, notifications, and on-device backups.

## Cross-cutting facts to keep in mind
- Money values carry their own `currency`; `Transaction.amountInBaseCurrency` is locked at entry time. Aggregations are inconsistent about converting (many screens sum mixed currencies); the base currency can be changed without recomputing stored base amounts.
- There are **five different net-worth computations** (`AccountsView`, `NetWorthService`, `DashboardView.computeMetrics`, `ReportsView.NetWorthReport`, `AICFOModeView`) and three VAT computations.
- Loose `UUID?` links (`linked*Id`) are the norm; only a handful of real `@Relationship`s exist (e.g. `Transaction.account`, `linkedLoan`, `linkedBNPL`, attachments, custom-category tree).
- Side stores avoid schema bumps: `PendingLoanLinkStore` (UserDefaults), BNPL allocations encoded in `PendingEmailTransaction.bnplSelectionRaw`, `NavigationRequestStore`, learned merchant/tag dictionaries.
