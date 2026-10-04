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
| 6 | Features (by folder, alphabetical) | 104 / ~63k | done (all 29 folders) |
| 7 | FinTrackWidget, FinTrackWatch (not in any build target) | 6 / 1641 | done |
| 8 | Write architecture/maintenance, slim CLAUDE.md, retire PROJECT_MAP.md + docs/maps | — | done |

## Decisions
- Reading method for large SwiftUI view files (stage 6+): blank lines and lines that *start with* a pure styling modifier (`.font(`, `.foregroundStyle(`, `.padding(`, `.frame(`, `.ftGlass(`, `.tint(`, `.lineLimit(`, `.multilineTextAlignment(`, `Divider()`) are filtered out (`scripts` not committed; command: `grep -vE '^\s*$|^\s*(\.font\(|\.foregroundStyle\(|\.padding\(|\.frame\(|\.ftGlass\(|\.tint\(|\.lineLimit\(|\.multilineTextAlignment\(|Divider\(\))'`). Everything else — logic, bindings, labels, data flow — is read line by line. From `Features/Import` on, the filter also drops lines that are only `.clipShape(`/`.shadow(`/`.minimumScaleFactor(`/`.tracking(`, a bare `Image(systemName: "literal")`, or a literal-only `Text("…")`/brace/`Spacer()` line (pure presentation; every line with an identifier, binding or logic is still read). `AddAccountView.swift` lines ~1250–1800 were read with an earlier, looser filter that also hid label `Text` lines carrying `.font` on the same line (logic unaffected).
- Canonical reference = `docs/ai/*`. `PROJECT_MAP.md` is now a redirect stub (kept because source comments cite "PROJECT_MAP §8", now `maintenance.md` → Invariants); `docs/maps/` removed. Old content recoverable from git at `3411a90`.

## Fix pass (after the review)
User request "Fix all problems": commits `085d3fc`…HEAD on this branch fix the issue register (see `maintenance.md` → Fixed / Decisions / Still open). Docs were updated in the same pass: `code-map.md` entries for every touched file, `architecture.md` flows, `CLAUDE.md` conventions. Validation was static reading only — nothing was built or run; the fixes need an Xcode build and device testing.

## UI/UX audit
Follow-up request: audit and fix the whole UI. Primary journeys were read line by line and the rest of `Features/` swept by pattern; details, what was fixed and what remains are in `maintenance.md` → "UI/UX audit". Validation was a tree-sitter Swift syntax parse of every file plus brace/paren balance checks — no build, run, screenshots or profiling were possible in this container.

## Next step
Review complete. For future work follow the workflow in `maintenance.md`. When code changes, re-read the touched files and update their `code-map.md` entries; to re-verify after many commits, diff from the reviewed commit (`git diff 3411a90 --stat -- FinTrack`) and re-read only changed files.

## Coverage
Every in-scope file listed in the plan was read (view files with the presentation-line filter described in Decisions; models, services, config and all logic read in full). Nothing in scope is unread. Not reviewed: `logo.png`, generated `contents.xcworkspacedata`. No build or tests were run (no toolchain in the container; no tests exist).

## Items resolved during the review
- `asPercentage()` fraction call sites — all listed in `maintenance.md` (Medium).
- Notification toggles gate nothing; `%g` edit prefill rounds amounts; BNPL `.bnpl` payment link doesn't advance plans; list deletes do remove lent/borrowed/salary records — all recorded in `code-map.md`/`maintenance.md`.
- Siri `LogExpense/LogIncome` queue moved to `UserDefaults.standard` in the fix pass.
- Nested `NavigationStack`s in pushed screens: AIAssistant views, `DigitalAssetsListView`, `FamilySetupView`, `TaxManagementView` (cosmetic/navigation-bar duplication risk).
