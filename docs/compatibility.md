# Compatibility

## Platform

- macOS 14 (Sonoma) or later — `Package.swift` declares `.macOS(.v14)` and the
  app uses AppKit APIs unavailable earlier.
- Apple Silicon (`arm64`) only. The packaged DMG is a single-arch build;
  Intel is not shipped or tested.

## Muse CLI

- Requires a separately installed `muse` on `PATH` (or a path in Settings).
- Tested against Muse Code 1.4.2's `serve` JSON-RPC — the embedded stable
  schema was exported and driven end to end (see
  [docs/verification.md](verification.md)).
- The app advertises `userInputDialogs` at handshake; older hosts that never
  send `userInput/request` still work — those cards simply never appear.

## Toolchain

- Swift toolchain from Xcode 15+ or Command Line Tools (`swift --version`),
  `swift-tools-version: 6.0`, language mode Swift 5.
- No third-party dependencies — SwiftPM resolves zero packages.
- CI pins `macos-15` for build/test/package.
