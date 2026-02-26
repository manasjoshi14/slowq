#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SlowQ"
BUNDLE_ID="io.github.manas.SlowQ"
TARGET_APP="/Applications/${APP_NAME}.app"

osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
rm -rf "$TARGET_APP"

tccutil reset All "$BUNDLE_ID" >/dev/null 2>&1 || true

"$ROOT_DIR/scripts/install-local.sh"

echo
echo "Fresh reinstall complete."
echo "Open SlowQ Settings, click Request Permission, and enable SlowQ in Input Monitoring."
