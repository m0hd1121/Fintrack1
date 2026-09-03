# MAP_Features.md — Feature Directory Reference

Part of PROJECT_MAP.md (see root for navigation). All folders under `FinTrack/Features/` unless noted.

### Features/AIAssistant/
- AIAssistantView.swift — AI hub landing screen: hero card, quick stats, features grid linking to all AI tools
- AnomalyDetectionView.swift — detects & lists unusual spending transactions by severity (high/medium/low) with filters
- BillNegotiationView.swift — surfaces bills worth negotiating, potential savings, negotiation scripts
- BudgetingCoachView.swift — weekly personalized coaching insights/tips from spending history and savings goals
- DigitalTwinView.swift — "what-if" financial simulator: net worth projection chart from adjustable params
- ESGAnalysisView.swift — scores spending by environmental/social/governance impact, carbon + category breakdown
- FinancialHealthView.swift — animated overall health score ring (0-100/grade) with component breakdown and tips
- PredictiveBalanceView.swift — 30-day account balance forecast chart using recurring bills/income patterns
- SavingsOpportunityView.swift — lists dismissable AI-detected savings opportunities ranked by priority
- SpendingPatternsView.swift — charts spending by day-of-week/hour/month, top merchants, peak-spend insights

**Core features:** on-device AI analytics suite — `AIAssistantView` is the hub; every other file is one self-contained analysis module driven by `AIAnalyticsService`.

### Features/Accounts/
- AccountDetailView.swift — single account detail: transaction list, 30-day balance sparkline, monthly bar chart; also hosts `RegularLoanDetailView`, `LoanPaymentHistorySection`, `RecordLoanPaymentSheet`
- AccountsView.swift — main accounts hub: balances across bank accounts, cards, investments, crypto, gold, gift cards, loyalty, loans, BNPL. Its module cards open Income/Portfolio/Savings Goals/Assets & Liabilities/Debt as **pushed** screens via a single enum-driven `.navigationDestination(item: $moduleRoute)` (NOT one `isPresented:` per module — several `isPresented` destinations on one stack contend for a single slot and freeze the main thread), not sheets; Net Worth + all Add/Edit forms stay as sheets.
- AddAccountView.swift — add/edit bank account form; also hosts `AddLoanView`, `AddBNPLView`, `AddGiftCardView` and other asset-adjacent add sheets

**Core features:** bank account CRUD & balance dashboard (`AccountsView`/`AddAccountView`/`AccountDetailView`); Loan and BNPL add/edit forms live here too (`AddLoanView`, `AddBNPLView`), separate from their detail/repayment UI in Features/Debt/.

### Features/AppIntents/
- FinTrackIntents.swift — Siri/Shortcuts intents: `LogExpenseIntent`, `LogIncomeIntent`, `LogTransactionFromText` (silent SMS→review-queue intent fed by a Shortcuts "When I receive a message" automation, see `SMSImportView`; **deliberately absent from `FinTrackShortcuts.appShortcuts`** — an App Shortcut is a fixed, parameterless entry point with no bindable fields, so registering it there made the automation picker offer an unconfigurable tile that prompted "enter a message" at every run), `GetBalanceIntent`, `GetBudgetStatusIntent`, `TransactionEntity`, `FinTrackShortcuts` provider

**Core features:** Siri & Shortcuts integration — intents enqueue into `WidgetDataService`'s pending transaction queue, drained by `RootView`.

### Features/Assets/
- AddRealEstateView.swift — add/edit real estate property form
- AssetsLiabilitiesView.swift — aggregated net worth view across real estate, vehicles, personal, digital assets
- DigitalAssetsListView.swift — list/filter/summary of digital assets with gain/loss totals
- PersonalAssetsListView.swift — list/filter of personal assets with market/insurance/purchase totals
- RealEstateListView.swift — list of real estate properties with total value/equity summary
- VehicleListView.swift — list of vehicles with total value, depreciation, registration/insurance expiry alerts

**Core features:** non-liquid asset tracking — `AssetsLiabilitiesView` is the aggregate hub; totals computed via `NetWorthService` (not in this folder).

