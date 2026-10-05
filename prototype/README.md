# FinTrack redesign: interactive prototype (awaiting approval)

**Status:** proposal only. The app (`FinTrack/`), its build settings, dependencies and data are unchanged. Nothing in this folder is compiled: the Xcode target only builds files under `FinTrack/`.

## How to view

- **Published link (private to you until shared):** https://claude.ai/artifact/WYo8GbP4EknWipf7hHGtTu. It's the same file as `FinTrack-Prototype.html`.
- **Locally:** open `prototype/index.html` (or the single-file `prototype/FinTrack-Prototype.html`) in Safari or Chrome. No server or build is needed.
- `python3 prototype/build.py` regenerates `FinTrack-Prototype.html` from `index.html`, `styles.css`, `data.js`, `screens.js` and `app.js`.
- The left panel switches screen size, light/dark, text size (Default → AX3), Reduce Transparency, Reduce Motion, Increase Contrast, right-to-left, long text, empty data, loading, offline, sync error and denied permissions. It also starts the flows (onboarding, lock, restore) and the simulated Siri and automation events.
- The right panel explains the current screen: its purpose, primary action, what changed and accessibility notes.
- The matrix at the bottom lists every feature. **Show** opens that feature in the device.

## 1. Major UX problems in the current app

1. **Modules are hidden in Settings and in unlabelled menus.**
   - Settings holds six planning tools, Family and Financial Intelligence.
   - Budget's unlabelled "Add or open" menu mixes creating things with navigating to Income, Debt and Bills.
2. **Duplicate entry points and duplicate concepts.**
   - Bills has three entry points: a Dashboard sheet, the Budget menu and a Debt tab.
   - Debt has two: the Budget menu and the Accounts grid.
   - Goals are split between Accounts and the Budget menu.
   - Two "intelligence" areas compute **two different health scores**.
   - Face ID, PIN and auto-lock appear both in Settings and in Security & Privacy.
3. **The core pipeline is easy to miss.** The review queue, the only way imports reach the ledger, is reached only through a banner inside Transactions. Its actions are explained as gestures.
4. **Primary destinations sit behind icon-only controls.** The Dashboard header's AI, Reports and Profile buttons have no text, and neither does the centre "+".
5. **The tab bar is custom, not native.** A hidden `TabView` sits under `CustomTabBar`. The app misses the system Liquid Glass tab bar, its minimise behaviour and the native sidebar on wide screens. iPad uses a separate hand-built `NavigationSplitView`.
6. **Long horizontal chip rows.**
   - Debt: 10 views. Investments: 10. Reports: 13. Income: 7.
   - These rows are hard to scan and get worse at large text sizes.
7. **Primary destinations open as modal sheets.** Net worth, Bills, Upcoming and Account detail are sheets, so Back behaves inconsistently.
8. **The Add Transaction form shows every option at once.** About 20 field groups, from split and loyalty to cheque and tax, are on one screen.
9. **Features can't be found by name.**
   - The app has no search for screens or settings.
   - The Siri and Shortcuts intents exist (`FinTrackIntents.swift`), but nothing in the app mentions them.
10. **Accessibility gaps.**
    - `FTColor.textMuted` #9AA8B4 is 2.4:1 on white. `FTColor.accent` #0E9C8A is 3.4:1, both as text and with white text on it. `FTColor.income` #1FA463 is 3.2:1. WCAG needs 4.5:1 for normal text.
    - iPhone is portrait-only.
    - There are no string catalogs, so the app is English-only, although `AppLanguage` declares Arabic and RTL.

## 2. Proposed navigation and why

```
Tab bar (native TabView):  Home · Activity · Plan · Wealth        [Search]  ← Tab(role: .search)
Bottom accessory:          [+ Add transaction] [Scan]                     ← tabViewBottomAccessory
Wide screens:              same tabs as a sidebar with sections (Plan, Wealth, More) ← .sidebarAdaptable + TabSection
```

