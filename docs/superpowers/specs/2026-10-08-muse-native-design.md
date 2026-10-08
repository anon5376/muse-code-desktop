# Muse Code native desktop design

The requested outcome is a Swift macOS application that continues running the installed Muse CLI, with a better native interface and a lean local architecture. The user delegated the remaining decisions. The focused-workspace scope is a stated working assumption; an optional scope question was presented before implementation.

## Integration decision

Use SwiftUI and AppKit for the UI, and `Foundation.Process` to supervise one `muse serve` child. Speak JSON-RPC 2.0 as newline-delimited UTF-8 JSON over stdin/stdout. No Node runtime, webview, network daemon, terminal emulation, SDK dependency, or replacement agent engine is required.

Alternatives considered: a PTY terminal wrapper preserves terminal behavior but cannot reliably expose structured native approvals or transcript items; a TypeScript SDK sidecar provides an existing client but adds another runtime and packaging boundary. Direct MSP is the smallest native route for this local app.

The exact integration contract is the stable schema exported by the installed 1.4.2 binary, not an assumption about the latest online SDK. Expected fingerprint: `sha256:61afea3112e0906e9dc3a536144278a74cb4b36fc6e20901a91d4432ba3568e2`. A mismatch is visible, not an automatic claim of compatibility. Wire envelope versions other than 1 are rejected.

## Ownership and state

- The process transport owns framing, request correlation, bounded buffering, request timeouts, stderr drainage, and child cleanup.
- The store owns the selected workspace/session and folds events by session and item ID. A completed or updated item replaces the corresponding item only when its revision is newer. Streaming deltas append only to active items and supported text fields.
- The app sends client-minted UUIDv7 command IDs. It never automatically retries a turn submission after an uncertain acknowledgement.
- Resume uses the host's inline or snapshot history and then its live stream. A session owned by another host remains an error rather than being taken over.
- Unknown item kinds show their fallback text and status. Unknown notifications are ignored. A failed turn exposes the host error.

## First-version workflow

1. Open a local project folder with the native folder picker.
2. Connect to the installed host. List sessions for that folder and models from the host.
3. Start a session or resume a listed session. Send prompts and show streamed messages, reasoning, and collapsible tool activity.
4. Interrupt an active turn with the stop action. Show the difference between admission and terminal completion.
5. Render approval requests using the host's exact available choices and current requirement identity. No implicit approval. Render agent questions and submit explicit answers.
6. Inspect actual workspace files in a side panel and insert a file mention into the composer. File inspection is read-only and bounded in size.
7. Reconnect deliberately after a host failure. Do not silently resubmit prompts.

Keyboard actions: Command-O opens a folder, Command-N starts a session, Command-Return sends the composer, Escape closes the inspector or dismisses a sheet where appropriate. Native selection, text editing, window resizing, and accessibility labels remain available.

## Presentation

An understated dark workspace using the user's Muse/Meta palette: charcoal surfaces, light text, a blue Muse mark and primary send action, and one-pixel separators. A narrow session sidebar sits alongside a generous transcript. The optional right inspector is a flat file/activity surface. Use the platform font for controls and prose, and monospaced text for code and measured values. Keep large gradients, decorative blur, card grids, and fabricated activity out of the working screen.

First launch shows a native folder action and usable prompt suggestions. It shows real connection state and no fabricated transcript. Demo data, if used for UI inspection, is conspicuously labeled and never reaches the real provider.

## Safety and local data

Resolve `muse` from a configured executable path, common installation locations, and PATH. Pass arguments directly to Process; never interpolate user text into shell commands. Disable the launcher's automatic update check for supervised children so startup cannot mutate the installed binary. Inherit the configured provider and permission policy. Never read or display auth files.

Only the offline diagnostic host uses the echo provider, isolated temporary XDG directories, memory-only sessions, and disabled workspace tools. The real app does not disable the host sandbox. Store only app preferences, recent workspace paths, and executable path in UserDefaults. Use Muse's session store rather than copying transcripts or credentials.

On app termination, close stdin and then terminate the owned child if it does not exit. Warn in the UI before quitting with active turns. Bound file previews and protocol frames to prevent accidental unlimited allocation.

## Performance and verification

Process I/O and JSON decoding run on a dedicated serial queue. Batch streaming notifications before publishing UI state; avoid a main-thread task for every token. Use stable IDs, lazy transcript rows, and bounded file previews. Measure actual process footprint and diagnostic timings without claiming an unmeasured improvement over Muse's TUI.

Required checks: build the Swift package; execute framing and transcript-fold regression tests; run the production transport against the real CLI's isolated echo host; launch the `.app`; inspect the actual native window and exercise a prompt in offline mode. A real-provider turn, real tool approval, and long-session performance remain unverified unless actually exercised.

## Sources

- Installed CLI: `muse --version`, `muse serve --help`, `muse schema generate-ts`.
- [Official MSP concepts](https://meta-models.github.io/muse-code-sdk/next/guides/msp-concepts/).
- [Official quickstart](https://meta-models.github.io/muse-code-sdk/next/guides/quickstart/).
- [Foundation Process](https://developer.apple.com/documentation/foundation/process).
