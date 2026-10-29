import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var controller = Phase0Controller.shared

    var body: some View {
        Text(
            controller.isScanning
                ? "Scanning…"
                : "\(controller.state?.sessions.count ?? 0) cached sessions"
        )
        .foregroundStyle(.secondary)

        Divider()

        Button("Open Sessions") {
            openWindow(id: "sessions")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Refresh Now") {
            controller.refresh()
        }

        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Button("Quit DevSessions") {
            NSApplication.shared.terminate(nil)
        }
    }
}
