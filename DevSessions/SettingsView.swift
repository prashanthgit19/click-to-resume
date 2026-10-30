import AppKit
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
        TabView {
            generalPane
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            terminalPane
                .tabItem {
                    Label("Terminal", systemImage: "terminal")
                }

            agentsPane
                .tabItem {
                    Label("Agents", systemImage: "stethoscope")
                }
        }
        .frame(width: 520, height: 420)
        .onAppear {
            loginItem.refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            loginItem.refresh()
        }
    }

    private var generalPane: some View {
        Form {
            Section {
                Picker("Show sessions from", selection: windowBinding) {
                    ForEach([1, 3, 7, 14, 30], id: \.self) { days in
                        Text(days == 1 ? "Last 24 hours" : "Last \(days) days")
                            .tag(days)
                    }
                }
            } header: {
                Text("Sessions")
            } footer: {
                Text("The widget is a flat list ordered globally by last activity. There are no per-agent sections or quotas.")
            }

            Section {
                Toggle("Launch DevSessions at login", isOn: launchAtLoginBinding)

                Button("Open Login Items Settings") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } header: {
                Text("Launch at Login")
            } footer: {
                if let message = loginItem.message {
                    Text(message)
                }
            }

            Section {
                LabeledContent("Version", value: version)
            } header: {
                Text("About")
            } footer: {
                Text("DevSessions reads local session metadata from OpenCode, Claude Code, Codex, Pi, and Oh My Pi. No session data leaves this Mac.")
            }
        }
        .formStyle(.grouped)
    }

    private var terminalPane: some View {
        Form {
            Section {
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

                Button("Test Terminal") {
                    app.testTerminal()
                }
            } header: {
                Text("Terminal")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if terminal.selected == .ghostty {
                        Text("Ghostty opens a new window in the running instance. macOS asks once for Automation approval.")
                    }
                    Text("Applies to every session. The widget always deep-links back to DevSessions first.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var agentsPane: some View {
        Form {
            Section {
                if app.state == nil {
                    Text("No scan yet.")
                        .foregroundStyle(.secondary)
                } else if detectedDiagnostics.isEmpty {
                    Text("No agents detected.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(detectedDiagnostics, id: \.agent) { diagnostic in
                        LabeledContent {
                            HStack(spacing: 8) {
                                Text(statusLabel(diagnostic.status))
                                    .foregroundStyle(
                                        diagnostic.status == .ok
                                            ? Color.secondary
                                            : Color.orange
                                    )
                                Text("\(diagnostic.sessionCount)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            Text(diagnostic.agent.displayName)
                        }
                    }
                }
            } header: {
                Text("Agents")
            } footer: {
                Text("Only agents detected on this Mac are listed. Counts reflect the last scan.")
            }

            Section {
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
                    LabeledContent("Last scan") {
                        Text(generatedAt, style: .relative)
                    }
                }

                if let error = app.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Scan")
            }
        }
        .formStyle(.grouped)
    }

    private var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
    }

    private var detectedDiagnostics: [AgentDiagnostic] {
        app.state?.diagnostics.filter(\.isDetected) ?? []
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
