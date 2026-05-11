#!/usr/bin/env bash
set -euo pipefail

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME="REM-Bar"
MCP_NAME="RemBarMCP"
BUNDLE_ID="com.psufka.REM-Bar"
VERSION_FILE="$ROOT/Sources/OuraKit/RemBarVersion.swift"
REM_BAR_VERSION=$(sed -nE 's/.*static let current = "([^"]+)".*/\1/p' "$VERSION_FILE" | head -n 1)
if [[ -z "$REM_BAR_VERSION" ]]; then
  echo "ERROR: Could not read REM-Bar version from $VERSION_FILE" >&2
  exit 1
fi
DIST="$ROOT/dist"
APP="$DIST/${APP_NAME}.app"
ZIP="$DIST/${APP_NAME}-v${REM_BAR_VERSION}.zip"
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

ARCH_LIST=( ${ARCHES:-} )
if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  ARCH_LIST=("$(uname -m)")
fi

move_to_trash() {
  local path="$1"
  [[ -e "$path" ]] || return 0

  local base
  local dest
  base=$(basename "$path")
  dest="$HOME/.Trash/${base}.$(date +%Y%m%d%H%M%S)"
  while [[ -e "$dest" ]]; do
    dest="${dest}.$$"
  done
  mv "$path" "$dest"
  echo "Moved existing $(basename "$path") to $dest"
}

resolve_binary_path() {
  local name="$1"
  local arch="$2"
  local candidates=(
    "$ROOT/.build/${arch}-apple-macosx/${CONF}/${name}"
    "$ROOT/.build/${CONF}/${name}"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

install_binary() {
  local name="$1"
  local destination="$2"
  local binaries=()

  for arch in "${ARCH_LIST[@]}"; do
    local binary
    binary=$(resolve_binary_path "$name" "$arch") || {
      echo "ERROR: Missing ${name} build for ${arch}." >&2
      exit 1
    }
    binaries+=("$binary")
  done

  if [[ ${#binaries[@]} -gt 1 ]]; then
    lipo -create "${binaries[@]}" -output "$destination"
  else
    cp "${binaries[0]}" "$destination"
  fi
  chmod +x "$destination"
}

for arch in "${ARCH_LIST[@]}"; do
  swift build -c "$CONF" --arch "$arch"
done

mkdir -p "$DIST"
move_to_trash "$APP"
move_to_trash "$ZIP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${REM_BAR_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 Paul Sufka. MIT License.</string>
    <key>REMBarBuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>REMBarGitCommit</key><string>${GIT_COMMIT}</string>
</dict>
</plist>
PLIST

install_binary "$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
install_binary "$MCP_NAME" "$APP/Contents/MacOS/$MCP_NAME"

if [[ -f "$ROOT/Icon.icns" ]]; then
  cp "$ROOT/Icon.icns" "$APP/Contents/Resources/Icon.icns"
elif [[ -f "$ROOT/Sources/REM-Bar/Resources/Icon.icns" ]]; then
  cp "$ROOT/Sources/REM-Bar/Resources/Icon.icns" "$APP/Contents/Resources/Icon.icns"
else
  echo "ERROR: Missing Icon.icns." >&2
  exit 1
fi

BUILD_DIR=$(dirname "$(resolve_binary_path "$APP_NAME" "${ARCH_LIST[0]}")")
RESOURCE_BUNDLE="$BUILD_DIR/REM-Bar_REMBar.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
else
  echo "ERROR: Missing SwiftPM resource bundle: $RESOURCE_BUNDLE" >&2
  exit 1
fi

plutil -lint "$APP/Contents/Info.plist" >/dev/null
xattr -cr "$APP"
find "$APP" -name '._*' -delete
codesign --force --sign - "$APP/Contents/MacOS/$MCP_NAME" >/dev/null
codesign --force --sign - "$APP" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP" >/dev/null

(
  cd "$DIST"
  ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "$(basename "$ZIP")"
)

echo "Created $APP"
echo "Created $ZIP"
