# Changelog

## Unreleased

### Changed

- Clarified the popover footer sleep-sync label so it shows the wake-date sleep before the bedtime range.
- Expanded metric info popovers with Oura-aligned explanations and Oura Help links.
- Added a Naps display setting, defaulting to Oura-like nap inclusion for sleep totals, stages, efficiency, and sleep debt.
- Bumped the local development version to 0.1.6.

## 0.1.5 - 2026-05-16

### Added

- Added first-run onboarding with token guidance and starter metric presets.
- Added metric explanation popovers on cards and card settings rows.
- Added metric presets for Sleep Focus, Recovery, Cardio, Minimal, and Everything.
- Added card group filtering in Display settings.
- Added per-metric threshold customization for supported numeric cards.
- Added a saved Custom metric preset so users can quickly restore their favorite card set.
- Added a running Sleep Debt Trend window with 7, 14, 30, and 90 day ranges.
- Added a sleep-goal picker directly in the Sleep Debt Trend window.
- Added hover values to Sleep Debt Trend bars.
- Kept the card popover visible when opening REM-Bar trend windows.
- Added trend windows to sleep, recovery, activity, cardiovascular, and breathing metric cards where a numeric trend is useful.
- Positioned trend windows beside the card popover instead of centered behind it.

### Changed

- Bumped the local development version to 0.1.5.
- Moved card info buttons to the lower-right corner so long metric titles have more room.
- Stabilized the menu-bar metric selector width in Display settings.
- Moved About-pane build details into the version hover help.
- Changed the Sleep Debt card to show a decaying 14-day running balance that follows the selected sleep goal.
- Moved the Sleep Debt goal into the card footer so the title row no longer truncates.
- Changed Sleep Debt Trend hover values to a compact two-line date/value label.
- Added extra right-side chart space so hover labels do not crowd the latest point.
- Renamed the Sleep Debt Trend average stat to "Avg debt".

## 0.1.4 - 2026-05-15

### Added

- Added Sparkle-powered in-app update support with an About-pane auto-update checkbox and manual Check for Updates button.
- Added Sparkle appcast generation and verification scripts for GitHub Releases.
- Added an Icon only menu-bar display option that shows the REM-Bar moon icon without a metric value.
- Added a Display switch for colored vs black-and-white metric icons.
- Added an Open at login toggle in Display settings.
- Added menu-bar trend arrows for numeric metrics when they differ from the selected average window.
- Added a Sleep Debt card driven by recent total sleep versus a user-selected sleep target.
- Added an Unavailable with your ring section in Display settings for metrics Oura reports as unsupported.

### Changed

- Bumped the local development version to 0.1.4.
- Package builds now embed Sparkle.framework and write Sparkle feed/public-key metadata into the app bundle.
- About now links to @psufka on X instead of the MCP docs, using the X mark in the link row.
- First-install default cards now include Sleep Debt instead of Average SpO2.
- Sleep target choices now use 15-minute intervals, and the Sleep Debt card title shows the active goal.
- Popover footer now shows the latest synced Oura sleep day and dated bedtime range, with a note that Oura Cloud/API data can take a couple hours to sync.
- Latest sleep footer timestamps now handle Oura timestamp variants more defensively.
- Latest sleep footer copy now presents the sleep interval directly to reduce date confusion.
- Added footer help for forcing an Oura Cloud sync, including links to Oura's missing-data instructions and Oura on the Web.

### Build-time decisions

- Added Sparkle 2.9.1 as the only third-party Swift package because native macOS auto-updates need Sparkle's signed appcast verification, installer, and update UI; reimplementing that would be higher risk than using the standard maintained framework.

## 0.1.2 - 2026-05-11

### Added

- Added a Display setting for 3-day, 7-day, 14-day, or 30-day metric averages; 7 days remains the default.
- Added a popover footer with the app name and version.

### Changed

- Centralized REM-Bar version metadata so the app, About pane, popover footer, MCP server, and package script read the same version value.
- Moved the copyright line into the About pane.
- Updated first-install active cards to Sleep Score, Readiness, HRV, Total Sleep, Deep Sleep, REM, Cardio Age, RHR, HRV Balance, Body Temp, VO2 Max, and Average SpO2.

## 0.1.1 - 2026-05-11

### Fixed

- Fixed the release package so `REM-Bar.app` contains SwiftPM resources only under `Contents/Resources` and verifies with an ad-hoc app bundle signature after unzipping.

### Changed

- Removed custom XCTest framework search-path fallbacks from `Package.swift`; local and CI test runs now use standard `swift test` with the full Xcode toolchain.

## 0.1.0 - 2026-05-11

### Added

