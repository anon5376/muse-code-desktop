#!/bin/bash
# Builds a clean release app and packages it as a drag-install DMG.
# Uses only Apple's hdiutil/PlistBuddy; no packaging dependencies.
#
# Usage: bash scripts/package-dmg.sh [version]
#   version   CFBundleShortVersionString/DMG label (default: read from the
#             app's Info.plist after the build; currently 0.1.0)
#
# Output:
#   build/muse-code-desktop-<version>-<arch>.dmg
#   build/muse-code-desktop-<version>-<arch>.dmg.sha256
#
# The app keeps its ad-hoc signature from scripts/build-app.sh. The DMG
# contains the complete bundle (resources, icon) and an Applications symlink;
# it never embeds the Muse CLI, credentials, caches or settings.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

app_path="$project_root/build/Muse Code.app"
dist_dir="$project_root/build/dist"
stage_dir="$project_root/build/dmg-stage"

# 1. Clean release build (ad-hoc signed, resource bundle + icon included).
rm -rf "$app_path" "$dist_dir" "$stage_dir"
bash "$project_root/scripts/build-app.sh" release

# 2. Version and build metadata stay consistent everywhere.
plist="$app_path/Contents/Info.plist"
version="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")}"
build_meta="$(git -C "$project_root" rev-parse --short HEAD 2>/dev/null || echo local)"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_meta" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
# Re-sign after the plist edit so the seal matches the shipped bundle.
codesign --force --sign - "$app_path"
echo "Packaging version $version (build $build_meta)"

arch="$(uname -m)"
case "$arch" in
  arm64|x86_64) ;;
  *) echo "Unsupported architecture label: $arch" >&2; exit 2 ;;
esac
dmg_name="muse-code-desktop-${version}-${arch}.dmg"
mkdir -p "$dist_dir"
dmg_path="$dist_dir/$dmg_name"

# 3. Stage a clean drag-to-install layout: the app + an Applications shortcut.
mkdir -p "$stage_dir"
cp -R "$app_path" "$stage_dir/Muse Code.app"
ln -s /Applications "$stage_dir/Applications"
# Hide the staging directory's Finder noise; keep the layout minimal.
xattr -cr "$stage_dir" 2>/dev/null || true

# 4. Create the compressed, architecture-labeled image.
hdiutil create -volname "Muse Code $version" \
  -srcfolder "$stage_dir" \
  -ov -format UDZO -imagekey zlib-level=9 \
  "$dmg_path"

# 5. Integrity record for the release page.
( cd "$dist_dir" && shasum -a 256 "$dmg_name" > "$dmg_name.sha256" )

# 6. Verify: mount, check contents, detach — leaves the source tree untouched.
mount_point="$(mktemp -d /tmp/muse-dmg-XXXXXX)"
hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse -readonly
test -d "$mount_point/Muse Code.app/Contents/MacOS"
test -f "$mount_point/Muse Code.app/Contents/Resources/Muse.icns"
test -L "$mount_point/Applications"
hdiutil detach "$mount_point" -quiet
rmdir "$mount_point"
rm -rf "$stage_dir"

echo "DMG: $dmg_path"
echo "SHA-256: $(cat "$dmg_path.sha256")"
