import AVFoundation
import AppKit

/// Observes the two permissions Zan needs and offers one-click fixes.
@MainActor
final class PermissionsManager: ObservableObject {
    @Published var micStatus: AVAuthorizationStatus = .notDetermined
    @Published var accessibilityTrusted = false

    init() { refresh() }

    func refresh() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }

    var micOK: Bool { micStatus == .authorized }

    func fixMicrophone() {
        switch micStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in self.refresh() }
            }
        default:
            openMicrophoneSettings()
        }
    }

    func fixAccessibility() {
        AccessibilityPermission.request()
        AccessibilityPermission.openSettings()
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
