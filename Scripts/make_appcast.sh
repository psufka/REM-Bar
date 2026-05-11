#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

VERSION_FILE="$ROOT/Sources/OuraKit/RemBarVersion.swift"
VERSION=$(sed -nE 's/.*static let current = "([^"]+)".*/\1/p' "$VERSION_FILE" | head -n 1)
FEED_URL=$(sed -nE 's/.*static let sparkleFeedURL = "([^"]+)".*/\1/p' "$VERSION_FILE" | head -n 1)
ZIP=${1:-"$ROOT/dist/REM-Bar-v${VERSION}.zip"}
PRIVATE_KEY_FILE=${SPARKLE_PRIVATE_KEY_FILE:-"$HOME/.rem-bar/sparkle-ed25519-private-key.txt"}
GENERATE_APPCAST=${GENERATE_APPCAST:-"$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"}

if [[ -z "$VERSION" || -z "$FEED_URL" ]]; then
  echo "ERROR: Could not read Sparkle version/feed config from $VERSION_FILE" >&2
  exit 1
fi
if [[ ! -f "$ZIP" ]]; then
  echo "ERROR: Zip not found: $ZIP" >&2
  exit 1
fi
if [[ ! -f "$PRIVATE_KEY_FILE" ]]; then
  echo "ERROR: Sparkle private key not found: $PRIVATE_KEY_FILE" >&2
  echo "Set SPARKLE_PRIVATE_KEY_FILE or create the REM-Bar Sparkle key." >&2
  exit 1
fi
if [[ ! -x "$GENERATE_APPCAST" ]]; then
  echo "ERROR: generate_appcast not found. Run swift build first." >&2
  exit 1
fi

WORK_DIR=$(mktemp -d /tmp/rembar-appcast.XXXXXX)
ZIP_NAME=$(basename "$ZIP")
ZIP_BASE="${ZIP_NAME%.zip}"
NOTES_HTML="$WORK_DIR/${ZIP_BASE}.html"
DOWNLOAD_URL_PREFIX=${SPARKLE_DOWNLOAD_URL_PREFIX:-"https://github.com/psufka/REM-Bar/releases/download/v${VERSION}/"}

cp "$ROOT/appcast.xml" "$WORK_DIR/appcast.xml"
cp "$ZIP" "$WORK_DIR/$ZIP_NAME"
cat > "$NOTES_HTML" <<HTML
<h2>REM-Bar ${VERSION}</h2>
<p>See the REM-Bar GitHub release notes for this version.</p>
<p><a href="https://github.com/psufka/REM-Bar/releases/tag/v${VERSION}">View release notes</a></p>
HTML

"$GENERATE_APPCAST" \
  --ed-key-file "$PRIVATE_KEY_FILE" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --embed-release-notes \
  --maximum-versions 1 \
  --link "$FEED_URL" \
  "$WORK_DIR"

cp "$WORK_DIR/appcast.xml" "$ROOT/appcast.xml"

echo "Generated $ROOT/appcast.xml"
echo "Sparkle work directory left at $WORK_DIR"
