# MAP_Services.md — Services & Public Interfaces Reference

Part of PROJECT_MAP.md (see root for navigation). All files under `FinTrack/Core/Services/` unless noted.

### AIAnalyticsService.swift
Purpose: broad AI-style analytics engine — health score, anomalies, forecasts, savings tips, ESG, digital-twin simulation.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `computeHealthScore(...)`, `detectAnomalies(transactions:currency:) -> [SpendingAnomaly]`, `predictBalance(accounts:transactions:bills:) -> BalanceForecast`, `computeSpendingPatterns(transactions:)`, `findSavingsOpportunities(...)`, `generateCoachingInsights(...)` (rotates weekly), `generateBillNegotiationTips(...)`, `analyzeESG(...)`, `runDigitalTwin(scenario:...)`, `monthlyAverages(transactions:monthsBack:)`
External APIs: none (pure computation)

### AICategorizationService.swift
Purpose: rule/keyword/learned-history category prediction + recurring/duplicate/insight detection.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `suggestCategory(for:amount:type:)`, `predictCategory(for:merchant:amount:type:rules:) -> CategoryPrediction` (priority: rules → CategoryLearningService → keywords → fallback), `detectRecurring(transactions:)`, `detectDuplicates(transactions:) -> [UUID]`, `generateInsights(...)`, `forecastNextMonth(transactions:)`
External APIs: NaturalLanguage (imported, keyword matching only)

### BackupEncryptionService.swift
Purpose: **mandatory, always-on** AES-GCM encryption for `.fintrack` backup files — shared by manual export, offline (local) backup, Google Drive, Email backup. Not user-configurable (no toggle, no passphrase). The key is a random 256-bit value generated once and stored **only** in this device's Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), so a backup can only ever be opened by this FinTrack install on this device — no other app can read it, and (by design) it can't be restored on a different device or after reinstall.
Singleton: no (enum namespace, all static) | Actor: **`nonisolated enum`** — opts out of MainActor isolation so `Task.detached` PBKDF2 work (100k iterations) never bounces back to main actor.
Key methods: `private encryptionKey` (lazily provisions + Keychain-caches the random key, NSLock-guarded against first-run races), `isEncrypted(_:) -> Bool` (checks 5-byte "FTBK1" header), `encryptIfEnabled(_:) async throws` (always encrypts — name kept for call sites), `decryptIfNeeded(_:) async throws` (decrypts if the header is present, else passes legacy plain files through; throws `.cannotOpen` on wrong-device/corrupt), `encrypt/decrypt(_:key:)`. Removed: the old user `storedPassphrase`/`isEnabled` and the `.passphraseRequired`/`.wrongPassphraseOrCorruptFile` errors (now a single `.cannotOpen`).
External APIs: CryptoKit (AES.GCM, HMAC<SHA256> manual PBKDF2), Security (SecRandomCopyBytes)

### BankEmailParser.swift
Purpose: regex-based on-device extraction of UAE bank transaction-alert emails (amount, merchant, direction, date, card digits, balance, reference).
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `bankName(forSender:)` (18 UAE banks), `isLikelyBankTransactionEmail(sender:subject:)`, `static gmailSenderQuery(extraSenders:)`, `parse(sender:subject:body:receivedAt:) -> ParsedBankEmail?` (confidence + suspicion heuristics), `static fingerprint(...)`, `static normalize(body:)`
External APIs: none (NSRegularExpression only)

### BillService.swift
Purpose: bill payment recording, reminders, auto-pay-missed detection, subscription waste analysis, price-change/overdue alerts.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `recordPayment(bill:amount:date:)`, `scheduleReminders/cancelReminders/scheduleAllReminders(for:)`, `isAutoPayMissed(bill:transactions:)`, `analyzeWaste(bill:transactions:) -> BillWasteAnalysis`, `checkAllAlerts(bills:transactions:currency:)`, `detectPriceChange(for:)`
External APIs: UNUserNotificationCenter

### BiometricService.swift
Purpose: Face ID / Touch ID / passcode authentication wrapper.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `biometricType/biometricTypeName/biometricIcon/isAvailable`, `authenticate(reason:) async -> Bool`, `authenticateWithBiometricsOrPIN(reason:) async -> Bool`
External APIs: LocalAuthentication (LAContext)

