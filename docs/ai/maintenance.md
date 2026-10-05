# Maintenance guide

Rules, sensitive areas, validation, and the register of problems found during the review of commit `3411a90`, updated after the fix pass (commits from `085d3fc` on). Fixes were validated by reading code only — nothing has been built or run (no toolchain in the container). Re-read the source before acting (it is authoritative), and confirm on a device where noted.

## Change workflow (for every future task)
1. Read `CLAUDE.md`, then the relevant parts of `architecture.md` and `code-map.md` to locate files. Don't re-read the whole repo.
2. **Read the actual source** of every file you will change, plus its callers (`grep` the symbol). Forms often have twins (e.g. `AddMoneyLentView`/`AddMoneyBorrowedView`) and money logic is duplicated across screens — check siblings.
3. Make the change; keep design-system tokens, wipe-and-recreate schema rules and the conventions below.
4. Validate (see below). There is no build or test runner in the cloud container; say so instead of claiming a build passed.
5. Update docs in the same commit: the affected `code-map.md` entry, this file (close/add issues), `architecture.md` if a flow changed, and `review-progress.md`'s reviewed-commit note if you re-reviewed files.

## Validation available
- **Here (Linux container)**: static reading only — no Xcode, no `swift build`, no simulator, no tests exist. Useful checks: `grep` call sites, confirm every new `@Model` is in `AppSchema.modelTypes`, confirm `currentSchemaVersion` was bumped (after asking the user), `git diff` review.
- **On a Mac**: build the `FinTrack` scheme in Xcode (iOS 26.5 SDK) and exercise the flow on a simulator/device. Background tasks, Shortcuts automations, Keychain, notifications and Foundation Models need a real device.

## Invariants and conventions (verified)
- **Schema**: wipe-and-recreate. New `@Model` or non-optional property ⇒ register in `AppSchema.modelTypes` **and** bump `currentSchemaVersion` in `FinTrackApp.swift` — this deletes all user data, so ask the user first. Prefer side stores (UserDefaults/JSON-in-existing-field) when a change would otherwise need a bump. Container load failure is a `fatalError`.
- **Enum raw values are persisted** (several models store enums directly). Renaming a case or raw value breaks existing stores.
- **Balances are stored, not derived.** Any code that posts, edits or deletes a money movement must adjust `Account.balance` (and loan/BNPL/debt/salary/loyalty state) and reverse it symmetrically by the transaction's own `type`. Pending and scheduled transactions don't touch balances.
- **The review queue is the only automated path to the ledger**: email/SMS/Apple Pay create `PendingEmailTransaction`s via `ImportFiler`; nothing posts without a user tap in `EmailReviewQueueView`; `EmailSyncService.approveToLedger` is the single posting function.
- **App Intents never touch SwiftData** — they read `WidgetDataService` snapshots and write queues that `RootView` drains. Intents taking real input must not be in `AppShortcutsProvider`; Shortcuts parameter types must match the bound variable exactly.
- **No App Group entitlement is active**; use `UserDefaults.standard` for in-app queues. Widget/Watch sources are not built.
- **Clear All Data** must reach everything stored outside SwiftData — add any new store to `DataResetService.wipeDerivedData`.
- **Disable, don't delete**: hide modules with `DisableableFeature.disabled` and keep `docs/DISABLED_FEATURES.md` in sync.
- **Never expose an encryption toggle and never name the algorithm in user-facing text** (code comments only).
- **UI gotchas**: `.swipeActions` only works inside a `List` (rows in `ScrollView`/`VStack` use `.contextMenu`); don't put `FTBackdrop()`/`.ignoresSafeArea()` views as `ZStack` siblings of the screen's `ScrollView` (use `.background {}` and `.safeAreaInset` for CTAs); one over-wide fixed row stretches a whole form; `.tracking` section labels need `.fixedSize`; `Button` around a glass card needs `.contentShape(Rectangle())`; `.gridCellColumns` doesn't work in `LazyVGrid`.
- **Concurrency**: default actor isolation is MainActor; mark pure helpers `nonisolated` when run detached.
- **SwiftData `#Predicate`**: only trust scalar comparisons (computed properties fail SQL translation; enum comparisons have crashed).
- **Performance**: bound `Transaction` fetches by date where possible (`ImportLearningService.duplicateTimeWindow`), avoid view-body filters over the whole ledger.
- **Secrets**: never copy credentials or tokens into docs. `FinTrack-Info.plist` holds a public Gmail OAuth client id — leave it there, don't repeat it.

## Issue register

