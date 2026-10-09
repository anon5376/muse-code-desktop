# Scripts

Every script assumes macOS with the Swift toolchain; run from anywhere — each
resolves the repo root itself. Caches stay inside `.build/` via
`swift-local.sh`.

| Script | Purpose |
| --- | --- |
| `build-app.sh` | Compile and bundle `build/Muse Code.app`, ad-hoc signed |
| `test.sh` | Core + workspace test suites |
| `test-workspace.sh` | Workspace store tests only (ModelHost fixture) |
| `swift-local.sh` | `swift` wrapper keeping module/package caches in `.build/` |
| `package-dmg.sh` | Build a reproducible DMG + `.sha256` in `build/dist/` |
| `verify-dmg.sh` | Mount, install, launch-verify a DMG; checks missing-CLI path |
| `capture-demo.sh` | Drive the app against ReviewHost and capture window frames |
| `demo-drive.swift` | Input-driving helper used by `capture-demo.sh` |
| `stitch-frames.swift` | Turn captured frames into `demo.gif` / `demo.mp4` |
| `record-app.swift` | Window/screen capture helper |
| `ui-check.swift` | Headless UI regression checks used by CI |
| `GenerateIcon.swift` | Render the app-icon tile from the bundled logo |

## DMG pipeline

The release path is three ordered stages — run them top to bottom:

1. `build-app.sh` → `build/Muse Code.app` (release, ad-hoc signed)
2. `package-dmg.sh` → `build/dist/muse-code-desktop-<ver>-arm64.dmg` + `.sha256`
3. `verify-dmg.sh` → mounts the DMG, installs the app to a temp dir, and
   launch-checks it — including the no-CLI error path

CI runs the same order in `.github/workflows/build.yml`.
