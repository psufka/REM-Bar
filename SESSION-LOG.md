# REM-Bar Session Log

## Built

- SwiftPM workspace with three products: `REM-Bar`, `OuraKit`, and `RemBarMCP`.
- Native macOS menu-bar app with configurable Oura metric, SF Symbol status item, Keychain token settings, display-link refresh pause behavior, and a SwiftUI popover with five Oura metric cards, seven-day sparklines, and deltas vs seven-day average.
- Shared `OuraKit` library with Oura API v2 endpoints for personal info, daily sleep, sleep detail, daily readiness, and daily activity.
- Keychain token storage using service `com.psufka.REM-Bar` and `kSecAttrAccessibleAfterFirstUnlock`.
- Serialized 401 retry gate for token re-resolution.
- Bundled `RemBarMCP` executable with a self-contained stdio JSON-RPC server and five read-only Oura tools.
- Offline tests with Oura fixtures and URLProtocol stubs.
- README, MIT LICENSE with CodexBar attribution, CHANGELOG, CI workflow, root icon, screenshot placeholder, scripts, and git history checkpoints.

## Build-Time Defaults

- SwiftPM module target is `REMBar`; executable product remains `REM-Bar` because Swift module names should not use hyphens.
- Personal Access Token retry re-reads/re-validates the configured token once instead of OAuth refresh because v1 is PAT-only.
- `OURA_TOKEN` overrides Keychain/config for development; Keychain remains the app/MCP shared default; `~/.oura-mcp/config.json` is a compatibility fallback.
- macOS 14 refresh pause uses `CVDisplayLink`; `NSScreen.displayLink` is used on macOS 15+ because the current SDK marks it macOS 15+.
- Test targets add a CommandLineTools `Testing.framework` search path when needed because this machine's selected CLT SwiftPM does not auto-discover XCTest or Swift Testing, and Xcode.app is blocked by unaccepted license terms.

## Left For Paul

- Paste a real Oura Personal Access Token in Settings.
- Create the GitHub repo and push when ready.
- Build the first release zip from the SwiftPM products.
- Codesign, notarize, DMG packaging, launch-at-login, and auto-update remain v1.1 work.