### Fixed in the fix pass (verify on device)
High
1. Edit prefill rounding — `AmountTextField.string(from:)` is exact to 3 decimals.
2. Category override on create — the chosen category is kept.
3. Fake PDF/OFX imports — OFX/QFX/QIF parse real files (`StatementFileParser`); PDF importer hidden (`DisableableFeature.pdfStatementImport`).
4. PIN/2FA — PIN enforced on the lock screen (`PINService`, salted, lockout after 5 tries); Settings toggle opens setup; 2FA hidden (`DisableableFeature.twoFactorAuth`), TOTP verified if re-enabled.
5. Backups — copy is truthful about the device-bound key; `KeychainStore.save` updates/adds and throws; key provisioning throws on failure. (Device-bound key kept — see Decisions.)
6. Backup fidelity — DTO v8 (transfer/BNPL/recurring/loose links, account/budget/settings/card extras, dividend payment date); dividends dedup on merge.
7. Rental tenancy recorded twice — fixed (`AddTenancySheet`, `endTenancy`).
8. Base-currency change — rebases every `amountInBaseCurrency` at current rates.
9. Unconfirmed deletes — Accounts (cascade warning), Debt, bank rules, family dissolve now confirm.
10. Import dedup — Apple Pay raw text carries a timestamp; unrelated known merchants can't reach the duplicate threshold.
11. `MIMEDecoder` infinite loop — fixed; charsets decoded.

Medium
- Percentages ×100 at every fraction call site.
- Notification toggles/thresholds/digests take effect (`NotificationService.apply`/`deliver`); budget alert levels; large-transaction and low-balance alerts wired; audit log honours `auditLogEnabled`.
- Bill price-change alert once per price. Siri log queue on `.standard`, honest failure; balance/budget intents require unlock.
- Principal: `isPrincipalMovement` excluded from income/expense/savings totals and Reports; investment sale posts only the gain.
- One net-worth definition (`NetWorthService`, now incl. receivables and unlinked property mortgages). One VAT formula (`UAEVAT`).
- Unconverted sums converted: debt plans/utilization, bills, freelance/rental, digital assets, family, remittance, insurance, AI health score, `FinancialIntelligenceService`, widget budgets.
- Swipe actions outside `List` → context menus (13 screens).
- Recurring: frequency-correct next date, `endDate`, transfers, edit keeps rule in sync.
- BNPL: one invariant (`apply/reverseInstallmentPayment`) for create/edit/delete/record. Loan delete from the list converts and restores the installment.
- Savings goals: transfers when the goal has an account; `isCompleted` cleared on withdrawal; round-up and salary-% applied.
- Income: deposit account for rent/invoice/dividend; salary reminders cancelled on delete/pause; Dividends YTD; stability score order; day-of-month date math.
- Dashboard customizer toggles real; budgets: Apply updates in place, `endDate` honoured, dead `remaining/progress` removed.
- Cancel discards edits in `EditPendingEmailSheet` and `RetirementEditView`.
- CSV import adjusts the account; Reports exclude pending/scheduled/future; cheques "Cleared"; cash-flow days ordered.
- SMS/email: received-time dates, decimal parsing (incl. 3-decimal currencies), sender matching, first-keyword direction, local-day fingerprints, Outlook 30-day paged fetch.
- FX/prices: crypto codes priced, Yahoo quote currency honoured, crypto polling 5 min.
- `SaleRecord.isLongTerm` uses purchase→sale (`acquiredDate`); real-estate equity total; lent/borrowed edits update base amount; new transactions default to the base currency.

Low
- Privacy policy / email privacy card / onboarding / security copy match behaviour; "+" sign precedence; Upcoming Payments custom start; Bills calendar header + `firstDayOfWeek` (`Calendar.app`); Add Bill currency picker and reminder cleanup; subcategory placeholder; invoice VAT toggle; Family amount parsing; FTA deadline check; estate-planning nisab; `Color.hex` grayscale crash.

### Decisions taken (revisit if product direction changes)
- Backups stay bound to the device key (no user passphrase) — making them portable needs a product decision and a passphrase/escrow design.
- 2FA and the PDF importer are hidden, not removed (`docs/DISABLED_FEATURES.md`).
- Merchant category lookup stays always-on (existing code comment says so deliberately); it is now disclosed in the privacy policy.
- Base-currency rebase uses today's rates (historical rates aren't stored).
- No schema bump: new data rides on optional JSON fields (`SaleRecord.acquiredDate`) or UserDefaults side stores (`ft_notification_preferences`, `ft_budget_alert_*`, `ft_bill_price_alert_*`, `ft_first_weekday` — all cleared by Clear All Data).

