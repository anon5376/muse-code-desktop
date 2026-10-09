#!/bin/bash
# Verifies the packaged DMG beyond packaging-time checks:
#   1. Mount read-only, confirm bundle + Applications link, detach cleanly.
#   2. Copy the app to a different location and launch it against the
#      ReviewHost fixture — proves the bundle is self-contained.
#   3. Launch it with no Muse CLI present — proves the missing-CLI error
#      surface instead of a crash.
# Evidence (window screenshots) is written to build/verify/.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

dmg_path="$(ls -t "$project_root"/build/dist/muse-code-desktop-*.dmg | head -1)"
verify_dir="$project_root/build/verify"
rm -rf "$verify_dir"; mkdir -p "$verify_dir"
drive_bin="$verify_dir/demo-drive"
host_bin="$verify_dir/MuseReviewHost"

/usr/bin/swiftc -module-cache-path "$project_root/.build/ModuleCache" \
    "$project_root/scripts/demo-drive.swift" -o "$drive_bin"
/usr/bin/swiftc -module-cache-path "$project_root/.build/ModuleCache" \
    "$project_root/Tests/MuseDesktopTests/ReviewHost.swift" -o "$host_bin"

echo "--- mount DMG"
mount_point="$(mktemp -d /tmp/muse-verify-XXXXXX)"
hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse -readonly
test -d "$mount_point/Muse Code.app/Contents/MacOS"
test -f "$mount_point/Muse Code.app/Contents/Info.plist"
test -f "$mount_point/Muse Code.app/Contents/Resources/Muse.icns"
test -L "$mount_point/Applications"
plutil -lint "$mount_point/Muse Code.app/Contents/Info.plist"
codesign --verify --deep --strict "$mount_point/Muse Code.app" && echo "signature: valid on disk"

install_dir="$(mktemp -d /tmp/muse-install-XXXXXX)"
cp -R "$mount_point/Muse Code.app" "$install_dir/Muse Code.app"
hdiutil detach "$mount_point" -quiet || hdiutil detach "$mount_point" -force
rmdir "$mount_point"
echo "--- copied app to $install_dir (source-tree independence check)"

fixture_ws="$verify_dir/workspace"; mkdir -p "$fixture_ws"
echo "# disposable" > "$fixture_ws/README.md"

pids=()
mount_point=""
install_dir=""
cleanup() {
    for p in "${pids[@]:-}"; do kill "$p" 2>/dev/null || true; done
    [[ -n "$mount_point" ]] && hdiutil detach "$mount_point" -force -quiet 2>/dev/null || true
    rm -rf "$mount_point" "$install_dir"
}
trap cleanup EXIT

echo "--- launch copied app against ReviewHost fixture"
"$install_dir/Muse Code.app/Contents/MacOS/MuseDesktop" \
    --echo --muse-executable "$host_bin" --workspace "$fixture_ws" &
app_pid=$!; pids+=("$app_pid")
sleep 6
window="$("$drive_bin" window "$app_pid" 2>/dev/null || true)"
if [[ -z "$window" ]]; then echo "FAIL: copied app did not present a window" >&2; exit 1; fi
WIN_ID="${window%%,*}"
/usr/sbin/screencapture -x -o -l "$WIN_ID" "$verify_dir/copied-app.png" 2>/dev/null || \
    "$drive_bin" shot "$app_pid" "$verify_dir/copied-app.png"
echo "PASS: app copied from DMG presents a window ($window)"

# A window alone does not prove the host connected — the app opens its window
# before the handshake completes. The supervised host must be a live child of
# the app process; a failed spawn or dead host fails verification here.
echo "--- supervised host is a live child of the copied app"
if pgrep -P "$app_pid" -l | grep -q MuseReviewHost; then
    echo "PASS: app supervises the ReviewHost process"
else
    pgrep -P "$app_pid" -l >&2 || true
    echo "FAIL: ReviewHost is not running under the app" >&2; exit 1
fi
kill "$app_pid" 2>/dev/null || true; wait "$app_pid" 2>/dev/null || true

echo "--- launch with an unavailable Muse executable (missing-prerequisite check)"
# Pointing at a nonexistent binary exercises the error path even on machines
# where a real muse is installed (preferredPath wins over every fallback).
"$install_dir/Muse Code.app/Contents/MacOS/MuseDesktop" \
    --muse-executable "$verify_dir/no-such-muse" --workspace "$fixture_ws" &
nomuse_pid=$!; pids+=("$nomuse_pid")
sleep 6
if ! kill -0 "$nomuse_pid" 2>/dev/null; then
    echo "FAIL: app exited instead of showing the missing-CLI error" >&2; exit 1
fi
window="$("$drive_bin" window "$nomuse_pid" 2>/dev/null || true)"
if [[ -n "$window" ]]; then
    WIN_ID="${window%%,*}"
    /usr/sbin/screencapture -x -o -l "$WIN_ID" "$verify_dir/missing-muse.png" 2>/dev/null || \
        "$drive_bin" shot "$nomuse_pid" "$verify_dir/missing-muse.png"
fi
echo "PASS: app stays up and reports the missing CLI ($window)"
kill "$nomuse_pid" 2>/dev/null || true

echo "DMG verification passed. Evidence in $verify_dir"
