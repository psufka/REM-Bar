# REM-Bar v0.1 Polish Plan

## Context

Codex built REM-Bar's first internal cut (labeled **v0.1** — still pre-release, no GitHub Release yet) in a single autonomous run at `~/Dropbox/code/REM-Bar/`. Two checkpoint commits landed (`MVP: scaffold menu bar app and OuraKit` 28d6632, `v1: add popover charts and MCP server` 765d96f — commit *messages* say "v1" but per current naming this is all v0.1; commit messages stay as-is, no history rewrite). Conformance to PLAN.md is high: 3 SwiftPM products, macOS 14 target, zero third-party deps, MIT + CodexBar attribution, 5 endpoints with real-fixture decoding tests, RemBarMCP with 5 stdio tools, GitHub Actions CI.

This plan covers the next pass of v0.1 work: (a) four real bugs the review uncovered, (b) a handful of polish items, and (c) feature work — adding `activity` plus five additional optional metrics as toggleable Settings cards. Version stays **v0.1** throughout — pre-release iteration, no public tag.

**Audit pass — `OuraTokenDiscovery.swift`** (standing untrusted-code rule): subprocess use is `/bin/launchctl getenv OURA_TOKEN` with hardcoded path and fixed args (no shell interpretation, no user input). File reads are a hardcoded dotfile list under `$HOME` — no path traversal possible. Token parsers (`parseTokenAssignment`, `shellWords`) are pure-Swift string manipulation; no eval, no exec. Foundation-only imports. Safe to keep.

**Accepted scope creep** (document in PLAN.md, then close out):
- Ambient token discovery cascade (env → Keychain → `~/.oura-mcp/config.json` → launchctl → shell/dotenv) beyond PLAN.md decision #3. Keep as power-user feature.
- DisplayLink driver shipped in MVP rather than v1 — fine, the work needed doing anyway.
- macOS 15 `NSScreen.displayLink` with CVDisplayLink fallback for 14 — Codex caught that the cleaner API is 15+; documented in CHANGELOG.

## Critical fixes (do these first)

| # | File:Line | Bug | Fix |
|---|---|---|---|
| C1 | `Sources/REM-Bar/DisplayLink.swift:67,78-82` | `Unmanaged.passUnretained(self).toOpaque()` passed to `CVDisplayLinkSetOutputCallback`. The `deinit`'s `Task @MainActor [weak self]` won't run `stop()` because `self` is already gone — CVDisplayLink keeps firing and dereferences a dangling pointer on shutdown. | Switch to `Unmanaged.passRetained(self).toOpaque()` at call site; balance with `Unmanaged.fromOpaque(...).release()` inside `stop()` after `CVDisplayLinkStop`. Guard against double-release with a flag. |
| C2 | `Sources/REM-Bar/MetricSnapshot.swift:58` | `activity _: [DailyActivity]` is fetched on every refresh but discarded by the builder. ~288 wasted HTTP requests/day. | Fixed by feature F1 below (add activity as a real metric). Don't fix separately. |
| C3 | `Sources/REM-Bar/RefreshCoordinator.swift:43-46` | `refresh()` calls `refreshTask?.cancel()` and immediately launches a new `Task` without awaiting cancellation. Rapid `refresh()` calls (e.g., user clicks manual-refresh) can spawn 2+ parallel API calls. | Convert to a tiny actor or replace with a serialized `AsyncSemaphore`: `await refreshTask?.value` before launching the next; or guard with an `inFlight: Bool` and just return early if already running (manual refresh becomes a no-op while a refresh is in flight, which is the right UX). |
| C4 | `Sources/REM-Bar/StatusItemController.swift:73-82` | Settings `NSWindow` created without delegate; `isReleasedWhenClosed = false` retains a window with no cleanup hook on close. On force-quit while popover/settings open, window can leak. | Make the window a strong property on the controller, conform to `NSWindowDelegate`, clear the property in `windowWillClose`. |

## Important polish