### Still open
- `AICategorizationService` keyword table: dictionary-order winner and short substring keywords (`"du"` ⊂ "dubai").
- `Transaction.init` defaults `amountInBaseCurrency` to `amount`; `Account.transactions` is `.cascade` (now confirmed in the UI, still destructive).
- `Loan.recordPayment` reduces only principal but both delete paths add back the full payment; counts one installment per payment.
- `RecordBNPLPaymentSheet` treats any amount as one installment (by the BNPL invariant).
- Budget: weekly/quarterly budgets only in the Annual tab; `BudgetDetailView` spend ignores keyword filters.
- `SalaryRecord.nextExpectedDate` assumes monthly; `isBNPLMerchant` "valu" substring; `TaxConfiguration` allowance double-count (feature disabled).
- Investment Cap Gains selectors don't affect the summary; `AIAssistantView` chat sums balances unconverted; Nominatim not throttled; email-backup size limit.
- Freelance "record payment" marks any amount as paid; debt edit "None" leaves the tx.
- Design drift: fixed font sizes (no Dynamic Type), system colours in some screens, `CustomTabBar` bypasses `ftGlass`, dead `FTSampleScreens`/`StatCard`, stale comment in `FinTrack.entitlements`.
- Watch/widget (not built): App Group not shared with Watch; Live Activity attribute type mismatch; `LiveActivityService` has no callers.

## UI/UX audit (after the fix pass)
Scope and method: primary journeys read line by line — `RootView`/tab bar, `AddTransactionView`, `TransactionsListView` + detail, `DashboardView`, `BudgetView` (main view), `AccountsView`, `AccountDetailView`, `EmailReviewQueueView`, `LockScreenView`, `OnboardingView`, `SettingsView`; the rest of `Features/` covered by pattern sweeps (icon-only buttons, system colours, perpetual animations, backdrop placement, nested stacks, tracked labels, formatter allocation, double submission). Validation: static only — every Swift file parses with tree-sitter-swift and brace/paren balance was checked, but **nothing was compiled, run, profiled or screenshotted** (no Xcode/simulator here).

Fixed: Dynamic Type for all text tokens (root cap `accessibility2`); window-level keyboard dismissal that no longer fights text fields; 89 `ZStack`-sibling backdrops moved to `.background`; Add Transaction (mode sync on edit, save-blocked reason, discard confirmation, no double save, duplicate alert, autofocus, location feedback); empty/no-results states and duplicate filter in Transactions; tappable recent/account transactions; account history beyond 20; PIN lockout that never ended; small-screen overflow on lock/About; onboarding keyboard covering fields; review-queue discoverability; busy overlays for backup restore / Clear All Data; Budget/Accounts ledger scans cached; formatter-in-comparator removed; 76 unlabelled icon buttons; 104 tracked labels; token colours; Reduce Motion for perpetual animations; 16 save paths single-submit; 6 nested `NavigationStack`s removed.

