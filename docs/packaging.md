# Packaging and release

The app ships as a compressed DMG built only with tools that ship with macOS:
`hdiutil`, `codesign`, `plutil`, `lipo` and `shasum`. No packaging dependency
is installed.

## Output

`bash scripts/package-dmg.sh` writes, into `build/dist/`:

- `Muse-Code-Desktop-0.1.0-arm64.dmg`
- `Muse-Code-Desktop-0.1.0-arm64.dmg.sha256`

The DMG contains exactly `Muse Code.app` and an `Applications` symlink for
drag-install. Nothing else is added. The separately installed Muse CLI, its
configuration and its caches are never bundled; the script fails if a `muse`
executable or Muse config artifact is found inside the bundle.

## What the script does

1. Fails unless the machine is Apple Silicon (`uname -m` is `arm64`). The
   packaged executable must also be an arm64-only Mach-O; the DMG filename is
   labeled `arm64` only after that check.
2. Rebuilds `build/Muse Code.app` in release configuration from scratch.
3. Checks `CFBundleShortVersionString` is `0.1.0` (build `1`), lints
   `Info.plist`, and verifies the SwiftPM resource bundle, `Muse.icns`, and
   the bundled `MuseLogo.svg` — whose SHA-256 must match the provenance hash
   recorded in [brand-assets.md](brand-assets.md).
4. Verifies the code signature (`codesign --verify --deep --strict`).
5. Stages a temporary drag-install folder under `build/`, creates a UDZO
   (zlib) compressed image named `Muse Code 0.1.0`, runs `hdiutil verify`,
   mounts it read-only, checks its contents, then detaches.
6. Copies the app out of the mounted image to a temporary directory outside
   the repository and re-verifies signature, plist and resources on that
   copy — the same artifact a user receives.
7. Writes the `.sha256` file in `shasum` format and self-checks it.
   All staging and mount directories are removed on success and on failure.
   The source checkout is left untouched (everything happens under `build/`
   and `/tmp`).

## Signature and install

The app is signed **ad hoc** (`codesign --sign -`). There is no Developer ID
signature and no notarization. macOS Gatekeeper will warn on first launch of
the quarantined download. Options:

- Right-click the app and choose **Open**, then confirm.
- Or remove the quarantine attribute:
  `xattr -d com.apple.quarantine "/Applications/Muse Code.app"`

This preview is intentionally distributed as ad-hoc/non-notarized; no
signing identity is required to build or package it.

To verify a download yourself:

```sh
cd build/dist
shasum -a 256 -c Muse-Code-Desktop-0.1.0-arm64.dmg.sha256
```

## Tests before packaging

`bash scripts/test.sh` runs the full suite: 14 core tests plus 19 workspace
checks. The real-Muse checks need an installed Muse CLI (echo provider runs
offline; no login needed for those). Install with the official installer:

```sh
curl -fsSL https://dev.meta.ai/install.sh | sh
```

`scripts/test-ci.sh` is the CI entry point. With `muse` present it runs the
full suite; without it, it runs the core suite only, emits a CI warning and
marks the run **fixture-only** — the real echo round trip and the 19
workspace checks are then skipped, not passed. A green fixture-only run must
not be reported as the full 33 checks; the full suite must pass locally
against an installed Muse before a release is tagged.

## Continuous integration

`.github/workflows/ci.yml` (push to `main`, pull requests; `contents: read`
only) on a `macos-15` Apple Silicon runner: asserts arm64, best-effort
installs Muse via the official installer, builds the release app, runs
`scripts/test-ci.sh`, packages the DMG and uploads `build/dist/` as a
workflow artifact (7-day retention). Release assets do not come from this
job.

## Release publishing

`.github/workflows/release.yml` runs only on the `v0.1.0` tag, only on
`anon5376/muse-code-desktop`. It repeats the build/test/package/verify
pipeline and then `scripts/publish-release.py` (Python standard library
only, `GITHUB_TOKEN` with `contents: write` on this job alone):

1. Refuses if a release for `v0.1.0` already exists — no overwrite.
2. Fails if tag `v0.1.0` does not resolve to the checked-out commit.
3. Requires `docs/releases/v0.1.0.md` for the release notes body — the file
   carries the actual verified test results; nothing is invented.
4. Creates a **draft** release (`prerelease: true`), uploads the DMG, its
   `.sha256`, and `docs/media/muse-code-demo.mp4` when that file is present
   in the tagged checkout.
5. Verifies every expected asset is present, then flips the draft to a
   published prerelease. Any failure deletes the draft it created.

Tagging and merging are performed manually after local full-suite
verification and hands-on acceptance; this automation only publishes what
was already verified.