| # | File | Issue | Fix |
|---|---|---|---|
| I1 | `Sources/OuraKit/OuraClient.swift:103-122` + `Sources/REM-Bar/RefreshCoordinator.swift` | 401-retry via `TokenRetryGate` is structurally inert with PAT auth (no refresh-token rotation possible). `tokenProvider()` returns the same token twice. CHANGELOG already documents this. | Bubble the `invalidToken` error to the UI as a banner ("Oura token is invalid — open Settings to update") instead of just stashing it in `lastError`. Don't change retry semantics — they're correct for the OAuth-future. |
| I2 | `Sources/OuraKit/KeychainStore.swift:32` | `String(data: data, encoding: .utf8)` silently returns `nil` if Keychain data isn't valid UTF-8. Caller gets a "missing token" error instead of the real cause. | Throw `OuraError.decode("Keychain token is not valid UTF-8")` explicitly. |
| I3 | `Sources/REM-Bar/RefreshCoordinator.swift:51-59` | Concurrent `async let` fetches: if one endpoint 5xx's, the snapshot is built from partial data silently. User sees stale/missing values with no error. | Catch per-endpoint with `try? await` and a `partialFailure` list; surface "N endpoints unavailable" in `lastError` if non-empty. |
| I4 | `Sources/REM-Bar/SettingsView.swift:269-285` (`reloadTokenState`) | Synchronous file I/O (dotfile reads) + `launchctl` subprocess on the MainActor. Settings open could hitch on slow disk. | Mark `reloadTokenState` `async`, offload `discovery.resolve()` + `sourceSummaries()` to `Task.detached` or a background actor, then assign results back on `@MainActor`. |
| I5 | Tests | Missing: `TokenValidator`, `ColorThresholds`, `SettingsStore` round-trip. | Add 3 small XCTest files: (a) TokenValidator with `StubURLProtocol` stubbing 200/401, (b) ColorThresholds boundary tests (84.9→amber, 85.0→green, 69.9→red), (c) SettingsStore round-trip with an ephemeral `UserDefaults(suiteName: UUID().uuidString)`. |

## Feature additions

### F1 — Expand BarMetric to 11 toggleable cards

`BarMetric` grows from 5 cases (sleep score / REM / HRV / RHR / readiness) to **11** total. Cards 1–6 default ON; cards 7–11 default OFF (opt-in). All 11 user-toggleable in Settings.

**Default ON (6):**

| # | Metric | Data source | Color thresholds | Icon |
|---|---|---|---|---|
| 1 | Sleep Score | `DailySleep.score` (existing) | green ≥85, amber 70–84, red <70 | `moon.zzz` |
| 2 | REM | `Sleep.remSleepDuration / 60` (existing) | n/a (informational, no color) | `bed.double` |
| 3 | HRV | `Sleep.averageHrv` (existing) | n/a (highly individual) | `heart.text.square` |
| 4 | RHR | `Sleep.lowestHeartRate` (existing) | n/a (highly individual) | `heart.text.square` |
| 5 | Readiness | `DailyReadiness.score` (existing) | green ≥85, amber 70–84, red <70 | `heart.text.square` |
| 6 | Activity | `DailyActivity.score` (existing — currently dropped, fixes C2) | green ≥85, amber 70–84, red <70 | `figure.walk` |

**Default OFF (5):**

| # | Metric | Data source | Color thresholds | Icon | Cost |
|---|---|---|---|---|---|
| 7 | Body Temp Deviation | `DailyReadiness.temperatureDeviation` (already fetched) | green \|Δ\|<0.2°C, amber 0.2–0.5, red >0.5 | `thermometer.medium` | FREE |
| 8 | Sleep Efficiency | `Sleep.efficiency` (already fetched) | green ≥85%, amber 75–84%, red <75% | `bed.double.fill` | FREE |
| 9 | Daily Stress | new endpoint `/v2/usercollection/daily_stress` | green low, amber medium, red high (Oura returns `stress_high`/`recovery_high` durations — TBD field) | `waveform.path.ecg` | +1 endpoint |
| 10 | Resilience | new endpoint `/v2/usercollection/daily_resilience` | **categorical** — red=limited, amber=adequate, green=solid/strong/exceptional. Bar shows the level word, not a number. No sparkline. | `shield` | +1 endpoint |
| 11 | Cardiovascular Age | new endpoint `/v2/usercollection/daily_cardiovascular_age` | green ≤ actual age, amber up to +5yr, red >+5yr (needs `PersonalInfo.age` for comparison) | `heart` | +1 endpoint |

