#!/bin/bash
# NavyRec installer — double-click (or run) from the unzipped release folder.
# Installs the app, then (optional) the tools for automatic transcripts.
set -euo pipefail
cd "$(dirname "$0")"
if pgrep -x NavyRec >/dev/null; then echo "Quit NavyRec first (never quit it while recording)."; exit 1; fi

rm -rf /Applications/NavyRec.app
ditto NavyRec.app /Applications/NavyRec.app
xattr -dr com.apple.quarantine /Applications/NavyRec.app 2>/dev/null || true
codesign --verify --deep --strict /Applications/NavyRec.app
echo "✓ Installed /Applications/NavyRec.app"

read -r -p "Set up automatic transcripts (Homebrew ffmpeg + whisper-cpp, ~550 MB models)? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  BREW=$(command -v brew || echo /opt/homebrew/bin/brew)
  if [ -x "$BREW" ]; then
    for p in ffmpeg whisper-cpp; do "$BREW" list "$p" >/dev/null 2>&1 || "$BREW" install "$p"; done
  else
    echo "! Homebrew not found (https://brew.sh). Install it, then: brew install ffmpeg whisper-cpp"
  fi
  mkdir -p ~/whisper-models
  get() { # url file sha256
    local f=~/whisper-models/$2
    if [ ! -f "$f" ]; then echo "Downloading $2 …"; curl -fL --progress-bar -o "$f.part" "$1" && mv "$f.part" "$f"; fi
    echo "$3  $f" | shasum -a 256 -c - >/dev/null && echo "✓ $2" || { echo "! checksum mismatch: $2 (deleted)"; rm -f "$f"; }
  }
  get https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin ggml-large-v3-turbo-q5_0.bin 394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2
  get https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin ggml-silero-v5.1.2.bin 29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf
fi
command -v codex >/dev/null || [ -x ~/.local/bin/codex ] || echo "(Optional) Codex CLI not found — AI summaries will be skipped."
open /Applications/NavyRec.app
echo "Done. On first recording allow Screen & System Audio Recording, Microphone and the save folder."
