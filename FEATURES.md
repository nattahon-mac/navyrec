# NavyRec — feature list

macOS screen + audio recorder (fork of QuickRecorder 1.6.9, AGPL-3.0). macOS 14+, Apple Silicon/Intel.
Status as of 2026-10-28. ✅ tested on a real Mac · ⚠️ built but not seen live.

## Recording sources
- **Screen** — whole display (choose display) ✅
- **Window** — one or more windows
- **App** — every window of the chosen app(s)
- **Area** — drag a rectangle, resize, remembers size
- **Audio only** — system audio (+ optional mic) → `recording.m4a` (mixed) + `tracks.qma` (separate mic/system tracks) when the mic is on; `recording.qma` when system audio only · `open navyrec://audio` ✅
- **iPhone/iPad** — over USB when connected
- Inherited from QuickRecorder: cursor show/hide, click highlight, screen magnifier, camera overlay, HDR, background (wallpaper/color) for window capture, video trimmer, QMA player/exporter, MP3 export

## Start
- **Start toolbar** (bottom-center): source segment with captions (Screen · Window · App · Area · Audio · iPhone), Mic toggle + ▾ microphone picker (when >1 mic), System audio toggle, camera overlay, Options ▾, **Record**
- **Quick** (red button · ⌘⇧1 · menu-bar menu · `open navyrec://quick`) — full screen under the pointer + current mic + system audio, no picker, no countdown ✅
- **Meeting preset** for Quick: 30 fps · H.265 · 1x resolution, ~6x smaller files (Options toggle, default on) ✅
- Camera overlay opens at bottom-right by default

## While recording
- **Compact bar** bottom-right (145×32 pt): REC dot + timer, mini Mic/System level bars, marker flag, Stop, expand ✅
- **Studio panel** (expanded): big timer, separate Mic and System meters (dBFS), source · resolution · fps, file size, free disk, Pause/Resume, marker, Stop. Remembers expanded/compact and position
- Recording UI is **excluded from the video** ✅
- Sits above the camera overlay instead of covering it
- **Markers** — ⌘⇧M · flag button · `open navyrec://marker` → saved with timestamps ✅
- **Silence warning** — meter turns amber after 10 s of silence; notification after 30 s of mic silence ⚠️
- Menu-bar item: red dot + timer; **left-click = stop**, right-click = menu (Stop, Pause/Resume, Quick record, controls, Quit)

## Stop — always works (the reason this app exists)
- Left-click menu-bar dot · ⌘⇧2 · Stop button · `open navyrec://stop` · AppleScript `stop recording` ✅
- Starting a new take is blocked until the previous file is fully written (no lost takes) ✅
- "Saved" toast only after the file is verified playable; failure toast with reason; click toast → Finder ✅

## Crash safety
- Fragmented MP4/MOV (10 s fragments): a crash/force quit loses at most the last ~10 s ✅
- Next launch files leftovers as `<date> Recovered/` and transcribes them ✅

## Files (AI-friendly)
- Default folder `~/Desktop/NavyRec/` (changeable: Options ▾ → Save folder…)
- One folder per recording: `YYYY-MM-DD HHmm <Source>/`
  - `recording.mp4` (mic + system mixed into one track) or `recording.qma`
  - `info.json` — started_at (local time), duration, source, preset, microphone, system audio, video size/fps, markers
  - `transcript.txt` / `transcript.srt` + `transcript.status`
  - `summary.md` + `summary.status`
- `index.jsonl` (one line per recording) + `README.md` explaining the layout, in the save folder
- Options toggles: each recording in its own folder · auto transcribe · auto summary

## After recording (automatic, background)
- **Transcript** — whisper.cpp large-v3-turbo, Thai by default, Silero VAD skips silence (prevents repeated-phrase hallucination) ✅
- **Summary** — Codex CLI writes Thai `summary.md`: title, date/length, short summary, topics with timestamps, decisions, action items table, marked moments ✅
- Notifications: "Transcript ready" / "Summary ready" / failures

## Automation
- URL scheme: `navyrec://quick` (full screen) · `navyrec://audio` (audio only) · `navyrec://stop` · `navyrec://marker` — no Automation permission needed, best for scripts/tests
- AppleScript: `quick record`, `stop recording`, `record screen`, `record screen area`, `record application`, `record window`, `record system audio`, `configure`
- Global hotkeys (Preferences): Quick ⌘⇧1 · Stop ⌘⇧2 · Marker ⌘⇧M · plus upstream start/pause/magnifier/save-frame/show-panel

## Look
- Dark navy theme (tokens in `Theme.swift`), app icon = glass orb (L03), all selector panels restyled
- Text contrast ≥ 4.5:1 (red buttons use #D62F43)

## Requirements per machine
- App: copy `NavyRec.app` to /Applications; grant Screen & System Audio Recording, Microphone, Desktop access once
- Transcript: `brew install ffmpeg whisper-cpp` + `~/whisper-models/ggml-large-v3-turbo-q5_0.bin` + `~/whisper-models/ggml-silero-v5.1.2.bin`
- Summary: Codex CLI logged in (`~/.local/bin/codex` or on PATH)
- Missing tools → status file says `skipped`; recording still works

## Not built yet
- Cloud sync across machines · self-update
