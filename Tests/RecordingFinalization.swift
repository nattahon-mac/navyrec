import AVFoundation
import Foundation

@main struct RecordingFinalizationTest {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let empty = directory.appendingPathComponent("empty.mp4")
        try Data().write(to: empty)
        do {
            try await RecordingFileValidator.validate(empty)
            fatalError("Empty file was accepted")
        } catch { print("PASS: empty file rejected") }

        // Finish two movies consecutively without any delay between recording sessions.
        for index in 0..<2 {
            let url = directory.appendingPathComponent("recording-\(index).mov")
            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
            // Uncompressed audio avoids requiring a hardware encoder or capture permission.
            let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000,
                                       channels: 1, interleaved: true)!
            let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800)!
            pcm.frameLength = 4800
            memset(pcm.mutableAudioBufferList.pointee.mBuffers.mData, 0,
                   Int(pcm.mutableAudioBufferList.pointee.mBuffers.mDataByteSize))
            var description: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: format.streamDescription,
                layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
                extensions: nil, formatDescriptionOut: &description)
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false], sourceFormatHint: description)
            writer.add(input)
            guard writer.startWriting() else { throw writer.error! }
            writer.startSession(atSourceTime: .zero)
            for frame in 0..<10 {
                while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
                var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48000),
                    presentationTimeStamp: CMTime(value: Int64(frame * 4800), timescale: 48000),
                    decodeTimeStamp: .invalid)
                var sample: CMSampleBuffer?
                CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
                    makeDataReadyCallback: nil, refcon: nil, formatDescription: description,
                    sampleCount: 4800, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                    sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample)
                guard let sample else { fatalError("No sample buffer") }
                CMSampleBufferSetDataBufferFromAudioBufferList(sample, blockBufferAllocator: kCFAllocatorDefault,
                    blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: pcm.audioBufferList)
                guard input.append(sample) else { throw writer.error! }
            }
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error! }
            try await RecordingFileValidator.validate(url)
            let data = try Data(contentsOf: url)
            precondition(data.range(of: Data("moov".utf8)) != nil)
            print("PASS: consecutive movie \(index), finalized moov and positive duration")
        }
    }
}
