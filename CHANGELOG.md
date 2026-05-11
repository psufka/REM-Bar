# Changelog

## Unreleased

### Added

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
- Refresh now skips endpoint fetches when every metric driven by that endpoint is disabled, and the snapshot builder omits disabled metric series.
- Time-series OuraClient calls default to `latest=true` when no date-time range is supplied.
- Added offline tests for `TokenValidator`, metric color thresholds, and `SettingsStore` persistence.
- Updated `PLAN.md` to describe v0.1 actuals: 26 metrics, 18 MCP tools, ambient token discovery, fetch gating, and the Gen3+/Membership-gated endpoints.
- Updated docs and tests for 26 card options and 18 MCP tools.

### Build-time decisions

- Used SwiftPM target name `REMBar` with executable product name `REM-Bar` because Swift module names cannot reliably use hyphens.
- Implemented personal-access-token 401 retry as a serialized token re-read/re-validation gate. Oura PATs do not expose refresh tokens, so the retry mirrors the promise-lock shape without OAuth refresh.
- Added a test-only CommandLineTools `Testing.framework` search path when present because this machine's selected CLT SwiftPM does not auto-discover XCTest or Swift Testing, while `/Applications/Xcode.app` cannot be used until its license is accepted.
- Used `NSScreen.displayLink` on macOS 15+ with a `CVDisplayLink` fallback on macOS 14 because the current SDK exposes `NSScreen.displayLink` as macOS 15+ despite the locked macOS 14 minimum.
- Named the Oura tag model `OuraTag` to avoid a source-level collision with Swift Testing's `Tag` type.