- Added `Scripts/package_app.sh` to build `dist/REM-Bar.app` and release zips from SwiftPM release products, bundling `RemBarMCP` at the documented MCP path.
- Replaced the README with a CodexBar-style public draft covering install, first run, token sources, MCP setup, privacy, and source builds.
- Replaced the README screenshot placeholder with a real REM-Bar popover screenshot.
- Converted tests from Swift Testing to XCTest for GitHub Actions macOS 14 compatibility.
- Expanded the menu-bar metric model from five metrics to thirteen, adding Activity, Deep Sleep, Total Sleep, body temperature deviation, sleep efficiency, daily stress, resilience, and cardiovascular age.
- Expanded the metric model from thirteen cards to twenty-six, adding Light Sleep, Awake Time, Time in Bed, Sleep Latency, Breath Rate, HRV Balance, Sleep Balance, Sleep Regularity, Average SpO2, Breathing Disturbance, VO2 Max, Optimal Bedtime, and Sleep Time Recommendation.
- Added Settings toggles for metric cards with the v0.1 defaults: sleep score, REM, HRV, RHR, readiness, and activity enabled; optional metrics disabled.
- Added persisted drag-and-drop ordering for metric cards in Settings.
- Added OuraKit models, fixtures, client methods, and endpoints for daily stress, daily resilience, and daily cardiovascular age.
- Added OuraKit models, fixtures, client methods, and endpoints for daily SpO2, VO2 max, sleep time, heart rate, ring battery level, workout, session, rest mode period, tag, and enhanced tag.
- Added three RemBarMCP tools: `oura_daily_stress`, `oura_daily_resilience`, and `oura_daily_cardiovascular_age`.
- Added ten RemBarMCP tools: `oura_daily_spo2`, `oura_vo2_max`, `oura_sleep_time`, `oura_heart_rate`, `oura_ring_battery_level`, `oura_workout`, `oura_session`, `oura_rest_mode_period`, `oura_tag`, and `oura_enhanced_tag`.
- Added a categorical Resilience card and unavailable-state copy for ring or membership-gated metric payloads.
- Added categorical cards for Optimal Bedtime and Sleep Time Recommendation.

### Fixed

- Retained and released the macOS 14 `CVDisplayLink` callback context explicitly to avoid dangling callback pointers on shutdown.
- Prevented overlapping manual/display-link refreshes by ignoring refresh requests while one refresh task is already in flight.
- Cleared the retained Settings window when it closes via `NSWindowDelegate`.
- Stopped discarding fetched daily activity data by promoting Activity to a first-class card metric.
- Reported invalid Oura tokens as a popover banner with a Settings action.
- Made invalid UTF-8 Keychain token data throw an explicit decode error.
- Preserved partial dashboard data when individual Oura endpoints fail and summarized endpoint failures in the popover.
- Moved token-source discovery for Settings off the UI path.

### Changed

- Added ambient Oura token discovery after explicit sources: process `OURA_TOKEN`, REM-Bar Keychain, `~/.oura-mcp/config.json`, `launchctl getenv OURA_TOKEN`, and common shell/dotenv files such as `~/.zshrc`.
- Settings now shows the exact active token source and can save a detected ambient token into the REM-Bar Keychain.
- Settings now lays out metric-card options in a fixed three-column grid inside a wider Display tab so all 26 options are visible with less scrolling.
- Settings now organizes metric cards into Active and Inactive drag-and-drop sections instead of checkbox toggles; the Active section order is the popover card order.
- Added a Display setting for Celsius vs Fahrenheit and applied it to Body Temp in the menu bar, card value, card delta, and 7-day average.
- Sleep duration metrics now display as hours and minutes, for example `6:51`, instead of total minutes.
- Added an Account settings help sheet with step-by-step Oura Personal Access Token setup instructions.
- Replaced the app icon with a dark moon-and-sleep symbol that matches REM-Bar's sleep status icon.
- Reordered Settings tabs to Display, Account, About so display customization is first.
- Daily Stress now follows the categorical-card convention and renders the latest day summary without a sparkline.
- Popover cards now use 1-4 columns by enabled-card count and scroll at a capped height when many cards are active.
- Popover sizing now uses the actual space below the menu-bar button so active cards can grow closer to the bottom of the display before scrolling.
- Popover card sizing is now deterministic across the controller, grid, and card views so the last row is not partially clipped before scrolling starts.
- README now clarifies that the bundled MCP server can be used by Claude Code, Codex, or any other MCP-capable LLM client.
- README install instructions now link directly to the release zip asset.
- Refresh now skips endpoint fetches when every metric driven by that endpoint is disabled, and the snapshot builder omits disabled metric series.
- Time-series OuraClient calls default to `latest=true` when no date-time range is supplied.
- Added offline tests for `TokenValidator`, metric color thresholds, and `SettingsStore` persistence.
- Updated docs and tests for 26 card options and 18 MCP tools.
- Moved internal planning and session notes out of the public repo.

### Build-time decisions

- Used SwiftPM target name `REMBar` with executable product name `REM-Bar` because Swift module names cannot reliably use hyphens.
- Implemented personal-access-token 401 retry as a serialized token re-read/re-validation gate. Oura PATs do not expose refresh tokens, so the retry mirrors the promise-lock shape without OAuth refresh.
- Used `NSScreen.displayLink` on macOS 15+ with a `CVDisplayLink` fallback on macOS 14 because the current SDK exposes `NSScreen.displayLink` as macOS 15+ despite the locked macOS 14 minimum.
- Named the Oura tag model `OuraTag` to avoid a source-level collision with Swift Testing's `Tag` type.
