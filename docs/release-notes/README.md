# Release notes

One file per tag: `vX.Y.Z.md` is picked up by the release workflow
([`.github/workflows/release.yml`](../../.github/workflows/release.yml)) and
used as the GitHub release body. If a tag has no file, the workflow writes a
minimal fallback — notes here always win.

| Tag | Highlights |
| --- | --- |
| [v0.1.0](v0.1.0.md) | Initial public preview: workspace, model routing, permissions, DMG |

## CHANGELOG vs release notes

`CHANGELOG.md` is the repo's running history; `docs/release-notes/<tag>.md`
is the body GitHub publishes for that tag — `release.yml` reads it verbatim
(and fabricates a minimal note if missing). Keep both: the changelog for
browsers of the tree, the per-tag file for the release page.
