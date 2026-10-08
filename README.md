<p align="center">
  <img src="Sources/MuseDesktop/Resources/MuseLogo.svg" width="56" alt="Muse logo">
</p>
<h1 align="center">Muse Code Desktop</h1>
<p align="center">A native macOS workspace for the installed Muse Code CLI.<br>
SwiftUI draws the interface; one supervised <code>muse serve</code> process runs the agent. No webview, no extra runtime, no third-party dependencies.</p>

> **Unofficial desktop client — not affiliated with or endorsed by Meta.**
> This is not the official Muse Code desktop app. Muse and its logo belong to Meta and are not covered by this project's MIT license.

<p align="center">
  <a href="https://github.com/anon5376/muse-code-desktop/releases/download/v0.1.0/muse-code-desktop-0.1.0-arm64.dmg"><strong>Download v0.1.0 (Apple Silicon)</strong></a> ·
  <a href="https://github.com/anon5376/muse-code-desktop/releases/tag/v0.1.0">Release notes + checksum</a>
</p>

<p align="center">
  <img src="docs/media/workspace.png" width="880" alt="Muse Code workspace showing the session sidebar, transcript, and composer">
</p>

## Demo

Real pixels, no staging: every capture shows the app driving its offline fixture host (`--echo` + `ReviewHost`), with the fixture banner left in frame on purpose. No provider, model, or tool ran during capture.

<p align="center">
  <a href="docs/media/demo.mp4"><img src="docs/media/demo.gif" width="880" alt="Short demo: markdown reply, approval card, palette, inspector, and compact resize"></a><br>
  <sub><a href="docs/media/demo.mp4">Watch the MP4</a> — same beats, smoother</sub>
</p>

| | |
| --- | --- |
| ![Markdown transcript](docs/media/markdown.png) | ![Pending approval card](docs/media/approval.png) |
| ![Question card](docs/media/question.png) | ![File inspector](docs/media/inspector.png) |
| ![Command-K palette](docs/media/palette.png) | ![Model picker](docs/media/model-picker.png) |

## Requirements

