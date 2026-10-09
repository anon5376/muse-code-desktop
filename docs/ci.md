# CI

Three workflows, all on `macos-15` runners, all capped at 30 minutes.

| Workflow | Trigger | What it does | Artifacts (retention) |
| --- | --- | --- | --- |
| `build.yml` | push to `main`, every PR, manual | Build → `scripts/test.sh` → package DMG → `verify-dmg.sh` | `dmg-<sha>`, `verify-evidence-<sha>` (14 d) |
| `demo-media.yml` | manual only | Drives the app against ReviewHost and captures frames | `demo-media-<sha>`, `demo-frames-<sha>` (30 d) |
| `release.yml` | `v*` tag push, manual re-dispatch | Build → test → package → verify → `gh release create --clobber` | the prerelease itself |

Notes:

- `build.yml` cancels superseded runs on the same ref; `demo-media.yml`
  deliberately never cancels (two runs would drive UI at once).
- Every workflow sets `permissions:` explicitly — build/demo read-only,
  release needs `contents: write`.
- The release job can be re-dispatched on an existing tag via
  `workflow_dispatch` without moving the tag; see
  [releasing.md](releasing.md).
