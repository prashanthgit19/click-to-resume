import AppKit
import SwiftUI

@main
struct DevSessionsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("DevSessions", systemImage: "terminal") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Window("DevSessions", id: "sessions") {
            Phase0View()
        }
        .defaultSize(width: 740, height: 660)

        Settings {
            SettingsView()
        }
    }
}
