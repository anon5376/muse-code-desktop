# Muse Code Desktop

<!-- impeccable:product-schema 1 -->

## Platform
macOS — a native desktop app, not an iOS or web surface.

## Stack
Swift, SwiftUI, AppKit, and Foundation. No third-party dependencies. The user explicitly requested Swift and delegated the remaining choices.

## Users
The owner of this Mac, using Muse Code to build real software in local project folders.

## Product Purpose
Keep the installed Muse Code CLI as the execution engine while replacing terminal presentation with a responsive, attractive native app.

## Operating Context
Muse Code 1.4.2 is installed at `~/.local/bin/muse`. Its `serve` subcommand exposes newline-delimited JSON-RPC over stdio. Swift 6.3.1 and the macOS command-line developer tools are available. No incumbent desktop implementation exists in this folder.

## Capabilities and Constraints
- Muse owns authentication, agent execution, tool policy, and durable sessions.
- The app owns navigation, presentation, process supervision, and explicit user responses to host requests.
- Preserve the host's permission posture. Do not select a more permissive approval mode or disable the real host's sandbox.
- The app includes sessions, chat, real model/provider/profile selection, reasoning preferences, skills, tool activity, host-exposed session/goal/agent/workflow controls, approvals, and read-only file inspection. Terminal-only management remains available through an explicit separate Muse CLI session. A full editable IDE is outside this version.
- UI responsiveness is the objective. Faster model inference or tool execution is not established by using Swift.
- A local test build comes first. On 2026-10-08 the owner explicitly authorized source publication as `muse-code-desktop` under MIT. Hands-on acceptance remains open; promotion waits for separate approval of the tested app. Notarization, distribution signing, and cross-platform clients are not implemented.

## Brand Commitments
Use the name Muse Code. The user requested the Muse/Meta charcoal and blue palette, improved model selection, and an attractive, friendly native design without generic AI dashboard styling. The owner retains design approval.

## Evidence on Hand
An actual isolated echo-provider round trip completed through the installed host on 2026-10-08 local time. The CLI's embedded stable schema was exported offline. No model benchmark, real-provider turn, or native-versus-terminal performance comparison has been established.

Executed checks and their limits are recorded in [docs/verification.md](docs/verification.md); unrun acceptance stays open in [docs/acceptance.md](docs/acceptance.md).

## Product Principles
- Render structured protocol events directly.
- Keep credentials in Muse's existing storage.
- Present acknowledgements and completed outcomes as different states.
- Keep the interface useful without extra services or packages.
