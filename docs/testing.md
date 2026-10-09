# Testing

The repo has no XCTest target. Tests are standalone Swift executables compiled
directly — fast, dependency-free, and identical between local Macs and CI.

## What runs where

| Suite | Entry point | Fixture | Runs on |
| --- | --- | --- | --- |
| Core tests | `Tests/MuseCoreTests/CoreTests.swift` | `MuseReviewHost` (synthetic JSON-RPC host) | `bash scripts/test.sh` |
| Workspace store | `Tests/MuseDesktopTests/StoreTests.swift` | `MuseModelHost` | `bash scripts/test-workspace.sh` |

`scripts/test.sh` builds `MuseCoreTests` via SwiftPM, compiles `ReviewHost.swift`
into `.build/debug/MuseReviewHost`, then runs both suites. `swift-local.sh`
keeps compiler caches inside `.build/`.

## Conventions

- Tests are functions registered in the `tests:` array — every new `testX`
  must be added there or it never runs.
- `equal()` and `throwsError()` helpers live in `CoreTests.swift`; each test
  prints `PASS`/`FAIL` and the runner counts failures.
- Store tests are `@MainActor` async and use `waitUntil { ... }` (10s deadline,
  10ms poll) instead of fixed sleeps — `SessionState` is a `final class`, so a
  captured reference sees live updates. Fixed `Task.sleep` polling was the
  source of a real flake (see the 200ms `asyncAfter` in `ModelHost.swift`).
- Echo/round-trip checks that need a real `muse serve` binary `SKIP` cleanly
  when none is installed (CI runners do not have it).

## CI mapping

`.github/workflows/build.yml` runs `scripts/test.sh` on `macos-15` between the
release build and DMG packaging — the same commands listed above.
