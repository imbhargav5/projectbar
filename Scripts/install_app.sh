#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="${PROJECTBAR_INSTALL_DIR:-${HOME}/Applications}"
DESTINATION_APP="$INSTALL_DIR/ProjectBar.app"

if [[ "$INSTALL_DIR" != /* ]]; then
  echo "PROJECTBAR_INSTALL_DIR must be an absolute path" >&2
  exit 1
fi
case "$DESTINATION_APP" in
  */Applications/ProjectBar.app) ;;
  *)
    echo "Refusing unexpected installation target: $DESTINATION_APP" >&2
    exit 1
    ;;
esac

"$ROOT_DIR/Scripts/package_app.sh" release
mkdir -p "$INSTALL_DIR"
pkill -x ProjectBar 2>/dev/null || true
rm -rf "$DESTINATION_APP"
ditto "$ROOT_DIR/ProjectBar.app" "$DESTINATION_APP"
codesign --verify --deep --strict "$DESTINATION_APP"
if [[ "${PROJECTBAR_ENABLE_LAUNCH_AT_LOGIN:-0}" == "1" ]]; then
  open -n "$DESTINATION_APP" --args --enable-launch-at-login
else
  open -n "$DESTINATION_APP"
fi

echo "Installed and launched $DESTINATION_APP"
