#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
export CLANG_MODULE_CACHE_PATH="$project_root/.build/ModuleCache"
bash scripts/swift-local.sh build --product MuseCoreTests
/usr/bin/swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" Tests/MuseDesktopTests/ModelHost.swift -o .build/debug/MuseModelHost
/usr/bin/swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" -I .build/debug/Modules \
  Sources/MuseDesktop/WorkspaceStore.swift Sources/MuseDesktop/FileBrowser.swift Sources/MuseDesktop/CLICatalog.swift \
  Tests/MuseDesktopTests/StoreTests.swift .build/debug/MuseCore.build/*.o \
  -o .build/debug/MuseWorkspaceTests
.build/debug/MuseWorkspaceTests --echo --model-host "$project_root/.build/debug/MuseModelHost"
