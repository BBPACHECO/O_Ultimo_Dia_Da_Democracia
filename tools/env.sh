#!/usr/bin/env bash
# Carregue com: source tools/env.sh
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export GAME_TOOL_ROOT="${GAME_TOOL_ROOT:-/workspace/.tools/democracia}"
export XDG_CONFIG_HOME="$GAME_TOOL_ROOT/config"
export XDG_DATA_HOME="$GAME_TOOL_ROOT/share"
export XDG_CACHE_HOME="$GAME_TOOL_ROOT/cache"
export ANDROID_HOME="$GAME_TOOL_ROOT/android-sdk"
if [[ -z "${JAVA_HOME:-}" ]]; then
    JAVA_HOME="$(dirname -- "$(dirname -- "$(readlink -f -- "$(command -v java)")")")"
    export JAVA_HOME
fi
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/35.0.1:$PATH"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
