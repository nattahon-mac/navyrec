# NavyRec

A macOS screen and meeting recorder that **always stops when you tell it to and never loses a take**, with automatic local transcripts.

NavyRec is a fork of [QuickRecorder 1.6.9](https://github.com/lihaoyun6/QuickRecorder) by lihaoyun6, licensed under **AGPL-3.0** (see [LICENSE](LICENSE)). All credit for the original recorder goes to the upstream project.

## Highlights

- **Reliable stop**: left-click the menu-bar dot, press ⌘⇧2, use the Stop button, or run `open navyrec://stop`
- **No lost takes**: a new recording can't start until the previous file has finished writing and been checked
- **Crash-safe**: recordings are written as fragmented MP4, so a crash or force quit still leaves a playable file, which is recovered the next time NavyRec starts
- **Quick record** (⌘⇧1 or `navyrec://quick`): records the screen under the pointer plus mic and system audio, with no picker and no countdown. The meeting preset (30 fps, H.265) makes files about 6x smaller
- **Audio only** (`navyrec://audio`)
- **Markers** (⌘⇧M or `navyrec://marker`): flag important moments while recording
- **One folder per recording**: `~/Desktop/NavyRec/YYYY-MM-DD HHmm <Source>/` with `info.json`, plus an `index.jsonl` for the whole library
- **Automatic transcript** (optional, runs on your Mac): whisper.cpp large-v3-turbo with Silero VAD writes `transcript.txt` and `transcript.srt`
- **Automatic summary** (optional): if the [Codex CLI](https://github.com/openai/codex) is installed, NavyRec writes `summary.md` with an overview, topics, decisions, action items and marked moments
- Dark navy UI; the recording panels are hidden from the capture

See [FEATURES.md](FEATURES.md) for the full list.

## Install (prebuilt)

1. Download `NavyRec-x.y.z-macOS.zip` from [Releases](../../releases) and unzip it.
2. Double-click **Install-NavyRec.command**, or run it in Terminal. It copies the app to /Applications and can also set up transcripts (Homebrew `ffmpeg` and `whisper-cpp`, plus about 550 MB of models from Hugging Face, each checked against a SHA-256 hash).
3. On the first recording, allow Screen & System Audio Recording, the Microphone and the save folder.

The app is ad-hoc signed and not notarized. If macOS blocks it, right-click the app and choose **Open**, or run `xattr -dr com.apple.quarantine /Applications/NavyRec.app`.

Requires macOS 14 or later (tested on macOS 27, Apple silicon).

## Privacy

NavyRec has no network code, no analytics and no update checker. Recordings and transcripts never leave your Mac. The one exception is the optional summary step: it sends the transcript to whatever Codex CLI account you are logged into. Uninstall or log out of Codex to turn summaries off.

## Build from source

```sh
./build.sh                 # SwiftPM + Command Line Tools, no Xcode needed → build/NavyRec.app
./install.sh               # copy to /Applications
./scripts/make-release.sh  # → dist/NavyRec-<version>-macOS.zip
Tests/run-finalization.sh
```

The first build needs network access to fetch SwiftPM dependencies. See [NOTES-PORT.md](NOTES-PORT.md) for porting notes and the source map.

## License

AGPL-3.0, inherited from QuickRecorder. If you distribute modified builds, you must also make your source available under the same license.
