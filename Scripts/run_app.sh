#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT_DIR/Scripts/package_app.sh" debug
pkill -x ProjectBar 2>/dev/null || true
open -n "$ROOT_DIR/ProjectBar.app"
