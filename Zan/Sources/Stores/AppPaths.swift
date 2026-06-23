import Foundation

/// Shared on-disk locations. User config lives here (outside the app bundle),
/// so app updates never wipe actions, prompts, or history.
enum AppPaths {
    static func appSupport() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Zan", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
