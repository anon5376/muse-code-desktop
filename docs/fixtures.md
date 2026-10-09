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

## Adding a beat

Emit extra `method`/`params` frames from the fixture at the point in the
script where the UI should react, then assert on store state (ModelHost path)
or on what the app renders (ReviewHost path, via `screencapture`/ui-check).
Keep fixtures offline and deterministic: no sleeps longer than a few hundred
ms, no random ordering, no network.
