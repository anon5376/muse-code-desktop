#!/bin/bash
# Builds a clean release app and packages it into a distributable DMG using
# only built-in macOS tools (hdiutil, codesign, plutil, shasum). The app is
# ad-hoc signed and NOT notarized: recipients open it via right-click > Open
# or after removing the quarantine attribute. See docs/packaging.md.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

version="0.1.0"
app_name="Muse Code"
app_path="$project_root/build/$app_name.app"
dist_dir="$project_root/build/dist"
dmg_name="Muse-Code-Desktop-$version-arm64.dmg"
dmg_path="$dist_dir/$dmg_name"
sha_path="$dmg_path.sha256"
volume_name="$app_name $version"
staging_dir=""

cleanup() {
  [[ -n "$staging_dir" && -d "$staging_dir" ]] && rm -rf "$staging_dir"
  [[ -n "${mount_dir:-}" && -d "${mount_dir:-}" ]] && hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() { echo "ERROR: $*" >&2; exit 1; }

# --- Hardware gate: arm64 only ---------------------------------------------
[[ "$(uname -m)" == "arm64" ]] || fail "This packaging targets Apple Silicon (arm64); found $(uname -m)."

# --- Clean release build ----------------------------------------------------
echo "==> Clean release build"
rm -rf "$app_path"
bash "$project_root/scripts/build-app.sh" release

# --- Bundle checks: version metadata, resources, signature ------------------
plist="$app_path/Contents/Info.plist"
[[ -f "$plist" ]] || fail "Missing Info.plist in $app_path"
plutil -lint "$plist" >/dev/null || fail "Info.plist failed lint"
short_version="$(plutil -extract CFBundleShortVersionString raw -o - "$plist")"
[[ "$short_version" == "$version" ]] || fail "CFBundleShortVersionString is '$short_version', expected '$version'"
echo "==> Version metadata: $short_version (build $(plutil -extract CFBundleVersion raw -o - "$plist"))"

executable="$app_path/Contents/MacOS/MuseDesktop"
[[ -x "$executable" ]] || fail "Missing executable $executable"
archs="$(lipo -info "$executable" 2>/dev/null || true)"
[[ "$archs" == *arm64* && "$archs" != *x86_64* ]] || fail "Executable is not arm64-only: $archs"
echo "==> Executable architecture: $archs"

bundle="$(find "$app_path/Contents/Resources" -maxdepth 1 -name '*.bundle' -print -quit)"
[[ -n "$bundle" ]] || fail "SwiftPM resource bundle missing from $app_path/Contents/Resources"
logo_svg="$(find "$bundle" -name 'MuseLogo.svg' -print -quit)"
[[ -n "$logo_svg" ]] || fail "MuseLogo.svg missing inside resource bundle"
logo_hash="$(shasum -a 256 "$logo_svg" | awk '{print $1}')"
[[ "$logo_hash" == "73bdf6aed3c3a03b2181c69532672554fca8a1d303644c301abb1caf5300d703" ]] \
  || fail "Packaged MuseLogo.svg hash $logo_hash does not match documented provenance (docs/brand-assets.md)"
[[ -f "$app_path/Contents/Resources/Muse.icns" ]] || fail "Muse.icns missing from $app_path/Contents/Resources"
echo "==> Resources verified: $(basename "$bundle"), MuseLogo.svg (provenance hash OK), Muse.icns"

# Never bundle the Muse CLI, its config or caches.
find "$app_path" \( -name 'muse' -o -name 'muse-bin-*' -o -name 'META_API_KEY' \) -print | grep . \
  && fail "Muse CLI/config content detected inside app bundle"
[[ "$(find "$app_path" -type f -perm +111 | wc -l | tr -d ' ')" == "1" ]] \
  || fail "Expected exactly one executable (MuseDesktop) inside the bundle"

codesign --verify --deep --strict "$app_path"
signature="$(codesign -dv "$app_path" 2>&1 | awk -F= '/^Signature=/{print $2}')"
echo "==> Signature: $signature (ad hoc expected; no Developer ID/notarization)"

# --- Stage a restrained drag-install layout ---------------------------------
echo "==> Staging DMG layout"
mkdir -p "$dist_dir"
staging_dir="$(mktemp -d "$project_root/build/dmg-staging.XXXXXX")"
cp -R "$app_path" "$staging_dir/$app_name.app"
ln -s /Applications "$staging_dir/Applications"
[[ "$(find "$staging_dir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" == "2" ]] \
  || fail "Staging must contain exactly the app and the Applications symlink"

# --- Create compressed DMG ---------------------------------------------------
echo "==> Creating $dmg_name"
rm -f "$dmg_path" "$sha_path"
hdiutil create -srcfolder "$staging_dir" -volname "$volume_name" -fs HFS+ \
  -format UDZO -imagekey zlib-level=9 -ov "$dmg_path" >/dev/null
hdiutil verify "$dmg_path" >/dev/null || fail "hdiutil verify failed for $dmg_path"

# --- Mount, inspect, detach --------------------------------------------------
echo "==> Verifying mounted contents"
mount_dir="$(mktemp -d "$project_root/build/dmg-mount.XXXXXX")"
hdiutil attach "$dmg_path" -nobrowse -readonly -mountpoint "$mount_dir" -quiet
[[ -d "$mount_dir/$app_name.app" ]] || fail "App missing inside mounted DMG"
[[ -L "$mount_dir/Applications" && "$(readlink "$mount_dir/Applications")" == "/Applications" ]] \
  || fail "Applications symlink missing or wrong inside mounted DMG"
[[ "$(find "$mount_dir" -mindepth 1 -maxdepth 1 ! -name '.*' | wc -l | tr -d ' ')" == "2" ]] \
  || fail "Mounted DMG must contain exactly the app and the Applications symlink"

# Copy the packaged app out of the DMG (outside the source tree) and verify it.
copied_root="$(mktemp -d /tmp/muse-dmg-check.XXXXXX)"
cp -R "$mount_dir/$app_name.app" "$copied_root/$app_name.app"
hdiutil detach "$mount_dir" -quiet
rm -rf "$mount_dir"; mount_dir=""
codesign --verify --deep --strict "$copied_root/$app_name.app"
[[ -f "$copied_root/$app_name.app/Contents/Resources/Muse.icns" ]] || fail "Copied app lost Muse.icns"
[[ -n "$(find "$copied_root/$app_name.app" -name 'MuseLogo.svg' -print -quit)" ]] || fail "Copied app lost MuseLogo.svg"
plutil -lint "$copied_root/$app_name.app/Contents/Info.plist" >/dev/null
echo "==> Copied-app checks passed (signature, plist, resources)"

# --- Checksum ----------------------------------------------------------------
(cd "$dist_dir" && shasum -a 256 "$dmg_name" > "$dmg_name.sha256")
(cd "$dist_dir" && shasum -a 256 -c "$dmg_name.sha256")

rm -rf "$staging_dir"; staging_dir=""
rm -rf "$copied_root"

echo ""
echo "Packaged: $dmg_path"
echo "Checksum: $sha_path"
echo "Signature: ad hoc, NOT notarized — see docs/packaging.md for install notes."
