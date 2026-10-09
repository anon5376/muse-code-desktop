#!/bin/bash
# Runs only the workspace store tests against the ModelHost fixture.
# Usage: bash scripts/test-workspace.sh
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
export CLANG_MODULE_CACHE_PATH="$project_root/.build/ModuleCache"
bash scripts/swift-local.sh build --product MuseCoreTests
/usr/bin/swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" Tests/MuseDesktopTests/ModelHost.swift -o .build/debug/MuseModelHost
# The store test compiles an explicit source list rather than a SwiftPM
# target (the app target would pull AppKit/SwiftUI into a CLI test). New
# dependencies of WorkspaceStore must be added here or linking fails.
/usr/bin/swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" -I .build/debug/Modules \
  Sources/MuseDesktop/WorkspaceStore.swift Sources/MuseDesktop/FileBrowser.swift Sources/MuseDesktop/CLICatalog.swift \
  Tests/MuseDesktopTests/StoreTests.swift .build/debug/MuseCore.build/*.o \
  -o .build/debug/MuseWorkspaceTests
.build/debug/MuseWorkspaceTests --echo --model-host "$project_root/.build/debug/MuseModelHost"
