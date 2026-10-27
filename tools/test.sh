#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"
cd "$PROJECT_ROOT"
godot --headless --path "$PROJECT_ROOT" --import
godot --headless --path "$PROJECT_ROOT" --script res://tests/test_3d.gd
