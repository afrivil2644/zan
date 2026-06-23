import SwiftUI

/// Permissions status + app-level toggles (launch at login).
struct SystemSectionView: View {
    @EnvironmentObject var permissions: PermissionsManager
    @EnvironmentObject var settings: AppSettings
    @State private var launchAtLogin = LoginItem.isEnabled

    // Refresh permission state periodically while the dropdown is open, since
    // the user may toggle them in System Settings without restarting the app.
    private let ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "System", systemImage: "gearshape")

            PermissionRow(
                name: "Microphone",
                ok: permissions.micOK,
                detail: "Record dictation",
                action: { permissions.fixMicrophone() }
            )
            PermissionRow(
                name: "Accessibility",
                ok: permissions.accessibilityTrusted,
                detail: "Paste & read selection",
                action: { permissions.fixAccessibility() }
            )

            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .font(.callout)
                .onChange(of: launchAtLogin) { _, newValue in
                    if !LoginItem.setEnabled(newValue) {
                        launchAtLogin = LoginItem.isEnabled // revert on failure
                    }
                }

            Toggle("Show window on launch", isOn: $settings.openWindowOnLaunch)
                .toggleStyle(.switch)
                .font(.callout)
        }
        .onAppear {
            permissions.refresh()
            launchAtLogin = LoginItem.isEnabled
        }
        .onReceive(ticker) { _ in permissions.refresh() }
    }
}

private struct PermissionRow: View {
    let name: String
    let ok: Bool
    let detail: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? .green : .orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.callout)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if !ok {
                Button("Enable", action: action)
                    .font(.caption2)
            }
        }
    }
}
