import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var controller = Phase0Controller.shared

    var body: some View {
        Button("Refresh Widget") {
            controller.refresh()
        }
        Button("Test Terminal Hand-off") {
            controller.testResume()
        }
        Divider()
        Button("Show Phase 0 Window") {
            openWindow(id: "phase0")
            NSApp.activate(ignoringOtherApps: true)
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
