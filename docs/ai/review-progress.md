# Review progress

Baseline: branch `claude/finance-app-features-f1fo3p`, commit `3411a90`, working tree clean at start.
Scope: all project-owned Swift (200 files, ~90.6k lines) + project config. No tests exist.
Excluded from line-by-line: `logo.png` (binary), `.xcworkspace/contents.xcworkspacedata` (generated).

## Plan (stages, in order)
| # | Stage | Files / lines | Status |
|---|---|---|---|
| 1 | Config: pbxproj, Info.plist, entitlements, xcassets JSON, .gitignore, README, docs/*.md/.html | — | done |
| 2 | FinTrack/App | 2 / 775 | done |
| 3 | Core/Utilities, UI/ | 5 / 1343 | done |
| 4 | Core/Models | 30 / 6640 | done |
| 5 | Core/Services (+SMS) | 52 / 16962 | done |
| 6 | Features (by folder, alphabetical) | 104 / ~63k | in progress — done: AIAssistant, Accounts, AppIntents, Assets, Bills, Budget, Business, Categories, Dashboard, Debt, Family, Import, Income, Intelligence, Investments, LiveActivity, NetWorth, Onboarding, Premium, Remittance |
| 7 | FinTrackWidget, FinTrackWatch (not in any build target) | 6 / 1641 | todo |
| 8 | Write architecture/maintenance, slim CLAUDE.md, retire PROJECT_MAP.md + docs/maps | — | todo |

## Decisions
- Reading method for large SwiftUI view files (stage 6+): blank lines and lines that *start with* a pure styling modifier (`.font(`, `.foregroundStyle(`, `.padding(`, `.frame(`, `.ftGlass(`, `.tint(`, `.lineLimit(`, `.multilineTextAlignment(`, `Divider()`) are filtered out (`scripts` not committed; command: `grep -vE '^\s*$|^\s*(\.font\(|\.foregroundStyle\(|\.padding\(|\.frame\(|\.ftGlass\(|\.tint\(|\.lineLimit\(|\.multilineTextAlignment\(|Divider\(\))'`). Everything else — logic, bindings, labels, data flow — is read line by line. From `Features/Import` on, the filter also drops lines that are only `.clipShape(`/`.shadow(`/`.minimumScaleFactor(`/`.tracking(`, a bare `Image(systemName: "literal")`, or a literal-only `Text("…")`/brace/`Spacer()` line (pure presentation; every line with an identifier, binding or logic is still read). `AddAccountView.swift` lines ~1250–1800 were read with an earlier, looser filter that also hid label `Text` lines carrying `.font` on the same line (logic unaffected).
- Canonical reference = `docs/ai/*`. The older `PROJECT_MAP.md` + `docs/maps/MAP_*.md` (~200 KB, partly unverified, with a changelog section) are migrated after verification and retired in stage 8 (recoverable from git at `3411a90`).

## Next step
Stage 6 continues with `Features/Reports` (then SavingsGoals, Settings, Tax, Transactions). Use the filter command in Decisions.

## Open items to verify while reading Features (stage 6)
- `Double.asPercentage()` does **not** multiply by 100 (`Extensions.swift:130`). Call sites passing 0…1 fractions render 100× too small (25% → "0.3%"). Confirmed: `AIAnalyticsService.swift:339,636`, `AIAssistantView.swift:78,439,484`, `DigitalTwinView.swift:94`. Also confirmed: utilization fractions in `DebtManagementView` (hero, `CreditCardDebtCard`, `CardUtilizationRow`). Check the rest of the list from `grep -rn "asPercentage(" FinTrack` as each file is read (Reports 1512/1587/2009/2351/2424; Family, AICFOMode, EstatePlanning confirmed).
- Do Settings notification toggles gate anything? (`NotificationSettingsView`)
- ~~Siri queue~~ CONFIRMED: `LogExpense/LogIncome` (`FinTrackIntents.swift:85,116`) → `WidgetDataService.enqueuePendingTransaction` → App Group suite only (no entitlement → not persisted).
- `AmountTextField.string(from:)` `%g` callers in `AddTransactionView` (edit prefill).
- `AddTransactionView` sets `linkedBNPL` for `.bnpl` payment-method txs (line ~1588): is that tx an installment (does it advance the plan)? `BNPLDetailSheet` treats every linked tx as a payment.
- Deleting a Lent/Borrowed repayment tx from the Transactions list: does it also remove the `RepaymentRecord`? (check `TransactionsListView` delete path ~line 490–530)
- Pushed destinations that wrap themselves in their own `NavigationStack` (all AIAssistant views do) → nested stacks.
