#!/bin/bash
# Captures genuine demo media of the built app, driven through its real UI.
# The app runs against the synthetic ReviewHost fixture (never a provider or
# tool), so every pixel is the real app and the offline-fixture banner stays
# visible. Output lands in build/demo/media/ for review before publication.
#
# Usage: bash scripts/capture-demo.sh [output-dir]
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

app_path="$project_root/build/Muse Code.app"
demo_root="$project_root/build/demo"
media_dir="${1:-$demo_root/media}"
shots="$demo_root/shots"
fixture_ws="$demo_root/hello-muse"
drive_bin="$demo_root/demo-drive"
host_bin="$demo_root/MuseReviewHost"

# ---------------------------------------------------------------- fixtures
rm -rf "$demo_root"; mkdir -p "$media_dir" "$shots"
mkdir -p "$fixture_ws/Sources/Greeter" "$fixture_ws/notes"
cat > "$fixture_ws/Package.swift" <<'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "hello-muse",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Greeter")]
)
EOF
cat > "$fixture_ws/Sources/Greeter/main.swift" <<'EOF'
struct Greeter {
    let audience: String
    func message() -> String { "Hello, \(audience) — shipped by Muse." }
}

print(Greeter(audience: "world").message())
EOF
cat > "$fixture_ws/README.md" <<'EOF'
# hello-muse

A tiny disposable project used to demo the Muse Code desktop client.
Nothing here matters; it only exists so the workspace has real files.
EOF
cat > "$fixture_ws/notes/roadmap.md" <<'EOF'
# Roadmap

- [ ] Render richer previews in the inspector
- [ ] Add unit tests for the greeting path
EOF

# ---------------------------------------------------------------- build
bash "$project_root/scripts/swift-local.sh" build -c release --product MuseDesktop
/usr/bin/swiftc -module-cache-path "$project_root/.build/ModuleCache" \
    "$project_root/Tests/MuseDesktopTests/ReviewHost.swift" -o "$host_bin"
/usr/bin/swiftc -module-cache-path "$project_root/.build/ModuleCache" \
    "$project_root/scripts/demo-drive.swift" -o "$drive_bin"
/usr/bin/swiftc -module-cache-path "$project_root/.build/ModuleCache" \
    "$project_root/scripts/stitch-frames.swift" -o "$demo_root/stitch-frames"

# ---------------------------------------------------------------- launch
"$drive_bin" probe || true
"$app_path/Contents/MacOS/MuseDesktop" --echo --muse-executable "$host_bin" --workspace "$fixture_ws" &
app_pid=$!
cleanup() { kill "$app_pid" 2>/dev/null || true; }
trap cleanup EXIT
sleep 6

read -r WIN_ID WIN_X WIN_Y WIN_W WIN_H <<< "$( { "$drive_bin" window "$app_pid" || true; } | tr ',' ' ')"
if [[ -z "${WIN_ID:-}" ]]; then echo "App window was not found; capture cannot continue" >&2; exit 1; fi
echo "Window $WIN_ID at $WIN_X,$WIN_Y ${WIN_W}x${WIN_H}"

shot() {  # shot <name>
    local out="$shots/$1.png"
    /usr/sbin/screencapture -x -o -l "$WIN_ID" "$out" 2>/dev/null || "$drive_bin" shot "$app_pid" "$out"
    echo "  captured $1.png"
}
key() { "$drive_bin" key "$app_pid" "$@"; sleep 0.4; }
type() { "$drive_bin" type "$app_pid" "$1"; sleep 0.4; }
click() { "$drive_bin" click "$app_pid" "$1" "$2"; sleep 0.6; }
geom() { read -r WIN_ID WIN_X WIN_Y WIN_W WIN_H <<< "$( { "$drive_bin" window "$app_pid" || true; } | tr ',' ' ')"; }

echo "--- beat: workspace at rest"
shot 01-workspace

echo "--- beat: suggestion card fills the composer, then a markdown reply"
# Suggestion cards are real buttons: clicking one sets the draft AND focuses
# the composer (the only click-reachable focus path that is reliable here).
click $((WIN_X + 700)) $((WIN_Y + 265))
sleep 1
shot 02-composer-draft
key 36 command
sleep 3
shot 03-markdown

echo "--- beat: 40-line approval card"
# The composer keeps focus after a send; the fixture prompt renders the card.
type "please present the approval fixture"
key 36 command
sleep 3
shot 04-approval

echo "--- beat: command palette -> synthetic skill chip"
key 40 command
sleep 2
shot 05-palette
type "synthetic"
sleep 1
shot 06-palette-filtered
key 36
sleep 1.5
shot 07-skill-chip

echo "--- beat: inspector files"
key 34 command option
sleep 1
shot 08-inspector
# First file row in the inspector list.
click $((WIN_X + WIN_W - 150)) $((WIN_Y + 130))
sleep 0.6
shot 09-file-preview

echo "--- beat: model picker"
click $((WIN_X + WIN_W - 130)) $((WIN_Y + WIN_H - 43))
sleep 1
shot 10-model-picker
key 53
sleep 0.5

echo "--- beat: resize to compact 980x640, palette open then dismissed"
"$drive_bin" drag "$app_pid" $((WIN_X + WIN_W - 3)) $((WIN_Y + WIN_H - 3)) $((WIN_X + 980 - 3)) $((WIN_Y + 640 - 3)) 24
sleep 1
geom
echo "  resized to ${WIN_W}x${WIN_H}"
shot 11-compact
key 40 command
sleep 2
shot 12-compact-palette
key 53
sleep 1

echo "--- beat: deny the synthetic request (app must stay responsive)"
DENY_X=$((WIN_X + 249 + 36 + 85 + 8 + 125 + 8 + 28))
DENY_Y=$((WIN_Y + WIN_H - 140))
click "$DENY_X" "$DENY_Y"
sleep 1
shot 13-resolved
if ! kill -0 "$app_pid" 2>/dev/null; then echo "App terminated unexpectedly during the regression" >&2; exit 1; fi

echo "--- beat: question card"
key 40 command
sleep 2
type "synthetic"
sleep 1
key 36
sleep 1.5
type "please present the question fixture"
key 36 command
sleep 2
shot 14-question
# First option row, then the card's Send/answer control.
click $((WIN_X + 300)) $((WIN_Y + WIN_H - 210))
sleep 0.5
click $((WIN_X + 300)) $((WIN_Y + WIN_H - 150))
sleep 1
shot 15-answered

kill "$app_pid" 2>/dev/null || true
sleep 1

# ---------------------------------------------------------------- media
for shot_file in "$shots"/*.png; do
    base="$(basename "$shot_file")"
    sips -Z 1440 "$shot_file" --out "$media_dir/$base" >/dev/null
done
"$demo_root/stitch-frames" "$shots" "$media_dir/demo.gif" "$media_dir/demo.mp4" 2>/dev/null || \
    echo "Video stitching unavailable; stills still captured"
echo "Media written to $media_dir"
ls -la "$media_dir"
