# REM-Bar Plan

## Context

REM-Bar is a personal macOS menu-bar app that surfaces Oura Ring data live in the menu bar — Steipete-pattern: small, single-purpose, native Swift, screenshot-worthy. v0.1 ships 11 toggleable Oura metrics: sleep score, REM, HRV, RHR, readiness, activity, body temperature deviation, sleep efficiency, daily stress, resilience, and cardiovascular age. Open-source from day 1 at `psufka/REM-Bar` under MIT. The project is the pathfinder for a family of six menu-bar apps (InboxBar, wRVUBar, CMEBar, PaBar, OnCallBar) — REM-Bar ships first, and the shared shell is YAGNI'd until the second app forces the abstraction.

The build forks the *shell* of `steipete/CodexBar` (StatusItemController, SettingsStore pattern, DisplayLink-driven refresh, Settings tabs) and ports the *auth + retry pattern* of `daveremy/oura-mcp` (TS) into Swift. Per user direction, v0.1 bundles an MCP wrapper (`RemBarMCP`) from day 1 so REM-Bar doubles as the canonical "menu-bar app + MCP server" template for the siblings.

Hardware: personal Mac on Sequoia, Apple Silicon, Xcode latest. Zero contact with employer systems, ever.

## Decisions (15)

| # | Question | Decision |
|---|---|---|
| 1 | Default bar metric | **Sleep Score**, color-coded (green ≥85, amber 70–84, red <70) |
| 2 | Popover | **11 toggleable metrics**; numeric cards use 7-day Swift Charts sparklines + ±delta vs 7-day avg, while Resilience is categorical with no sparkline |
| 3 | Auth | **Personal Access Token** validated against `/v2/usercollection/personal_info`; token discovery cascade is env `OURA_TOKEN` → REM-Bar Keychain → `~/.oura-mcp/config.json` → launchctl → shell init files / `.env`; Settings shows the active source |
| 4 | Refresh | **5-min default**, configurable 1/5/15/30/60; auto-pause on screen sleep via `NSScreen.displayLink()` |
| 5 | Bar mode | **Fixed metric**, swappable in Settings (no click-to-cycle) |
| 6 | Min macOS | **macOS 14 Sonoma** (matches CodexBar; gets modern displayLink API) |
| 7 | Icon | **11 BarMetric cases**: sleep score, REM, HRV, RHR, readiness, activity + optional body temp deviation, sleep efficiency, stress, resilience, cardiovascular age; each maps to its own SF Symbol; per-metric enable toggles in Settings; cards 1–6 default on, 7–11 default off |
| 8 | Distribution | **Unsigned for v0.1 internal builds**; README documents `xattr -dr com.apple.quarantine`. Codesign + notarize deferred to v1 |
| 9 | README | **Steipete-style**: one screenshot, install, 4 lines of how-it-works, MCP usage block |
| 10 | Synthetic mode | **Skip** — blur real numbers in screenshots manually |
| 11 | Shared shell | **YAGNI** — extract `BarAppKit` when InboxBar starts. Sample size of 1 makes the abstraction shape guessing |
| 12 | Scope cut | **All-in v0.1**: menu-bar app + 8-tool MCP server bundled from day 1 |
| 13 | Port-vs-build | See matrix below |
| 14 | MCP surface | **Full surface — 1 tool per endpoint** (8 tools), read-only |
| 15 | Fetch gating | **Per-metric enable toggles in Settings gate both UI rendering and network fetch** |

## Architecture

