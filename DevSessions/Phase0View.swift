import AppKit
import DevSessionsCore
import SwiftUI

struct Phase0View: View {
    @ObservedObject private var controller = Phase0Controller.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DevSessions")
                    .font(.largeTitle.bold())
                Text("Phase 0 — platform walking skeleton")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Shared state") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(controller.statusMessage)
                    if let state = controller.state {
                        Text("\(state.sessions.count) demo sessions · \(state.activityWindowFooterText)")
                            .foregroundStyle(.secondary)
                    }
                    if let error = controller.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox("Demo sessions") {
                VStack(alignment: .leading, spacing: 8) {
                    if let sessions = controller.state?.sessions {
                        ForEach(sessions, id: \.cacheKey) { session in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.projectName)
                                        .font(.headline)
                                    Text("\(session.agent.displayName) · \(session.title)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(session.lastActive, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Resume") {
                                    controller.resume(session, hideAfterLaunch: false)
                                }
                            }
                        }
                    } else {
                        Text("No demo state yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HStack {
                Button("Refresh Widget") {
                    controller.refresh()
                }
                Button("Test Terminal Hand-off") {
                    controller.testResume()
                }
                SettingsLink {
                    Text("Settings…")
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Next steps")
                    .font(.headline)
                Text("1. Add the DevSessions widget from Notification Center or the desktop.")
                Text("2. Click a demo row in the widget. Terminal should open in a test project directory.")
                Text("3. Real agent discovery and resume commands land in later phases.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 580, minHeight: 480)
        .onAppear {
            controller.bootstrap()
        }
    }
}
