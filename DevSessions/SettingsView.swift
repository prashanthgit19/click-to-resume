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

struct SettingsView: View {
    @ObservedObject private var model = LoginItemModel()

    var body: some View {
        Form {
            Section("General") {
                Text("DevSessions is a local-only utility. It reads agent metadata on this Mac and never sends session data anywhere.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Launch at Login") {
                Toggle(
                    "Launch DevSessions at login",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                if let message = model.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Open Login Items Settings") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }

            Section("Phase 0") {
                Text("This build writes three demo sessions to the shared App Group cache. Real discovery and resume are implemented in later phases.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 480)
        .onAppear {
            model.refresh()
        }
    }
}