```
                            ┌──────────────────────────────┐
   ┌──────────────────┐     │  macOS Menu Bar              │
   │   Oura API v2    │◄────┤  [🌙 87]  ← NSStatusItem      │
   │  (REST, Bearer)  │     └──────┬───────────────────────┘
   └──────────────────┘            │ click
            ▲                      ▼
            │           ┌──────────────────────────┐
            │           │   PopoverView (SwiftUI)  │
            │           │   ┌──────┐  ┌──────┐    │
            │           │   │Sleep │  │ REM  │    │  ←  11 toggleable cards
            │           │   │  87  │  │ 94m  │    │     numeric cards sparkline
            │           │   │ ↑3   │  │ ↓12  │    │     + delta vs 7d avg
            │           │   │ ╱╲╱╲ │  │ ╲╱╲╱ │    │
            │           │   └──────┘  └──────┘    │
            │           │   [HRV] [RHR] [Ready]   │
            │           │   ─────────────────     │
            │           │   Open Oura · 2m ago    │
            │           └──────────────────────────┘
            │
            │      ┌──────────────────────────────────────────────┐
            │      │                REM-Bar.app                   │
            │      │  ┌────────────────────────────────────────┐  │
            │      │  │ StatusItemController                   │  │
            │      │  │ ↳ IconRenderer (SF Symbol per metric)  │  │
            │      │  │ ↳ ColorThresholds                      │  │
            │      │  ├────────────────────────────────────────┤  │
            │      │  │ RefreshCoordinator                     │  │
            │      │  │ ↳ DisplayLink (screen-sleep pause)     │  │
            │      │  │ ↳ Timer (configurable cadence)         │  │
            │      │  ├────────────────────────────────────────┤  │
            │      │  │ SettingsStore (UserDefaults)           │  │
            │      │  │ SettingsView (token paste, cadence)    │  │
            │      │  └────────────────────────────────────────┘  │
            │      └─────────────────┬────────────────────────────┘
            │                        │
            │                        ▼
            │      ┌──────────────────────────────────────────────┐
            └──────┤  OuraKit (SwiftPM library, shared)           │
                   │  ┌────────────────────────────────────────┐  │
                   │  │ OuraClient (URLSession + async/await)  │  │
                   │  │ ↳ 401 → serialized re-validate retry   │  │
                   │  ├────────────────────────────────────────┤  │
                   │  │ Endpoint (enum)                        │  │
                   │  │ Models/  (Codable: DailySleep, Sleep,  │  │
                   │  │           DailyReadiness, DailyActivity│  │
                   │  │           DailyStress, Resilience,     │  │
                   │  │           CardiovascularAge,           │  │
                   │  │           PersonalInfo)                │  │
                   │  ├────────────────────────────────────────┤  │
                   │  │ KeychainStore (Security framework)     │  │
                   │  │ TokenValidator (/personal_info ping)   │  │
                   │  └────────────────────────────────────────┘  │
                   └─────────────────┬────────────────────────────┘
                                     │
                                     ▼
                   ┌──────────────────────────────────────────────┐
                   │  RemBarMCP (SwiftPM executable, stdio)       │
                   │  ┌────────────────────────────────────────┐  │
                   │  │ JSON-RPC stdio server                  │  │
                   │  │ Reads same Keychain token as the app   │  │
                   │  ├────────────────────────────────────────┤  │
                   │  │ Tools (8):                             │  │
                   │  │  • oura_daily_sleep(start, end)        │  │
                   │  │  • oura_sleep_detail(start, end)       │  │
                   │  │  • oura_daily_readiness(start, end)    │  │
                   │  │  • oura_daily_activity(start, end)     │  │
                   │  │  • oura_daily_stress(start, end)       │  │
                   │  │  • oura_daily_resilience(start, end)   │  │
                   │  │  • oura_daily_cardiovascular_age(...)  │  │
                   │  │  • oura_personal_info()                │  │
                   │  └────────────────────────────────────────┘  │
                   └──────────────────────────────────────────────┘
                              ▲
                              │ claude mcp add rem-bar /path/to/RemBarMCP
                              │
                   ┌──────────────────────────────────────────────┐
                   │  Claude Code  (consumes via MCP)             │
                   └──────────────────────────────────────────────┘
```

## File structure

