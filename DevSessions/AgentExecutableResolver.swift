import Foundation
import DevSessionsCore

enum AgentExecutableResolver {
    private static var cache: [AgentKind: URL] = [:]

    static func resolve(_ agent: AgentKind) -> URL? {
        if let cached = cache[agent],
           FileManager.default.isExecutableFile(atPath: cached.path) {
            return cached
        }

        for path in knownPaths(for: agent)
        where FileManager.default.isExecutableFile(atPath: path) {
            let url = URL(fileURLWithPath: path)
            cache[agent] = url
            return url
        }

        if let path = loginShellPath(for: agent),
           FileManager.default.isExecutableFile(atPath: path) {
            let url = URL(fileURLWithPath: path)
            cache[agent] = url
            return url
        }

        return nil
    }

    private static func knownPaths(for agent: AgentKind) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser

        switch agent {
        case .opencode:
            return [
                home.appendingPathComponent(".opencode", isDirectory: true)
                    .appendingPathComponent("bin", isDirectory: true)
                    .appendingPathComponent("opencode").path,
                home.appendingPathComponent(".local", isDirectory: true)
                    .appendingPathComponent("bin", isDirectory: true)
                    .appendingPathComponent("opencode").path,
                "/opt/homebrew/bin/opencode",
                "/usr/local/bin/opencode"
            ]
        case .claude:
            return [
                home.appendingPathComponent(".local", isDirectory: true)
                    .appendingPathComponent("bin", isDirectory: true)
                    .appendingPathComponent("claude").path,
                home.appendingPathComponent(".claude", isDirectory: true)
                    .appendingPathComponent("local", isDirectory: true)
                    .appendingPathComponent("claude").path,
                "/opt/homebrew/bin/claude",
                "/usr/local/bin/claude"
            ]
        case .codex:
            return [
                home.appendingPathComponent(".local", isDirectory: true)
                    .appendingPathComponent("bin", isDirectory: true)
                    .appendingPathComponent("codex").path,
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex"
            ]
        case .pi:
            return [
                home.appendingPathComponent(".local", isDirectory: true)
                    .appendingPathComponent("bin", isDirectory: true)
                    .appendingPathComponent("pi").path,
                home.appendingPathComponent(".pi", isDirectory: true)
                    .appendingPathComponent("agent", isDirectory: true)
                    .appendingPathComponent("bin", isDirectory: true)
                    .appendingPathComponent("pi").path,
                "/opt/homebrew/bin/pi",
                "/usr/local/bin/pi"
            ]
        case .omp:
            return [
                "/opt/homebrew/bin/omp",
                home.appendingPathComponent(".local", isDirectory: true)
                    .appendingPathComponent("bin", isDirectory: true)
                    .appendingPathComponent("omp").path,
                "/usr/local/bin/omp"
            ]
        }
    }

    private static func loginShellPath(for agent: AgentKind) -> String? {
        let command: String
        switch agent {
        case .opencode: command = "opencode"
        case .claude: command = "claude"
        case .codex: command = "codex"
        case .pi: command = "pi"
        case .omp: command = "omp"
        }

        for flag in ["-lc", "-lic"] {
            if let path = runShell(flag: flag, command: command) {
                return path
            }
        }
        return nil
    }

    private static func runShell(flag: String, command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [flag, "command -v \(command)"]
        process.standardError = FileHandle.nullDevice

        let output = Pipe()
        process.standardOutput = output

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
        return text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last(where: { !$0.isEmpty })
    }
}
