import AVFoundation
import Foundation

/// A successful writer callback alone does not prove the file is playable.
enum RecordingFileValidator {
    static func validate(_ url: URL) async throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attrs[.size] as? NSNumber)?.int64Value ?? 0 > 0 else {
            throw failure("The recording file is empty.")
        }
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        guard duration.isFinite && duration > 0 else {
            throw failure("The recording has no playable duration.")
        }
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "io.github.navyrec.recording", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