```
~/Dropbox/code/REM-Bar/
├── Package.swift                       # SwiftPM workspace, 3 products
├── PLAN.md                             # this file
├── README.md                           # Steipete-style
├── LICENSE                             # MIT
├── CHANGELOG.md
├── Icon.icns
├── version.env
├── .swiftformat
├── .swiftlint.yml
├── .gitignore
├── .github/workflows/
│   └── ci.yml                          # macOS 14, swift build + swift test
├── Scripts/
│   ├── compile_and_run.sh              # dev loop
│   └── lint.sh                         # swiftformat + swiftlint
├── Sources/
│   ├── REM-Bar/                        # the app
│   │   ├── RemBarApp.swift             # @main
│   │   ├── AppDelegate.swift           # NSApplicationDelegateAdaptor
│   │   ├── StatusItemController.swift  # NSStatusItem + click → menu
│   │   ├── PopoverView.swift           # SwiftUI menu content (11 toggleable cards)
│   │   ├── MetricCardView.swift        # one card: value + delta + sparkline
│   │   ├── SparklineView.swift         # Swift Charts 7-day sparkline
│   │   ├── SettingsView.swift          # token, cadence, metric, link to ouraring.com tokens
│   │   ├── SettingsStore.swift         # @AppStorage wrapper
│   │   ├── RefreshCoordinator.swift    # DisplayLink + Timer
│   │   ├── IconRenderer.swift          # SF Symbol → NSImage per metric
│   │   ├── ColorThresholds.swift       # green/amber/red mapping per metric
│   │   └── Resources/
│   │       └── Assets.xcassets
│   ├── OuraKit/                        # shared library (app + MCP both consume)
│   │   ├── OuraClient.swift            # URLSession, async/await, 401 retry
│   │   ├── Endpoint.swift              # enum: dailySleep, sleep, dailyReadiness, dailyActivity, stress, resilience, cardiovascularAge, personalInfo
│   │   ├── Models/
│   │   │   ├── DailySleep.swift
│   │   │   ├── Sleep.swift
│   │   │   ├── DailyReadiness.swift
│   │   │   ├── DailyActivity.swift
│   │   │   ├── DailyStress.swift
│   │   │   ├── DailyResilience.swift
│   │   │   ├── DailyCardiovascularAge.swift
│   │   │   └── PersonalInfo.swift
│   │   ├── KeychainStore.swift         # Security.framework, kSecAttrAccessibleAfterFirstUnlock
│   │   ├── TokenValidator.swift        # GET /personal_info, 200/401 → bool + error
│   │   └── OuraError.swift             # invalidToken, rateLimited, network, decode
│   └── RemBarMCP/                      # MCP server executable
│       ├── main.swift                  # stdio loop
│       ├── Server.swift                # JSON-RPC dispatch
│       └── Tools/
│           ├── DailySleepTool.swift
│           ├── SleepDetailTool.swift
│           ├── DailyReadinessTool.swift
│           ├── DailyActivityTool.swift
│           ├── DailyStressTool.swift
│           ├── DailyResilienceTool.swift
│           ├── DailyCardiovascularAgeTool.swift
│           └── PersonalInfoTool.swift
└── Tests/
    ├── OuraKitTests/
    │   ├── ModelDecodingTests.swift    # real Oura API JSON fixtures
    │   └── ClientTests.swift           # URLProtocol stubs, 401 retry
	    └── RemBarTests/
	        └── ColorThresholdsTests.swift  # boundary tests (84.9 → amber, 85 → green)
	```

## Oura API surface

v0.1 reads these Oura API v2 endpoints:

- `/v2/usercollection/personal_info`
- `/v2/usercollection/daily_sleep`
- `/v2/usercollection/sleep`
- `/v2/usercollection/daily_readiness`
- `/v2/usercollection/daily_activity`
- `/v2/usercollection/daily_stress`
- `/v2/usercollection/daily_resilience`
- `/v2/usercollection/daily_cardiovascular_age`

Daily stress, daily resilience, and daily cardiovascular age require a Gen3+ ring or Ring 4 plus active Oura Membership for the underlying features. REM-Bar treats 200-empty responses and unavailable endpoint failures as "Not available on your ring" card states.

## Phased scope

### MVP (~5 hrs) — local-only, works on your machine
- SwiftPM workspace skeleton with all 3 products declared
- StatusItemController shows hardcoded "87" in green
- `OuraKit.OuraClient` hits `/v2/usercollection/personal_info` + `/daily_sleep`
- `KeychainStore` reads/writes token
- `SettingsView` paste-token → validate → save
- DisplayLink-driven 5-min refresh with screen-sleep pause
- Sleep score in bar, color-coded; no popover, no charts

### v0.1 — pre-release internal cut
- Popover with 11 toggleable metric cards; numeric cards show delta + 7-day Swift Charts sparkline, Resilience is categorical
- 8 Oura API endpoints in `OuraClient`; all Codable models with fixtures
- `IconRenderer` swaps SF Symbol when bar metric changes
- Settings: cadence picker (1/5/15/30/60), bar-metric picker, metric card toggles, active token source display
- Per-metric fetch gating so disabled cards do not burn endpoint requests
- `RefreshCoordinator` uses `NSScreen.displayLink()` on macOS 15+ and `CVDisplayLink` fallback on macOS 14
- `RemBarMCP` executable with 8 stdio tools, sharing OuraKit + Keychain
- GitHub Actions CI (swiftformat lint + swift build + swift test on macOS 14)
- README: screenshot, install with `xattr -dr com.apple.quarantine` step, how-it-works, MCP install one-liner