**Implementation touch list:**

- `Sources/OuraKit/Endpoint.swift` — add 3 cases: `dailyStress`, `dailyResilience`, `dailyCardiovascularAge`.
- `Sources/OuraKit/Models/` — add `DailyStress.swift`, `DailyResilience.swift`, `DailyCardiovascularAge.swift` Codable structs with real-API fixtures in `Tests/OuraKitTests/Fixtures/`.
- `Sources/OuraKit/OuraClient.swift` — add `dailyStress`, `dailyResilience`, `dailyCardiovascularAge` methods mirroring the existing collection() shape.
- `Sources/RemBarMCP/Tools/` — add 3 new tool files (`DailyStressTool.swift`, `DailyResilienceTool.swift`, `DailyCardiovascularAgeTool.swift`) — keep PLAN.md decision #14 (1 tool per endpoint, full surface) intact. Updates RemBarMCP from 5 → 8 tools.
- `Sources/REM-Bar/MetricSnapshot.swift` — `BarMetric` enum grows to 11 cases. `DashboardSnapshotBuilder.make()` gains parameters for the 3 new endpoint payloads + reads temp-dev / efficiency from existing data. Activity parameter stops being underscored.
- `Sources/REM-Bar/ColorThresholds.swift` — add cases for activity, bodyTempDev (signed |Δ| comparison), sleepEfficiency, stress, resilience (string→color), cardiovascularAge (relative-to-actual-age comparison; takes `PersonalInfo.age` as input).
- `Sources/REM-Bar/IconRenderer.swift` — add the 6 new SF Symbols above.
- `Sources/REM-Bar/MetricCardView.swift` — handle the **categorical resilience case**: show level text in place of number, no sparkline below. Either a `MetricCardView.Variant` enum (numeric vs categorical) or a sibling `CategoricalMetricCardView`. Lean: sibling view to keep MetricCardView simple.
- `Sources/REM-Bar/PopoverView.swift` — grid layout needs to handle 1–11 cards. Lean: `LazyVGrid` with 3 columns; rows wrap naturally. Test at all card counts.
- `Sources/REM-Bar/SettingsView.swift` — new "Metrics" section with 11 Toggles. Prevent disabling the currently-selected bar metric (auto-swap to the first enabled one, or block the toggle with a tooltip).
- `Sources/REM-Bar/SettingsStore.swift` — add `enabledMetrics: Set<BarMetric>` backed by `@AppStorage` with a JSON-encoded default of cards 1–6.

### F2 — Per-metric fetch gating

Toggles aren't just UI — they should gate the network fetch too, so disabled metrics don't burn API quota or wall-clock.

**Touch list:**
- `Sources/REM-Bar/RefreshCoordinator.swift` — wrap each `async let` in `if settings.enabledMetrics.containsAny([…relevant metrics for this endpoint])`. Mapping:
  - `daily_sleep` → drives metric 1 (Sleep Score)
  - `sleep` (detail) → drives 2, 3, 4, 8 (REM, HRV, RHR, Efficiency)
  - `daily_readiness` → drives 5, 7 (Readiness, Temp Dev)
  - `daily_activity` → drives 6 (Activity)
  - `daily_stress` → drives 9
  - `daily_resilience` → drives 10
  - `daily_cardiovascular_age` → drives 11
- `DashboardSnapshotBuilder.make()` — accept `enabledMetrics: Set<BarMetric>` and skip building disabled metric series (no wasted compute, no orphaned cards in the snapshot).
- Log skipped fetches at debug level so it's visible in Console why a given refresh is "fast".

