#!/bin/sh
set -eu
if command -v swiftformat >/dev/null 2>&1; then
  swiftformat .
else
  echo "swiftformat not installed; skipping"
fi
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint
else
  echo "swiftlint not installed; skipping"
fi
