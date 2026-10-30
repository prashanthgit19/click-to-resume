import AppKit
import SwiftUI

@main
struct DevSessionsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            MenuBarMark()
        }
        .menuBarExtraStyle(.menu)

        Window("DevSessions", id: "sessions") {
            Phase0View()
        }
        .defaultSize(width: 740, height: 660)

        Settings {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuBarMark: View {
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.86)
                .stroke(
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )
                .rotationEffect(.degrees(-20))

            Circle()
                .frame(width: 3.4, height: 3.4)
                .offset(x: 5, y: -5)
        }
        .frame(width: 15, height: 15)
        .foregroundStyle(.primary)
        .accessibilityLabel("DevSessions")
    }
}
