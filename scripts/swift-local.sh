#!/bin/bash
# Wraps `swift` so compiler/package caches stay inside .build/ — keeps the
# project self-contained and CI cache-friendly.
# Usage: bash scripts/swift-local.sh [swift-subcommand] [args...]
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
export CLANG_MODULE_CACHE_PATH="$project_root/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift_command="${1:-build}"
if [[ $# -gt 0 ]]; then shift; fi
exec /usr/bin/swift "$swift_command" --disable-sandbox \
  --cache-path "$project_root/.build/cache" \
  --config-path "$project_root/.build/config" \
  --security-path "$project_root/.build/security" "$@"
