import SwiftUI

@main
struct ZanApp: App {
    // App-lifetime stores, injected into the dropdown.
    @StateObject private var presets = PresetStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var dictation = DictationController()
    @StateObject private var transforms = TransformController()
    @StateObject private var history = HistoryStore()
    @StateObject private var permissions = PermissionsManager()
    @StateObject private var welcome = WelcomeWindowController()

    var body: some Scene {
        // Menu-bar agent. `.window` style hosts the rich Voice-to-Text /
        // Transforms dropdown. The icon reflects recording state.
        MenuBarExtra {
            MenuContentView()
                .environmentObject(presets)
                .environmentObject(settings)
                .environmentObject(dictation)
                .environmentObject(transforms)
                .environmentObject(history)
                .environmentObject(permissions)
        } label: {
            Image(systemName: dictation.isRecording ? "waveform.circle.fill" : "waveform")
                // Register transform hotkeys + wire history at launch (the label
                // renders even when the dropdown has never been opened).
                .onAppear {
                    transforms.bind(presets: presets, history: history)
                    dictation.history = history
                    dictation.presets = presets
                    if settings.openWindowOnLaunch {
                        welcome.showOnce(content: AnyView(
                            WelcomeView()
                                .environmentObject(presets)
                                .environmentObject(settings)
                                .environmentObject(dictation)
                                .environmentObject(transforms)
                                .environmentObject(history)
                                .environmentObject(permissions)
                        ))
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }
}
