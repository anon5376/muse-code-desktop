#!/bin/bash
# CI test entry point. Runs the full suite when a muse executable is
# installed; otherwise runs only the core suite (which itself prints SKIP for
# the real Muse echo round trip) and emits a visible CI warning plus a step
# summary line, so a green run never silently stands in for the Muse-backed
# checks. Local full-suite verification before a release is documented in
# docs/packaging.md.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
export PATH="$HOME/.local/bin:$PATH"

note_skipped() {
  echo "::warning::Muse CLI not installed - running core tests only. The real echo round trip and the 19 workspace checks are SKIPPED, not passed."
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf -- '- **Muse-dependent tests skipped**: real Muse echo round trip and workspace checks did not run (no `muse` executable on this runner).\n' >> "$GITHUB_STEP_SUMMARY"
  fi
}

if command -v muse >/dev/null 2>&1; then
  echo "Muse CLI detected: $(muse --version 2>&1 | head -1). Running the full test suite."
  bash scripts/test.sh
else
  note_skipped
  bash scripts/swift-local.sh build --product MuseCoreTests
  /usr/bin/swiftc -module-cache-path "$project_root/.build/ModuleCache" \
    "$project_root/Tests/MuseDesktopTests/ReviewHost.swift" -o "$project_root/.build/debug/MuseReviewHost"
  "$project_root/.build/debug/MuseCoreTests" --review-host "$project_root/.build/debug/MuseReviewHost"
  echo "Core suite finished; Muse-dependent checks were skipped (see warning above)."
fi
