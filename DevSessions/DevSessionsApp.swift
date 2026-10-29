import AppKit
import DevSessionsCore
import SwiftUI

@main
struct DevSessionsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("DevSessions", systemImage: "terminal") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Window("DevSessions — Phase 0", id: "phase0") {
            Phase0View()
        }
        .defaultSize(width: 580, height: 480)

        Settings {
            SettingsView()
        }
    }
}
