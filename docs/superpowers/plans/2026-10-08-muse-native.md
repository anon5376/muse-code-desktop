# Muse Code Native Implementation Plan

> **For agentic workers:** Execute natively in this session with focused behavioral tests and one independent final review.

**Goal:** Build and run a native Swift macOS shell around the installed Muse Code CLI.

**Architecture:** One supervised `muse serve` process, a serial JSON-RPC transport, per-session event folding, and a SwiftUI workspace. AppKit supplies file picking and read-only code inspection.

**Tech Stack:** Swift 6 toolchain, macOS 14 minimum, Foundation, SwiftUI, AppKit, standalone Swift test executables; no third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-10-08-muse-native-design.md`.

## Global Constraints

- Preserve the host's configured approval and sandbox policy.
- Never access credential contents or automatically retry uncertain turn submissions.
- Keep offline diagnostics isolated from real sessions and providers.
- Build a local `.app` with the command-line toolchain; no Xcode installation or package download.
- Scope is sessions, chat, tools, approval/question responses, and read-only file inspection.

## Review Focus

Split UTF-8 frames; authoritative revisions following deltas; host death with pending requests; session-switch races; retained approvals and questions after resume.

## Task 1 — Protocol and transcript core

Files: `Package.swift`, `Sources/MuseCore/Wire.swift`, `Sources/MuseCore/Transcript.swift`, `Tests/MuseCoreTests/CoreTests.swift`.

Interfaces: a Codable JSON value, an incremental line framer, UUIDv7 generation, and a transcript reducer accepting JSON-RPC notification frames.

- [x] Write focused failing tests for fragmented UTF-8, frame bounds, and final-item replacement after deltas.
- [x] Implement the smallest core that makes those behavioral checks pass.
- [x] Run `bash scripts/test.sh`; standalone executables replace XCTest because it is unavailable in this command-line toolchain.

## Task 2 — Real Muse process integration

Files: `Sources/MuseCore/MuseConnection.swift`, `Sources/MuseDiagnostics/main.swift`, integration test in `Tests/MuseCoreTests`.

Interfaces: `MuseConnection.start`, async `request`, `notify`, and `stop`; batched event callback; isolated diagnostic executable.

- [x] Exercise the missing integration through an actual echo host; never mock successful host replies.
- [x] Implement process lifecycle, request correlation/timeouts, framed I/O, and safe exit.
- [x] Verify handshake, session start, streamed response, completed terminal, and clean shutdown.

## Task 3 — Native workspace

Files: `Sources/MuseDesktop/MuseDesktopApp.swift`, `WorkspaceStore.swift`, `WorkspaceView.swift`, `TranscriptView.swift`, `InspectorView.swift`, `Theme.swift`.

Interfaces: an observable main-actor store consuming batched connection events, and native SwiftUI views using that store.

- [x] Implement folder/session selection, model selection, streaming transcript, stop, explicit approvals/questions, and bounded file previews.
- [x] Build and launch in offline mode, then inspect the actual UI at normal and minimum window widths.
- [x] Verify folder selection, session start, send, and inspector behavior through the running app.

## Task 4 — Local delivery and review

Files: `scripts/build-app.sh`, `scripts/GenerateIcon.swift`, `README.md`, `DESIGN.md`, and a verification report.

- [x] Package `build/Muse Code.app` with icon and Info.plist.
- [x] Run the test suite, actual-CLI diagnostic, and release build.
- [x] Get one independent code/UI review and fix material findings.
- [x] Record actual output, footprint, limitations, and the launch command.

## Execution notes

The workspace was empty and is not a Git repository, so no worktree, branch, commit, or push is part of this build. UI decisions are delegated by the user's request; the optional scope question remained available while integration research proceeded. No dependencies will be added.

The final local release is packaged and opened with normal Muse configuration. Core tests returned 9/9, three real-host workspace lifecycle checks passed, and the independent verdict pass scored all four material fixes resolved. The design documenter extracted actual native tokens into DESIGN.md and .impeccable/design.json. Runtime limits are explicit in docs/verification.md; no full production-flow or performance-superiority claim is made.
