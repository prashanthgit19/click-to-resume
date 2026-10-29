import Foundation

public enum ResumeCommand {
    public static func arguments(for agent: AgentKind, sessionID: String) -> [String] {
        switch agent {
        case .opencode:
            return ["--session", sessionID]
        case .claude:
            return ["--resume", sessionID]
        case .codex:
            return ["resume", sessionID]
        }
    }
}

public enum CommandScriptBuilder {
    /// The real resume command used from Phase 2 onward.
    public static func resumeScript(
        for session: AgentSession,
        executablePath: String
    ) -> String {
        let args = ResumeCommand.arguments(for: session.agent, sessionID: session.id)
            .map(shellQuote)
            .joined(separator: " ")

        return """
        #!/bin/zsh -l
        cd -- \(shellQuote(session.projectPath)) || exit 1
        exec \(shellQuote(executablePath)) \(args)
        """
    }

    /// Phase 0 hand-off. Proves Terminal opens in the project directory without
    /// requiring any real agent executable.
    public static func demoScript(for session: AgentSession) -> String {
        let lines = [
            "#!/bin/zsh -l",
            "cd -- \(shellQuote(session.projectPath)) || { printf '%s\\n' 'Project directory not found'; read -k 1; exit 1; }",
            "printf '%s\\n' \(shellQuote("DevSessions Phase 0")) '' \(shellQuote("Resume hand-off test")) \(shellQuote("Agent: \(session.agent.displayName)")) \(shellQuote("Project: \(session.projectName)")) \(shellQuote("Session: \(session.title)")) \(shellQuote("ID: \(session.id)")) ''",
            "printf '%s\\n' \"Directory: $(pwd)\"",
            "",
            "read -k 1 '?Press any key to close...'",
            ""
        ]
        return lines.joined(separator: "\n")
    }

    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
