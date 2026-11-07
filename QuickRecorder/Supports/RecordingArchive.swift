//
//  RecordingArchive.swift
//  NavyRec
//
//  Each saved recording gets its own folder so people and AI tools can read it:
//
//  <save dir>/2026-10-28 2007 Screen/
//      recording.mp4          (or recording.qma for audio only)
//      info.json              what was recorded, when, how long
//      transcript.srt/.txt    written by navyrec-post.sh when auto transcribe is on
//      transcript.status      running | done | failed | skipped
//  <save dir>/index.jsonl     one line per recording, newest last
//

import AVFoundation
import Foundation

enum RecordingArchive {
    static var lastSource = "Recording"
    static var enabled: Bool { ud.object(forKey: "archiveFolders") as? Bool ?? true }
    static var autoTranscribe: Bool { ud.object(forKey: "autoTranscribe") as? Bool ?? true }
    static var autoSummary: Bool { ud.object(forKey: "autoSummary") as? Bool ?? true }

    /// Moves the validated recording into its own folder and writes info.json.
    /// Returns the new file URL, or the original URL if archiving is off or fails.
    static func archive(_ url: URL, seconds: Double, source: String) -> URL {
        guard enabled else { return url }
        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let stamp = DateFormatter()
        stamp.calendar = Calendar(identifier: .gregorian)
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM-dd HHmm"
        var folder = parent.appendingPathComponent("\(stamp.string(from: created)) \(source)")
        var n = 2
        while fm.fileExists(atPath: folder.path) {
            folder = parent.appendingPathComponent("\(stamp.string(from: created)) \(source) \(n)"); n += 1
        }
        let target = folder.appendingPathComponent("recording.\(url.pathExtension)")
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try fm.moveItem(at: url, to: target)
        } catch {
            print("Archive failed: \(error.localizedDescription)")
            return url
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = .current
        let size = (try? fm.attributesOfItem(atPath: target.path)[.size] as? NSNumber)?.int64Value
        var info: [String: Any] = [
            "app": "NavyRec",
            "file": target.lastPathComponent,
            "source": source,
            "started_at": iso.string(from: created),
            "duration_seconds": NSDecimalNumber(string: String(format: "%.1f", seconds)),
            "microphone": ud.bool(forKey: "recordMic") ? (ud.string(forKey: "micDevice") ?? "default") : "off",
            "system_audio": ud.bool(forKey: "recordWinSound") || source == "Audio",
            "transcript": autoTranscribe ? "transcript.txt" : NSNull(),
            "summary": autoTranscribe && autoSummary ? "summary.md" : NSNull(),
            "preset": SCContext.activeMeeting ? "meeting" : "custom",
            "markers": SCContext.markers.map { t -> [String: Any] in
                let r = Int(t.rounded())
                return ["seconds": NSDecimalNumber(string: String(format: "%.1f", t)),
                        "time": String(format: "%02d:%02d:%02d", r / 3600, r / 60 % 60, r % 60)]
            },
        ]
        if let size { info["bytes"] = size }
        if let track = AVURLAsset(url: target).tracks(withMediaType: .video).first {
            let s = track.naturalSize
            info["video"] = ["width": Int(s.width), "height": Int(s.height),
                             "fps": SCContext.activeMeeting ? 30 : ud.integer(forKey: "frameRate")]
        }
        if let data = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: folder.appendingPathComponent("info.json"))
        }
        var line = info
        line["folder"] = folder.lastPathComponent
        if let data = try? JSONSerialization.data(withJSONObject: line, options: [.sortedKeys]) {
            appendLine(data, to: parent.appendingPathComponent("index.jsonl"))
        }
        writeReadme(parent)
        if autoTranscribe { transcribe(folder) }
        return target
    }

    /// After a crash/force quit, an unfinished take is left in the save folder as
    /// "<name>.mp4.mp4.mp4" (or a plain .mp4/.mov that never got archived). Fragmented
    /// writing keeps it playable, so file it as "Recovered" on the next launch.
    static func recoverOrphans() {
        guard enabled, let dir = ud.string(forKey: "saveDirectory") else { return }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for url in items where ["mp4", "mov"].contains(url.pathExtension) && url.lastPathComponent.hasPrefix("NavyRec Recording") {
            let asset = AVURLAsset(url: url)
            let seconds = asset.duration.seconds
            guard seconds.isFinite, seconds > 0 else { continue }  // stub without data: leave it alone
            var clean = url
            while ["mp4", "mov"].contains(clean.deletingPathExtension().pathExtension) {  // .mp4.mp4.mp4 → .mp4
                clean = clean.deletingPathExtension()
            }
            if clean != url { try? fm.moveItem(at: url, to: clean) }
            _ = archive(clean, seconds: seconds, source: "Recovered")
        }
    }

    static func transcribe(_ folder: URL) {
        guard let script = Bundle.navyResources.url(forResource: "navyrec-post", withExtension: "sh") else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [script.path, folder.path, ud.string(forKey: "transcribeLanguage") ?? "th",
                             autoSummary ? "summary" : "nosummary"]
        process.qualityOfService = .utility
        try? process.run()
    }

    /// A short guide at the top of the save folder for people and AI agents.
    private static func writeReadme(_ dir: URL) {
        let url = dir.appendingPathComponent("README.md")
        let text = """
        # NavyRec recordings

        One folder per recording, named `YYYY-MM-DD HHmm <Source>` (Source = Screen, Window, App, Area, Audio, iPhone).

        Inside each folder:
        - `recording.mp4` / `.mov` (or `recording.qma` for audio only: mic + system audio files inside)
        - `info.json` — started_at (local time), duration_seconds, source, microphone, system_audio, video size/fps
        - `transcript.txt` — plain transcript (Thai by default)
        - `transcript.srt` — transcript with timestamps
        - `transcript.status` — running | done | failed | skipped
        - `summary.md` — meeting summary (Thai): overview, decisions, action items, marked moments
        - `summary.status` — running | done | failed | skipped
        - `info.json` → `markers`: moments the user flagged while recording (⌘⇧M)

        `index.jsonl` here lists every recording, one JSON object per line (same fields as info.json + `folder`), newest last.
        Read `index.jsonl` first to find a recording, then open its `transcript.txt`.
        """
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func appendLine(_ data: Data, to url: URL) {
        var line = data; line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(line); try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }
}