**Cadence coupling — defer.** Activity-on vs activity-off doesn't change refresh math (5 min = 288/day either way). Hold the cadence picker at 1/5/15/30/60 default; don't auto-couple. Revisit if disable-everything-but-readiness becomes common.

### F3 — Update PLAN.md

- Decision #3 ("Auth") — extend to: "PAT validated against `/personal_info`. Token discovery cascade: env `OURA_TOKEN` → REM-Bar Keychain → `~/.oura-mcp/config.json` → launchctl → shell init files / `.env`. Settings UI shows the active source."
- Decision #7 ("Icon") — flip to: "11 BarMetric cases (sleep score, REM, HRV, RHR, readiness, activity + 5 optional: body temp dev, sleep efficiency, stress, resilience, cardiovascular age). Each maps to its own SF Symbol. Per-metric enable toggles in Settings; cards 1–6 default on, 7–11 default off."
- Decision #14 ("MCP surface") — bump from 5 → 8 tools (added daily_stress, daily_resilience, daily_cardiovascular_age).
- Decisions table — add row 15: "Per-metric enable toggles in Settings gate both UI rendering and network fetch."
- "Phased scope" — relabel MVP/v1/v1.1/v2 to **MVP / v0.1 / v1 (first public release) / v2**. What shipped this week + this polish pass is all v0.1 (pre-release iteration, no public tag). v1 = the eventual first public ship.
- Add 3 new endpoints to the documented Oura API surface section: `/v2/usercollection/daily_stress`, `/v2/usercollection/daily_resilience`, `/v2/usercollection/daily_cardiovascular_age`. Note that #9–#11 require Gen3+ ring + Oura Membership for the underlying features.

## Defer (post-v0.1)

- `@frozen` on `OuraError` — not real for a hobby app, no binary compatibility surface.
- `ColorThresholds.color(for:)` overload disambiguation — current API works.
- `scheduleTimer()` rename — cosmetic.
- Snapshot-style tests for `StatusItemController` / `PopoverView` — UI regression coverage can wait until v2.

## Verification

Per fix:

| # | Verify |
|---|---|
| C1 | Build & run, open/close Settings 10×, force-quit; no crash. `leaks` against the process shows no DisplayLinkDriver retain growth. |
| C3 | Spam manual-refresh button rapidly; Console shows only one in-flight refresh at a time. |
| C4 | Open Settings, close window (red dot), open again 5× — Activity Monitor "Open Files" doesn't grow. |
| I1 | Paste bogus token, save, wait for next refresh tick → banner shows "Oura token is invalid". |
| I2 | Manually write garbage bytes to the Keychain item via `security add-generic-password` with `-w $'\xff\xfe'`, relaunch app → user-visible error mentions UTF-8. |
| I3 | Block `daily_readiness` endpoint via `/etc/hosts` to `127.0.0.1`, refresh → snapshot still populates other 4 metrics and `lastError` shows "1 endpoint unavailable". |
| I4 | Add `sleep 2` to a `.zshrc` (temporary), open Settings → window opens immediately, not blocked. |
| I5 | `swift test` passes with 3 new test files. |
| F1 | Bar metric picker shows all 11 cases. Default-on cards 1–6 render in popover; default-off cards 7–11 hidden. Enabling Resilience renders a categorical card (level text, no sparkline). Enabling Cardiovascular Age compares against `PersonalInfo.age` for color. |
| F2 | Disable Activity in Settings → `daily_activity` endpoint no longer hit (Console.app filter `subsystem:com.psufka.REM-Bar`). Disable Stress + Resilience + CV Age → 3 fewer requests per refresh cycle. |
| F3 | PLAN.md decisions #3, #7, #14 updated; Phased scope renumbered; 3 new endpoints documented. |

## Suggested ordering

1. F1 + C2 together (activity feature kills the "fetched but ignored" bug).
2. C1, C3, C4 — the other three critical fixes. Small, surgical.
3. I1–I5 — polish round.
4. F2 — feature.
5. F3 — PLAN.md update.
6. Continue under v0.1 — no tag yet, no public release.

Total scope: ~6–9 hrs.
