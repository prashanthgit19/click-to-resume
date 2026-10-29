import AppKit
import Foundation

enum TerminalLauncherError: LocalizedError {
    case terminalNotFound
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .terminalNotFound:
            return "Terminal.app could not be found."
        case let .launchFailed(message):
            return "Terminal could not launch the hand-off script: \(message)"
        }
    }
}

@MainActor
enum TerminalLauncher {
    static func open(script: String) async throws {
        let fileManager = FileManager.default
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let launchDirectory = support
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

        let fileURL = launchDirectory
            .appendingPathComponent("phase0-\(UUID().uuidString).command")
        try Data(script.utf8).write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: fileURL.path
        )

        guard let terminalURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Terminal"
        ) else {
            throw TerminalLauncherError.terminalNotFound
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open(
                [fileURL],
                withApplicationAt: terminalURL,
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
}
