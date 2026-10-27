#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"
case "$(godot --version)" in
    4.6.3.stable.*) ;;
    *) printf '%s\n' 'Este projeto requer Godot 4.6.3 estável.' >&2; exit 1 ;;
esac
python3 "$PROJECT_ROOT/tools/setup_android.py"
