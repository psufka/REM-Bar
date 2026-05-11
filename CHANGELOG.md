# Changelog

## Unreleased

### Build-time decisions

- Used SwiftPM target name `REMBar` with executable product name `REM-Bar` because Swift module names cannot reliably use hyphens.
- Implemented personal-access-token 401 retry as a serialized token re-read/re-validation gate. Oura PATs do not expose refresh tokens, so the retry mirrors the promise-lock shape without OAuth refresh.
- Added a test-only CommandLineTools `Testing.framework` search path when present because this machine's selected CLT SwiftPM does not auto-discover XCTest or Swift Testing, while `/Applications/Xcode.app` cannot be used until its license is accepted.
