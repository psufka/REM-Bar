# REM-Bar Session Log

## PLAN2 baseline audit (2026-05-11)

| Item | Status | Evidence | Remaining work |
|------|--------|----------|----------------|
| C1 | NOT STARTED | [DisplayLink.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/DisplayLink.swift:63): `takeUnretainedValue()`; [DisplayLink.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/DisplayLink.swift:67): `Unmanaged.passUnretained(self).toOpaque()`; diff `765d96f..HEAD` is empty for this file. | Retain the callback context, stop CVDisplayLink, release exactly once, and remove the ineffective weak-self deinit cleanup. |
| C2 | NOT STARTED | [MetricSnapshot.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/MetricSnapshot.swift:58): `activity _: [DailyActivity])`; [IconRenderer.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/IconRenderer.swift:3): `enum BarMetric: String, CaseIterable, Identifiable` still has only 5 cases through line 8; diff `765d96f..HEAD` is empty for `MetricSnapshot.swift`. | Add Activity as a real enabled metric through F1. |
| C3 | NOT STARTED | [RefreshCoordinator.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/RefreshCoordinator.swift:43): `func refresh()`; line 44 `refreshTask?.cancel()`; line 46 `refreshTask = Task { [weak self] in`; diff `765d96f..HEAD` is empty for this file. | Serialize refreshes or make manual refresh a no-op while one is in flight. |
| C4 | PARTIAL | [StatusItemController.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/StatusItemController.swift:10): `private var settingsWindow: NSWindow?`; [StatusItemController.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/StatusItemController.swift:67): `let window = settingsWindow ?? makeSettingsWindow()`; [StatusItemController.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/StatusItemController.swift:79): `window.isReleasedWhenClosed = false`; diff shows the strong property/window creation was added after v1, but there is no `NSWindowDelegate`, `window.delegate`, or `windowWillClose`. | Add delegate cleanup and clear `settingsWindow` when the settings window closes. |
| I1 | PARTIAL | [OuraClient.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/OuraKit/OuraClient.swift:112): `} catch OuraError.invalidToken {`; [RefreshCoordinator.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/RefreshCoordinator.swift:69): `} catch {`; line 71 `self.lastError = error.localizedDescription`; [PopoverView.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/PopoverView.swift:25): `if let lastError {` displays generic red text. Diff shows only generic empty-state text was added after v1. | Preserve retry semantics, but surface invalid-token as a specific banner with a Settings action instead of only generic `lastError`. |
| I2 | NOT STARTED | [KeychainStore.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/OuraKit/KeychainStore.swift:32): `return String(data: data, encoding: .utf8)`; diff `765d96f..HEAD` is empty for this file. | Throw `OuraError.decode("Keychain token is not valid UTF-8")` when decoding fails. |
| I3 | NOT STARTED | [RefreshCoordinator.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/RefreshCoordinator.swift:51): `async let dailySleep`; lines 52-54 start the other endpoint fetches; lines 65-72 collapse failures into whole-refresh errors. Diff `765d96f..HEAD` is empty for this file. | Convert endpoint fetches to per-endpoint results, keep available data, and report partial failures. |
| I4 | NOT STARTED | [SettingsView.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/SettingsView.swift:269): `private func reloadTokenState()`; lines 270-275 synchronously read Keychain, resolve discovery, and collect source summaries on the UI path. Diff after v1 added this method synchronously. | Offload token discovery/file I/O/launchctl work off the MainActor and assign state back on MainActor. |
| I5 | PARTIAL | [ColorThresholdsTests.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Tests/RemBarTests/ColorThresholdsTests.swift:6): `@Test func sleepScoreBoundaries()`; lines 7-10 cover 84.9, 85, 69.9, and 70. `rg TokenValidatorTests Tests` and `rg SettingsStore Tests` find no matching tests. | Add TokenValidator 200/401 tests and SettingsStore round-trip tests; extend threshold tests as new metrics land. |
| F1 | PARTIAL | [Endpoint.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/OuraKit/Endpoint.swift:7): existing `case dailyActivity`; [Server.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/RemBarMCP/Server.swift:15): tool list still contains only 5 tools through line 21; [IconRenderer.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/IconRenderer.swift:3): `BarMetric` still contains only sleep score, REM, HRV, RHR, readiness through line 8. No new F1 endpoint/model/tool diffs after v1. | Expand to 11 metrics, add 3 Oura endpoints/models/fixtures/MCP tools, add metric toggles, categorical Resilience card, and PersonalInfo age support for cardiovascular age. |
| F2 | NOT STARTED | [SettingsStore.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/SettingsStore.swift:33): only `refreshCadence` is persisted; [SettingsStore.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/SettingsStore.swift:39): only `selectedMetric` follows; [RefreshCoordinator.swift](/Users/paulsufka/Dropbox/code/REM-Bar/Sources/REM-Bar/RefreshCoordinator.swift:51): endpoint fetches are unconditional. Diffs after v1 do not add `enabledMetrics`. | Add `SettingsStore.enabledMetrics`, filter rendered cards, and gate each endpoint fetch by enabled metrics. |
| F3 | NOT STARTED | [PLAN.md](/Users/paulsufka/Dropbox/code/REM-Bar/PLAN.md:16): popover still says `5 metrics`; [PLAN.md](/Users/paulsufka/Dropbox/code/REM-Bar/PLAN.md:17): auth only names PAT plus `OURA_TOKEN`; [PLAN.md](/Users/paulsufka/Dropbox/code/REM-Bar/PLAN.md:28): MCP surface still says `5-7 tools`; diff `765d96f..HEAD` is empty for `PLAN.md`. | Update PLAN.md with v0.1 actuals per F3 without editing PLAN2.md. |

