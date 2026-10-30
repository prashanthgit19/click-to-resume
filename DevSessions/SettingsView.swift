import AppKit
import DevSessionsCore
import ServiceManagement
import SwiftUI
import WidgetKit

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
    @State private var widgetTheme: WidgetTheme = .midnight
    @State private var themeError: String?

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

            widgetPane
                .tabItem {
                    Label("Widget", systemImage: "paintpalette")
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
        .frame(width: 520, height: 480)
        .onAppear {
            loginItem.refresh()
            widgetTheme = SharedStore.appGroup()?.loadWidgetTheme() ?? .midnight
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

    private var widgetPane: some View {
        Form {
            Section {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 145), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(WidgetTheme.allCases, id: \.self) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: widgetTheme == theme
                        ) {
                            widgetTheme = theme
                            if let store = SharedStore.appGroup() {
                                do {
                                    try store.saveWidgetTheme(theme)
                                    themeError = nil
                                    WidgetCenter.shared.reloadAllTimelines()
                                } catch {
                                    themeError = error.localizedDescription
                                }
                            } else {
                                themeError = "The App Group store is unavailable."
                            }
                        }
                    }
                }
                .padding(.vertical, 2)

                if let themeError {
                    Text(themeError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("Themes apply in Full Color. Clear and Tinted widget styles are controlled by macOS and replace the theme background with its glass treatment.")
            }

            Section {
                Text("Change how all desktop widgets look in System Settings → Appearance.")
                Button("Open Appearance Settings") {
                    guard let url = URL(
                        string: "x-apple.systempreferences:com.apple.Appearance-Settings.extension"
                    ) else {
                        return
                    }
                    NSWorkspace.shared.open(url)
                }
            } header: {
                Text("System Widget Style")
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

// MARK: - Theme cards

private struct ThemeCard: View {
    let theme: WidgetTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ThemeSwatch(theme: theme)
                    .frame(height: 62)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(
                                isSelected
                                    ? Color.accentColor
                                    : Color.primary.opacity(0.10),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                HStack(spacing: 4) {
                    Text(theme.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 2)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) widget theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(theme.summary)
    }
}

private struct ThemeSwatch: View {
    let theme: WidgetTheme

    var body: some View {
        if theme == .system {
            SystemThemePreview()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: theme.swatch.top),
                        Color(hex: theme.swatch.bottom)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ThemePreviewContent(
                    accent: Color(hex: theme.swatch.accent),
                    secondary: Color(hex: theme.swatch.secondary)
                )
            }
        }
    }
}

private struct SystemThemePreview: View {
    var body: some View {
        HStack(spacing: 0) {
            half(
                background: Color(hex: 0xF2F2F7),
                foreground: Color.black.opacity(0.8)
            )
            half(
                background: Color(hex: 0x1C1C1E),
                foreground: Color.white.opacity(0.9)
            )
        }
    }

    private func half(
        background: Color,
        foreground: Color
    ) -> some View {
        ZStack {
            background

            HStack(spacing: 6) {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(foreground)
                        .frame(width: 26, height: 3)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(foreground.opacity(0.55))
                        .frame(width: 18, height: 3)
                }
            }
        }
    }
}

private struct ThemePreviewContent: View {
    let accent: Color
    let secondary: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .stroke(accent, lineWidth: 2)
                .frame(width: 26, height: 26)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(accent)
                        .frame(width: 4, height: 4)
                        .offset(x: 1, y: -1)
                }

            VStack(alignment: .leading, spacing: 3) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(secondary.opacity(0.9))
                    .frame(width: 54, height: 4)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(secondary.opacity(0.5))
                    .frame(width: 38, height: 4)
            }
        }
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
