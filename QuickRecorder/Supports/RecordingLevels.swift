import AVFoundation

/// Capture callbacks publish only numbers under a small lock. No new audio capture or UI work.
final class RecordingLevels {
    static let shared = RecordingLevels()
    enum Track: Int { case mic, system }
    private let lock = NSLock()
    private var values: [(db: Double, time: TimeInterval)] = [(-120, 0), (-120, 0)]
    private var lastAnalysis: [TimeInterval] = [0, 0]

    func reset() {
        lock.lock(); defer { lock.unlock() }
        values = [(-120, 0), (-120, 0)]; lastAnalysis = [0, 0]
    }
    func read(_ track: Track) -> Double {
        lock.lock(); defer { lock.unlock() }
        let value = values[track.rawValue]
        return Date.timeIntervalSinceReferenceDate - value.time < 1 ? value.db : -120
    }
    func ingest(_ buffer: AVAudioPCMBuffer, track: Track) {
        let now = Date.timeIntervalSinceReferenceDate
        lock.lock()
        guard now - lastAnalysis[track.rawValue] >= 0.1 else { lock.unlock(); return }
        lastAnalysis[track.rawValue] = now
        lock.unlock()
        let frames = Int(buffer.frameLength), channels = Int(buffer.format.channelCount)
        guard frames > 0, channels > 0 else { return }
        var sum = 0.0
        let stride = buffer.stride
        for channel in 0..<channels {
            for frame in 0..<frames {
                let index = frame * stride
                let value: Double
                if let data = buffer.floatChannelData { value = Double(data[channel][index]) }
                else if let data = buffer.int16ChannelData { value = Double(data[channel][index]) / 32768 }
                else if let data = buffer.int32ChannelData { value = Double(data[channel][index]) / 2147483648 }
                else { return }
                sum += value * value
            }
        }
        let db = max(-120, min(0, 10 * log10(max(sum / Double(frames * channels), 1e-12))))
        lock.lock(); values[track.rawValue] = (db, now); lock.unlock()
    }
    func ingest(_ sample: CMSampleBuffer, track: Track) {
        // Keep the retained audio block alive while reading its PCM bytes.
        guard let formatDescription = CMSampleBufferGetFormatDescription(sample) else { return }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        var needed = 0
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample, bufferListSizeNeededOut: &needed,
            bufferListOut: nil, bufferListSize: 0, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
            flags: 0, blockBufferOut: nil) == noErr else { return }
        let storage = UnsafeMutableRawPointer.allocate(byteCount: needed, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { storage.deallocate() }
        let list = storage.assumingMemoryBound(to: AudioBufferList.self)
        var block: CMBlockBuffer?
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample, bufferListSizeNeededOut: nil,
            bufferListOut: list, bufferListSize: needed, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
            flags: 0, blockBufferOut: &block) == noErr,
              let pcm = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: list) else { return }
        withExtendedLifetime(block) { ingest(pcm, track: track) }
    }
}