## Built

- SwiftPM workspace with three products: `REM-Bar`, `OuraKit`, and `RemBarMCP`.
- Native macOS menu-bar app with configurable Oura metric, SF Symbol status item, Keychain token settings, display-link refresh pause behavior, and a SwiftUI popover with thirteen toggleable Oura metric cards.
- Numeric cards show seven-day sparklines and deltas vs seven-day average; Resilience is categorical with no sparkline.
- Shared `OuraKit` library with Oura API v2 endpoints for personal info, daily sleep, sleep detail, daily readiness, daily activity, daily stress, daily resilience, and daily cardiovascular age.
- Keychain token storage using service `com.psufka.REM-Bar` and `kSecAttrAccessibleAfterFirstUnlock`.
- Ambient token discovery for `OURA_TOKEN`, launchctl, oura-mcp config, and common shell/dotenv files.
- Serialized 401 retry gate for token re-resolution.
- Per-metric fetch gating so disabled cards do not request their backing endpoints.
- Bundled `RemBarMCP` executable with a self-contained stdio JSON-RPC server and eight read-only Oura tools.
- Offline tests with Oura fixtures and URLProtocol stubs.
- README, MIT LICENSE with CodexBar attribution, CHANGELOG, CI workflow, root icon, screenshot placeholder, scripts, and git history checkpoints.

## Build-Time Defaults

- SwiftPM module target is `REMBar`; executable product remains `REM-Bar` because Swift module names should not use hyphens.
- Personal Access Token retry re-reads/re-validates the configured token once instead of OAuth refresh because v1 is PAT-only.
- `OURA_TOKEN` overrides Keychain/config for development; Keychain remains the app/MCP shared default; `~/.oura-mcp/config.json` is a compatibility fallback.
- macOS 14 refresh pause uses `CVDisplayLink`; `NSScreen.displayLink` is used on macOS 15+ because the current SDK marks it macOS 15+.
- Test targets add a CommandLineTools `Testing.framework` search path when needed because this machine's selected CLT SwiftPM does not auto-discover XCTest or Swift Testing, and Xcode.app is blocked by unaccepted license terms.
- New daily stress, resilience, and cardiovascular age models were based on Oura's OpenAPI spec at `/v2/static/json/openapi-1.29.json`; no real Oura API calls were made.

## Left For Paul

- Paste a real Oura Personal Access Token in Settings.
- Run a manual smoke test with real Oura data: token save, refresh, metric toggles, invalid-token banner, and MCP `tools/list`.
- Create the GitHub repo and push when ready.
- Decide the future public-push/release strategy before tagging anything.
- Build the first public release zip from the SwiftPM products when v1 scope is ready.
- Codesign, notarize, DMG packaging, launch-at-login, and auto-update remain v1 work.