Still open (UI): fixed `Font.system(size:)` remains on many icons and ~60 text spots (they don't scale); fixed-width frames may clip at the largest text sizes (hence the cap); RTL/Arabic is modelled (`AppLanguage.isRTL`) but there is no localisation, so it isn't applied; most sheets other than the ones listed above still close without an unsaved-changes check; short state-change springs aren't gated on Reduce Motion; screens not read line by line (most Premium/Tax/Business/Family/Income sub-screens, `AddAccountView` bodies, Reports sub-reports) may have issues the sweeps can't detect; no performance measurements exist — the caching changes are based on code inspection, not profiling.

## Unresolved questions
- Do expense saves get blocked for credit-card *accounts* by `AddTransactionView.isBalanceInsufficient` (depends on how card balances are stored)?
- Swift 6 / strict-concurrency readiness: `InvestmentPortfolioView` runs `InvestmentService.monteCarlo` on a global queue while the type is MainActor by default — builds today in Swift 5 mode; check before raising the language mode.

## UI redesign (branch `claude/redesign-ui`)
Implements the approved prototype (`prototype/`, see `prototype/README.md`). UI only — no `@Model`/schema change, no business-logic change.

Changed: native adaptive `TabView` shell (`MainTabView`: Home · Activity · Plan · Wealth + Search tab, Add Transaction bottom accessory, sidebar sections on regular width) replacing `CustomTabBar`, the shrink-on-scroll modifier and the iPad `NavigationSplitView`; new `PlanView`, `GlobalSearchView`, `SiriShortcutsView`, `PlanningToolsView`/`FeatureDestinationView`/`OptionalNavigationStack` (`UI/Components/AppNavigation.swift`); Home (To Review card, labelled shortcut tiles, account cards open the account, pushes instead of sheets, Edit Home); Wealth (title, Add menu, Net Worth pushed, Income/Goals cards moved to Plan); Budget menu creates only; Activity (title, Import & Sync entry, “N to review” banner); Insights = one health score (`FinancialIntelligenceService`); Settings preferences only (modules moved, duplicated security toggles removed); Add Transaction “More details”; 9 Insights tools and 5 dual-use screens no longer nest `NavigationStack`s; contrast-tuned `FTColor` light values; iOS 27 transaction view annotation (`SystemIntegration.swift`).

Validation: static only (tree-sitter parse + bracket balance on every changed file, reading). **Not compiled or run.** Verify in Xcode:
- iOS 26 SDK APIs used for the first time here: `Tab`/`TabSection`/`.defaultVisibility(.hidden, for: .tabBar)`, `Tab(value:role: .search)`, `.tabViewBottomAccessory`, `.tabBarMinimizeBehavior(.onScrollDown)`, `.buttonStyle(.glass/.glassProminent)` on new buttons.
- Sidebar-only tabs are hidden on the compact tab bar and the accessory shows on iPhone; check how the accessory behaves in sidebar mode on iPad (the sidebar has no Add button of its own; ⌘N works).
- `annotatesTransaction` compiles only with Swift ≥ 6.3 (Xcode 27); its `appEntityIdentifier`/`EntityIdentifier(for:identifier:)` signature comes from a WWDC26 session sample, not the SDK headers.
- iPhone Duo: run in Xcode 27.1 Device Hub (open/closed/folded); the inner display ignores the iPhone portrait lock, and layout relies on size classes only.

Still open from the plan: Siri "Open my budget" lands on Plan (one tap from Budgets) rather than Budgets itself; Search only matches transaction titles (not merchant/notes); no String Catalog yet (English only; RTL not exercised); `FinancialHealthView`/`AIAnalyticsService.computeHealthScore` are unused now but kept.

### Bottom navigation update (no "More", Search + New in the bar)
- iPhone no longer uses the system tab bar: its 19 declared tabs overflowed into an automatic **More** screen (the `.defaultVisibility(.hidden, for: .tabBar)` hints didn't keep sidebar-only tabs out on iPhone). Compact width now shows a five-destination `TabView` with the system bar hidden and `AppTabBar` (Home · Activity · New · Plan · Wealth · Search). The floating `tabViewBottomAccessory` is gone; **New** is a bar item that opens Add Transaction without changing the selected tab.
- Former More destinations and where they live now: Budgets, Bills & Payments, Goals, Income, Debt, Household, Planning Tools → Plan; Net Worth, Investments, Property & Assets → Wealth (Net Worth also Home tile; Debt also Wealth › What You Owe); Insights, Reports → Home tiles; Import & Sync → Activity (+ menu) and Settings; Settings → Home profile button. All are also in Search and in the iPad sidebar (its "More" section became "Insights & Reports" and "Data & Settings").
- `.searchable` on screens under the bar uses `placement: .navigationBarDrawer` (Search, Activity, Digital Assets, Audit Log) so iOS 26 doesn't put the field at the bottom, under the bar.
- Verify in Xcode: the hidden system tab bar stays hidden on pushed screens (`.toolbar(.hidden, for: .tabBar)` is applied outside each tab's `NavigationStack`, as the pre-redesign bar did); content clears the bar via the safe-area inset; the bar hides with the keyboard; the sidebar's New Transaction item opens the sheet without leaving the current section; `searchFocused` raises the keyboard when Search is chosen.
- Fix: content ran under the bottom bar on every screen because the TabView-level `safeAreaInset` isn't propagated into tabs. Each compact tab now reserves the measured bar height (`MainTabView.reservingTabBarSpace`), which also covers pushed screens and bottom-aligned overlays. Removed the fixed 100–120 pt "clear the floating tab bar" padding left from the old custom bar on Budgets, Debt, Income, Investments, Goals, Property & Assets, Net Worth, Reports and Activity (list margin, Undo snackbar, bulk-edit bar). Sheets keep their own bottom spacing (they're not under the bar).
- Follow-up: the per-tab inset still let content run under the bar, so the compact layout now stacks the TabView *above* the bar (`VStack`), making overlap impossible; the TabView ignores only the top safe area. Trade-off: content no longer scrolls beneath the bar's glass.
