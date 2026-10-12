# Protocol surface

The app speaks newline-delimited JSON-RPC 2.0 to `muse serve` on stdio (see
`Wire.swift` for framing). This is the surface the code actually emits and
handles — grep-able truth, not a spec claim. The host may support more; the
app only relies on what is listed here.

## Requests the app sends

| Method | Purpose |
| --- | --- |
| `initialize` / `initialized` | Handshake; `capabilities` advertises `userInputDialogs: true` and carries `requestedCapabilities` — `["userShell"]` for real hosts, empty in echo/fixture mode |
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
| `approval/request` / `approval/requested` | Permission card — both wire spellings accepted |
| `approval/updated` · `approval/resolved` | Merge into / close a pending approval |
| `userInput/request` / `userInput/requested` | Question card — both wire spellings accepted |
| `userInput/settled` | Close a pending question |
| `connection/closed` | Host exit/pipe closure |

## Framing, timeouts, and refusals

- One JSON object per line in each direction (`LineFramer`); a frame over
  8 MiB is a protocol failure, not a truncated message.
- Requests carry generated UUIDv7-style ids (`CommandID`) so late responses
  correlate even across session switches.
- Unacknowledged requests time out (default 30 s) with the user-facing
  "did not acknowledge … in time" message — never a silent hang.
- Unknown host→client methods get JSON-RPC `-32601`; unknown notifications
  are ignored, so a newer host degrades gracefully.

## Requests the host sends the app

`approval/request` and `userInput/request` are pinned above the composer and
answered with `approval/decide` / `userInput/answer`. Any other inbound
method is refused with JSON-RPC `-32601` ("Client method is not supported") —
the app never silently handles a request shape it doesn't know.

When either pending-request method arrives carrying an `id`, the app replies
`{}` immediately — a presentation receipt only; the human decision still
travels on `approval/decide` / `userInput/answer`, never on that reply.

`userInput/answer` bodies follow the host's question contract
(`UserInputAnswer.make` enforces it before sending): `selectedLabel` for
`selection.mode: "single"` (exactly one label), `selectedLabels` for
`"multiple"` (bounded by `minSelections`/`maxSelections`, defaults `1` and
unbounded), or `freeText` — capped at 500 scalars — when no option is picked.
Every selected label must come from the question's `options`; anything else
is refused client-side and never reaches the wire.

The Activity inspector fires ad-hoc methods the host may implement
(`noop/action` in the fixtures stands in for the family). A result of
`{"status": "noop", "reason": "<why>"}` means "already done" and renders
the reason as a notice; any other success reads as a generic acceptance,
and a JSON-RPC error surfaces as the row's error text.
