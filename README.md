# Muse Code Desktop

A native macOS workspace for the installed Muse Code CLI. SwiftUI draws the interface; one supervised `muse serve` process runs the agent. There is no webview or extra runtime.

**Unofficial desktop client. This is not the official Muse Code desktop app and is not affiliated with or endorsed by Meta.**

## Run

Build the app locally, then open it:

```sh
bash scripts/build-app.sh
open "build/Muse Code.app"
```

Choose a project with **⌘O**, enter a prompt, and send with **⌘Return**. **⌘N** opens an unsaved draft; the first send creates its host session. **⌘K** opens the skills and commands palette over the conversation, **⌘⌥I** toggles the inspector, **⌘⌃S** toggles sessions, and **⌘,** opens settings. The app discovers Muse at `~/.local/bin/muse`, common Homebrew locations, or PATH. Settings can select another executable.

Use your existing Muse login and configuration. If sign-in is needed, run `muse login` in Terminal, then reconnect. Authentication remains in Muse; the app does not read credentials. Your configured approval and sandbox policy remains in force. Approval cards require an explicit choice.

Signal Desk uses neutral charcoal, Muse blue for focus and selection, and amber for pending requests and model data-use notices. Approvals and questions stay above the composer while browsing commands or inspecting files. Replies render native headings, lists, quotes, tables and code blocks with Copy controls.

## Models, skills, and tools

The searchable model picker reads Muse's real catalog, keeps provider/profile routes distinct, and resolves the configured default to its actual model. The composer names the model and profile, with an amber **Data use** badge when the host supplies a Contributor notice; the picker exposes the full notice. Reasoning choices come from advertised variants, including the default, and are retained per session. An explicit model must be accepted before submitting a turn; failed profile selection also blocks goal execution and forks.

Command-K, or `/` in an empty composer, opens skills and session commands. The inspector has **Files · Activity · Skills · Session** tabs. Skills offers search, source filtering, descriptions and **Use in chat**; choosing a skill inserts a removable attachment. Installed skills are checked against the session catalog before sending; trust and activation still apply. Goal and Activity also have direct title-band buttons.

| Surface | Desktop behavior |
| --- | --- |
| Agent tools | The host executes configured tools; transcript and Activity expose calls, output, and permission requests. The stable host has no `tool/list` method. |
| Session controls | Rename, fork, compact context, interrupt, and stop background tasks through MSP. |
| Shell | Explicit commands through Muse's negotiated `userShell` capability. |
| Goals | Set, pause, resume, or clear a goal using host controls. |
| Agents/workflows | Contextual controls on actual agent and workflow activity, including result retrieval. |
| Stored output | Fetch up to the first 256 KiB of referenced tool output. |
| Extensions | Inspect the installed plugin list. Open the full Muse CLI for plugin/MCP management, login, voice, and terminal-only commands. |

**Open Muse in Terminal** launches a separate terminal session in the chosen workspace. Full native parity with every terminal command is not claimed. There is no editable IDE or embedded terminal pane.

## Build and verify

Requires macOS 14 or later, Apple's Swift command-line tools, and an installed Muse CLI. This build was verified on macOS 26.4, Apple Silicon, Swift 6.3.1, and Muse 1.4.2. It has no third-party dependencies.

Quit the app before rebuilding its bundle.

```sh
bash scripts/build-app.sh
bash scripts/test.sh
bash scripts/swift-local.sh run MuseDiagnostics
```

The build script produces `build/Muse Code.app` and signs it locally with an ad-hoc signature. It is not notarized or signed for public distribution. `swift-local.sh` keeps compiler/package caches inside this project. Tests are standalone Swift executables because this Mac's command-line toolchain does not provide XCTest. They cover the production transport and store using actual isolated Muse echo sessions and local protocol fixtures.

Settings → **Test local connection** exercises the production transport against Muse's offline echo provider in a temporary, isolated session. It makes no model request and disables workspace tools. To inspect the entire UI in that mode:

```sh
open "build/Muse Code.app" --args --echo --workspace "$PWD"
```

Quit any running copy first when changing launch mode. The offline banner remains visible throughout the test. Muse's echo provider may report an unsupported reminder child task; that failure remains visible even when the main echo turn succeeds.

## Boundaries

- Faster model inference or tool execution has not been established. Native rendering, off-main-thread I/O, stable transcript identities, and batched updates target interface responsiveness. See [verification](docs/verification.md) for measured evidence.
- Transcript rows are measured eagerly to avoid a SwiftUI layout loop when resizing rich replies with a pending request. Long-session performance remains unmeasured.
- Real-provider turns, real tool approval/question flows, host action controls, durable recovery, and long-session performance require hands-on validation. Existing-session resume is implemented against the installed schema; the offline test cannot establish durable-history compatibility. See the [acceptance checklist](docs/acceptance.md).
- Session listing currently displays at most the first 100 entries returned by Muse. Search filters that loaded list.
- File scanning excludes hidden files, symlinks, and common generated directories, and stops at 2,000 entries / six directory levels. Previews are UTF-8 text, capped at 256 KiB. Inline tool output is bounded; stored-output retrieval shows its first 256 KiB. Patch retrieval is not implemented.
- Wire envelope version 1 is required. A schema fingerprint mismatch is shown as a warning. New Muse releases can require client updates.
- Reconnection never resubmits a prompt automatically. Check the session before retrying a timed-out submission.
- Failed startup retains only the latest 8 KiB of host stderr in memory, exposed through collapsed error Details. Diagnostic text is not logged to disk.
- Shutdown bounds the output drain and app termination wait. Whole-process-group cleanup of arbitrary tool descendants has not been established.
- Pending requests set a Dock badge and request app attention. System notifications and global approval/deny shortcuts are not implemented.

## Project files

`Sources/MuseCore` contains the JSON-RPC transport and transcript reducer. `Sources/MuseDesktop` contains the native app. `Sources/MuseDiagnostics` runs the isolated host check. [Design](DESIGN.md), [integration specification](docs/superpowers/specs/2026-10-08-muse-native-design.md), and [implementation plan](docs/superpowers/plans/2026-10-08-muse-native.md) record the scope and decisions.

## License and release status

The wrapper source is under the [MIT License](LICENSE). The separately installed Muse CLI is not included. Muse and its logo belong to Meta; the bundled logo and trademarks are not covered by this project's MIT license. See [logo provenance](docs/brand-assets.md).

The owner authorized source publication as `muse-code-desktop` on 2026-10-08. This remains a test candidate: hands-on acceptance and live-provider checks are open. Promotion requires separate approval.
