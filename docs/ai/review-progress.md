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
| 6 | Features (by folder, alphabetical) | 104 / ~61k | todo |
| 7 | FinTrackWidget, FinTrackWatch (not in any build target) | 6 / 1641 | todo |
| 8 | Write architecture/maintenance, slim CLAUDE.md, retire PROJECT_MAP.md + docs/maps | — | todo |

## Decisions
- Canonical reference = `docs/ai/*`. The older `PROJECT_MAP.md` + `docs/maps/MAP_*.md` (~200 KB, partly unverified, with a changelog section) are migrated after verification and retired in stage 8 (recoverable from git at `3411a90`).

## Next step
Stage 6: Features, by folder alphabetically (`ls FinTrack/Features`). Add a `## Features` heading to code-map.md, one entry per file. Suspected issues so far are tagged ⚠ inline in code-map.md; consolidate them into maintenance.md in stage 8.
