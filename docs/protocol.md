# Protocol surface

The app speaks newline-delimited JSON-RPC 2.0 to `muse serve` on stdio (see
`Wire.swift` for framing). This is the surface the code actually emits and
handles — grep-able truth, not a spec claim. The host may support more; the
app only relies on what is listed here.

## Requests the app sends

| Method | Purpose |
| --- | --- |
| `initialize` / `initialized` | Handshake; the app advertises `userInputDialogs` |
| `session/list` | Existing sessions for the workspace |
| `session/start` | New session with workspace root + model route |
| `session/resume` | Resume durable history |
| `session/fork` | Fork a session |
| `session/setModel` | Change the model route mid-session |
| `model/list` | Catalog routes (model × provider × profile) |
| `skill/list` | Bundled skills for the palette |
| `turn/start` | Submit a turn with a `commandId` for correlation |
| `turn/interrupt` | Stop the running turn |
| `goal/set` · `goal/edit` · `goal/pause` · `goal/resume` | Host-side goal controls |
| `item/readOutput` | Read a tool item's captured output |
| `usage/read` | Session usage figures |
| `subagent/readResult` | Read a subagent's result |
| `userInput/answer` | Answer a question card (see `UserInputAnswer`) |
| `approval/decide` | Approve or deny a permission request |

## Notifications the app consumes

| Method | Purpose |
| --- | --- |
| `item/started` · `item/updated` · `item/completed` · `item/delta` | Transcript items and streamed text (folded by `Transcript`) |
| `turn/started` · `turn/completed` | Turn lifecycle; `terminal` carries `completed`/`failed`/`interrupted` |
| `session/started` · `session/closed` · `session/statusChanged` | Session lifecycle |
| `session/modelChanged` · `session/nameChanged` · `session/goalChanged` | Session metadata |
| `session/approvalModeChanged` · `session/contextUsage` · `session/tokenUsage` | Posture and usage |
| `session/viewHealthChanged` · `view/gap` | View integrity — a gap means refetch |
| `skill/changed` | Live skill catalog updates |
| `connection/closed` | Host exit/pipe closure |

## Requests the host sends the app

`approval/request` and `userInput/request` are pinned above the composer and
answered with `approval/decide` / `userInput/answer`. Any other inbound
method is refused with JSON-RPC `-32601` ("Client method is not supported") —
the app never silently handles a request shape it doesn't know.
