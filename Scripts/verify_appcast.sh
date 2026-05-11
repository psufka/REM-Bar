#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

VERSION_FILE="$ROOT/Sources/OuraKit/RemBarVersion.swift"
VERSION=${1:-$(sed -nE 's/.*static let current = "([^"]+)".*/\1/p' "$VERSION_FILE" | head -n 1)}
APPCAST="$ROOT/appcast.xml"
PRIVATE_KEY_FILE=${SPARKLE_PRIVATE_KEY_FILE:-"$HOME/.rem-bar/sparkle-ed25519-private-key.txt"}
SIGN_UPDATE=${SIGN_UPDATE:-"$ROOT/.build/artifacts/sparkle/Sparkle/bin/sign_update"}

if [[ ! -f "$APPCAST" ]]; then
  echo "ERROR: appcast.xml not found." >&2
  exit 1
fi
if [[ ! -f "$PRIVATE_KEY_FILE" ]]; then
  echo "ERROR: Sparkle private key not found: $PRIVATE_KEY_FILE" >&2
  exit 1
fi
if [[ ! -x "$SIGN_UPDATE" ]]; then
  echo "ERROR: sign_update not found. Run swift build first." >&2
  exit 1
fi

TMP_ZIP=$(mktemp /tmp/rembar-appcast-enclosure.XXXXXX.zip)
TMP_META=$(mktemp /tmp/rembar-appcast-meta.XXXXXX)
trap 'rm -f "$TMP_ZIP" "$TMP_META"' EXIT

python3 - "$APPCAST" "$VERSION" >"$TMP_META" <<'PY'
import sys
import xml.etree.ElementTree as ET

appcast, version = sys.argv[1], sys.argv[2]
tree = ET.parse(appcast)
root = tree.getroot()
ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}

for item in root.findall("./channel/item"):
    short_version = item.findtext("sparkle:shortVersionString", default="", namespaces=ns)
    if short_version != version:
        continue
    enclosure = item.find("enclosure")
    print(enclosure.get("url"))
    print(enclosure.get("{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature"))
    print(enclosure.get("length"))
    break
else:
    raise SystemExit(f"No appcast entry found for version {version}")
PY

readarray -t META <"$TMP_META"
URL="${META[0]}"
SIGNATURE="${META[1]}"
EXPECTED_LENGTH="${META[2]}"

curl -L -o "$TMP_ZIP" "$URL"
ACTUAL_LENGTH=$(stat -f%z "$TMP_ZIP")
if [[ "$ACTUAL_LENGTH" != "$EXPECTED_LENGTH" ]]; then
  echo "ERROR: Length mismatch: expected $EXPECTED_LENGTH, got $ACTUAL_LENGTH" >&2
  exit 1
fi

"$SIGN_UPDATE" --verify "$TMP_ZIP" "$SIGNATURE" --ed-key-file "$PRIVATE_KEY_FILE"
echo "Appcast entry for $VERSION verified."
