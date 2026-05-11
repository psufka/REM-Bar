# REM-Bar Session Log

## GitHub release prep (2026-05-11)

- Drafted a CodexBar-style public README with install instructions, first-run token setup, token source order, MCP server setup, feature summary, privacy notes, source build commands, credits, and license information.
- Added `Scripts/package_app.sh` to build `dist/REM-Bar.app` and `dist/REM-Bar-v0.1.0.zip` from SwiftPM release products.
- The app bundle now includes `Contents/MacOS/REM-Bar`, `Contents/MacOS/RemBarMCP`, `Contents/Resources/Icon.icns`, `Contents/Info.plist`, and the SwiftPM resource bundle needed by `Bundle.module`.
- Verified the packaged MCP server from `dist/REM-Bar.app/Contents/MacOS/RemBarMCP` with `initialize` and `tools/list`; it reports all 18 read-only Oura tools.
- Adjusted popover sizing to use the actual space below the menu-bar button so cards can extend closer to the bottom of the display before the grid scrolls.

### Build-time decisions

- The README assumes the public GitHub repo will be `psufka/REM-Bar`, matching the existing bundle/keychain naming. Update the badge and release links before pushing if the repo owner or name changes.
- The first package script intentionally does not sign or notarize the app; README keeps the quarantine removal step for v0.1.
- The package script defaults to the host architecture and supports `ARCHES="arm64 x86_64"` for a universal build when both architecture builds are available.
- Existing generated app bundles and release zips are moved to `~/.Trash` before replacement; the script avoids destructive clean operations.

### Left for Paul

- Replace `docs/screenshot-placeholder.svg` with a real screenshot before the public release page is published.
- Confirm the public GitHub repo path is `psufka/REM-Bar`; if not, update README badge and release links.
- Manual smoke test the packaged app from `dist/REM-Bar.app` with your real Oura token.
- Decide whether `PLAN2.md` and `SESSION-LOG.md` should remain public or be removed before the first GitHub push.
- Create the GitHub repo, add the remote, push, tag `v0.1.0`, and upload `dist/REM-Bar-v0.1.0.zip`.

## Pre-tag polish audit (2026-05-11)

| Concern | Status | Evidence | Fix |
|---------|--------|----------|-----|
| DailyStress categorical/numeric inconsistency | STILL PRESENT | `IconRenderer.swift`: `dailyStress` is listed in the non-categorical branch of `isCategorical`; `MetricSnapshot.swift`: `.dailyStress` builds numeric points with `stressValue` and also assigns `categoryValue` from `daySummary`; `ColorThresholds.swift` has both numeric and category color paths; `MetricCardView.swift` renders whichever `MetricSeries` supplies. | Flip `dailyStress` to categorical, remove the numeric extraction path, and keep `daySummary` category color mapping. |
| Popover height with many cards enabled | STILL PRESENT | `PopoverView.swift`: the grid is not wrapped in a scroll view and `gridColumns` uses `visibleMetrics.count > 2 ? 3 : 2`, so 15-26 enabled cards can produce a very tall popover. | Add the requested 1/2/3/4 column rule and cap the grid in a scroll view with `maxHeight: 600`. |
| Drag-reorder under rapid input | NO ACTION | Current request explicitly marks this concern as no-action; `SettingsStore` repair behavior is left untouched. | none |

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
- Native macOS menu-bar app with configurable Oura metric, SF Symbol status item, Keychain token settings, display-link refresh pause behavior, and a SwiftUI popover with twenty-six toggleable, reorderable Oura metric cards.
- Numeric cards show seven-day sparklines and deltas vs seven-day average; Resilience, Optimal Bedtime, and Sleep Time Recommendation are categorical with no sparkline.
- Shared `OuraKit` library with Oura API v2 endpoints for personal info, daily sleep, sleep detail, daily readiness, daily activity, daily stress, daily resilience, daily cardiovascular age, daily SpO2, VO2 max, sleep time, heart rate, ring battery level, workout, session, rest mode period, tag, and enhanced tag.
- Keychain token storage using service `com.psufka.REM-Bar` and `kSecAttrAccessibleAfterFirstUnlock`.
- Ambient token discovery for `OURA_TOKEN`, launchctl, oura-mcp config, and common shell/dotenv files.
- Serialized 401 retry gate for token re-resolution.
- Per-metric fetch gating so disabled cards do not request their backing endpoints.
- Wider Settings window with Active and Inactive drag-and-drop metric sections; Active ordering drives popover card order.
- Display setting for Celsius/Fahrenheit; Body Temp remains stored and thresholded in Oura's Celsius deviation, with Fahrenheit shown as a converted deviation.
- Sleep duration-backed cards use `H:MM` formatting for values, averages, deltas, and menu-bar titles.
- Account settings includes a clickable token setup guide with a direct Oura token page action.
- App icon now uses the moon-and-sleep symbol; Settings tabs are ordered Display, Account, About.
- Bundled `RemBarMCP` executable with a self-contained stdio JSON-RPC server and eighteen read-only Oura tools.
- Offline tests with Oura fixtures and URLProtocol stubs.
- README, MIT LICENSE with CodexBar attribution, CHANGELOG, CI workflow, root icon, screenshot placeholder, scripts, and git history checkpoints.

## Build-Time Defaults

- SwiftPM module target is `REMBar`; executable product remains `REM-Bar` because Swift module names should not use hyphens.
- Personal Access Token retry re-reads/re-validates the configured token once instead of OAuth refresh because v1 is PAT-only.
- `OURA_TOKEN` overrides Keychain/config for development; Keychain remains the app/MCP shared default; `~/.oura-mcp/config.json` is a compatibility fallback.
- macOS 14 refresh pause uses `CVDisplayLink`; `NSScreen.displayLink` is used on macOS 15+ because the current SDK marks it macOS 15+.
- Test targets add a CommandLineTools `Testing.framework` search path when needed because this machine's selected CLT SwiftPM does not auto-discover XCTest or Swift Testing, and Xcode.app is blocked by unaccepted license terms.
- New daily stress, resilience, cardiovascular age, SpO2, VO2 max, sleep time, heart rate, battery, workout, session, rest, tag, and enhanced tag models were based on Oura's OpenAPI spec at `/v2/static/json/openapi-1.29.json`; no real Oura API calls were made.
- Optimal Bedtime is displayed as a local 24-hour `HH:mm-HH:mm` window derived from Oura's `start_offset` and `end_offset`.
- The Oura tag model is named `OuraTag` to avoid a collision with Swift Testing's `Tag` type.

## Left For Paul

- Paste a real Oura Personal Access Token in Settings.
- Run a manual smoke test with real Oura data: token save, refresh, metric toggles and ordering, the newly added optional cards, invalid-token banner, and MCP `tools/list`.
- Create the GitHub repo and push when ready.
- Decide the future public-push/release strategy before tagging anything.
- Build the first public release zip from the SwiftPM products when v1 scope is ready.
- Codesign, notarize, DMG packaging, launch-at-login, and auto-update remain v1 work.
