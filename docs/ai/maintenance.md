# Maintenance guide

Rules, sensitive areas, validation, and the register of suspected problems found during the review of commit `3411a90`. Nothing listed here has been fixed — the review changed documentation only. Every issue cites the file and symbol where the evidence is; re-read the source before acting (it is authoritative), and confirm on a device where noted.

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
- **UI gotchas**: `.swipeActions` only works inside a `List` (many screens violate this — see issues); don't put `FTBackdrop()`/`.ignoresSafeArea()` views as `ZStack` siblings of the screen's `ScrollView` (use `.background {}` and `.safeAreaInset` for CTAs); one over-wide fixed row stretches a whole form; `.tracking` section labels need `.fixedSize`; `Button` around a glass card needs `.contentShape(Rectangle())`; `.gridCellColumns` doesn't work in `LazyVGrid`.
- **Concurrency**: default actor isolation is MainActor; mark pure helpers `nonisolated` when run detached.
- **SwiftData `#Predicate`**: only trust scalar comparisons (computed properties fail SQL translation; enum comparisons have crashed).
- **Performance**: bound `Transaction` fetches by date where possible (`ImportLearningService.duplicateTimeWindow`), avoid view-body filters over the whole ledger.
- **Secrets**: never copy credentials or tokens into docs. `FinTrack-Info.plist` holds a public Gmail OAuth client id — leave it there, don't repeat it.

## Issue register (suspected problems with evidence)
Severity is a judgment of user impact. "Verify" = needs device confirmation.

### High — data loss/corruption, fake data, security claims that aren't true
1. **Editing a transaction changes its amount.** `AddTransactionView.loadEditingData` prefills with `AmountTextField.string(from:)` which formats with `%g` (6 significant digits) → 12,345.67 becomes 12,345.7; ≥1,000,000 becomes exponent notation. Saving writes the rounded amount and balance delta. (`UI/Components/AmountTextField.swift`, `Features/Transactions/AddTransactionView.swift`)
2. **User-chosen category overridden on create.** `AddTransactionView.commitSave` replaces the selected category with `AICategorizationService.suggestCategory(title)` whenever it isn't `.other` (no confidence threshold). Combined with the keyword matcher's dictionary-order and substring issues (`AICategorizationService`), categories end up wrong.
3. **PDF and OFX/QIF/QFX "import" insert fake sample data.** `PDFImportView.simulateAIParsing`/`generateSampleParsedItems` and `OFXImportView.startParsing`/`generateSampleItems` never read the file and insert hard-coded transactions into the real ledger. Both are live (not disabled).
4. **App PIN and 2FA are never enforced.** `LockScreenView` only uses `LAContext`; nothing reads `pinHash`, `twoFactorEnabled`, `twoFactorSecret` outside `SecurityPrivacyView`. 2FA "verification" accepts any 6 digits; the QR is a placeholder. `SettingsView`'s PIN toggle sets `usePIN` but presents no setup sheet (`showingPINSetup` unbound). PIN hash is unsalted SHA-256 of 4–6 digits and is exported in backups (`DataTransferService`).
5. **Backups bound to one device.** `BackupEncryptionService` derives the key from a device-only Keychain item, so email/Drive/manual backups can't be restored on a new device; `EmailBackupService`'s email text promises "any device"; Drive "sync" can't work across devices. `KeychainStore.save` ignores `SecItemAdd` failure (key loss risk). (`Core/Services/BackupEncryptionService.swift`, `EmailSyncService.swift` → `KeychainStore`)
6. ~~**Backup fidelity gaps.**~~ **Fixed** — DTO v8 carries the missing fields/links; dividends dedup on merge.
7. **Rental tenancies recorded twice.** `AddTenancySheet.save` calls `IncomeService.addOccupancyPeriod(property:&…)` (which appends the period and stubs) and then appends the period again. (`Features/Income/RentalView.swift`)
8. **Base-currency change doesn't recompute stored base amounts.** `SettingsView` currency picker only updates `AppState`/UserDefaults; every `amountInBaseCurrency` stays in the old currency but is labelled with the new one app-wide.
9. **Account delete cascades to transactions without confirmation** (`Account.transactions` `.cascade`; unconfirmed delete paths in Accounts). Also unconfirmed context-menu deletes for loans/lent/borrowed/BNPL in `DebtManagementView`, bank rules in `EmailImportView`, family group dissolve.
10. **Import dedup can merge or drop distinct purchases.** `ImportFiler` gives Apple Pay items a date-less `rawText` → a second identical purchase is dropped while the first row exists; `ImportLearningService.score` reaches the 0.6 merge threshold on amount+currency+≤2 h alone, so different merchants can be merged by `ImportDeduper`.
11. **`MIMEDecoder.decodeEncodedWords` infinite loop** on a B-encoded non-UTF-8 header (hangs the main actor during IMAP sync). (`Core/Services/IMAPClient.swift`)

