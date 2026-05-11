# REM-Bar Plan

## Context

REM-Bar is a personal macOS menu-bar app that surfaces Oura Ring data (sleep score, REM, HRV, RHR, readiness) live in the menu bar — Steipete-pattern: small, single-purpose, native Swift, screenshot-worthy. Open-source from day 1 at `psufka/REM-Bar` under MIT. The project is the pathfinder for a family of six menu-bar apps (InboxBar, wRVUBar, CMEBar, PaBar, OnCallBar) — REM-Bar ships first, and the shared shell is YAGNI'd until the second app forces the abstraction.

The build forks the *shell* of `steipete/CodexBar` (StatusItemController, SettingsStore pattern, DisplayLink-driven refresh, Settings tabs) and ports the *auth + retry pattern* of `daveremy/oura-mcp` (TS) into Swift. Per user direction, v1 bundles an MCP wrapper (`RemBarMCP`) from day 1 so REM-Bar doubles as the canonical "menu-bar app + MCP server" template for the siblings.

Hardware: personal Mac on Sequoia, Apple Silicon, Xcode latest. Zero contact with employer systems, ever.

## Decisions (13 + 1)

| # | Question | Decision |
|---|---|---|
| 1 | Default bar metric | **Sleep Score**, color-coded (green ≥85, amber 70–84, red <70) |
| 2 | Popover | **5 metrics + 7-day Swift Charts sparklines + ±delta vs 7-day avg** |
| 3 | Auth | **Personal Access Token** validated against `/v2/usercollection/personal_info`; `OURA_TOKEN` env override for dev |
| 4 | Refresh | **5-min default**, configurable 1/5/15/30/60; auto-pause on screen sleep via `NSScreen.displayLink()` |
| 5 | Bar mode | **Fixed metric**, swappable in Settings (no click-to-cycle) |
| 6 | Min macOS | **macOS 14 Sonoma** (matches CodexBar; gets modern displayLink API) |
| 7 | Icon | **SF Symbol that matches current metric** — `moon.zzz` (sleep score), `bed.double` (REM), `heart.text.square` (HRV/readiness/RHR), `figure.walk` (activity) |
| 8 | Distribution | **Unsigned only for first ship**; GitHub Release ships a zip; README documents `xattr -dr com.apple.quarantine`. Codesign + notarize deferred to v1.1 |
| 9 | README | **Steipete-style**: one screenshot, install, 4 lines of how-it-works, MCP usage block |
| 10 | Synthetic mode | **Skip** — blur real numbers in screenshots manually |
| 11 | Shared shell | **YAGNI** — extract `BarAppKit` when InboxBar starts. Sample size of 1 makes the abstraction shape guessing |
| 12 | Scope cut | **All-in v1**: menu-bar app + 5-tool MCP server bundled from day 1 |
| 13 | Port-vs-build | See matrix below |
| 14 | MCP surface | **Full surface — 1 tool per endpoint** (5–7 tools), read-only |

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
            │           │   │Sleep │  │ REM  │    │  ←  5 MetricCardView
            │           │   │  87  │  │ 94m  │    │     each with sparkline
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
                   │  │ Tools (5):                             │  │
                   │  │  • oura_daily_sleep(start, end)        │  │
                   │  │  • oura_sleep_detail(start, end)       │  │
                   │  │  • oura_daily_readiness(start, end)    │  │
                   │  │  • oura_daily_activity(start, end)     │  │
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
│   │   ├── PopoverView.swift           # SwiftUI menu content (5 cards)
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
│   │   ├── Endpoint.swift              # enum: dailySleep, sleep, dailyReadiness, dailyActivity, personalInfo
│   │   ├── Models/
│   │   │   ├── DailySleep.swift
│   │   │   ├── Sleep.swift
│   │   │   ├── DailyReadiness.swift
│   │   │   ├── DailyActivity.swift
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
│           └── PersonalInfoTool.swift
└── Tests/
    ├── OuraKitTests/
    │   ├── ModelDecodingTests.swift    # real Oura API JSON fixtures
    │   └── ClientTests.swift           # URLProtocol stubs, 401 retry
    └── RemBarTests/
        └── ColorThresholdsTests.swift  # boundary tests (84.9 → amber, 85 → green)
```

## Phased scope

### MVP (~5 hrs) — local-only, works on your machine
- SwiftPM workspace skeleton with all 3 products declared
- StatusItemController shows hardcoded "87" in green
- `OuraKit.OuraClient` hits `/v2/usercollection/personal_info` + `/daily_sleep`
- `KeychainStore` reads/writes token
- `SettingsView` paste-token → validate → save
- 5-min Timer-based refresh (no DisplayLink yet)
- Sleep score in bar, color-coded; no popover, no charts

### v1 (~12 hrs total, MVP + ~7 hrs) — public ship
- Popover with 5 `MetricCardView`s, each with delta + 7-day Swift Charts sparkline
- All 5 endpoints in `OuraClient`; all Codable models with fixtures
- `IconRenderer` swaps SF Symbol when bar metric changes
- Settings: cadence picker (1/5/15/30/60), bar-metric picker
- `RefreshCoordinator` migrates to `NSScreen.displayLink()` for screen-sleep pause
- `RemBarMCP` executable with 5 stdio tools, sharing OuraKit + Keychain
- GitHub Actions CI (swiftformat lint + swift build + swift test on macOS 14)
- README: screenshot, install with `xattr -dr com.apple.quarantine` step, how-it-works, MCP install one-liner
- GitHub Release: `REM-Bar-v0.1.0.zip` (unsigned), source

### v1.1 — distribution polish
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
| `steipete/CodexBar` (Swift, MIT) | `StatusItemController.swift`, `SettingsStore.swift` pattern, `PreferencesView` tab structure, `DisplayLink.swift`, `Scripts/package_app.sh` (for v1.1), `.github/workflows/ci.yml` | **Primary structural fork.** ~60–70% of structural code adapts. MIT — lift with attribution in LICENSE/NOTICE. |
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
| Paste bogus token in Settings | Inline error "Token invalid", no Keychain write |
| Paste real token | Bar populates within 5 sec, popover shows real data |
| Color thresholds | Score of 84 → amber, 85 → green, 69 → red (unit test in `ColorThresholdsTests`) |
| Switch cadence to 1-min | `Console.app` shows refresh every minute |
| Close laptop lid 5 min, reopen | No requests fired during sleep (Console filter `subsystem:com.psufka.REM-Bar`) |
| Bar-metric swap to HRV in Settings | Icon changes from `moon.zzz` to `heart.text.square`; bar value changes to HRV ms |
| `claude mcp add rem-bar …` then `oura_daily_sleep` from Claude Code | Returns last 7 days of sleep score JSON |
| Download Release zip → `xattr -dr com.apple.quarantine` → open | App launches without Gatekeeper block |
| README screenshot | Real numbers blurred before posting (manual step) |

## Execution kickoff (next session)

1. Read CodexBar's `StatusItemController.swift`, `SettingsStore.swift`, `PreferencesView.swift`, `DisplayLink.swift`, `Package.swift`, `Scripts/package_app.sh` (verify MIT-compatible license first)
2. Read `daveremy/oura-mcp` `TokenManager` and 401-refresh handler
3. `git init` here, MIT LICENSE, create private `psufka/REM-Bar` on GitHub
4. Scaffold `Package.swift` with 3 products (REM-Bar, OuraKit, RemBarMCP)
5. Start MVP per phased scope above
