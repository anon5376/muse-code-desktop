# Architecture

Two layers, one dependency edge. Nothing reaches a model provider from this
repository — the app supervises `muse serve`, and the CLI owns providers,
tools, and policy.

```text
SwiftUI / AppKit shell                  Muse Code.app  (Sources/MuseDesktop)
        │  owns a WorkspaceStore per workspace
        ▼
JSON-RPC line protocol + transcript    MuseCore       (Sources/MuseCore)
        │  spawns and frames
        ▼
muse serve                             installed CLI (separate distribution)
```

## Sources/MuseCore — the wire layer

Pure Swift, no AppKit. Everything here is testable against fixtures.

| File | Responsibility |
| --- | --- |
| `Wire.swift` | `JSONValue` (total accessors), `LineFramer` (8 MiB frames), `CommandID` |
| `Requests.swift` | `SessionHistory` decode, `UserInputAnswer` contract, `ApprovalDescription`, `ActivityStatus` labels |
| `Transcript.swift` | `Transcript` upsert/delta folding — replay-resistant, final revisions win |
| `MarkdownBlocks.swift` | Structural markdown splitter for transcript rendering |
| `MuseConnection.swift` | Subprocess spawn, stdio framing, handshake, request/event dispatch |
| `EchoDiagnostic.swift` | Offline round-trip check used by the app and `MuseDiagnostics` |

## Sources/MuseDesktop — the shell

| Area | Files |
| --- | --- |
| State | `WorkspaceStore.swift` (session lifecycle, pending requests, drafts) |
| Chrome | `WorkspaceView.swift`, `Theme.swift`, `SettingsView.swift` |
| Content | `TranscriptView.swift`, `LibraryView.swift`, `ModelPicker.swift` |
| Catalog | `CLICatalog.swift`, `FileBrowser.swift` |

`Sources/MuseDiagnostics` is a tiny CLI wrapping `EchoDiagnostic` for
terminal-side checks (`swift run MuseDiagnostics`).

## Tests

Standalone executables, not XCTest — see [testing.md](testing.md).
`Tests/MuseCoreTests` covers the wire layer plus an integration tail on the
synthetic `ReviewHost`; `Tests/MuseDesktopTests` drives `WorkspaceStore`
against `ModelHost`.
