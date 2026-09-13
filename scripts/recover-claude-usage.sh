#!/bin/bash
set -euo pipefail

RECOVERY_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -n "${NOTCHBRIDGE_APP:-}" ]]; then
  RECOVERY_APPS=("$NOTCHBRIDGE_APP")
else
  RECOVERY_APPS=(
    "$RECOVERY_SCRIPT_DIR/../.."
    "$RECOVERY_SCRIPT_DIR/../build/NotchBridge.app"
    "/Applications/NotchBridge.app"
    "$HOME/Applications/NotchBridge.app"
  )
fi

for RECOVERY_APP in "${RECOVERY_APPS[@]}"; do
  if [[ -x "$RECOVERY_APP/Contents/MacOS/NotchBridge" && -f "$RECOVERY_APP/Contents/Resources/recover-claude-usage.sh" ]]; then
    exec "$RECOVERY_APP/Contents/MacOS/NotchBridge" --recover-claude "$@"
  fi
done

echo "Install a NotchBridge version with usage recovery, then run this script again." >&2
echo "For a custom app location, set NOTCHBRIDGE_APP to its .app path." >&2
exit 1
