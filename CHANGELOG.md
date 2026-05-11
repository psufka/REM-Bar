# Changelog

## Unreleased

### Added

- Expanded the menu-bar metric model from five metrics to eleven, adding Activity, body temperature deviation, sleep efficiency, daily stress, resilience, and cardiovascular age.
- Added Settings toggles for metric cards with the v0.1 defaults: sleep score, REM, HRV, RHR, readiness, and activity enabled; optional metrics disabled.
- Added OuraKit models, fixtures, client methods, and endpoints for daily stress, daily resilience, and daily cardiovascular age.
- Added three RemBarMCP tools: `oura_daily_stress`, `oura_daily_resilience`, and `oura_daily_cardiovascular_age`.
- Added a categorical Resilience card and unavailable-state copy for ring or membership-gated metric payloads.

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
- Refresh now skips endpoint fetches when every metric driven by that endpoint is disabled, and the snapshot builder omits disabled metric series.
- Added offline tests for `TokenValidator`, metric color thresholds, and `SettingsStore` persistence.

### Build-time decisions

- Used SwiftPM target name `REMBar` with executable product name `REM-Bar` because Swift module names cannot reliably use hyphens.
- Implemented personal-access-token 401 retry as a serialized token re-read/re-validation gate. Oura PATs do not expose refresh tokens, so the retry mirrors the promise-lock shape without OAuth refresh.
- Added a test-only CommandLineTools `Testing.framework` search path when present because this machine's selected CLT SwiftPM does not auto-discover XCTest or Swift Testing, while `/Applications/Xcode.app` cannot be used until its license is accepted.
- Used `NSScreen.displayLink` on macOS 15+ with a `CVDisplayLink` fallback on macOS 14 because the current SDK exposes `NSScreen.displayLink` as macOS 15+ despite the locked macOS 14 minimum.
