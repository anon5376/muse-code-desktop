# Contributing

Small, focused PRs only — one improvement per change.

## Reporting bugs

Use the bug-report issue template and include the macOS version, the Muse CLI
version (`muse --version`), and which fixture or real session showed the
problem. Security issues go through private advisories (see SECURITY.md),
never a public issue.

## Setup

- macOS 14+, Apple Silicon
- Swift toolchain from Xcode or Command Line Tools (`swift --version`)
- No third-party dependencies; do not add any without asking first

## Commits and PRs

- Imperative subjects under ~72 characters ("Test …", "Add …", "Document …").
- PRs merge by squash, so the PR title becomes the permanent history entry —
  write it accordingly.
- One improvement per PR; leave unrelated files alone.

## Build and test

```sh
bash scripts/build-app.sh      # release app bundle in build/
bash scripts/test.sh           # core + workspace suites
bash scripts/package-dmg.sh    # reproducible DMG + .sha256
bash scripts/verify-dmg.sh     # mount/install/launch checks
```

Tests are standalone Swift executables (not XCTest) — conventions and CI
mapping live in [docs/testing.md](docs/testing.md). Workspace tests run the
production store against synthetic fixtures (`ReviewHost`, `ModelHost`) — they
never touch a provider, model, or real tools. Keep it that way.

## Conventions

- SwiftUI/AppKit, system typography, SF Symbols — follow [DESIGN.md](DESIGN.md)
  (Signal Desk: flat charcoal, Muse blue accent, amber for pending requests)
- Don't invent host state, model metadata, or permission grants in the UI
- Scripts are `bash` with `set -euo pipefail`; keep caches inside `.build/`
- Run `bash scripts/test.sh` before pushing; CI runs the same on `macos-15`
  (workflow map: [docs/ci.md](docs/ci.md))

## Honest claims

README, docs, and release notes only state what was actually verified. If you
didn't run it, say so.
