# Changelog

## [Unreleased]

Documentation and test hardening only — no product behavior changed.

- Docs: architecture, testing, fixtures, protocol surface, compatibility,
  releasing runbook, CI map, onboarding, launch flags, media catalog
- Tests: frame-limit edges, history decode rejections, markdown edges,
  streaming partials, JSONValue accessor bounds, status labels, command-id
  format, transcript upsert lifecycle, file-scan exclusions
- Repo: SECURITY.md, issue templates + chooser, CODEOWNERS, PR template,
  .editorconfig, .gitattributes, CONTRIBUTING/PRODUCT/README updates
- CI: manual `workflow_dispatch` on build and release, cancel-in-progress
  on build, artifact retention documented
- Fixed: a flaky workspace-store check that raced ModelHost's delayed
  terminal failure (now polls with `waitUntil`)

## [v0.1.0] — 2026-10-08 ([release](https://github.com/anon5376/muse-code-desktop/releases/tag/v0.1.0))
Initial public preview (prerelease).

- Native SwiftUI workspace: transcript-first layout, session sidebar, ⌘K palette, inspector (Files · Activity · Skills · Session)
- Real model routing from the installed Muse CLI catalog with reasoning choices and data-use notices
- Explicit permission posture: approvals/questions pinned above the composer, never auto-decided
- Reproducible hdiutil DMG (`muse-code-desktop-0.1.0-arm64.dmg`), ad-hoc signed, not notarized
- macOS 14+, Apple Silicon only

[Full notes](docs/release-notes/v0.1.0.md) · [Release](https://github.com/anon5376/muse-code-desktop/releases/tag/v0.1.0)
