import AVFoundation
import AppKit
import KeyboardShortcuts

/// Owns dictation: subscribes to the global trigger, drives the recorder in the
/// user's chosen mode, manages the microphone permission, and publishes state
/// for the dropdown.
///
/// Stage 2 stops at "audio saved to a temp file". Transcription (Stage 3) will
/// consume `lastRecordingURL`.
@MainActor
final class DictationController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var lastRecordingURL: URL?
    @Published private(set) var lastRecordingBytes: Int?
    @Published private(set) var micPermission: AVAuthorizationStatus
    @Published var statusMessage: String = "Idle"
    /// Rolling mic levels for the on-screen waveform (newest at the end).
    @Published private(set) var levels: [CGFloat] = DictationController.idleLevels

    @Published private(set) var isTranscribing = false
    @Published var transcript: String = ""
    @Published private(set) var lastError: String?
    @Published private(set) var needsAccessibility = false

    private let recorder = AudioRecorder()
    /// Set at launch so completed dictations are logged to the activity list.
    var history: HistoryStore?
    private let overlay = RecordingOverlayController()
    private var meterTimer: Timer?

    static let barCount = 28
    private static let idleLevels = [CGFloat](repeating: 0.04, count: barCount)

    init() {
        micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        registerHotkey()
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        // One trigger, two behaviors. Key-down/up let us support hold-to-talk;
        // toggle ignores key-up. KeyboardShortcuts invokes these on the main
        // thread, so it is safe to assume MainActor isolation.
        KeyboardShortcuts.onKeyDown(for: .dictationTrigger) { [weak self] in
            MainActor.assumeIsolated { self?.handleKeyDown() }
        }
        KeyboardShortcuts.onKeyUp(for: .dictationTrigger) { [weak self] in
            MainActor.assumeIsolated { self?.handleKeyUp() }
        }
    }

    private func handleKeyDown() {
        switch AppSettings.currentDictationMode() {
        case .toggle:     toggle()
        case .holdToTalk: start()
        }
    }

    private func handleKeyUp() {
        if AppSettings.currentDictationMode() == .holdToTalk { stop() }
    }

    // MARK: - Recording control

    func toggle() { isRecording ? stop() : start() }

    func start() {
        guard !isRecording else { return }
        ensureMicPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.statusMessage = "Microphone access needed"
                return
            }
            do {
                let url = try self.recorder.startRecording()
                self.isRecording = true
                self.lastRecordingURL = url
                self.lastRecordingBytes = nil
                self.statusMessage = "Recording…"
                self.startMetering()
                self.overlay.show(dictation: self)
            } catch {
                self.statusMessage = "Could not start recording"
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        stopMetering()
        overlay.hide()
        let url = recorder.stopRecording()
        isRecording = false
        lastRecordingURL = url
        if let url {
            let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int
            lastRecordingBytes = bytes
            transcribe(url)
        } else {
            statusMessage = "Stopped (no file)"
        }
    }

    // MARK: - Transcription

    private func transcribe(_ url: URL) {
        // OpenAI needs a key; on-device Whisper does not.
        if AppSettings.currentTranscriptionProvider() == .openai, !KeychainStore.hasOpenAIKey {
            statusMessage = "Add your OpenAI API key below"
            lastError = nil
            return
        }
        let model = AppSettings.currentTranscriptionModel()
        let transcriber = TranscriberFactory.make()
        let onDevice = AppSettings.currentTranscriptionProvider() == .local
        isTranscribing = true
        transcript = ""
        lastError = nil
        statusMessage = onDevice ? "Transcribing on device…" : "Transcribing…"

        Task {
            do {
                let raw = try await transcriber.transcribe(fileURL: url, model: model)
                if raw.isEmpty {
                    self.transcript = ""
                    self.statusMessage = "No speech detected"
                } else {
                    let finalText = await self.cleanedIfEnabled(raw)
                    self.transcript = finalText
                    // Keep the raw transcript in history only if cleanup changed it.
                    let rawForHistory = (finalText != raw) ? raw : ""
                    self.history?.record(kind: .dictation, title: "Dictation",
                                         input: rawForHistory, output: finalText)
                    self.insertAtCursor(finalText)
                }
            } catch {
                self.lastError = error.localizedDescription
                self.statusMessage = "Transcription failed"
            }
            self.isTranscribing = false
        }
    }

    /// Runs the transcript through the editable cleanup prompt when the
    /// "Clean up with AI" toggle is on. Best-effort: on failure, returns raw.
    private func cleanedIfEnabled(_ text: String) async -> String {
        let prompt = AppSettings.currentCleanupPrompt()
        guard AppSettings.currentCleanupEnabled(),
              !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }
        statusMessage = "Cleaning up…"
        do {
            let cleaned = try await TextEngineFactory.make().transform(
                prompt: prompt, text: text, model: AppSettings.currentTextModel())
            return cleaned.isEmpty ? text : cleaned
        } catch {
            return text
        }
    }

    /// Inserts text at the cursor in the frontmost app. Surfaces the
    /// Accessibility requirement if the permission is not yet granted.
    func insertAtCursor(_ text: String) {
        guard !text.isEmpty else { return }
        guard AccessibilityPermission.isTrusted else {
            needsAccessibility = true
            statusMessage = "Enable Accessibility to insert text"
            return
        }
        needsAccessibility = false
        TextInjector.insert(text)
        statusMessage = "Inserted at cursor"
    }

    func requestAccessibility() {
        AccessibilityPermission.request()
        AccessibilityPermission.openSettings()
    }

    // MARK: - Live metering (drives the on-screen waveform)

    private func startMetering() {
        levels = Self.idleLevels
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickMeter() }
        }
        RunLoop.main.add(timer, forMode: .common) // keep updating while menus are open
        meterTimer = timer
    }

    private func tickMeter() {
        let level = max(0.04, CGFloat(recorder.currentLevel()))
        var next = levels
        next.removeFirst()
        next.append(level)
        levels = next
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        levels = Self.idleLevels
    }

    // MARK: - Microphone permission

    private func ensureMicPermission(_ completion: @escaping @MainActor (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    self.micPermission = granted ? .authorized : .denied
                    completion(granted)
                }
            }
        default: // denied / restricted
            micPermission = status
            completion(false)
        }
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
