#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
bash "$project_root/scripts/swift-local.sh" build --product MuseCoreTests
/usr/bin/swiftc -module-cache-path "$project_root/.build/ModuleCache" "$project_root/Tests/MuseDesktopTests/ReviewHost.swift" -o "$project_root/.build/debug/MuseReviewHost"
"$project_root/.build/debug/MuseCoreTests" --review-host "$project_root/.build/debug/MuseReviewHost"
bash "$project_root/scripts/test-workspace.sh"
