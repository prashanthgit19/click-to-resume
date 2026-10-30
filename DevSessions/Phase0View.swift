import AppKit
import DevSessionsCore
import SwiftUI

struct Phase0View: View {
    @ObservedObject private var controller = Phase0Controller.shared

    private var visibleSessions: [AgentSession] {
        controller.state?.sessions(withinDays: controller.activityWindowDays) ?? []
    }

    private var detectedDiagnostics: [AgentDiagnostic] {
        controller.state?.diagnostics.filter(\.isDetected) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            status

            GroupBox("Recent sessions") {
                VStack(alignment: .leading, spacing: 8) {
                    if visibleSessions.isEmpty {
                        Text(
                            controller.isScanning
                                ? "Scanning…"
                                : "No sessions in the last \(controller.activityWindowDays) days."
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(visibleSessions, id: \.cacheKey) { session in
                                    sessionRow(session)
                                }
                            }
                        }
                        .frame(maxHeight: 320)
                    }

                    if let state = controller.state {
                        HStack {
                            Text("\(visibleSessions.count) shown · \(state.sessions.count) cached")
                            Spacer()
                            Text(state.activityWindowFooterText)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox("Agent diagnostics") {
                VStack(alignment: .leading, spacing: 6) {
                    if controller.state == nil {
                        Text("No scan yet.")
                            .foregroundStyle(.secondary)
                    } else if detectedDiagnostics.isEmpty {
                        Text("No agents detected.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(detectedDiagnostics, id: \.agent) { diagnostic in
                            HStack(spacing: 12) {
                                Text(diagnostic.agent.displayName)
                                    .frame(width: 110, alignment: .leading)
                                Text(statusLabel(diagnostic.status))
                                    .foregroundStyle(diagnostic.status == .ok ? Color.secondary : Color.orange)
                                Spacer()
                                Text("\(diagnostic.sessionCount)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            if let message = diagnostic.message,
                               !message.isEmpty,
                               diagnostic.status != .ok {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 122)
                            }
                        }

                        Text("Only agents detected on this Mac are listed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HStack {
                Button("Refresh Now") {
                    controller.refresh()
                }
                SettingsLink {
                    Text("Settings…")
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }

            Text("Add the DevSessions widget from the desktop or Notification Center. Sessions are ordered globally by last activity.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 640)
        .onAppear {
            controller.bootstrap()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DevSessions")
                .font(.largeTitle.bold())
            Text("Recent sessions from OpenCode, Claude, Codex, Pi, and Oh My Pi.")
                .foregroundStyle(.secondary)
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if controller.isScanning {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(controller.statusMessage)
                    .foregroundStyle(.secondary)
            }

            if let generatedAt = controller.state?.generatedAt {
                Text("Last scan \(generatedAt, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let error = controller.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private func sessionRow(_ session: AgentSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectName)
                    .font(.headline)
                Text("\(session.agent.displayName) · \(session.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(session.lastActive, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Resume") {
                controller.resume(session, hideAfterLaunch: false)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func statusLabel(_ status: DiagnosticStatus) -> String {
        switch status {
        case .ok: return "OK"
        case .unsupported: return "Unsupported format"
        case .notInstalled: return "Not installed / no data"
        case .error: return "Error"
        }
    }
}
