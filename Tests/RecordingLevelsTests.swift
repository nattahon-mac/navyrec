import AVFoundation

@main
struct RecordingLevelsTests {
    static func main() throws {
        let meter = RecordingLevels.shared
        func near(_ actual: Double, _ expected: Double) {
            precondition(abs(actual - expected) < 0.05, "Expected \(expected) dBFS, got \(actual)")
        }
        let mono = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let pcm = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: 1024)!
        pcm.frameLength = 1024
        for i in 0..<1024 { pcm.floatChannelData![0][i] = 0.5 }
        meter.reset(); meter.ingest(pcm, track: .mic)
        near(meter.read(.mic), -6.0206)
        near(meter.read(.system), -120)
        // Silence is a finite floor, never NaN or negative infinity.
        for i in 0..<1024 { pcm.floatChannelData![0][i] = 0 }
        meter.ingest(pcm, track: .system); near(meter.read(.system), -120)
        // Stereo interleaved signed PCM: full-scale left and silent right => -3 dBFS.
        let stereo = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 2, interleaved: true)!
        let interleaved = AVAudioPCMBuffer(pcmFormat: stereo, frameCapacity: 1024)!
        interleaved.frameLength = 1024
        for i in 0..<1024 { interleaved.int16ChannelData![0][2 * i] = 32767; interleaved.int16ChannelData![0][2 * i + 1] = 0 }
        meter.reset(); meter.ingest(interleaved, track: .system); near(meter.read(.system), -3.0106)
        // Exercise the CMSampleBuffer path used by SCStream and selected microphones.
        var sample: CMSampleBuffer?
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48000), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        precondition(CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: stereo.formatDescription,
            sampleCount: 1024, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample) == noErr)
        precondition(CMSampleBufferSetDataBufferFromAudioBufferList(sample!, blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: interleaved.audioBufferList) == noErr)
        meter.reset(); meter.ingest(sample!, track: .mic); near(meter.read(.mic), -3.0106)
        Thread.sleep(forTimeInterval: 1.05)
        near(meter.read(.mic), -120)
        print("PASS: RMS, channel separation, silence, interleaved PCM, CMSampleBuffer and stale levels")
    }
}
