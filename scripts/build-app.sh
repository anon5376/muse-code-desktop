#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${1:-release}"
if [[ "$configuration" != release && "$configuration" != debug ]]; then
  echo 'Usage: bash scripts/build-app.sh [release|debug]' >&2
  exit 2
fi
bash "$project_root/scripts/swift-local.sh" build -c "$configuration" --product MuseDesktop
app_path="$project_root/build/Muse Code.app"
resources="$app_path/Contents/Resources"
mkdir -p "$app_path/Contents/MacOS" "$resources"
cp "$project_root/.build/$configuration/MuseDesktop" "$app_path/Contents/MacOS/MuseDesktop"
cp -R "$project_root/.build/$configuration/MuseNative_MuseDesktop.bundle" "$resources/"
CLANG_MODULE_CACHE_PATH="$project_root/.build/ModuleCache" /usr/bin/swift "$project_root/scripts/GenerateIcon.swift" "$project_root/Sources/MuseDesktop/Resources/MuseLogo.svg" "$project_root/build/Muse-1024.png"
cp "$project_root/build/Muse-1024.icns" "$resources/Muse.icns"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>MuseDesktop</string>
  <key>CFBundleIdentifier</key><string>local.musecode.native</string>
  <key>CFBundleName</key><string>Muse Code</string>
  <key>CFBundleDisplayName</key><string>Muse Code</string>
  <key>NSHumanReadableCopyright</key><string>Unofficial independent client. Not affiliated with or endorsed by Meta. Muse and its logo belong to Meta.</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>Muse.icns</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>LSMultipleInstancesProhibited</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_path"
echo "Built: $app_path"