### v1 — first public release
- GitHub Release: `REM-Bar-v1.0.0.zip`, source
- Apple Developer ID codesign + notarize via adapted `Scripts/package_app.sh`
- Signed `.dmg` artifact on Releases
- Launch-at-login via `ServiceManagement.SMAppService`
- Sparkle auto-update with appcast.xml

### v2 — later
- HealthKit fallback (resilience if Oura API changes)
- Widget target
- Optional second user (the OAuth dance from `ruhrpotter/oura-cli`)

## Port-vs-build matrix

| Source | What to lift | Verdict |
|---|---|---|
| `daveremy/oura-mcp` (TS) | Auth model: config file + env override. Serialized 401-refresh promise lock. URL/query-param shape. Tool naming for MCP. | **Port** patterns idiomatically to Swift. Read `TokenManager` and the 401-retry handler closely. |
| `steipete/CodexBar` (Swift, MIT) | `StatusItemController.swift`, `SettingsStore.swift` pattern, `PreferencesView` tab structure, `DisplayLink.swift`, `Scripts/package_app.sh` (for v1), `.github/workflows/ci.yml` | **Primary structural fork.** ~60–70% of structural code adapts. MIT — lift with attribution in LICENSE/NOTICE. |
| `turing-complet/python-ouraring` (Py, 139⭐) | Auth-handler delegation pattern, error hierarchy | Reference only — v1 API endpoints don't match v2. |
| `ruhrpotter/oura-cli` (Go) | OAuth localhost-callback flow | Skip for v1; revisit for v2 multi-user. |
| `visionik/ouracli` (Py) | Relative date strings ("7 days") | Skip — too early-stage, no retry logic. |
| `hagelstam/ouractl` (Go) | TUI patterns | Skip — wrong domain. |
| `arzzen/oura` (bash) | OpenAPI spec scraping | Skip — overkill. |

## Open questions (resolve at execution time)

1. ~~**Brainstorm doc gap.** REM-Bar isn't explicitly spelled out in `coding-ideas-steipete.md`.~~ **Resolved: this PLAN.md + the originating Claude Code conversation are the authoritative spec.** Do not look for a longer brainstorm entry.
2. ~~**CodexBar license.** Verify CodexBar's license is MIT-compatible before lifting structural code.~~ **Resolved: MIT.** Free to lift structural code with attribution.
3. **First-launch UX when no token.** Lean: red `?` in bar + popover opens directly to Settings tab. Confirm before wiring.
4. **MCP install path.** `claude mcp add rem-bar /Applications/REM-Bar.app/Contents/MacOS/RemBarMCP` vs a separate binary in `~/.local/bin/`? Lean: bundle inside the .app so one install covers both. Confirm during MCP wiring.
5. **REM-Bar v0.1.0 sleep-score color thresholds.** Locked at 85/70 for green/amber/red. Confirm or tune after a week of real data.

## Verification

End-to-end smoke test once shipped:

| Test | Expected |
|---|---|
| Paste bogus token in Settings | Inline error "Token invalid", no Keychain write; next refresh shows invalid-token banner with Settings action |
| Paste real token | Bar populates within 5 sec, popover shows real data |
| Color thresholds | Score of 84 → amber, 85 → green, 69 → red (unit test in `ColorThresholdsTests`) |
| Switch cadence to 1-min | `Console.app` shows refresh every minute |
| Close laptop lid 5 min, reopen | No requests fired during sleep (Console filter `subsystem:com.psufka.REM-Bar`) |
| Toggle optional metrics in Settings | Cards appear/disappear and disabled endpoint fetches are skipped |
| Bar-metric swap to HRV in Settings | Icon changes from `moon.zzz` to `heart.text.square`; bar value changes to HRV ms |
| `claude mcp add rem-bar …` then `oura_daily_sleep` / `oura_daily_stress` from Claude Code | Returns date-range JSON from the bundled MCP server |
| Download internal zip → `xattr -dr com.apple.quarantine` → open | App launches without Gatekeeper block |
| README screenshot | Real numbers blurred before posting (manual step) |

## Execution kickoff (next session)

1. Read CodexBar's `StatusItemController.swift`, `SettingsStore.swift`, `PreferencesView.swift`, `DisplayLink.swift`, `Package.swift`, `Scripts/package_app.sh` (verify MIT-compatible license first)
2. Read `daveremy/oura-mcp` `TokenManager` and 401-refresh handler
3. `git init` here, MIT LICENSE, create private `psufka/REM-Bar` on GitHub
4. Scaffold `Package.swift` with 3 products (REM-Bar, OuraKit, RemBarMCP)
5. Start MVP per phased scope above
