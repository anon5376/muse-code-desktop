# Changelog

## [Unreleased]

Documentation and test hardening only — no product behavior changed.

- Docs: architecture, testing, fixtures, protocol surface (incl. the
  initialize capabilities payload), compatibility, releasing runbook, CI
  map, onboarding, launch flags, media catalog, glossary; DESIGN.md
  cross-links PRODUCT.md and the machine-readable design.json; superpowers
  working notes marked as preserved context; onboarding links the deeper
  docs; review-shots pointer corrected; Package.swift notes the
  script-compiled suite; protocol doc gains the request-receipt
  and `userInput/answer` payload contracts; fixtures.md lists every
  ModelHost input trigger incl. the pending-request, stream, lifecycle,
  and gap beats
- Tests: frame-limit edges, history decode rejections, markdown edges,
  streaming partials, JSONValue accessor bounds, status labels, command-id
  format, transcript upsert lifecycle, file-scan exclusions, stale-revision
  rejection, delta field whitelist + view-cursor dedup, JSONValue encode
  round-trip, connection-failure copy, Markdown tables, unadvertised
  reasoning-effort rejection, unconnected admission, empty skill catalog,
  transcript restore reset, sorted prettyPrinted keys, session search
  filtering, fork/draft admission guards, send-admission content, pending-request docking + ordering,
  streamed-turn fold through the store, lifecycle notifications, view
  gaps, session-history decode contract, frame size cap, echo-diagnostic
  config, executable discovery
- Repo: SECURITY.md, issue templates + chooser, CODEOWNERS, PR template,
  .editorconfig, .gitattributes, CONTRIBUTING/PRODUCT/README updates
- CI: manual `workflow_dispatch` on build and release, cancel-in-progress
  on build, artifact retention documented, build-status badge in README
- Fixed: EINTR from a terminated child flaked the verify-dmg step after all
  checks passed — its final echo is now non-fatal
- Fixed: a flaky workspace-store check that raced ModelHost's delayed
  terminal failure (now polls with `waitUntil`)
- Covered the store's full notification surface end-to-end via ModelHost
  beats: approval/question docks, stream folding, lifecycle metadata,
  `view/gap`, `approval/updated` merges, `session/started` upserts,
  `nameChanged`, `notLoaded` invalidation, upsert guards, cross-session
  isolation, background turns, resume buffering + failure, `session/fork`,
  `turn/interrupt`, `usage/read`, `item/readOutput`, `noop/action`,
  the 1 MiB draft cap, and the Files-inspector scan/preview/mention chain
- Store: `states` is now `private(set)` so tests can observe session
  transitions

## [v0.1.0] — 2026-10-08 ([release](https://github.com/anon5376/muse-code-desktop/releases/tag/v0.1.0))
Initial public preview (prerelease).

- Native SwiftUI workspace: transcript-first layout, session sidebar, ⌘K palette, inspector (Files · Activity · Skills · Session)
- Real model routing from the installed Muse CLI catalog with reasoning choices and data-use notices
- Explicit permission posture: approvals/questions pinned above the composer, never auto-decided
- Reproducible hdiutil DMG (`muse-code-desktop-0.1.0-arm64.dmg`), ad-hoc signed, not notarized
- macOS 14+, Apple Silicon only

[Full notes](docs/release-notes/v0.1.0.md) · [Release](https://github.com/anon5376/muse-code-desktop/releases/tag/v0.1.0)
