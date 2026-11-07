#!/bin/bash
# Build NavyRec and pack dist/NavyRec-<version>-macOS.zip (app + installer + license).
set -euo pipefail
cd "$(dirname "$0")/.."
./build.sh
ver=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' build/NavyRec.app/Contents/Info.plist)
out=dist/NavyRec-$ver; rm -rf "$out" "$out-macOS.zip"; mkdir -p "$out"
ditto build/NavyRec.app "$out/NavyRec.app"
cp scripts/Install-NavyRec.command LICENSE "$out/"
cp README.md "$out/README.md"
(cd dist && ditto -c -k --norsrc --noextattr --keepParent "NavyRec-$ver" "NavyRec-$ver-macOS.zip")
shasum -a 256 "$out-macOS.zip"
