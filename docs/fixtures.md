# Test fixtures

Two synthetic hosts live under `Tests/`. Both speak the app's JSON-RPC line
protocol on stdio and **never** invoke Muse, a tool, or a provider — that is
what makes the suites reproducible on CI runners with no CLI installed.

## ReviewHost (`Tests/MuseDesktopTests/ReviewHost.swift`)

Scripted presentation fixture used by `scripts/test.sh` and CI:

- answers `skills`/`plugins` CLI probes (`skills` → one bundled fixture)
- handshake → session lifecycle
- emits approval (`approval`) and question (`question`) cards for the
  permission-presentation and native-UI checks
- counts presentation receipts and user decisions, exposed via the
  `fixture/status` request — so a test can assert a card was *shown*
  (`receipts`) versus *answered* (`decisions`)

## ModelHost (`Tests/MuseDesktopTests/ModelHost.swift`)

Workspace-store fixture used by `scripts/test-workspace.sh`:

- model-change / first-turn ordering regression
- a deliberately delayed terminal failure (`asyncAfter` ~200 ms) that drove
  a real flake when a test used a fixed `Task.sleep` — store tests now poll
  with `waitUntil`
- input-driven beats: `reject once then retry` fails `turn/start` once with
  `-32602` then accepts the retry; `delayed terminal failure` accepts, emits
  `turn/started`, then `turn/completed` ~200 ms later; any input containing
  `explicit model` is rejected unless `reasoningEffort: "high"` accompanies
  it; `pending approval check` emits `approval/requested`
  mid-turn and `approval/decide` resolves it; `pending question check`
  emits `userInput/requested` and `userInput/answer` settles it;
  `pending both checks` emits one of each in order; `stream demo` folds a
  streamed turn (`item/delta` chunks, token/context usage, `durationMs`);
  `lifecycle demo` emits model/goal/approval-mode change notifications;
  `gap demo` emits `view/gap` to mark the session unavailable;
  `notification tail` exercises `approval/updated` + `session/started`
  upserts; `notload demo` emits `statusChanged notLoaded`; `rename demo`
  emits `session/nameChanged`; `session list hygiene` covers upsert's
  workspace/title guards; `isolation demo` sends events keyed to another
  session; `background start`/`background stop` emit `turn/started` +
  `turn/completed` for `extra-r`; `interrupt demo` starts a turn that only
  `turn/interrupt` ends. The fixture also answers `item/readOutput`,
  `usage/read`, `session/fork` (returns `fork-1` with history), and any
  method ending in `/action`-style `noop` via `noop/action`
- `session/resume` is answered only for the hard-coded id `buf-s` (a
  delayed result with an item event in front, exercising the buffered
  channel); every other id gets an empty result, so resume lands in the
  failure path — which the suite asserts on `extra-s`

## Adding a beat

Emit extra `method`/`params` frames from the fixture at the point in the
script where the UI should react, then assert on store state (ModelHost path)
or on what the app renders (ReviewHost path, via `screencapture`/ui-check).
Keep fixtures offline and deterministic: no sleeps longer than a few hundred
ms, no random ordering, no network.
