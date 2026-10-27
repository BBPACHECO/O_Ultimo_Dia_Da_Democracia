#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"
cd "$PROJECT_ROOT"
mkdir -p builds
godot --headless --path "$PROJECT_ROOT" --import
godot --headless --path "$PROJECT_ROOT" --export-debug Android builds/o-ultimo-dia-debug.apk
"$ANDROID_HOME/build-tools/35.0.1/apksigner" verify --verbose builds/o-ultimo-dia-debug.apk
python3 tools/verify_apk.py builds/o-ultimo-dia-debug.apk