### Medium — wrong numbers or broken features
- **Percentages 100× too small**: `Double.asPercentage()` doesn't multiply by 100, but fractions are passed in `AIAnalyticsService`, `AIAssistantView`, `DigitalTwinView`, `DebtManagementView` (utilization), `ReportsView.DebtReport`, Family views, `AICFOModeView`, `EstatePlanningView`, `IncomeTaxEstimatorView`. (`Core/Utilities/Extensions.swift`)
- **Notification settings gate nothing**: no service reads the toggles/thresholds in `NotificationSettingsView` (except the two digests, which don't reschedule on day/hour change). `AuditLogService.log` ignores `auditLogEnabled`.
- **Bill price-change alert repeats forever** after any increase (`BillService`; no notified state).
- **Siri log intents**: `LogExpense`/`LogIncome` enqueue via the App Group suite (`WidgetDataService.enqueuePendingTransaction`) that isn't backed by an entitlement and always report success; intents have no authentication policy (can speak balances while locked); Spotlight indexes balances. Verify on device.
- **Loan/borrow principal counted as income/spending**: Debt screens post `.income`/`.expense` for lending, borrowing and repayments; investment sales post full proceeds as income (`RecordSaleSheet`); nothing excludes these from income/expense totals and savings rates.
- **Five net-worth definitions** disagree (`AccountsView`, `NetWorthService` (ignores mortgages on property and `MoneyLent`), `DashboardView.computeMetrics` (widget/Siri only), `ReportsView.NetWorthReport`, `AICFOModeView`).
- **Unconverted sums labelled base currency**: Bills totals, `DebtService` plans/utilization, Freelance/Rental summaries ("AED" hard-coded), Digital assets, Family, Insurance, Remittance, widget budget snapshot totals, `FinancialIntelligenceService` (hard-coded "AED"), `AIAnalyticsService`.
- **VAT computed three ways**: Reports (5 % of gross; all income as output VAT), Tax tags (5/105), manual `TaxRecord`s.
- **Unreachable delete/archive** (`.swipeActions` outside `List`): Assets lists, `MileageTrackerView`, `RuleManagementView`, `FamilySetupView`, `SharedFamilyGoalsView`, `RemittanceTrackerView`, `NetWorthDashboardView` snapshots, `SavingsGoalsView` cards, `VATTrackerView`, `TaxDocumentVaultView`.
- **Recurring transactions**: new rules always get `nextDueDate = date + 1 month` regardless of frequency (`AddTransactionView`); `RootView` processing ignores `endDate`/`maxOccurrences` and transfers.
- **BNPL bookkeeping**: a `.bnpl` payment-method tx links to a plan without advancing it, yet counts as a payment in `BNPLDetailSheet` (deleting it decrements `paidInstallments`); deleting a BNPL-linked tx from the list doesn't adjust the plan; `RecordBNPLPaymentSheet` treats any amount as one installment.
- **Loan delete from Transactions list** restores `outstandingBalance` with the unconverted amount and leaves `paidInstallments` (`TransactionsListView.deleteTransaction`, vs `LoanDetailSheet.deletePayment`). `Loan.recordPayment` installment counting and `SaleRecord.isLongTerm` are also suspect.
- **Savings goals are virtual**: contributions never move money (account picker ignored); round-up/salary-% never act; `isCompleted` never cleared on withdrawal.
- **Income module**: invoice/rent/dividend income txs have no account or back-link (double counting if the bank alert is also approved); salary reminders not cancelled on record delete or deactivation; "Dividends YTD" sums all years; `computeStabilityScore` sorts month keys alphabetically; `checkSalaryAlerts` likely never fires (verify).
- **Dashboard**: hero/budget customizer toggles do nothing (no such sections); widget budget snapshot uses unfiltered category spend.
- **Budget**: `endDate` never read; weekly/quarterly budgets only in Annual tab; "Apply" on increase/decrease recommendation creates a duplicate budget; `Budget.spent` stored but never updated; detail vs list spend differ.
- **Edit sheets that write through on Cancel**: `EditPendingEmailSheet` (merchant/type/date/category/account bound to the model), `RetirementEditView`.
- **CSV import** doesn't adjust the chosen account's balance; Reports include pending/scheduled/future-dated txs; Cheques report has no cleared state; CashFlow daily chart sorts day strings alphabetically.
- **SMS/email parsing**: `BankSMSParser` uses parse time when the SMS has no date; `TextNormalizer.decimalValue` misreads "45.5"→455 and 3-decimal currencies; `BankSMSTemplateStore` short-name substring matches; `BankEmailParser` credit-first "received" and UTC-day fingerprints; Outlook fetch takes the newest 50 messages of the whole mailbox.
- **FX/prices**: unknown currencies convert at 1.0 (BTC/ETH/USDT); Yahoo quote currency ignored (`StockPriceService`); perpetual 25 s Binance polling on the main actor (`CryptoPriceService`).
- **Watch/widget** (not built): App Group isn't shared across iPhone/Watch (needs WatchConnectivity); Live Activity attribute type mismatch (`BudgetLiveActivityAttributes` vs `BudgetActivityAttributes`); `LiveActivityService.start/update` have no callers.

### Low — copy, privacy text, UX, design-system drift
- **Privacy/claims**: `PrivacyPolicyView` says backups are in the Files app, uninstall removes all data (Keychain snapshot survives), PIN is handled by iOS, and omits merchant-lookup/price/email traffic; `EmailImportView` privacy card ("OAuth only", "nothing is uploaded"); Onboarding and Security screen claim "end-to-end encryption"; `ImportIntegrationView` says backups are "visible in Files". `MerchantCategoryService` sends merchant names to third parties without a setting.
- Hard-coded system colors/sizes in several screens (`UpcomingPaymentsView`, Reports, NetWorth, Business); fixed-size fonts (no Dynamic Type); `CustomTabBar` bypasses `ftGlass`; `FTSampleScreens.swift` and `StatCard` are dead; `Color(hex: String)` grayscale crash; stale entitlement comment.
- Smaller logic: `DashboardView`/`HouseholdBudgetView` "+" shown without amount for positive cash flow (ternary precedence); `UpcomingPaymentsView` ignores custom start date; Bills calendar header misaligned for non-Sunday week starts; `AddBill` free-text currency and orphaned reminders; `CategoryManagement` placeholder subcategory persists; Business invoice VAT-off still stores VAT; `firstDayOfWeek` setting never read; `ChildAllowance`/Family amounts parsed with `Double(text)`; `FTAVATReportView` "past deadline" check uses quarter-end day 28; `EstatePlanningView` nisab hard-coded 7,200 compared in base currency.

## Unresolved questions
- Does `UserDefaults(suiteName:)` without the App Group entitlement persist on device for this app (Siri queue)? PROJECT_MAP recorded "no"; confirm on a device.
- Does `IncomeService.checkSalaryAlerts` ever fire (forward-searching `date(bySetting:)`)?
- Do expense saves get blocked for credit-card *accounts* by `AddTransactionView.isBalanceInsufficient` (depends on how card balances are stored)?
- Swift 6 / strict-concurrency readiness: `InvestmentPortfolioView` runs `InvestmentService.monteCarlo` on a global queue while the type is MainActor by default — builds today in Swift 5 mode; check before raising the language mode.
