import AppKit
import Combine
import DevSessionsCore
import WidgetKit

@MainActor
final class Phase0Controller: ObservableObject {
    static let shared = Phase0Controller()

    @Published private(set) var state: SharedState?
    @Published private(set) var statusMessage = "Not started"
    @Published private(set) var errorMessage: String?

    private var store: SharedStore?
    private var projectDirectory: URL?
    private var didBootstrap = false

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
            writeDebugStatus("STORE \(store.fileURL.path)")

            let project = try makeProjectDirectory()
            self.projectDirectory = project

            let demo = DemoData.make(projectPath: project.path)
            try store.save(demo)
            state = demo
            statusMessage = "Shared state written. Add the widget from Notification Center."
            errorMessage = nil
            writeDebugStatus("OK sessions=\(demo.sessions.count) path=\(store.fileURL.path)")
            reloadWidget()
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Phase 0 setup failed."
            writeDebugStatus("ERROR \(error.localizedDescription)")
        }
    }

    func refresh() {
        guard let store, let projectDirectory else {
            bootstrap()
            return
        }

        do {
            let demo = DemoData.make(projectPath: projectDirectory.path)
            try store.save(demo)
            state = demo
            statusMessage = "Refreshed at \(Self.timeFormatter.string(from: demo.generatedAt))"
            errorMessage = nil
            writeDebugStatus("REFRESH OK sessions=\(demo.sessions.count)")
            reloadWidget()
        } catch {
            errorMessage = error.localizedDescription
            writeDebugStatus("REFRESH ERROR \(error.localizedDescription)")
        }
    }

    func testResume() {
        guard let session = state?.sessions.first else {
            errorMessage = "No demo session is available."
            return
        }
        resume(session, hideAfterLaunch: false)
    }

    func handle(_ url: URL) {
        guard let link = DeepLink.parse(url) else {
            errorMessage = "Ignored invalid deep link: \(url.absoluteString)"
            return
        }

        switch link {
        case .settings:
            openSettings()
        case let .resume(agent, sessionID):
            guard let session = state?.sessions.first(where: {
                $0.agent == agent && $0.id == sessionID
            }) else {
                errorMessage = "Session not found in the Phase 0 cache."
                return
            }
            resume(session, hideAfterLaunch: true)
        }
    }

    func resume(_ session: AgentSession, hideAfterLaunch: Bool) {
        guard FileManager.default.fileExists(atPath: session.projectPath) else {
            errorMessage = "Project directory no longer exists: \(session.projectPath)"
            return
        }

        let script = CommandScriptBuilder.demoScript(for: session)
        Task {
            do {
                try await TerminalLauncher.open(script: script)
                statusMessage = "Terminal launched for \(session.projectName)."
                errorMessage = nil
                writeDebugStatus("RESUME LAUNCHED \(session.agent.rawValue) \(session.id)")
                if hideAfterLaunch {
                    NSApp.hide(nil)
                }
            } catch {
                errorMessage = error.localizedDescription
                writeDebugStatus("RESUME ERROR \(error.localizedDescription)")
            }
        }
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func makeProjectDirectory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support
            .appendingPathComponent("DevSessions", isDirectory: true)
            .appendingPathComponent("Phase0Project", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func openSettings() {
        let showSettings = Selector(("showSettingsWindow:"))
        let showPreferences = Selector(("showPreferencesWindow:"))
        if !NSApp.sendAction(showSettings, to: nil, from: nil) {
            NSApp.sendAction(showPreferences, to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
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
            to: directory.appendingPathComponent("phase0-status.txt"),
            atomically: true,
            encoding: .utf8
        )
        #endif
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
