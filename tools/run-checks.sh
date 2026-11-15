#!/usr/bin/env bash
set -euo pipefail
: "${GODOT:=godot}"
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
"$GODOT" --headless --path "$ROOT" --editor --import
"$GODOT" --headless --path "$ROOT" --script res://tests/run_tests.gd

"$GODOT" --headless --path "$ROOT" --script res://tests/core/run_core.gd
"$GODOT" --headless --path "$ROOT" --script res://tests/ui/smoke.gd
"$GODOT" --headless --path "$ROOT" --script res://tools/check_ui_run.gd