- macOS 14 or later, Apple Silicon (arm64 build; no Intel/universal artifact yet)
- A working [Muse Code CLI](https://muse.ai/) installation, already logged in

The app discovers Muse at `~/.local/bin/muse`, common Homebrew locations, or `PATH`. Settings can select another executable. Authentication stays in the CLI — the app never reads credentials — so if sign-in is needed, run `muse login` in Terminal, then reconnect.

## Install

1. Download the DMG and verify it:

   ```sh
   shasum -a 256 muse-code-desktop-0.1.0-arm64.dmg
   # compare with the checksum file on the release page
   ```

2. Open the image and drag **Muse Code** into **Applications**.
3. First launch: this build is **ad-hoc signed and not notarized**. Right-click the app and choose **Open**, or allow it under System Settings → Privacy & Security. If Finder reports the app as damaged, run `xattr -dr com.apple.quarantine "/Applications/Muse Code.app"` once.

## First run

Choose a project with **⌘O**, type a prompt, send with **⌘Return**. **⌘N** opens an unsaved draft — the first send creates its host session.

| Keys | Action |
| --- | --- |
| ⌘Return | Send message |
| ⌘N | New session (unsaved draft) |
| ⌘O | Choose workspace |
| ⌘K | Skills & commands palette (or `/` in an empty composer) |
| ⌘⌥I | Toggle inspector (Files · Activity · Skills · Session) |
| ⌘⌃S | Toggle session sidebar |
| ⌘, | Settings |
| ⌘. | Stop the current turn |

## What it does

- **Transcript-first workspace.** Native Markdown rendering (headings, lists, quotes, tables, selectable code blocks), session sidebar with search, running/attention states, and a composer that grows with your draft.
- **Real model routing.** The picker reads Muse's actual catalog — provider/profile routes stay distinct, the configured default resolves to its real model, reasoning choices come from advertised variants, and the host's Contributor notice surfaces as an amber **Data use** badge. An explicit route must be accepted before a turn ships; a rejected profile blocks sends, forks, and goals.
- **Explicit permission posture.** Approvals and questions stay above the composer while you browse; a request is never auto-decided — presentation receipts acknowledge, only your choice answers. Your configured approval and sandbox policy stays in force.
- **Skills & palette.** Command-K lists session-catalog skills and commands; picking one attaches a removable chip. Unavailable skills are rejected before sending instead of being submitted as literal text.
- **Inspection without an IDE.** Files, Activity, Skills, and Session tabs give read-only previews and host controls (rename, fork, compact, goal set/pause/resume, stop). **Open Muse in Terminal** covers plugin/MCP management, login, voice, and other CLI-only commands.

## Architecture

```
Muse Code.app (SwiftUI/AppKit, macOS 14+, zero deps)
  ├─ Sources/MuseCore      newline-delimited JSON-RPC transport, transcript reducer,
  │                        bounded stderr tail, request-receipt contract, wire v1
  ├─ Sources/MuseDesktop   window, sidebar, transcript, cards, palette, inspector
  └─ Sources/MuseDiagnostics   isolated host check
        │
        └─ supervises:  muse serve   (installed separately; owns auth,
                                     agent execution, tools, durable sessions)
```

Tests are standalone Swift executables rather than XCTest: `Tests/MuseCoreTests` covers transport/protocol behavior against real child processes, `Tests/MuseDesktopTests` drives the production store against the synthetic `ReviewHost`/`ModelHost` fixtures — which never touch a provider or run tools. The ReviewHost is also what powers the demo media and the offline UI fixture.

## Build and verify

```sh
bash scripts/build-app.sh      # build/Muse Code.app, ad-hoc signed
bash scripts/test.sh           # core + workspace suites
bash scripts/package-dmg.sh    # build/dist/muse-code-desktop-*-<arch>.dmg + .sha256
bash scripts/verify-dmg.sh     # mount/install/copied-launch + missing-CLI checks
```

`scripts/swift-local.sh` keeps compiler and package caches inside the project. Quit the app before rebuilding its bundle. CI ([`build.yml`](.github/workflows/build.yml)) runs the same commands on a clean `macos-15` runner; the release workflow ([`release.yml`](.github/workflows/release.yml)) rebuilds, retests, repackages and publishes on each `v*` tag. The demo media is regenerated by [`demo-media.yml`](.github/workflows/demo-media.yml) via [`scripts/capture-demo.sh`](scripts/capture-demo.sh).

To inspect the whole UI offline against the real `muse` echo provider (no model calls, workspace tools disabled):

```sh
open "build/Muse Code.app" --args --echo --workspace "$PWD"
```

## Known limitations

- Ad-hoc signature, no Developer ID, not notarized — the Gatekeeper step above is required.
- Live-provider turns, real tool grants, durable history restore, and long-session stress are not covered by the fixture checks. The transcript's eager row layout trades measurement work for correctness under resize. See [acceptance](docs/acceptance.md).
- Session listing shows the first 100 entries; file scanning skips hidden files/symlinks and caps at 2,000 entries / 256 KiB previews; stored-output reads cap at 256 KiB; patch retrieval is not implemented.
- Wire envelope version 1 is required; a schema fingerprint mismatch is shown as a warning, and new Muse releases can require client updates.
- Reconnection never resubmits a prompt automatically — check the session before retrying a timed-out send.

## Design

[Signal Desk](DESIGN.md): neutral charcoal surfaces with one-point hairlines, Muse blue for selection and focus, amber for pending requests and data-use notices. The bundled logo is the unchanged SVG from Muse's public website — [provenance and license boundary](docs/brand-assets.md). Review evidence: [verification](docs/verification.md).

## License

The wrapper source is under the [MIT License](LICENSE). The Muse CLI is a separate installed product and is not included. Muse and its logo belong to Meta; the bundled logo and trademarks are **not** covered by the MIT license.
