# Releasing

Tags drive everything. The release workflow builds, tests, packages, verifies,
and publishes the prerelease in one job — a failed run cannot leave a
half-published release because `--clobber` makes re-runs idempotent.

## Cut a release

1. Land everything on `main`, wait for green CI.
2. Write `docs/release-notes/<tag>.md` — the workflow publishes it as the
   release body (it fabricates a minimal note if the file is missing, so don't
   skip this).
3. Add a CHANGELOG section for the tag.
4. Tag and push:

   ```sh
   git tag v0.2.0 && git push origin v0.2.0
   ```

5. `release.yml` runs on `macos-15`: build → `scripts/test.sh` →
   `package-dmg.sh` → `verify-dmg.sh` → `gh release create --clobber`.

## Re-run a failed release

Re-dispatch the workflow with `workflow_dispatch` and the existing `tag`
input — do not move or delete the tag. Asset uploads are clobbered cleanly.

## Artifacts

`build/dist/muse-code-desktop-<version>-arm64.dmg` plus a `.sha256` sidecar,
both attached to the prerelease. Verify locally with
`bash scripts/verify-dmg.sh <dmg>` before promoting the prerelease.

## Honest limits

Ad-hoc signed, not notarized, arm64 only. Those limits ship in the release
notes, not just here.
