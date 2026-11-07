#!/bin/zsh
# navyrec-post — runs after a recording is saved into its own folder.
# 1. transcript.srt / transcript.txt (whisper.cpp, local; Silero VAD skips silence so long
#    quiet stretches don't make whisper loop "ขอบคุณครับ")
# 2. summary.md via Codex (optional)
# Usage: navyrec-post.sh <recording folder> [lang=th] [summary|nosummary]
# Status for tools/AI: transcript.status / summary.status = running | done | failed | skipped
PATH=$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
dir="$1"; lang="${2:-th}"; want_summary="${3:-summary}"
[ -d "$dir" ] || exit 1
cd "$dir" || exit 1
model="$HOME/whisper-models/ggml-large-v3-turbo-q5_0.bin"
vad="$HOME/whisper-models/ggml-silero-v5.1.2.bin"
notify() { osascript -e "display notification \"$1 · ${dir:t}\" with title \"NavyRec\"" >/dev/null 2>&1 }

if ! command -v whisper-cli >/dev/null || ! command -v ffmpeg >/dev/null || [ ! -f "$model" ]; then
  echo skipped > transcript.status
  echo "whisper-cli, ffmpeg or $model missing" > transcript.log
  exit 0
fi
echo running > transcript.status
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Collect every audio source: recording.qma/ (mic + sys files) or every track of recording.<ext>
inputs=(); maps=""
if [ -d recording.qma ]; then
  for f in recording.qma/*.(m4a|wav|mp3|aac)(N); do inputs+=(-i "$f"); done
  n=$(( ${#inputs[@]} / 2 ))
  for i in $(seq 0 $((n - 1))); do maps="${maps}[$i:a:0]"; done
else
  src=(recording.*(N)); src="${src[1]}"
  inputs=(-i "$src")
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$src" | wc -l | tr -d ' ')
  for i in $(seq 0 $((n - 1))); do maps="${maps}[0:a:$i]"; done
fi
if [ "$n" -lt 1 ]; then echo skipped > transcript.status; echo "no audio" > transcript.log; exit 0; fi

if [ "$n" -ge 2 ]; then
  ffmpeg -y -hide_banner -loglevel error "${inputs[@]}" -filter_complex "${maps}amix=inputs=$n:normalize=0[a]" -map "[a]" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$tmp/a.wav"
else
  ffmpeg -y -hide_banner -loglevel error "${inputs[@]}" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$tmp/a.wav"
fi || { echo failed > transcript.status; echo "ffmpeg failed" > transcript.log; exit 1; }

vadargs=()
[ -f "$vad" ] && vadargs=(--vad -vm "$vad")
if whisper-cli -m "$model" -l "$lang" -t 8 -sns "${vadargs[@]}" -osrt -otxt -of "$tmp/t" "$tmp/a.wav" > transcript.log 2>&1; then
  mv "$tmp/t.srt" transcript.srt
  mv "$tmp/t.txt" transcript.txt
  echo done > transcript.status
else
  echo failed > transcript.status
  notify "Transcript failed"
  exit 1
fi

# ---- summary ----
if [ "$want_summary" != "summary" ]; then exit 0; fi
if ! command -v codex >/dev/null || [ ! -s transcript.txt ]; then
  echo skipped > summary.status; notify "Transcript ready"; exit 0
fi
echo running > summary.status
cat > "$tmp/prompt.md" <<'PROMPT'
You are summarizing a recorded meeting/screen session. Files in the current folder:
- transcript.srt — machine transcript with timestamps (may contain mis-heard words; fix obvious ones from context, never invent content)
- info.json — metadata; "markers" are moments the user flagged as important while recording

Write summary.md in Thai (keep technical terms/product names in English) with exactly these sections:
# <short title of what was discussed>
**วันที่:** <started_at from info.json, local date/time> · **ความยาว:** <duration>
## สรุปสั้น
3-5 bullet points.
## เรื่องที่คุย
One bullet per topic, each with its start timestamp [mm:ss].
## สิ่งที่ตกลงกัน
Decisions only. Write "—" if none.
## Action items
Table: | งาน | ใคร | กำหนด | — use only what was said; "—" when unknown.
## ช่วงที่ปักหมุด
For each marker in info.json: [hh:mm:ss] + 1-2 lines of what was being said around that time. Omit this section if there are no markers.

Rules: do not create or modify any other file. If the transcript is empty or meaningless, write a one-line summary.md saying so.
PROMPT
if codex exec --skip-git-repo-check -s workspace-write -C "$PWD" - < "$tmp/prompt.md" > summary.log 2>&1 && [ -s summary.md ]; then
  echo done > summary.status
  notify "Summary ready"
else
  echo failed > summary.status
  notify "Transcript ready (summary failed)"
fi