### Features/Bills/
- AddBillView.swift — add/edit recurring bill/subscription form (cycle, category, autopay, reminders)
- BillDetailView.swift — bill detail: hero card, autopay info, price-history/waste analysis, record payment. `RecordPaymentSheet` (private) has a "Pay From" account picker (defaults to the default account) — recording a payment now creates a linked expense `Transaction` (`linkedBillId`, category via `BillCategory.transactionCategory`) and deducts that account's balance, on top of `BillService.recordPayment`'s existing due-date/history bookkeeping. `Bill` has no payment-history array (just `lastPaidDate`/`lastPaidAmount`), so there's no past-payment edit/delete flow needing the same balance-reversal treatment as Lent/Borrowed.
- BillsView.swift — bills hub: calendar view + subscriptions list tab; defines `SubscriptionsTabContent` (internal, not `private` — reused directly by `DebtManagementView`'s Bills tab, see below) plus several `private` row/card helpers (`SummaryHeroCard`, `BillSectionHeader`, `WasteAlertCard`, `AutoPayWarningCard`, `CalendarTabContent`, etc.) that stay file-scoped

**Core features:** recurring bills & subscriptions — list/calendar, create/edit, drill-down + waste analysis (`BillService`). Also surfaced as a 10th tab in Debt Management (`DebtManagementView`'s Bills tab embeds `SubscriptionsTabContent` directly rather than duplicating it — same data, same Add/Edit/Detail sheets).

### Features/Budget/
- BudgetView.swift — budget hub, 4 tabs (Monthly/Annual/Envelopes/Zero-Based); spending-by-category computation, recommendations, links to bills/income/debt; also hosts `AddBudgetView`, `EnhancedBudgetRow`, `AnnualBudgetRow`, `EnvelopeRow`, `ZeroBasedAllocationRow`, `SavingsGoalRow`, `BudgetDetailView`, `AddEnvelopeView`, `EnvelopeDetailView`

**Core features:** all budgeting modes (monthly/annual/envelope/zero-based) in one large file, plus savings-goal row rendering and template/recommendation entry points. Currency-conversion helpers (`effectiveBudgetAmount`, `convertedRollover`, etc.) live in the main `BudgetView` struct.

### Features/Business/
- BusinessExpenseView.swift — filters/tags business-deductible transactions by project/client/date range
- BusinessFreelancerView.swift — business hub: summary strip + module grid
- ClientManagementView.swift — client list/search/filter by status
- InvoiceCreatorView.swift — create/edit invoice: client picker, line items, VAT calculation
- MileageTrackerView.swift — logs/filters business mileage trips
- ProjectProfitabilityView.swift — per-project profitability: revenue vs expenses vs invoices

**Core features:** freelancer/small-business toolkit — `BusinessFreelancerView` is the hub; client/invoice/VAT workflow, mileage, and profitability round it out.

### Features/Categories/
- CategoryManagementView.swift — CRUD for custom transaction categories (root/child hierarchy, archive, search)
- RuleManagementView.swift — CRUD for auto-categorization rules (priority-ordered)

**Core features:** category taxonomy (`CustomCategory` tree) and auto-categorization rules (`CategorizationRule`, drives `AICategorizationService`).

### Features/Dashboard/
- DashboardCustomizerView.swift — defines `DashboardWidget` enum for show/hide toggling
- DashboardView.swift — main dashboard: net worth hero, monthly metrics, income/budget/goals/debt/portfolio/bills widgets, AI insights
- UpcomingPaymentsView.swift — aggregated upcoming payments (loans, cards, BNPL, recurring, bills, **money borrowed**) filterable by date range. `MoneyBorrowed` rows use `dueDate` + `remainingBalance` and skip repaid/written-off/no-due-date items; `MoneyLent` is deliberately excluded (incoming, not a payment). The Dashboard's own 5-item preview list (`DashboardView.metrics.upcomingPayments`) is built separately — keep the two in sync when adding a source.

**Core features:** app home screen — widget visibility controlled by `DashboardCustomizerView`'s enum + `AppSettings.dashboardHiddenWidgets`; `UpcomingPaymentsView` is a drill-down sheet.

### Features/Debt/
- AddMoneyBorrowedView.swift — add/edit money borrowed from a person, with a "Deposit Into" account picker (linked account, due date, reminders); creates/reverses a linked `Transaction` (`.income`, `.personalBorrowed`) + `Account` balance delta, same pattern as Loan/BNPL
- AddMoneyLentView.swift — add/edit money lent to a person, with a "Lend From" account picker (linked account, due date, reminders); creates/reverses a linked `Transaction` + `Account` balance delta, same pattern as Loan/BNPL
- DebtManagementView.swift — debt hub, 10 tabs (overview/loans/snowball/avalanche/calculator/lent/borrowed/BNPL/utilization/bills); also hosts `LoanDetailSheet`, `RecordBNPLPaymentSheet`, `BNPLDetailSheet`, `MoneyLentDetailSheet`, `MoneyBorrowedDetailSheet`, delete-with-cleanup helpers. All 6 Add/Edit Lent/Borrowed sheet presentations here now call the real `AddMoneyLentView`/`AddMoneyBorrowedView` structs (see §8 — this file used to contain dead-code duplicates `AddMoneyLentSheet`/`AddMoneyBorrowedSheet`, now deleted). The Bills tab embeds `Features/Bills/BillsView.swift`'s `SubscriptionsTabContent` (own `@Query` for `Bill`/`Transaction`, own `showingAddBill`/`selectedBill` state, `AddBillView`/`BillDetailView` sheets) rather than a separate implementation.

**Core features:** debt tracking & payoff planning — loans, credit cards, BNPL, snowball/avalanche strategies, interest calculator, all in one multi-tab file. Every debt type (Loan/BNPL/MoneyLent/MoneyBorrowed) follows the same pattern: tap card → detail sheet → Record Payment creates a linked `Transaction` + deducts an `Account`; delete reverses that deduction first. The *initial* lend/borrow now follows this same pattern too (previously MoneyLent/MoneyBorrowed only got this on repayment, not on creation — see §8).

### Features/Family/
- ChildAllowanceView.swift — children list with allowance summary, per-child cards, record payment
- FamilyDashboardView.swift — per-family-group dashboard: cash flow, member cards, shared goals preview
- FamilyFinanceView.swift — family finance hub/entry point (or setup prompt if no group)
- FamilyPermissionsView.swift — permission matrix editor for family members
- FamilySetupView.swift — create/manage family group (name, admin, members, delete group)
- HouseholdBudgetView.swift — household-wide budget: cash flow, contributions, expense breakdown, trend chart
- SharedFamilyGoalsView.swift — shared family savings goals list (active/completed/archived)

**Core features:** family/household finance sharing — `FamilyFinanceView` is the hub (created via `FamilySetupView`); dashboards driven by `FamilyService`; sub-features gated by `FamilyGroup`/`FamilyMemberData` permissions.

### Features/Import/
- BankSetupWizardView.swift — configure one bank's email-alert profile (`BankEmailRule` CRUD)
- EmailBackupView.swift — backup/restore via plain email (IMAP, app-password, no OAuth)
- EmailImportView.swift — email import hub: connect mailboxes, manage bank rules, manual paste import
- EmailReviewQueueView.swift — inbox-style swipe review (approve/reject/edit) of parsed bank alert emails
- GoogleDriveBackupView.swift — backup/restore via Google Drive OAuth
- ImportIntegrationView.swift — import & integration hub: sync status, links, history
- OFXImportView.swift — step-based OFX/QIF/QFX file import
- PDFImportView.swift — step-based bank statement PDF import
- LocalBackupView.swift — backup hub (titled just "Backup"; on-device, read-only to the user — Back Up Now, "Back Up After Every Change" toggle (change-driven via `LocalBackupService.startObservingChanges`, not a schedule), Restore for the single retained backup; deliberately **no** delete/share): replaced `iCloudSyncView`.
- SMSImportView.swift (+ `SMSBankRuleSheet`) — SMS import hub: a single one-time Shortcuts setup walkthrough (`shortcuts://create-shortcut` deep link) — one automation with multiple senders selected under "From" covers every bank, since bank identification/parsing/account-matching are all automatic content-based (`BankSMSTemplateStore`/`EmailSyncService.recognizeAccount`) and need no app-side config. "My Banks (Optional)" (bank picker + SMS sender ID + linked account, reusing `BankEmailRule` tagged `"sms:…"`) exists only to pin a bank's transactions to a specific account or hint an unrecognized sender — no auto-approve control, every import waits for manual approval. First-SMS-within-24h status card, plus a "Not recognized" section listing SMS that reached the app but produced no transaction (raw text + sender + time, from `SMSIngestService.unparsedMessages`, with Clear) — so a message never vanishes silently and you can see exactly what text the Shortcuts automation delivered. See `BankSMSParser`/`SMSIngestService` (MAP_Services.md).

**Core features:** email-based bank ingestion (`EmailImportView` + `BankSetupWizardView` + `EmailReviewQueueView`, driven by `EmailSyncService`); SMS-based bank ingestion (`SMSImportView`, driven by `BankSMSParser`/`SMSIngestService`, filed into the same `EmailReviewQueueView`); file-based import (`OFXImportView`, `PDFImportView`, `ImportIntegrationView`); 3 backup/restore providers (`LocalBackupView` (offline/on-device), `EmailBackupView`, `GoogleDriveBackupView`), each wrapping its own `*BackupService.shared`.

### Features/Income/
- AddDividendView.swift — add/edit dividend payment
- AddFreelanceProjectView.swift — add/edit freelance project
- AddRentalPropertyView.swift — add/edit rental property
- AddSalaryRecordView.swift — add/edit salary record
- FreelanceView.swift — freelance projects list: active/completed, contract value, overdue invoices
- IncomeManagementView.swift — income hub, 7 tabs (overview/salary/freelance/rental/dividends/passive/stability)
- RentalView.swift — rental properties list: monthly rent, collection rate, occupancy
- SalaryTrackerView.swift — salary records list: expected monthly total, payment history

**Core features:** multi-stream income tracking — `IncomeManagementView` is the tabbed hub; per-income-type list+add screens for salary/freelance/rental/dividends, all via `IncomeService`.

### Features/Intelligence/
- FinancialIntelligenceView.swift — health score card, deterministic insights, predictions (from `FinancialIntelligenceService`, fully on-device, no network)

**Core features:** single view surfacing `FinancialHealthScore`/`IntelligenceInsight`/`IntelligencePrediction`.

### Features/Investments/
- AddCryptoView.swift — add/edit `CryptoHolding` (coin search, purchase lots, wallet address)
- AddGoldHoldingView.swift — add/edit `GoldHolding` (metal/form, weight unit, Dubai Gold Souk fields)
- AddInvestmentView.swift — add/edit `Investment` (stock/ETF/fund, expense ratio/dividend yield, lots)
- InvestmentPortfolioView.swift — tabbed portfolio hub (Overview/Holdings/Crypto/Gold/Allocation/Performance/Dividends/Cap Gains/Scenarios/Simulation), live prices via `CryptoPriceService`/`StockPriceService`

**Core features:** portfolio management across stocks/ETFs, crypto, gold — add forms feed the multi-tab hub.

### Features/LiveActivity/
- BudgetLiveActivityService.swift — `BudgetActivityAttributes` (ActivityKit) + `LiveActivityService` (start/update/end a budget-spending Live Activity)

**Core features:** Live Activity lifecycle, mirrored by `BudgetLiveActivityAttributes` in `FinTrackWidget.swift`.

### Features/NetWorth/
- NetWorthDashboardView.swift — tabbed net-worth dashboard (Overview/History/Forecast/Allocation/Milestones), aggregates every asset/liability model

**Core features:** comprehensive net worth calculation/visualization + historical snapshots + milestone tracking.

### Features/Onboarding/
- OnboardingView.swift — first-launch flow: paged intro, currency/name setup, writes completion + base currency into `AppState`

**Core features:** one-time onboarding sequence gating `RootView` (`OnboardingPage` model, `PageView`/`SetupPage` renderers).

### Features/Premium/
- AICFOModeView.swift — "AI CFO" advisory view generating `CFORecommendation`s from period-filtered data
- CollaborativePlannerView.swift — manages `AdvisorAccess` records (invite/view/revoke)
- EstatePlanningView.swift — aggregates all assets/liabilities into a net-estate summary
- FinancialEducationView.swift — lesson library with lessons generated from the user's own data
- InsuranceOptimizerView.swift — tracks `InsurancePolicy` records, premium totals, expiring-soon alerts
- LifeEventPlanningView.swift — tracks `LifeEventPlan` milestones (marriage, home, baby, etc.)
- RetirementSimulationView.swift — UAE retirement projection (readiness, gratuity, growth, milestones)
- SmartCashAllocationView.swift — idle-cash allocator (emergency fund vs idle cash → goals/loans/investments)

**Core features:** higher-tier advisory tools, each a standalone SwiftData-backed view reachable from Settings. **Known bug**: `SmartCashAllocationView.totalCash` sums `Account.balance` across accounts without currency conversion (pre-existing, not yet fixed).

### Features/Remittance/
- RemittanceTrackerView.swift — logs `RemittanceRecord`s, compares providers/rates/fees

**Core features:** remittance/money-transfer tracking with provider filtering and rate/fee comparison.

### Features/Reports/
- ReportsView.swift — single large file: `ReportsView` root + every report type as a sibling struct (`CashFlowReport`, `SpendingReport`, `IncomeReport`, `NetWorthReport`, `TrendsReport`, `DebtReport`, `ChequesReport`, `InvestmentReport`, `SavingsGoalsReport`, `TaxSummaryReport`, `VATReport`, `AnnualSummaryReport`, `MerchantSpendReport`); also defines the shared `ftChartPalette`/`.ftChartAxes()` Swift Charts helper used app-wide. `ChequesReport` lists cheque-method transactions grouped Overdue/Today/Week/Month/Later by `chequeDate` (unfiltered by the period selector, like `TrendsReport`/`SavingsGoalsReport`); row tap opens `TransactionDetailView` in a sheet.

**Core features:** one-stop reporting/analytics — every report type switched on by `ReportType` inside `ReportsView`. `SavingsGoalsReport.totalSaved/totalTarget` convert each goal's own currency to base currency before summing (fixed this session).

### Features/SavingsGoals/
- AddSavingsGoalView.swift — add/edit `SavingsGoal` form: type, target/current amount, target date, linked account, auto-contribution settings, currency picker (defaults to base currency for new goals)
- ContributeToGoalView.swift — contribute-to/withdraw-from-goal sheet with live progress/new-balance preview
- SavingsGoalDetailView.swift — tabbed goal detail (Overview/Progress/Auto-Save/Insights)
- SavingsGoalsView.swift — goals list, filter tabs (Active/On Track/Completed/All), conflict detection

**Core features:** full savings-goal lifecycle via `SavingsGoalService`. Emergency-fund template suggestion converts the base-currency expense estimate into the goal's selected currency (fixed this session).

### Features/Settings/
- AppearanceView.swift — theme/OLED/high-contrast/accent-color/fiscal-month/first-day-of-week bindings
- LockScreenView.swift — Face ID/Touch ID unlock screen (`AppState.isLocked`)
- NotificationSettingsView.swift — notification permission, master toggle, bill/budget threshold editors
- PrivacyPolicyView.swift — static privacy policy text
- SecurityPrivacyView.swift — biometrics/PIN, 2FA, recovery codes, audit log viewer (`auditLogCard`, hidden by default — `if DisableableFeature.auditLog.isEnabled`, a `.nested`-category `DisableableFeature`; background logging keeps running either way). Hidden Mode / Decoy PIN was fully removed (not just hidden) per explicit user request — `HiddenModeView`, `PINSetupSheet.isDecoy`, `AppSettings.decoyPINHash`/`.hiddenModeEnabled`, `AppState.isHiddenMode`, and `AuditEventType.hiddenModeActivated` no longer exist anywhere in the codebase.
- SettingsView.swift — root Settings screen: currency picker, About, backup links (Backup/Google Drive/Email), Clear All Data, links to every other Settings/Premium/Tax sub-screen (tab bar is full — new modules surface here). Note: the "Data & Privacy" card has an **"Import Backup"** row (`.fileImporter` → merge/replace confirmation → `runImport`/`runImportAsync` → `DataTransferService.importBackup`, transparently `BackupEncryptionService.decryptIfNeeded`-ed), but **no** "Export Backup" row and **no** "Export as CSV" row (both removed — no `exportBackup`/`presentShareSheet`); local `DataTransferService.exportBackup` + CSV export still exist as APIs but are unreachable from Settings. Presented as a **pushed** destination from `DashboardView` (a single enum-driven `.navigationDestination(item: $dashRoute)` shared with Reports, not a sheet), so its body is a bare `ScrollView` with **no own `NavigationStack`** (it uses the Dashboard's stack; back button handles dismissal, no "Done" toolbar). "Premium Features" card renders only enabled `.premium`-category `DisableableFeature`s (via `visibleFeatures` + `destinationView(for:)` switch), and the whole card is hidden if none remain; there is **no** user-facing "Manage Features" screen (disabling is developer-only — `DisableableFeature.disabled` + `docs/DISABLED_FEATURES.md`). Standalone sections like "Tax Management" wrap their `sectionCard` in `if DisableableFeature.taxManagement.isEnabled` for the same effect on `.topLevelSection` cases; the "Google Drive Backup" row inside the shared "Data & Privacy" card is a `.nested` case, wrapped individually (`if DisableableFeature.googleDriveBackup.isEnabled`) since it's just one sibling row, not its own card
- TermsOfServiceView.swift — static terms-of-service text

**Core features:** app-wide preferences and security — `SettingsView` is the hub; appearance/notifications/security are dedicated sub-views. Backup encryption is mandatory/always-on and has no UI (not surfaced in Settings or Backup).

### Features/Tax/
- FTAVATReportView.swift — UAE FTA quarterly VAT report with quarter selector and annual summary
- IncomeTaxEstimatorView.swift — estimates income tax by country config (annualized or manual entry)
- TaxDocumentVaultView.swift — searchable/filterable vault of `TaxDocument`s
- TaxManagementView.swift — tax hub for a selected year: VAT summary, deductibles, Zakat, feature grid
- TaxTransactionTagView.swift — tags transactions tax-deductible/VAT-reclaimable
- VATTrackerView.swift — VAT record tracker (Overview/Records/FTA Report tabs)
- ZakatCalculatorView.swift — UAE Zakat calculator (2.5% over nisab)

**Core features:** full UAE tax module — `TaxManagementView` is the year-scoped hub linking to VAT/FTA/income-tax/Zakat/tax-tagging/document-vault, all via `TaxService`.

### Features/Transactions/
- AddTransactionView.swift — largest add/edit form: core fields, receipt scanning, voice entry, location tagging; defines `LocationHelper`. Also auto-links a matching active `Bill` (via title/merchant name match against `Bill.name`/`.provider`, or manual "Paying Bill" picker scoped to bills sharing the selected category) — first-time linking calls `BillService.recordPayment` so the bill's due date/history advances the same as its own Record Payment sheet (`AddTransactionView.originalLinkedBillId` prevents re-advancing on a plain edit-save). Also shows a live, read-only "Budget" row (`recognizedBudget`) naming which `Budget` the transaction counts against, via `BudgetService.matchingBudget(...)` — same category+keyword matching `BudgetView` uses to compute spending, so the two can't disagree. No manual override; edit the budget's name/`merchantFilter` to change what it matches.
- CSVImportView.swift — 3-step CSV import wizard (upload/map/preview)
- TransactionsListView.swift — main list: search/filter, bulk edit mode, undo snackbar; defines `UndoSnackbar`, `BulkEditBar`, `TransactionDetailView`, `FlowLayout`, etc.
- VoiceTransactionView.swift — voice-to-transaction capture UI wrapping `SpeechTransactionService`

**Core features:** transaction CRUD and ingestion — manual entry with receipt/voice/location capture, bulk CSV import, searchable/filterable list + detail, standalone voice capture, cheque-due reminders (configurable lead time per transaction; the upcoming-cheques list lives in the Reports tab's `ChequesReport`, not here).

---

## App/
- FinTrackApp.swift — `@main` entry point. Builds the `ModelContainer` with wipe-and-recreate schema versioning (`currentSchemaVersion` string, e.g. `"v28"`, compared against `UserDefaults` key `fintrack_schema_version`; mismatch deletes the SQLite store files + clears pending local notifications). The `Schema([...])` array registering every `@Model` (~50 models) lives here (~line 37-90) — must be updated whenever a new `@Model` is added. Also defines `AppState` (`@Observable @MainActor`, flat stored properties: `selectedTab`, `isLocked`, `baseCurrency`, `showingAddTransaction`, onboarding state) and `AppTab` (`String`-backed `CaseIterable` enum: `.dashboard .transactions .add .budget .accounts .reports`, `.reports` not in the tab bar but navigable from Budget).
- RootView.swift — top-level switcher: onboarding → lock screen → iPad `NavigationSplitView` (`iPadMainView`) or `MainTabView`/`CustomTabBar` by `horizontalSizeClass`. Owns app-wide `.onAppear`/`.onChange(scenePhase)` side effects (recurring/scheduled transaction processing, bill/income/debt alert scheduling, `drainPendingIntentQueue()` for Siri/Watch, offline/Google Drive/email backup scheduling, live crypto/stock price refresh) and Spotlight deep-link handling. All 4 `GoogleDriveBackupService.shared.syncIfDue`/`.startAutoSync` call sites are gated behind `isGoogleDriveBackupEnabled` (reads `AppSettings.isFeatureEnabled(.googleDriveBackup)`) so disabling the feature actually stops the background sync loop, not just the Settings entry point. Also defines `MainTabView`/`CustomTabBar` (floating glass tab bar with centre FAB). `CustomTabBar` shrinks ~20% (`.scaleEffect(0.8)`, animated) while scrolling down: the `TabBarScrollCollapseModifier` (`.collapsesTabBarOnScroll()`, `onScrollGeometryChange`-based, iOS 18+) is attached to each of the 4 tab roots' main vertical `ScrollView`/`List` and drives `AppState.tabBarCollapsed` (reset to full size on tab change / near top).

## UI/
- AmountTextField.swift — `TextField` wrapper auto-inserting thousands separators; `AmountTextField.double(from:)` parses back
- AppTheme.swift — semantic token layer: `AppColors`, `AppSpacing`, `AppRadius`, `Color(hex: String)`, component library (`GlassCard`, `Card`, `PrimaryButton`, `AmountDisplayView`, `SectionHeader`, `EmptyStateView`, `BadgeView`, `IconBadge`)
- FTDesignSystem.swift — canonical design-system source: `Color(light:dark:)`/`Color(hex: UInt)`, `FTColor`, `FTSpacing`, `FTRadius`, font extensions, `.ftGlass`/`.ftGlassInteractive` modifiers, components (`FTCard`, `FTIconTile`, `FTChip`, `FTProgressBar`, `FTSegmentedControl`, `FTToggleRow`, `FTTransactionRow`, `FTTab`, `FTGlassTabBar`, `FTBackdrop`)
- FTSampleScreens.swift — reference/mock screens (`FTRootView`, `FTDashboardView`) demonstrating design-system composition with placeholder data; not wired to real queries, a template for new screens

**Core features:** `FTDesignSystem.swift` is the single source of truth; `AppTheme.swift` layers older/parallel semantic aliases on top.

## FinTrackWidget/
- FinTrackWidget.swift — entire Widget Extension in one file: local Codable mirrors of main-app models, App-Group `UserDefaults` reader, placeholder generators, `FinTrackEntry`/`FinTrackProvider` (`TimelineProvider`, 15-min refresh), size-specific views per widget, the Live Activity UI (`BudgetLiveActivityAttributes`, `BudgetLiveActivityView`, `BudgetDynamicIslandExpandedView`), and `@main FinTrackWidgetBundle`

**WidgetBundle members** (5, not 3 — CLAUDE.md is stale here): `FinTrackBalanceWidget` (sm/md/lg + accessory circular/rectangular/inline), `FinTrackBudgetWidget` (sm/md/lg), `FinTrackBillsWidget` (md/lg), `FinTrackPaymentsWidget` (lg only — BNPL/bill/scheduled payments merged), `FinTrackLiveActivityConfiguration` (iOS 16.1+). All read `UserDefaults(suiteName: "group.com.fintrack.shared")` keys `widget_net_worth`, `widget_currency`, `widget_recent_transactions`, `widget_budgets`, `widget_bills`, `widget_upcoming_payments` — written by `WidgetDataService`.

## FinTrackWatch/
- App/FinTrackWatchApp.swift — `@main` watchOS entry point, presents `WatchRootView()`
- Views/WatchBalanceView.swift — net-worth hero + income/expense totals from `WatchDataSource.transactions`
- Views/WatchQuickExpenseView.swift — quick expense/income entry with Digital Crown amount dial; builds a `WatchPendingTransaction`, calls `dataSource.enqueuePendingTransaction`
- Views/WatchRootView.swift — `WatchRootView` (TabView root) + `WatchDataSource` (`ObservableObject` singleton reading the shared App Group), Codable mirrors `WatchTransaction`/`WatchBudget`/`WatchBill`/`WatchPendingTransaction`
- Views/WatchTransactionsView.swift — recent-transactions list (first 10)

**TabView / data sharing:** `WatchRootView` → 3-tab TabView (Balance/Transactions/Add), sharing one `WatchDataSource` via `@EnvironmentObject`. Reads same App Group suite `group.com.fintrack.shared` / same `widget_*` keys as the widget extension (`dataSource.reload()` on `.onAppear`). Writes quick-add entries to key `pending_transactions`, drained by `RootView.drainPendingIntentQueue()` on the main app (same queue Siri App Intents use).
