import DevSessionsCore
import ServiceManagement
import SwiftUI

@MainActor
final class LoginItemModel: ObservableObject {
    @Published var launchAtLogin = false
    @Published var message: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        launchAtLogin = (status == .enabled || status == .requiresApproval)

        switch status {
        case .enabled:
            message = "Enabled."
        case .requiresApproval:
            message = "Waiting for approval in System Settings."
        case .notRegistered:
            message = "Not registered."
        case .notFound:
            message = "The app could not be found by the login-item service. Try running it from /Applications."
        @unknown default:
            message = "Unknown status."
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                launchAtLogin = true
                message = "Requested. If macOS asks, approve DevSessions in Login Items."
            } else {
                try SMAppService.mainApp.unregister()
                launchAtLogin = false
                message = "Unregistered."
            }
        } catch {
            let status = SMAppService.mainApp.status
            launchAtLogin = (status == .enabled || status == .requiresApproval)
            message = error.localizedDescription
        }
    }
}

@MainActor
final class TerminalModel: ObservableObject {
    let available = TerminalPreferences.installed
    @Published var selected: TerminalKind

    init() {
        selected = TerminalPreferences.effective
    }

    func set(_ kind: TerminalKind) {
        TerminalPreferences.selected = kind
        selected = kind
    }
}

struct SettingsView: View {
    @ObservedObject private var app = Phase0Controller.shared
    @ObservedObject private var loginItem = LoginItemModel()
    @ObservedObject private var terminal = TerminalModel()

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { loginItem.launchAtLogin },
            set: { loginItem.setLaunchAtLogin($0) }
        )
    }

    private var windowBinding: Binding<Int> {
        Binding(
            get: { app.activityWindowDays },
            set: { app.setActivityWindow($0) }
        )
    }

    var body: some View {
        Form {
            Section("Sessions") {
                Picker("Show sessions from", selection: windowBinding) {
                    ForEach([1, 3, 7, 14, 30], id: \.self) { days in
                        Text(days == 1 ? "Last 24 hours" : "Last \(days) days")
                            .tag(days)
                    }
                }
                Text("The widget is a flat list ordered globally by last activity. There are no per-agent sections or quotas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Terminal") {
                Picker(
                    "Open sessions in",
                    selection: Binding(
                        get: { terminal.selected },
                        set: { terminal.set($0) }
                    )
                ) {
                    ForEach(terminal.available) { kind in
                        Text(kind.displayName)
                            .tag(kind)
                    }
                }

                if terminal.selected == .ghostty {
                    Text("Ghostty opens a new window in the running instance. macOS asks once for Automation approval.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Test Terminal") {
                    app.testTerminal()
                }

                Text("Applies to every session. The widget always deep-links back to DevSessions first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Agents") {
                if let diagnostics = app.state?.diagnostics {
                    ForEach(diagnostics, id: \.agent) { diagnostic in
                        HStack {
                            Text(diagnostic.agent.displayName)
                            Spacer()
                            Text(statusLabel(diagnostic.status))
                                .foregroundStyle(
                                    diagnostic.status == .ok ? Color.secondary : Color.orange
                                )
                            Text("\(diagnostic.sessionCount)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No scan yet.")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Refresh Now") {
                        app.refresh()
                    }
                    if app.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let generatedAt = app.state?.generatedAt {
                    Text("Last scan \(generatedAt, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = app.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section("Launch at Login") {
                Toggle("Launch DevSessions at login", isOn: launchAtLoginBinding)
                if let message = loginItem.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Open Login Items Settings") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }

            Section("About") {
                Text("DevSessions reads local session metadata from OpenCode, Claude Code, Codex, Pi, and Oh My Pi. No session data leaves this Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 540)
        .onAppear {
            loginItem.refresh()
        }
    }

    private func statusLabel(_ status: DiagnosticStatus) -> String {
        switch status {
        case .ok: return "OK"
        case .unsupported: return "Unsupported"
        case .notInstalled: return "No data"
        case .error: return "Error"
        }
    }
}