| Tab | Holds | Replaces |
|---|---|---|
| **Home** | Pay-cycle summary, *To review* card, labelled shortcuts (Reports, Insights, Net worth, Bills), Coming up, Budgets, Spending, Recent, Insights, Edit Home. Profile button → Settings | Dashboard; Dashboard Layout setting |
| **Activity** | Search, scopes, filters, *To review* (badge on tab), Import, Select | Transactions; review queue banner; Import hub moved from Settings |
| **Plan** | Budgets, Bills & Subscriptions, Goals, Income, Debt, Household, Planning tools | Budget tab + its menu; Goals/Debt from Accounts; Family and Premium tools from Settings |
| **Wealth** | Net worth hero, accounts grouped by type, loans and BNPL, Investments, Property & assets, Cards & rewards | Accounts tab with 4 inner tabs; Net worth sheet |
| **Search** | Transactions, accounts, bills, goals **and every screen and setting** by name | New |
| **Settings** | Preferences only: currency, notifications, appearance, Home layout, Siri & Shortcuts, Import & Sync, Categories & Rules, Backup & Restore, Face ID & Passcode, About | Settings hub that also hosted modules |

Why this structure:

- **Familiar and native.** It uses a system tab bar, a Search tab, navigation stacks and sheets. There are no custom navigation conventions to learn.
- **Organised by intent.** Each tab answers a different question:
  - Home: how am I doing?
  - Activity: what happened?
  - Plan: where should money go?
  - Wealth: what do I own and owe?
- **The most frequent action is labelled and always in thumb reach.** "Add transaction" sits above the tab bar on every tab, and in the sidebar on wide screens.
- **One home per feature, and fewer chip rows.**
  - Each feature has exactly one primary entry point; other links are shortcuts to the same screen.
  - Chip rows with more than 5 options become lists, or a short picker plus a list.
- **Adapts by size class only, never by device name.** The same hierarchy becomes a sidebar at regular width, as Apple's iPhone Duo guidance asks.

## 3. Platform capabilities: verified, conditional and unverified

**Project facts (from `project.pbxproj`):**
- Xcode 26.5 project (`LastUpgradeCheck = 2650`), deployment target iOS 26.5, Swift 5 mode.
- iPhone is portrait only; iPad supports all orientations.
- One app target, no extension targets, English only.