### BudgetService.swift
Purpose: budget forecasting, multi-threshold alerts, rollover processing, AI spend recommendations, seasonal templates (Ramadan/Eid/Summer), budget↔transaction matching.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `forecastEndOfMonth(for:spent:transactions:baseCurrency:) -> BudgetForecast` (blends pace + 3mo history), `checkAndSendAlerts(budget:spent:currency:)` (75/90/100%), `processRollovers(budgets:transactions:baseCurrency:)`, `generateRecommendations(transactions:budgets:)`, `builtInTemplates()`, `autoKeyword(from:)`/`effectiveKeyword(for:allBudgets:)` (derives/resolves a budget's match keyword — explicit `Budget.merchantFilter` wins, else auto-derived from `Budget.name` when disambiguating same-category siblings or specific enough alone), `matchingBudget(title:merchant:category:budgets:) -> Budget?` (which budget a transaction belongs to — category alone is ambiguous once siblings share it), `spending(for:allBudgets:transactions:in:) -> Double` (per-budget monthly spend using the same keyword match, with a cross-category keyword fallback)
External APIs: UNUserNotificationCenter
Note: `forecastEndOfMonth`/`checkAndSendAlerts`/`processRollovers` all take a currency param and convert `Budget.amount`/`.rolloverAmount` internally — fixed after cross-currency bugs were found. `BudgetView.swift`'s own `autoKeyword`/`effectiveKeyword` are now thin delegates to this service (moved here so `AddTransactionView`'s live budget-recognition indicator can't drift from what `BudgetView` uses to compute spending) — `BudgetView.spending(for:in:)`/`.ytdSpending(for:)` keep their own cached-dictionary fast path and were left as-is.

### CSVImportService.swift
Purpose: CSV parsing, delimiter/date-format auto-detection, column-mapping suggestion, row mapping with dedup + AI categorization.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `parseCSV(data:delimiter:)`, `detectDelimiter(in:)`, `detectDateFormat(samples:)`, `mapRows(_:mapping:existingTransactions:rules:) -> [CSVImportRow]`, `suggestMapping(for:)`
External APIs: none

### CategoryLearningService.swift
Purpose: persists user's merchant→category corrections (UserDefaults) so predictions improve over time.
Singleton: `.shared` | Actor: implicit MainActor, `@Observable`
Key methods: `recordCorrection(merchant:category:)`, `learnedCategory(for:) -> TransactionCategory?`, `forget(merchant:)`, `clearAll()`
External APIs: none (UserDefaults + JSONEncoder)

### CryptoPriceService.swift
Purpose: live crypto USD prices (Binance primary, CryptoCompare fallback), auto-refresh ~25s, 150+ coin registry/search.
Singleton: `.shared` | Actor: **`@MainActor @Observable`** (explicit)
Key methods: `fetchPrices() async` (falls back to CryptoCompare on failure), `usdPrice(for:)`, `searchCoins(query:)`, `updateHoldings(_:currencyService:)`
External APIs: api.binance.com, min-api.cryptocompare.com (raw URLSession)

### CurrencyService.swift
Purpose: FX rates (open.er-api.com) with multi-source IRR black-market-rate handling; hourly auto-refresh, disk cache, fallback table.
Singleton: `.shared` | Actor: **`@MainActor @Observable`** (explicit)
Key methods: `convert(_:from:to:) -> Double` (core conversion used everywhere), `amountInBase(_:from:) -> Double` + `baseCurrencyCode` (lock a new transaction's `amountInBaseCurrency` at the current rate at creation — reads base from UserDefaults, needs no AppState; **every** `Transaction(...)` in a possibly-foreign currency must pass `amountInBaseCurrency:` via this so the base value is frozen at that moment), `symbol(for:)`, `info(for:)`, `fetchLiveRates(baseCurrency:) async` (chains 5 IRR fallback sources)
External APIs: open.er-api.com, api.tetherland.com, coingecko.com, tgju.org, nobitex.ir, wallex.ir

### DataTransferService.swift (+ DataTransferService+ExtraBackup.swift)
Purpose: full JSON backup/restore of the **whole** SwiftData store via Codable DTOs — the shared substrate under manual export/import, offline (local) backup, Google Drive, and Email backup. Covers every `@Model` **except** the transient `PendingEmailTransaction` review queue.
Singleton: `.shared` | Actor: **`@MainActor`** (explicit)
Key methods: `exportBackup(context:) throws -> URL`, `importBackup(from:context:mode:) throws -> ImportSummary` (`.merge` dedup-by-UUID or `.replace` wipes-then-inserts), private `deleteAll(context:) throws`, `restoreExtras(_:existing:mode:context:)` generic helper.
Pattern for adding a model to the backup (see `+ExtraBackup.swift`): add a `struct XDTO: BackupDTO` mirroring the model's **stored** props (enums as `…Raw`, arrays as `…Data`), a `var backupDTO` on the model, `extension X: BackupIdentifiable {}`, an optional field on `FinTrackBackup`, one fetch line in `exportBackup`, and one `restoreExtras(...)` line in `importBackup` (relationship models like `CustomCategory`/`DocumentAttachment` are linked explicitly instead). Backup `currentVersion` = 7; new fields are optional so old backups still decode.
External APIs: none (SwiftData only)

### DebtService.swift
Purpose: debt payoff planning — snowball/avalanche simulators, interest-savings comparison, credit-utilization analysis.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `debtItems(loans:creditCards:) -> [DebtItem]`, `totalOutstandingDebt/totalMinimumPayments(...)`, `snowballPlan/avalanchePlan(items:extraMonthlyPayment:) -> DebtPayoffPlan`, `calculateInterestSavings(...)`, `utilizationSummary(creditCards:)`
External APIs: none

### EmailBackupService.swift
Purpose: automatic backup-to-self-inbox via plain SMTP/IMAP (app-specific password, no OAuth) — emails the zlib-compressed, optionally-encrypted `.fintrack` file, restores by searching for it.
Singleton: `.shared` | Actor: **`@MainActor @Observable`** (explicit)
Key methods: `connect(email:password:smtpHost:imapHost:) async throws` (verifies SMTP+IMAP up front), `disconnect()`, `performBackup(context:) async -> Bool`, `restoreFromEmail(context:mode:) async -> String`, `scheduleAutomaticBackupIfNeeded/startAutoBackup/stopAutoBackup`, `static suggestedSMTPHost(for:)`. **Server hosts are never shown to the user** — the sign-in sheets ask only for email + password and derive SMTP/IMAP via `suggestedSMTPHost`/`EmailSyncService.suggestedIMAPHost` (provider table + `smtp./imap.<domain>` fallback). Add new providers to those tables, not to the UI.
External APIs: SMTPClient, IMAPClient (custom raw-socket clients), Keychain
Note: hourly auto-backup interval + a real foreground polling loop (`startAutoBackup`), added this session because scene-phase-only checks weren't reliable. Pipeline order is compress (zlib, always) → encrypt (always, via `BackupEncryptionService`) on backup, decrypt → decompress on restore; a private `"FTGZ1"` magic header lets restore detect and skip decompression for backup emails sent before compression was added. This compression step is local to `EmailBackupService` — `GoogleDriveBackupService`/local/manual export still send uncompressed (only encryption is shared via `BackupEncryptionService`).

### EmailSyncService.swift
Purpose: orchestrates the whole email → pending-transaction pipeline — Gmail/Outlook OAuth2+PKCE, IMAP app-password, background sync, bank-email parsing, dedup, auto-approval to ledger.
Singleton: `.shared` | Actor: **`@MainActor @Observable`** (explicit), NSObject subclass for `ASWebAuthenticationPresentationContextProviding`
Key methods: `connect(provider:context:) async throws -> EmailAccount` (OAuth2+PKCE), `connectIMAP(email:password:host:provider:context:) async throws`, `disconnect(...)`, `runSyncPass(context:) async` / `startAutoSync(context:)` (15-min foreground loop) / `stopAutoSync()`, `static registerBackgroundSync/scheduleBackgroundRefresh` (BGTaskScheduler; expiration handler calls `task.setTaskCompleted(success: false)` on cancel so iOS doesn't penalize future scheduling), `syncAll(accounts:context:) async`, `processEmail(_:accountId:context:) -> Bool` (classify→parse→learn→categorize→dedup→enqueue→maybe-auto-approve→`sendEmailImportAlert` unconditionally for every new item, with the current pending-review count for the notification badge), `approveToLedger(item:context:autoApproved:)` (creates the permanent Transaction, updates Account balance + BNPL plan + learning services), `importPastedEmail/importSampleEmails`, `static recognizeAccount(bankName:cardLast4:currency:accounts:)`
Also defines: `nonisolated enum KeychainStore` (Security wrapper, used by BackupEncryptionService too), `enum AuditLogService` (@MainActor, writes AuditLogEntry)
External APIs: Gmail REST API, Microsoft Graph API, ASWebAuthenticationSession, BackgroundTasks, IMAPClient, Keychain, CryptoKit (SHA256 for PKCE)

### FamilyService.swift
Purpose: household budget summaries, family permission checks/defaults, shared-goal milestones, allowance insights.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `householdBudgetSummary(transactions:bills:currency:)`, `canAccess(member:resourceType:resourceId:requiredLevel:) -> Bool`, `defaultPermissions(for:)`, `milestones(for goal:)`, `allowanceInsights(child:currency:)`, `buildMemberSummaries(...)`
External APIs: none

### FinancialIntelligenceService.swift
Purpose: deterministic on-device financial-health scoring, ranked insights, predictions — grounds the "AI CFO" feature entirely in real records (no LLM).
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `healthScore(transactions:accounts:budgets:goals:loans:) -> FinancialHealthScore?` (6 weighted components; nil if no data), `insights(transactions:budgets:baseCurrency:) -> [IntelligenceInsight]` (MoM swings, hidden recurring charges, budget-overrun early warning, etc.), `predictions(transactions:accounts:bills:baseCurrency:) -> [IntelligencePrediction]`
External APIs: none

### GoogleDriveBackupService.swift
Purpose: OAuth2+PKCE (drive.file scope only) backup/restore/two-way sync to Google Drive — cloud alternative to the on-device offline backup.
Singleton: `.shared` | Actor: **`@MainActor @Observable`** (explicit), NSObject subclass for auth presentation
Key methods: `connect() async throws`, `disconnect()`, `performBackup(context:) async -> Bool`, `restoreFromDrive(context:mode:) async -> String`, `syncNow(context:) async` (two-way "gossip" merge, create-only — no field-level conflict resolution), `startAutoSync/stopAutoSync/syncIfDue(context:)` (2-min-floor loop)
External APIs: Google Drive v3 REST API, ASWebAuthenticationSession, Keychain (via KeychainStore)

### IMAPClient.swift
Purpose: minimal hand-rolled IMAP4rev1 client over TLS (Network.framework) — LOGIN/SELECT/UID SEARCH/UID FETCH/LOGOUT — plus a `MIMEDecoder` for multipart/quoted-printable/base64/RFC2047 decoding.
Singleton: no (`final class IMAPClient: @unchecked Sendable`, per-connection) | Actor: not actor-isolated — runs on its own DispatchQueue
Key methods: `connect()/login(user:password:)/selectInbox()/uidSearch(_:) -> [Int]/fetchMessage(uid:)/fetchRawMessage(uid:) -> Data/logout()/close()`; `enum MIMEDecoder`: `readableBody`, `extractAttachment(from:filenameContains:)`, `decodeQuotedPrintable`, `decodeEncodedWords`, `headerValue`
External APIs: Network.framework (raw NWConnection/TLS)

### ImportLearningService.swift
Purpose: on-device learning memory for the email-import review queue — merchant rename aliases, tag suggestions, rejection tracking, weighted duplicate-detection scoring.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `static merchantKey/normalizedMerchant(for:)`, `recordMerchantRename(raw:cleanName:)`, `static cosmeticCleanup(_:)`, `suggestedTags(for:)`, `recordApprovedTags(rawMerchant:tags:)`, `recordRejection/isUsuallyRejected(rawMerchant:)`, `duplicateCheck(...) -> DuplicateVerdict`, `static similarityScore/tokenOverlap`
External APIs: none

### IncomeService.swift
Purpose: salary/freelance/rental income tracking (payments, overdue/late alerts, reminders) + AI Income Stability Score + passive-income analytics.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `recordSalaryPayment/checkSalaryAlerts/scheduleSalaryReminder/cancelSalaryReminder`, `recordInvoicePayment/checkOverdueInvoices/sendOverdueInvoiceAlert`, `recordRentPayment/addOccupancyPeriod/endOccupancy/checkLateRentAlerts`, `computeStabilityScore(...) -> IncomeStabilityScore` (6 weighted factors), `computeStreamSummaries(...)`, `computePassiveIncomeMetrics(...)`, `monthlyIncomeTotals(transactions:months:)`
External APIs: UNUserNotificationCenter

### InvestmentService.swift
Purpose: portfolio math — totals/cost/PnL across stocks/crypto/gold, allocation slices, FIFO/LIFO/average-cost capital gains, dividend aggregation, Monte Carlo + deterministic projection scenarios.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `totalValue/totalCost/unrealizedPnL/totalRealizedPnL(...)`, `allocationSlices(...)`, `calculateGain(lots:selling:at:method:) -> GainResult`, `capitalGainsSummary(...)`, `annualDividendIncome(...)`, `projectPortfolio(...) -> [ProjectionPoint]`, `monteCarlo(...) -> MonteCarloResult`, `portfolioReturn(...)`
External APIs: none

### MerchantCategoryService.swift
Purpose: last-resort merchant→category lookup via Google Places (if key configured) or OpenStreetMap Nominatim (keyless fallback), with permanent per-merchant caching (including negative results). **Always on** — `isEnabled` is a hardcoded `true` (no user toggle; the old "Category from Maps"/"Google Maps Key" UI in `EmailImportView` was removed). Lookups are country-biased via `regionCode` (`Locale.current.region`, default AE); Nominatim pulls up to 10 results and walks them for the first that maps; Google reads `primaryType` before `types`. Cache key is `..._v3` (bumped when the lookup logic strengthened).
Singleton: `.shared` | Actor: **`@MainActor @Observable`** (explicit)
Key methods: `lookupCategory(for merchant:) async -> (category:source:)?`, `static category(forPlaceType:) -> TransactionCategory?`
External APIs: places.googleapis.com, nominatim.openstreetmap.org

### NetWorthService.swift
Purpose: aggregates total assets/liabilities/net worth across every asset class + liabilities; milestone detection, historical snapshotting, forecasting, wealth-percentile estimate.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `totalAssets/totalLiabilities/netWorth(...)`, `assetAllocationSlices(...)`, `checkMilestones(currentNetWorth:existingMilestones:base:context:)` (inserts NetWorthMilestone at $100k/250k/.../10M), `recordSnapshot(...)`, `forecastNetWorth(...) -> [ForecastPoint]`, `wealthPercentile(netWorth:baseCurrency:currencyService:) -> PercentileResult` (hardcoded UAE distribution thresholds)
External APIs: SwiftData (ModelContext, for inserts)

### NetworkMonitor.swift
Purpose: reachability + connection-type observation, gates Wi-Fi-only backup jobs.
Singleton: `.shared` | Actor: implicit MainActor (`@Observable`, path updates dispatched via `DispatchQueue.main.async`)
Key methods: `isConnected`, `connectionType` (published properties)
External APIs: Network.framework (NWPathMonitor)

### NotificationService.swift
Purpose: central UNUserNotificationCenter facade for every local notification type (bills, loans, cards, BNPL, budgets, salary, rent, goals, large/low-balance, email import).
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `requestPermission() async -> Bool`, `scheduleBillReminder/scheduleLoanReminder/scheduleCreditCardReminder/scheduleBNPLReminder(...)`, `scheduleBudgetAlert/sendMinimumBalanceAlert/sendLargeTransactionAlert/sendLowBalanceAlert/sendHighUtilizationAlert`, `scheduleSalaryReminder/sendSalaryNotReceivedAlert/sendInvoiceOverdueAlert/sendRentLateAlert`, `scheduleLentReminder/scheduleBorrowedReminder`, `scheduleSavingsGoalMilestone/sendGoalCompletedAlert/scheduleSavingsGoalContributionReminder`, `sendEmailImportAlert(merchant:amount:currency:category:autoApproved:pendingReviewCount:)` (badge set to `pendingReviewCount` when > 0), `scheduleChequeReminder(chequeNumber:amount:currency:chequeDate:daysBefore:id:)` (id `"cheque_<transactionUUID>"`, scheduled/cancelled from `AddTransactionView.commitSave()`/`TransactionsListView.deleteTransaction`), `cancelNotification(id:)/cancelAll()`
External APIs: UserNotifications

### ReceiptDocumentDetector.swift
Purpose: Vision-based receipt-quad detection + perspective correction + Core Image preprocessing (grayscale/contrast/sharpen/denoise) for OCR accuracy.
Singleton: no (plain class, instantiated by ReceiptScannerService) | Actor: implicit MainActor
Key methods: `detect(in image:) async -> DetectedDocument`, `preprocess(_:)`
External APIs: Vision (VNDetectRectanglesRequest), CoreImage/CIFilterBuiltins

### ReceiptScannerService.swift
Purpose: full receipt OCR pipeline — Vision text recognition (AR/FA/EN) + structured field extraction (total, VAT, date, currency, payment method, merchant) with per-field confidence.
Singleton: `.shared` | Actor: **`@MainActor @Observable`** (explicit)
Key methods: `scanReceipt(image:) async` (populates `scanResult: ScannedReceiptData?`)
External APIs: Vision (VNRecognizeTextRequest)

### ReportExportService.swift
Purpose: generates PDF reports (hand-drawn `UIGraphicsPDFRenderer` layout) and CSV files, drives the system share sheet.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `generatePDF(title:periodLabel:sections:) -> URL?`, `writeCSV(_:filename:) -> URL?`, `share(url:)`
External APIs: UIKit (UIGraphicsPDFRenderer, UIActivityViewController)

### SMTPClient.swift
Purpose: minimal hand-rolled SMTP client over implicit TLS (port 465) — EHLO/AUTH LOGIN/MAIL FROM/RCPT TO/DATA/QUIT, MIME multipart with base64 attachment.
Singleton: no (`final class SMTPClient: @unchecked Sendable`, per-connection) | Actor: not actor-isolated
Key methods: `connect()/ehlo(domain:)/authLogin(user:password:)/sendMessage(from:to:subject:textBody:attachment:attachmentFilename:)/quit()/close()`
External APIs: Network.framework (raw NWConnection/TLS)

### SavingsGoalService.swift
Purpose: savings-goal math — income/expense estimation, emergency-fund recommendation, required monthly contribution, multi-goal conflict analysis, milestones, auto-contribution scheduling, UAE benchmark tables (tuition, Hajj/Umrah).
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `estimatedMonthlyIncome/estimatedMonthlyExpenses(transactions:)`, `emergencyFundRecommendation(transactions:months:currency:)`, `requiredMonthlyContribution(for goal:)`, `analyzeConflicts(goals:transactions:currencyService:base:) -> GoalConflict`, `checkMilestones(goal:context:) -> [Double]` (25/50/75/100%), `goalsDueForContribution(goals:)`, `generateInsights(...)`, `goalStatus(for goal:) -> GoalStatus`
External APIs: SwiftData (ModelContext.save in checkMilestones)

### SpeechTransactionService.swift
Purpose: voice-to-transaction pipeline — SFSpeechRecognizer live transcription + custom NLP parser extracting amount/currency/merchant/category/type.
Singleton: `.shared` | Actor: **`@MainActor @Observable`** (explicit)
Key methods: `requestPermission() async -> Bool`, `startListening() throws`, `stopListening()`, `parse(transcript:) -> ParsedVoiceTransaction`
External APIs: Speech (SFSpeechRecognizer), AVFoundation

### SpotlightService.swift
Purpose: CoreSpotlight indexing of transactions/accounts for iOS system search + deep-link resolution back into the app.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `indexTransactions/indexAccounts(_:)`, `removeTransactionFromIndex/removeAccountFromIndex(id:)`, `clearTransactionIndex/clearAllIndexes()`, `handleUserActivity(_:) -> SpotlightDeepLink?` (`.transaction(UUID)`/`.account(UUID)`/`.unknown(UUID)`)
External APIs: CoreSpotlight

### StockPriceService.swift
Purpose: live stock/ETF/bond/REIT prices via Yahoo Finance's keyless v8 chart endpoint (concurrent per-symbol fetch), auto-refresh every 5 min, disk cache.
Singleton: `.shared` | Actor: **`@MainActor @Observable`** (explicit)
Key methods: `fetchPrices(symbols:) async` (TaskGroup), `updateHoldings(_:)`
External APIs: query1.finance.yahoo.com (raw URLSession, spoofed User-Agent)

### TagSuggestionService.swift
Purpose: suggests transaction tags from merchant history + seasonal context (Ramadan/Eid/summer/holidays) + amount thresholds.
Singleton: `.shared` | Actor: implicit MainActor, `@Observable`
Key methods: `suggestTags(for merchant:amount:existing:)`, `recordTagUsed(_:for:)`, `clearAll()`
External APIs: none (UserDefaults)

### TaxService.swift
Purpose: UAE-context tax engine — VAT summary/quarterly breakdown, FTA quarter reports, bracket-based income-tax estimator (for expats), deductibles summary, synthetic VAT-record generation, Zakat pre-fill.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `vatSummary(records:taxYear:) -> VATSummary`, `ftaReport(records:year:quarter:) -> FTAQuarterReport`, `estimateIncomeTax(annualIncome:configuration:) -> IncomeTaxEstimate`, `deductiblesSummary(transactions:taxYear:)`, `vatRecordsFromTransactions(...)`, `availableTaxYears(...)`, `prefillZakat(record:transactions:accounts:investments:goldHoldings:moneyLent:loans:currency:) -> ZakatRecord`
External APIs: none

### WidgetDataService.swift
Purpose: writes lightweight snapshots into the shared App Group UserDefaults so FinTrackWidget/Watch/Siri can read data without touching SwiftData; also the pending-intent queue for Siri/Watch quick-add.
Singleton: `.shared` | Actor: implicit MainActor
Key methods: `updateAll(netWorth:currency:transactions:budgets:bills:payments:)` (+ `WidgetCenter.shared.reloadAllTimelines()`), `update(netWorth:currency:recentTransactions:)` (legacy/partial), `enqueuePendingTransaction(_:)`, `dequeuePendingTransactions() -> [PendingWidgetTransaction]` (drained by RootView)
External APIs: WidgetKit, `UserDefaults(suiteName: "group.com.fintrack.shared")`

### LocalBackupService.swift
Purpose: **protected on-device backup/restore** — replaced `iCloudBackupService`. Two layers: (1) encrypted `.fintrack` files in **Application Support/Backups** (sandboxed, *not* Documents — `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace` are deliberately ABSENT from `FinTrack-Info.plist` so backups never appear in the Files app and can't be edited/deleted by the user; the UI offers no delete/share either); (2) a **Keychain "device snapshot"** — iOS erases the whole app container on delete, so files cannot survive an uninstall, but Keychain items do and are reclaimed by the same bundle id on reinstall.
Singleton: `.shared` | Actor: implicit MainActor, `@Observable`
Key methods: `performBackup(context:) async -> Bool` (export → encrypt → write file → prune to 10 → refresh snapshot), `listBackups()`, `restore(from:context:mode:) async -> String`, `restoreFromDeviceSnapshotIfNeeded(container:) async -> Bool` (auto-restore at launch), `hasDeviceSnapshot`, `startObservingChanges(container:)`, `backupsDirectory` (also migrates legacy `Documents/Backups`).
Auto-backup is **change-driven, not schedule-driven**: `startObservingChanges` (called once from `RootView.task`) observes `ModelContext.didSave` and debounces 4 s, so a burst of edits produces one backup right after the user's last change. It reads the user's switch (`AppSettings.cloudSyncEnabled`) at fire time, waits out an in-flight backup instead of dropping the edit, and both restore paths run inside `withAutoBackupSuppressed` so an import's own `save()` can't re-trigger a backup. There is no launch/resume backup call any more.
Snapshot details: payload is slimmed (`receiptImageData`, tax `fileData`, attachment `data` stripped) → zlib via `EmailBackupService.compressForSnapshot` → encrypted → Keychain, capped at 2 MB (over-cap deletes the stale item rather than keeping it). Auto-restore only fires into a **genuinely empty store** (0 transactions AND 0 accounts) so it can never clobber existing data; `RootView` gates launch on it and calls `completeOnboarding` when data comes back.
Caveats to preserve: images/documents are NOT in the snapshot, and nothing survives erasing the device or moving to another one — Google Drive / Email Backup remain the off-device options.
External APIs: none (local filesystem + Keychain)

---

## ERROR HANDLING PATTERN

Three co-existing patterns depending on layer:

1. **Silent `try?` swallowing dominates "fire and forget" persistence/notification code.** UserDefaults encode/decode, `context.save()`, and notification scheduling almost universally use `try?` with nothing surfaced to the user (e.g. `CategoryLearningService.persist()`, `try? context.save()` throughout `EmailSyncService.swift`, `BillService.swift` never wraps `UNUserNotificationCenter...add()` in any error handling at all).
2. **Typed `LocalizedError` enums + `async throws` propagate for user-facing network/crypto/auth operations**, caught at the service boundary and turned into a published `lastError: String?` for the UI to bind to — never re-thrown further up to SwiftUI. Examples: `BackupEncryptionError`, `EmailSyncError`/`DriveBackupError`/`EmailBackupError`, the catch-and-store pattern in `GoogleDriveBackupService.performBackup` and `EmailBackupService.restoreFromEmail`.
3. **Best-effort fallback chains, not error propagation**, for external data fetching: `CurrencyService.fetchLiveIRRRate` tries 5 sources in order and returns `nil` if all fail (keeps stale/fallback rates); `CryptoPriceService`/`StockPriceService` catch network errors internally and fall back to a secondary API or keep the last cached value.

Net effect: almost nothing in `Core/Services` lets a Swift error escape to a caller's `catch` for business logic — only the low-level network clients (`IMAPClient`, `SMTPClient`) and `DataTransferService`/`BackupEncryptionService` `throw` all the way through; everything downstream either gets `try?`-swallowed or converted to a published `lastError` string.

## ACTOR-ISOLATION QUIRKS

Project has **Default Actor Isolation = MainActor** (Xcode build setting) — plain classes/enums are implicitly MainActor-isolated unless marked `nonisolated`.

- **`BackupEncryptionService`** — `nonisolated enum` so its `Task.detached` PBKDF2 work (100k HMAC iterations) never bounces to the main actor.
- **`KeychainStore`** (defined inside `EmailSyncService.swift`, not its own file) — `nonisolated enum`, so it can be called synchronously from other nonisolated code (e.g. BackupEncryptionService) as well as MainActor callers.
- **`EmailSyncService.presentationAnchor(for:)`** / **`GoogleDriveBackupService.presentationAnchor(for:)`** — both `nonisolated func` (required by `ASWebAuthenticationPresentationContextProviding`) but wrap their body in `MainActor.assumeIsolated { ... }` to touch `UIApplication.shared` safely.
- **`IMAPClient`** / **`SMTPClient`** are the only services **not** MainActor singletons — `final class ...: @unchecked Sendable`, per-connection, own `DispatchQueue`. Intentionally not actor-isolated since they're short-lived stateful network sessions, not app-wide singletons.
- **`LocalBackupService`** is a plain `@Observable` singleton (implicit MainActor) doing its file IO inline and publishing state back via `await MainActor.run { ... }`.
- Most other singletons (`CurrencyService`, `CryptoPriceService`, `StockPriceService`, `MerchantCategoryService`, `EmailBackupService`, `GoogleDriveBackupService`, `SpeechTransactionService`, `ReceiptScannerService`, `DataTransferService`) are **explicitly** `@MainActor @Observable` even though that's the project-wide default — for clarity given they do async network/IO and mutate `@Observable` state from completion callbacks.
