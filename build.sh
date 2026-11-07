#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# Keep caches inside the checkout, including on CLT-only/sandboxed machines.
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" .build/cache
# The macOS 27 CLT SDK references SwiftUIMacros, which this CLT does not ship.
# Use the bundled stable SDK when available; deployment remains macOS 14.
sdk="${NAVYREC_SDK:-$(xcrun --show-sdk-path)}"
if [ -z "${NAVYREC_SDK:-}" ] && [ -d "$(dirname "$sdk")/MacOSX26.5.sdk" ]; then
    sdk="$(dirname "$sdk")/MacOSX26.5.sdk"
fi
swift package --disable-sandbox --cache-path "$PWD/.build/cache" resolve
python3 scripts/prepare-dependencies.py
swift build --build-system native --sdk "$sdk" -c release --disable-sandbox --cache-path "$PWD/.build/cache"
bin="$(swift build --build-system native --sdk "$sdk" -c release --disable-sandbox --cache-path "$PWD/.build/cache" --show-bin-path)"
app="$PWD/build/NavyRec.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/NavyRec" "$app/Contents/MacOS/NavyRec"
for bundle in "$bin"/*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "$app/Contents/Resources/"
done
cp QuickRecorder/Supports/Scriptable.sdef "$app/Contents/Resources/"
for locale in QuickRecorder/Resources/*.lproj; do
    mkdir -p "$app/Contents/Resources/$(basename "$locale")"
    cp "$locale/"* "$app/Contents/Resources/$(basename "$locale")/"
done
python3 - "$app" <<'PY'
import plistlib, sys
from pathlib import Path
with open('QuickRecorder/Info.plist','rb') as f: info=plistlib.load(f)
for key in list(info):
    if key.startswith('SU'): del info[key]
info.update(CFBundleIdentifier='io.github.navyrec', CFBundleName='NavyRec',
    CFBundleDisplayName='NavyRec', CFBundleExecutable='NavyRec', CFBundlePackageType='APPL',
    CFBundleShortVersionString='1.0.0', CFBundleVersion='1', LSMinimumSystemVersion='14.0',
    LSUIElement=True, CFBundleIconFile='AppIcon', NSPrincipalClass='NSApplication',
    NSCameraUsageDescription='NavyRec needs this permission to record your camera and mobile device.',
    NSMicrophoneUsageDescription='NavyRec needs this permission to record your voice.',
    NSScreenCaptureUsageDescription='NavyRec needs this permission to record your screen and system audio.',
    NSHumanReadableCopyright='Based on QuickRecorder, Copyright © 2024 lihaoyun6. AGPL-3.0.',
    OSAScriptingDefinition='Scriptable.sdef',
    CFBundleURLTypes=[{'CFBundleURLName': 'io.github.navyrec', 'CFBundleURLSchemes': ['navyrec']}])
with open(Path(sys.argv[1])/'Contents/Info.plist','wb') as f: plistlib.dump(info,f)
PY
if [ -f graphic/AppIcon.icns ]; then
    cp graphic/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
else
    mkdir -p build/AppIcon.iconset
    cp QuickRecorder/Assets.xcassets/AppIcon.appiconset/*.png build/AppIcon.iconset/
    if ! iconutil -c icns build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"; then
        # Some CLT/macOS combinations reject valid PNG iconsets; ImageIO can encode ICNS.
        sips -s format icns build/AppIcon.iconset/icon_512x512@2x.png --out "$app/Contents/Resources/AppIcon.icns" >/dev/null
    fi
fi
if ! iconutil -c icns QuickRecorder/Assets.xcassets/Others/qmaIcon.iconset -o "$app/Contents/Resources/qmaIcon.icns"; then
    sips -s format icns QuickRecorder/Assets.xcassets/Others/qmaIcon.iconset/icon_512x512@2x.png --out "$app/Contents/Resources/qmaIcon.icns" >/dev/null
fi
codesign --force --deep -s - -r='designated => identifier "io.github.navyrec"' --entitlements QuickRecorder/QuickRecorder.entitlements "$app"
echo "Built $app"