| Capability | Status for this project | Source |
|---|---|---|
| Liquid Glass on system containers: `TabView`, navigation bars, toolbars, sheets, menus, alerts | **Available with the current SDK (26.x).** Native containers adopt it automatically; the app already calls `.glassEffect` in `CustomTabBar` | Project code. Apple's Liquid Glass documentation page didn't render in this environment; confirm details in Xcode's docs |
| `Tab(role: .search)`, `tabViewBottomAccessory`, `tabBarMinimizeBehavior`, `.buttonStyle(.glass / .glassProminent)`, `GlassEffectContainer` | **iOS 26 SDK APIs** (from my knowledge of the iOS 26 SDK; confirm signatures in Xcode) | — |
| `.tabViewStyle(.sidebarAdaptable)`, `TabSection` | iOS 18+, so available | — |
| `swipeActionsContainer` (swipe actions outside `List`), toolbar `visibilityPriority`, item-bound alerts and confirmation dialogs, reorderable containers | **Needs the iOS 27 SDK (Xcode 27).** Gate with `if #available(iOS 27, *)` | [WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/) |
| App Intents App Schemas, `IndexedEntity` (Spotlight semantic index), view annotations (`.appEntityIdentifier`), `AppIntentsTesting` | iOS 27 SDK. **Needs Apple Intelligence**; availability varies by device, language and region. The documented schema domains include messages, mail and photos. **I found no finance domain**, so FinTrack would use generic entities | [What's new in iOS](https://developer.apple.com/ios/whats-new/), [WWDC26 session 240](https://developer.apple.com/videos/play/wwdc2026/240/) |
| Foundation Models | Already used for the SMS fallback. Needs a device that supports Apple Intelligence, a supported language and Apple Intelligence turned on | Project code, [WWDC26 Apple Intelligence guide](https://developer.apple.com/wwdc26/guides/apple-intelligence/) |
| **iPhone Duo** | **Verified as Apple's foldable iPhone.** See the details below this table | [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/), [Adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/), [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/) |
| Widgets, Control Center controls, Live Activities | **Not available in this build.** They need an extension target and an App Group (paid developer account). Source exists in `FinTrackWidget/` but there is no target | Project config |

**iPhone Duo details, from Apple's developer tech talks:**
- The outer display behaves like a standard iPhone.
- The inner display is regular width and regular height, and **it ignores supported orientations**.
- Full-screen support requires building with the **iOS 27.1 SDK (Xcode 27.1)**. Otherwise the app runs in a compatibility mode.
- Fold-aware layout uses `ReservedRegion` / `reservedRegions(kind: .division)` and `ArrangementView` (27.1).
- **No point dimensions are claimed.** The talks I could read gave none, and apple.com was blocked here. The prototype's "Regular width" frame is a representative size, not a Duo spec.

The prototype marks every system feature it imitates as **Simulated**. Its glass is a CSS blur, **not** native Liquid Glass.

## 4. Proposed system integrations (new features, outside the redesign scope; each needs your approval)

| Integration | User problem it solves | Constraints |
|---|---|---|
| **Siri & Shortcuts page** (in scope: UI only) | People can't discover the existing phrases and automations | None; it uses the existing intents |
| View annotations on transaction and account screens ("split this with Layla") | Acting on what's on screen without retyping | iOS 27 SDK, Apple Intelligence devices only |
| `IndexedEntity` for transactions (Siri and Spotlight semantic search) | "How much did I spend at Carrefour?" from anywhere | **Privacy:** financial data goes into the system index, outside the app lock. Recommend opt-in, off by default |
| Foundation Models "Ask" (replace the keyword chat) | Free-form questions about your own data | Device, language and region dependent. Must stay grounded in local data |
| Home Screen widgets and a Control Center "Add expense" control | Glanceable balance and one-tap entry | New extension target plus App Group (paid account); `WidgetDataService` snapshots already exist |
| Budget Live Activity | Live budget status while shopping | Existing service is dead code. Not recommended unless you want it |

## 5. Screen sizes and scenarios actually checked

- **Automated, headless Chromium (Playwright):**
  - All 59 matrix routes at four sizes: 375 × 667, 402 × 874, 440 × 956 and a 900 × 700 regular-width layout. No script errors and no horizontal overflow.
  - Every link and action control on 28 screens, and every control in the sheets and dialogs they open. No script errors after fixes.
  - All routes again at AX3 text, with long-text pseudo-localisation, right-to-left, dark mode and empty data. No overflow after fixes.
  - These runs found and fixed: a timer bug when closing the sheet during a scan, overflow from long unbroken words, and clipped form groups in sheets.
- **Screenshots reviewed:** Home (light and dark), Add sheet, To review, Budgets at regular width, Activity at AX3, Wealth in right-to-left.
- **Contrast** was computed for the colour tokens. The light-mode text, filled-button and income colours were darkened in the prototype to reach at least 4.5:1. These are proposed token changes.
- **Not checked:**
  - Real VoiceOver on iOS, and real Safari on iPhone.
  - Native Liquid Glass rendering.
  - An actual iPhone Duo, and the partially folded or tabletop poses (not simulated).
  - The software keyboard covering fields.
  - Performance on device.

## 6. What works and what is simulated

**Works in the prototype:**
- Tab switching (tap the current tab to pop to root), Back, sheets, dialogs and toasts with Undo.
- Add, edit and delete transactions, with account balances updating, a duplicate warning, a balance check and a discard-changes prompt.
- Review queue: approve, edit, reject, approve all ready items, BNPL and duplicate gates, reject all.
- Activity search, scopes, filters and select mode with bulk delete.
- Global search, including screens and settings.
- Budgets, Bills (list, calendar, subscriptions), Goals, Income, Debt (payoff planner slider), Wealth and Net worth views.
- Home customisation with accessible reordering, theme and accent, the passcode setup form with validation.
- Onboarding, lock screen (sample passcode 1234, lockout after 5 tries) and restore.
- Clear all data with typed confirmation.
- Every state toggle in the left panel.

**Simulated:**
- Siri and Shortcuts automations, OAuth sign-in, file pickers, receipt OCR, dictation and location.
- Share sheet and PDF export, backups and restore, price refresh and notifications, deep links into iOS Settings.
- The glass material (CSS approximation).
- Secondary module screens show the new entry point and layout with summarised content: planning tools, household tools, investment analysis and most reports. The existing SwiftUI content is kept as is when implemented.

## 7. Implementation plan (after approval)

The redesign changes UI only. No `@Model` or schema changes are expected, so **no schema bump**. Business logic and services are untouched.

1. **Shell.**
   - Replace `MainTabView`, `CustomTabBar` and the iPad `NavigationSplitView` with one native `TabView` (`Tab`, `TabSection`, `.sidebarAdaptable`, search role, bottom accessory, minimise on scroll).
   - `AppTab` gains `plan`/`wealth`/`search`.
   - `PendingNavigationTarget` keeps its persisted raw values (`budget` maps to Plan → Budgets, `accounts` to Wealth), so the existing intents keep working.
2. **Home and Activity.**
   - Restructure Dashboard sections and add the To review card.
   - Move the import entry point to Activity.
   - Account cards open Account detail.
3. **Plan and Wealth hubs.**
   - New hub views that push the existing module views.
   - Turn long chip rows into a `Picker` plus lists.
   - Turn modal destinations (Net worth, Bills, Upcoming, Account) into pushes.
   - Remove nested `NavigationStack`s.
4. **Add Transaction sheet and Search.**
   - Regroup the Add sheet with `DisclosureGroup`.
   - Add the Search tab (bounded `FetchDescriptor` queries plus a static screen and setting index).
   - Add the Siri & Shortcuts page.
   - Slim Settings down to preferences only.
5. **Accessibility and localisation.**
   - Token contrast fixes in `FTDesignSystem.swift`.
   - Dynamic Type layout at AX sizes.
   - Right-to-left review and a String Catalog scaffold (no translations).
6. **iOS 27 and iPhone Duo (optional, needs Xcode 27.1).**
   - Gate `swipeActionsContainer`, toolbar priorities and dialog item-binding behind `#available`.
   - Verify in Device Hub's iPhone Duo simulator.

I can't build in this environment, so each phase is checked by reading the code and running a Swift syntax parse. You build and run it in Xcode.

## Feature coverage matrix

Generated from `FEATURES` in `data.js` (the same list the prototype shows).

| Area | Feature | Current entry point | UX problem | Proposed entry point | Prototype route |
|---|---|---|---|---|---|
| Home | Monthly overview (income, spending, savings rate, spending donut) | Dashboard tab | Header has three unlabelled icon buttons (AI, Reports, Profile); no clear primary action | Home tab — summary card first, labelled shortcuts | `home` |
| Home | Account cards row | Dashboard (tapping switches tab) | Tapping a card silently switches tabs instead of opening the account | Home → account opens Account detail | `home` |
| Home | Upcoming payments (loans, cards, BNPL, bills, borrowed) | Dashboard → sheet | Second "bills" card duplicates it | Home → Coming up → Upcoming (pushed) | `upcoming` |
| Home | Smart insights cards | Dashboard | Separate from the AI hub and from Financial Intelligence | Home → Insights (one hub) | `insights` |
| Home | Customise dashboard sections | Settings → Dashboard Layout | Lives three levels away from Home | Home → Edit Home (bottom of Home) and Settings → Home screen | `home-edit` |
| Entry | Add expense / income / transfer | Centre "+" in a custom tab bar | Icon-only, custom non-native bar | Labelled "Add transaction" bar above the tab bar (iPhone) / toolbar button (wide) | `sheet:add` |
| Entry | Receipt scan (OCR), voice entry | Inside the Add form | Found only after opening the long form | First row of the Add sheet: Scan receipt · Dictate | `sheet:add` |
| Entry | Split, recurring, tags, location, pending/scheduled, tax flags, loyalty points, payment method (cheque, BNPL, bill link), attachments | Add form (one long screen) | Everything shown at once | "More details" grouped sections in the Add sheet | `sheet:add` |
| Entry | Unsaved-changes protection, duplicate warning, balance check | Add form | — | Kept; shown inline at the Save button | `sheet:add` |
| Activity | Transaction list grouped by day, search | Transactions tab | Search covers title/category/merchant only | Activity tab with search, scopes and filters | `activity` |
| Activity | Type and date-range filters | Chips + date sheet | — | Filter button (shows count) → Filter sheet | `activity` |
| Activity | Delete with Undo, bulk delete/category/tag | Swipe; Edit mode | Delete is gesture-only | Row "More" menu + swipe; Select in toolbar | `activity` |
| Activity | Transaction detail (FX rate, splits, receipt, attachments) and edit | Tap row | — | Same | `txn:t7` |
| Activity | Duplicate transactions banner | Transactions tab banner | — | Filter "Possible duplicates" | `activity` |
| Review | Review queue for email, SMS and Apple Pay imports | Banner inside Transactions; tab badge | The core pipeline is reached only through a banner; actions explained as gestures | "To review" card on Home + section at top of Activity; visible Approve / Edit buttons | `review` |
| Review | Approve all high-confidence, multi-select, reject all, history | Review queue | — | Same, labelled buttons | `review` |
| Review | Gates: BNPL plan, loan link, possible duplicate, "I paid for someone" | Edit sheet / dialogs | Blocked rows don't say why until tapped | Each blocked row states what it needs | `review` |
| Import | Import & Sync hub | Settings → Import & Integration | Far from the ledger it feeds | Activity → Import, and Settings → Import & Sync | `import` |
| Import | Email accounts (Gmail, Outlook, iCloud, IMAP), bank rules, paste email, sample emails | Import → Email | — | Import → Bank emails | `import-email` |
| Import | SMS automation via Shortcuts, SMS bank rules | Import → SMS | Setup steps are dense text | Import → Bank SMS (step list) | `import-sms` |
| Import | Apple Pay automation via Shortcuts | Import → Apple Pay | — | Import → Apple Pay | `import-applepay` |
| Import | CSV import with column mapping | Import hub | — | Import → Spreadsheet (CSV) | `import-csv` |
| Import | OFX / QFX / QIF statement import | Import hub | — | Import → Bank statement file | `import-ofx` |
| Plan | Budgets — monthly, annual, envelopes, zero-based | Budget tab (4 inner tabs) | Toolbar menu "Add or open" mixes creating and navigating | Plan → Budgets (view picker + one Add button) | `budgets` |
| Plan | Budget detail, rollover, shared, alerts threshold, expiry | Budget row | — | Same | `budget:bu2` |
| Plan | Seasonal templates (Ramadan, Eid, Summer), budget suggestions | Hidden in Budget toolbar menu | Undiscoverable | Budgets → Suggestions and Templates sections | `budgets` |
| Plan | Bills & subscriptions (calendar, waste, price changes, auto-pay check) | Dashboard sheet, Budget menu, Debt → Bills tab | Three entry points, two presentations | Plan → Bills & Subscriptions (one screen) | `bills` |
| Plan | Record bill payment | Bill detail | — | Bill detail → Record payment | `bill:bl1` |
| Plan | Savings goals, contributions, auto-save reminders, round-ups | Accounts module grid; Add Goal in Budget menu | Split across two tabs | Plan → Goals | `goals` |
| Plan | Income — salary, freelance, rental, dividends, passive, stability score | Budget toolbar menu | Hidden in a menu | Plan → Income | `income` |
| Plan | Debt — overview, loans, snowball/avalanche, calculator, lent, borrowed, BNPL, card utilisation | Budget menu and Accounts grid | Two entry points; ten chip tabs | Plan → Debt (Overview, Payoff plan, People, BNPL) | `debt` |
| Plan | Family — household budget, child allowances, shared goals, permissions, members | Settings → Family | A module inside Settings | Plan → Household | `family` |
| Plan | Planning tools: AI CFO, Retirement, Life events, Estate, Smart cash, Education | Settings → Premium Features | Modules inside Settings | Plan → Planning tools | `tools` |
| Wealth | Net worth headline (one shared definition) | Accounts hero | — | Wealth tab hero | `wealth` |
| Wealth | Accounts (bank, savings, cash, wallets, credit cards) and account detail | Accounts tab, inner tab 1 | Mixed with holdings in four inner tabs | Wealth → grouped list → Account | `account:a1` |
| Wealth | Loan detail, record payment, amortisation | Account / Debt | — | Wealth → Loans and Plan → Debt | `loan:l1` |
| Wealth | Net worth dashboard — history, forecast, allocation, milestones, snapshots | Sheet from Accounts | A primary destination opened as a modal | Wealth → Net worth (pushed) | `networth` |
| Wealth | Investments — holdings, crypto, gold, allocation, performance, dividends, capital gains, scenarios, simulation | Accounts → Portfolio (10 chip tabs) | Ten tabs in a scrolling chip row | Wealth → Investments (Holdings + Analysis list) | `investments` |
| Wealth | Real estate, vehicles, personal and digital assets | Accounts → Assets & Liabilities | Name promises liabilities it doesn't show | Wealth → Property & assets | `assets` |
| Wealth | Gift cards and loyalty programmes | Accounts inner tab "Other" | Hidden under "Other" | Wealth → Cards & rewards | `rewards` |
| Insights | Reports (13) with PDF/CSV export | Dashboard icon button | Unlabelled icon | Home → Reports; sidebar on wide screens | `reports` |
| Insights | AI assistant tools: anomalies, coach, patterns, savings, balance forecast, bill negotiation, ESG, digital twin | Dashboard sparkle icon | Separate from Financial Intelligence; two health scores | Home → Insights (one hub) | `insights` |
| Insights | Financial health score and predictions | Settings → Financial Intelligence | Inside Settings | Insights → Health score | `insight:health` |
| Insights | Ask (rule-based chat) | AI hub → chat sheet | — | Insights → Ask | `sheet:ask` |
| Search | In-app search across records and features | — (Spotlight only) | No way to find a feature by name | Search tab: transactions, accounts, bills, goals and every screen/setting | `search` |
| Settings | Profile name, base currency | Settings | — | Settings → Profile / Currency | `settings` |
| Settings | Face ID, passcode (PIN), auto-lock, security score | Settings (inline toggles) + Security subpage | Same controls in two places | Settings → Face ID & Passcode (one place) | `security` |
| Settings | Notifications (bills, budgets 75/90/100%, low balance, large purchase, salary, goals, digests) | Settings → Notifications | — | Same; permission-denied state | `notifications` |
| Settings | Appearance — theme, OLED, accent, high contrast, first weekday, fiscal year | Settings → Appearance | — | Same | `appearance` |
| Settings | Categories and auto-categorisation rules | Settings → sheets | — | Settings → Categories & Rules (also "Manage" from the category picker) | `categories` |
| Settings | On-device backup, email backup, import a backup file, restore | Settings → Data & Privacy | — | Settings → Backup & Restore | `backup` |
| Settings | Clear all data | Settings → Data & Privacy | One tap from other rows | Bottom of Backup & Restore, typed confirmation | `backup` |
| Settings | Siri & Shortcuts phrases | Not shown in the app | Users can't discover phrases or automations | Settings → Siri & Shortcuts | `siri` |
| Settings | About, privacy policy, terms | Settings | — | Same | `about` |
| App | Onboarding (name, base currency) | First launch | Four marketing pages before setup | Two steps: welcome, setup | `scene:onboarding` |
| App | Lock screen (Face ID, PIN, lockout) | Launch / return | — | Same | `scene:lock` |
| App | Restore from device snapshot after reinstall | Launch | — | Same | `scene:restore` |
| System | Siri / Shortcuts intents: log expense/income, balance, budget, open section, SMS, Apple Pay | App Intents | Invisible inside the app | Unchanged intents + Settings → Siri & Shortcuts (simulated in prototype) | `siri` |
| Hidden | Tax management, Business & freelancer, Remittance, Insurance, Collaborative planner, Audit log, Google Drive backup, PDF import, Two-factor | Hidden by DisableableFeature | Not user-visible today | Stay hidden; each has a reserved slot (Plan → Planning tools, Import, Security) for when it is re-enabled | `tools` |
