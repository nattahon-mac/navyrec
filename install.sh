#!/bin/bash
# Copy the built app to /Applications. Only this copy should be granted
# Screen Recording / Mic permissions; build/ is rebuilt often and would
# invalidate the grant every time.
set -euo pipefail
cd "$(dirname "$0")"
src=build/NavyRec.app
dst=/Applications/NavyRec.app
[ -d "$src" ] || { echo "run ./build.sh first"; exit 1; }
if pgrep -x NavyRec >/dev/null; then echo "Quit NavyRec first (never kill it while recording)"; exit 1; fi
rm -rf "$dst"
ditto "$src" "$dst"
codesign --verify --deep --strict "$dst"
echo "Installed $dst"
