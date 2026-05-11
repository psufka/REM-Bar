# REM-Bar

![REM-Bar screenshot placeholder](docs/screenshot-placeholder.svg)

REM-Bar is a native macOS menu-bar app for Oura Ring sleep, readiness, activity, recovery, SpO2, VO2 max, and bedtime guidance data.

## Install

Download `REM-Bar-v0.1.0.zip`, unzip it, move `REM-Bar.app` to `/Applications`, then run:

```sh
xattr -dr com.apple.quarantine /Applications/REM-Bar.app
```

## How It Works

REM-Bar stores your Oura Personal Access Token in the macOS Keychain and can discover `OURA_TOKEN` from ambient sources.
The menu-bar item refreshes Oura API v2 on the cadence you choose.
The popover shows the Oura metric cards you enable, in the order you choose.
The bundled MCP server exposes 18 read-only Oura endpoint tools to Claude Code.

## MCP

```sh
claude mcp add rem-bar /Applications/REM-Bar.app/Contents/MacOS/RemBarMCP
```
