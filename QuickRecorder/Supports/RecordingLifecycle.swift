import SwiftUI
import AVFoundation

/// Main-thread UI state. The sample lock fences in-flight callbacks before finishing a writer.
final class RecordingLifecycle: ObservableObject {
    static let shared = RecordingLifecycle()
    @Published var isFinalizing = false
    var isStarting = false
    var stopWhenStarted = false
    var terminationPending = false
}

struct RecordingStartGate: ViewModifier {
    @ObservedObject private var lifecycle = RecordingLifecycle.shared
    func body(content: Content) -> some View {
        content.disabled(lifecycle.isFinalizing)
    }
}

extension SCContext {
    static let sampleLock = NSRecursiveLock()
    // Access while holding sampleLock in capture callbacks.
    static var acceptingSamples = false
    static var aecStarted = false

    static func enableSamples() {
        sampleLock.lock()
        acceptingSamples = true
        sampleLock.unlock()
    }

    static var canStartRecording: Bool {
        !RecordingLifecycle.shared.isFinalizing && streamType == nil
    }

    static func stopAnyRecording() {
        if streamType == .idevice { AVOutputClass.shared.stopRecording() }
        else { stopRecording() }
    }

    @MainActor static func finishLifecycle() {
        RecordingLifecycle.shared.isFinalizing = false
        PopoverState.shared.isPaused = false
        controlPanel.close()
        updateStatusBar()
        if RecordingLifecycle.shared.terminationPending {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
    }

    /// Loading a positive duration verifies the finalized movie metadata (moov for MP4/MOV).
    static func validateRecording(_ url: URL) async throws {
        if url.pathExtension == "qma" {
            let package = try qmaPackageHandle.load(from: url)
            try await validateRecording(url.appendingPathComponent("sys.\(package.info.format)"))
            try await validateRecording(url.appendingPathComponent("mic.\(package.info.format)"))
            return
        }
        try await RecordingFileValidator.validate(url)
    }

    static func recordingError(_ message: String) -> NSError {
        NSError(domain: "io.github.navyrec.recording", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    @discardableResult
    @MainActor static func presentSavedRecording(_ url: URL, image: NSImage? = nil, archive: Bool = true) async throws -> URL {
        try await validateRecording(url)
        let assetURL: URL
        if url.pathExtension == "qma" {
            let package = try qmaPackageHandle.load(from: url)
            assetURL = url.appendingPathComponent("sys.\(package.info.format)")
        } else { assetURL = url }
        let seconds = try await AVURLAsset(url: assetURL).load(.duration).seconds
        let duration = String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
        let source = url.pathExtension == "qma" ? "Audio" : RecordingArchive.lastSource
        let url = archive ? RecordingArchive.archive(url, seconds: seconds, source: source) : url
        RecordingToast.shared.show("Saved · \(url.lastPathComponent) · \(duration) verified", url: url)
        if ud.bool(forKey: "showPreview") { showPreview(path: url.path, image: image) }
        else {
            showNotification(title: "Recording Completed".local,
                             body: String(format: "File saved to: %@".local, url.path),
                             id: "navyrec.completed.\(UUID().uuidString)")
        }
        return url
    }
}
