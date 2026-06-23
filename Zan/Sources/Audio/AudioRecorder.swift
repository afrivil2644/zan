import AVFoundation

/// Captures microphone audio to a temp `.m4a` (AAC, 16 kHz mono: small and
/// well-suited to speech / OpenAI transcription). macOS has no AVAudioSession,
/// so AVAudioRecorder is used directly.
@MainActor
final class AudioRecorder: NSObject {
    private(set) var isRecording = false
    private var recorder: AVAudioRecorder?

    /// Starts recording to a fresh temp file and returns its URL.
    func startRecording() throws -> URL {
        let url = Self.makeTempURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.delegate = self
        rec.isMeteringEnabled = true
        guard rec.record() else { throw RecorderError.couldNotStart }
        recorder = rec
        isRecording = true
        return url
    }

    /// Stops recording and returns the finished file URL.
    @discardableResult
    func stopRecording() -> URL? {
        let url = recorder?.url
        recorder?.stop()
        recorder = nil
        isRecording = false
        return url
    }

    /// Current input loudness, normalized to 0...1 for the waveform display.
    func currentLevel() -> Float {
        guard let recorder, isRecording else { return 0 }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0) // ~ -160 (silent) ... 0 (loud)
        let floorDb: Float = -55
        guard db > floorDb else { return 0 }
        return max(0, min(1, (db - floorDb) / -floorDb))
    }

    private static func makeTempURL() -> URL {
        let stamp = Self.timestampFormatter.string(from: Date())
        let name = "zan-dictation-\(stamp).m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()

    enum RecorderError: Error { case couldNotStart }
}

extension AudioRecorder: AVAudioRecorderDelegate {}
