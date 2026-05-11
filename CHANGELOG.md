# Changelog

## Unreleased

### Fixed

- Retained and released the macOS 14 `CVDisplayLink` callback context explicitly to avoid dangling callback pointers on shutdown.
- Prevented overlapping manual/display-link refreshes by ignoring refresh requests while one refresh task is already in flight.
- Cleared the retained Settings window when it closes via `NSWindowDelegate`.

### Changed

- Added ambient Oura token discovery after explicit sources: process `OURA_TOKEN`, REM-Bar Keychain, `~/.oura-mcp/config.json`, `launchctl getenv OURA_TOKEN`, and common shell/dotenv files such as `~/.zshrc`.
- Settings now shows the exact active token source and can save a detected ambient token into the REM-Bar Keychain.

### Build-time decisions

- Used SwiftPM target name `REMBar` with executable product name `REM-Bar` because Swift module names cannot reliably use hyphens.
- Implemented personal-access-token 401 retry as a serialized token re-read/re-validation gate. Oura PATs do not expose refresh tokens, so the retry mirrors the promise-lock shape without OAuth refresh.
- Added a test-only CommandLineTools `Testing.framework` search path when present because this machine's selected CLT SwiftPM does not auto-discover XCTest or Swift Testing, while `/Applications/Xcode.app` cannot be used until its license is accepted.
- Used `NSScreen.displayLink` on macOS 15+ with a `CVDisplayLink` fallback on macOS 14 because the current SDK exposes `NSScreen.displayLink` as macOS 15+ despite the locked macOS 14 minimum.
