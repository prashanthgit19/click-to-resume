import AppKit
import Foundation

enum TerminalLauncherError: LocalizedError {
    case terminalNotFound(TerminalKind)
    case launchDirectoryUnavailable
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case let .terminalNotFound(terminal):
            return "\(terminal.displayName) could not be found."
        case .launchDirectoryUnavailable:
            return "The terminal launch directory is unavailable."
        case let .launchFailed(message):
            return "The terminal could not launch the hand-off script: \(message)"
        }
    }
}

@MainActor
enum TerminalLauncher {
    static func open(script: String, terminal: TerminalKind) async throws {
        let scriptURL = try writeScript(script)

        guard let applicationURL = terminal.applicationURL else {
            throw TerminalLauncherError.terminalNotFound(terminal)
        }

        switch terminal {
        case .terminal:
            try await openWithWorkspace(scriptURL, applicationURL)
        case .ghostty:
            try launchGhostty(scriptURL, applicationURL)
        }
    }

    private static func writeScript(_ script: String) throws -> URL {
        let fileManager = FileManager.default
        guard let caches = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            throw TerminalLauncherError.launchDirectoryUnavailable
        }

        let launchDirectory = caches
            .appendingPathComponent("DevSessions", isDirectory: true)
            .appendingPathComponent("launch", isDirectory: true)

        try fileManager.createDirectory(
            at: launchDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: launchDirectory.path
        )

        if let existing = try? fileManager.contentsOfDirectory(
            at: launchDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            let cutoff = Date().addingTimeInterval(-86_400)
            for file in existing {
                let modified = try? file.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ).contentModificationDate
                if let modified, modified < cutoff {
                    try? fileManager.removeItem(at: file)
                }
            }
        }

        let fileURL = launchDirectory
            .appendingPathComponent("resume-\(UUID().uuidString).command")
        try Data(script.utf8).write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: fileURL.path
        )
        return fileURL
    }

    private static func openWithWorkspace(
        _ scriptURL: URL,
        _ applicationURL: URL
    ) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open(
                [scriptURL],
                withApplicationAt: applicationURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(
                        throwing: TerminalLauncherError.launchFailed(error.localizedDescription)
                    )
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func launchGhostty(_ scriptURL: URL, _ applicationURL: URL) throws {
        // Reuse the running instance so resumes do not add a second Dock icon.
        // When Ghostty is not running, its normal launch path is simpler and
        // avoids the Automation prompt.
        let isRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.mitchellh.ghostty")
            .isEmpty

        if isRunning {
            try newGhosttyWindow(scriptURL)
        } else {
            try launchGhosttyProcess(scriptURL, applicationURL)
        }
    }

    private static func launchGhosttyProcess(_ scriptURL: URL, _ applicationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-na",
            applicationURL.path,
            "--args",
            "--command=\(scriptURL.path)"
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw TerminalLauncherError.launchFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TerminalLauncherError.launchFailed(
                message.isEmpty ? "open exited with status \(process.terminationStatus)" : message
            )
        }
    }

    private static func newGhosttyWindow(_ scriptURL: URL) throws {
        let source = """
        tell application id "com.mitchellh.ghostty"
            set cfg to new surface configuration
            set command of cfg to "\(appleScriptLiteral(scriptURL.path))"
            new window with configuration cfg
        end tell
        """

        guard let appleScript = NSAppleScript(source: source) else {
            throw TerminalLauncherError.launchFailed(
                "Could not create the Ghostty AppleScript."
            )
        }

        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)

        guard let error else { return }

        if (error[NSAppleScript.errorNumber] as? Int) == -1743 {
            throw TerminalLauncherError.launchFailed(
                "DevSessions needs permission to control Ghostty. "
                    + "Allow it in System Settings → Privacy & Security → Automation."
            )
        }

        throw TerminalLauncherError.launchFailed(
            error[NSAppleScript.errorMessage] as? String
                ?? "Ghostty did not accept the new-window request."
        )
    }

    private static func appleScriptLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
