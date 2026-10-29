import AppKit
import Combine
import DevSessionsCore
import WidgetKit

@MainActor
final class Phase0Controller: ObservableObject {
    static let shared = Phase0Controller()

    @Published private(set) var state: SharedState?
    @Published private(set) var activityWindowDays = 7
    @Published private(set) var isScanning = false
    @Published private(set) var statusMessage = "Ready to scan."
    @Published private(set) var errorMessage: String?

    private var store: SharedStore?
    private var didBootstrap = false
    private var scanTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    private init() {}

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        writeDebugStatus("BOOTSTRAP")

        do {
            guard let store = SharedStore.appGroup() else {
                throw Phase0Error.appGroupUnavailable
            }
            self.store = store

            if let cached = try? store.load() {
                activityWindowDays = allowedWindow(cached.activityWindowDays)
                if !cached.sessions.contains(where: {
                    $0.projectPath.contains("DevSessions/Phase0Project")
                }) {
                    state = cached
                }
            }

            startScheduler()
            refresh()
        } catch {
            presentError(error.localizedDescription)
            statusMessage = "Setup failed."
        }
    }

    func refresh() {
        guard !isScanning else { return }
        guard store != nil else {
            presentError(Phase0Error.appGroupUnavailable.localizedDescription)
            return
        }

        isScanning = true
        statusMessage = "Scanning all agents…"

        Task { [weak self] in
            guard let self else { return }
            let result = await Task.detached(priority: .utility) {
                SessionScanner(windowDays: 30).scan(now: Date())
            }.value
            self.apply(result)
        }
    }

    func setActivityWindow(_ days: Int) {
        let allowed = allowedWindow(days)
        guard allowed == days else { return }

        activityWindowDays = days

        if var current = state {
            current.activityWindowDays = days
            state = current
            do {
                try store?.save(current)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    func resume(_ session: AgentSession, hideAfterLaunch: Bool) {
        guard FileManager.default.fileExists(atPath: session.projectPath) else {
            presentError("The project folder no longer exists:\n\(session.projectPath)")
            return
        }

        guard let executable = AgentExecutableResolver.resolve(session.agent) else {
            presentError(
                "Could not find the \(session.agent.displayName) CLI. Install it or add it to your login shell PATH."
            )
            return
        }

        let script = CommandScriptBuilder.resumeScript(
            for: session,
            executablePath: executable.path
        )
        let terminal = TerminalPreferences.effective

        Task {
            do {
                try await TerminalLauncher.open(script: script, terminal: terminal)
                statusMessage = "Opened \(session.projectName) in \(terminal.displayName)."
                errorMessage = nil
                writeDebugStatus(
                    "RESUME \(session.agent.rawValue) \(session.id) terminal=\(terminal.rawValue)"
                )
                if hideAfterLaunch {
                    NSApp.hide(nil)
                }
                scheduleRescanAfterResume()
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    func testTerminal() {
        let terminal = TerminalPreferences.effective
        let script = """
        #!/bin/zsh -l
        printf '%s\\n' 'DevSessions terminal test'
        printf 'Directory: %s\\n' "$(pwd)"
        sleep 2
        """

        Task {
            do {
                try await TerminalLauncher.open(script: script, terminal: terminal)
                statusMessage = "Terminal test opened in \(terminal.displayName)."
                errorMessage = nil
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    func handle(_ url: URL) {
        guard let link = DeepLink.parse(url) else {
            presentError("Invalid DevSessions link.")
            return
        }

        switch link {
        case .settings:
            openSettings()

        case let .resume(agent, sessionID):
            guard let session = state?.sessions.first(where: {
                $0.agent == agent && $0.id == sessionID
            }) else {
                presentError(
                    "That session is no longer in the current cache. Refresh and try again."
                )
                return
            }
            resume(session, hideAfterLaunch: true)
        }
    }

    // MARK: - Private

    private func apply(_ result: SessionScanResult) {
        let newState = SharedState(
            generatedAt: result.generatedAt,
            activityWindowDays: activityWindowDays,
            sessions: result.sessions,
            diagnostics: result.diagnostics
        )

        let changed = state?.sessions != newState.sessions
            || state?.diagnostics != newState.diagnostics
            || state?.activityWindowDays != newState.activityWindowDays

        do {
            try store?.save(newState)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            writeDebugStatus("SAVE ERROR \(error.localizedDescription)")
        }

        state = newState
        isScanning = false
        statusMessage = "\(newState.sessions.count) sessions · \(Self.timeFormatter.string(from: result.generatedAt))"
        writeDebugStatus("SCAN \(newState.sessions.count) sessions")

        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func startScheduler() {
        guard scanTimer == nil else { return }

        scanTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func scheduleRescanAfterResume() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            self?.refresh()
        }
    }

    private func openSettings() {
        let showSettings = Selector(("showSettingsWindow:"))
        let showPreferences = Selector(("showPreferencesWindow:"))
        if !NSApp.sendAction(showSettings, to: nil, from: nil) {
            NSApp.sendAction(showPreferences, to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentError(_ message: String) {
        errorMessage = message
        statusMessage = "Needs attention"
        writeDebugStatus("ERROR \(message)")

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "DevSessions"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func allowedWindow(_ days: Int) -> Int {
        [1, 3, 7, 14, 30].contains(days) ? days : 7
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    private func writeDebugStatus(_ message: String) {
        #if DEBUG
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return
        }
        let directory = support.appendingPathComponent("DevSessions", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try? message.write(
            to: directory.appendingPathComponent("scan-status.txt"),
            atomically: true,
            encoding: .utf8
        )
        #endif
    }

    deinit {
        scanTimer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}

enum Phase0Error: LocalizedError {
    case appGroupUnavailable

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "App Group container is unavailable. Add the App Group entitlement and sign both targets with the same team."
        }
    }
}
