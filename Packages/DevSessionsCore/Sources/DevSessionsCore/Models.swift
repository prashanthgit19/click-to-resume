import Foundation

public enum AgentKind: String, Codable, CaseIterable, Sendable {
    case opencode
    case claude
    case codex
    case pi
    case omp

    public var displayName: String {
        switch self {
        case .opencode:
            return "OpenCode"
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        case .pi:
            return "Pi"
        case .omp:
            return "Oh My Pi"
        }
    }
}

public struct AgentSession: Codable, Hashable, Sendable {
    public var id: String
    public var agent: AgentKind
    public var projectName: String
    public var projectPath: String
    public var title: String
    public var lastActive: Date

    public init(
        id: String,
        agent: AgentKind,
        projectName: String,
        projectPath: String,
        title: String,
        lastActive: Date
    ) {
        self.id = id
        self.agent = agent
        self.projectName = projectName
        self.projectPath = projectPath
        self.title = title
        self.lastActive = lastActive
    }

    /// Unique across agents for SwiftUI lists and cache lookups.
    public var cacheKey: String {
        "\(agent.rawValue):\(id)"
    }
}

public enum DiagnosticStatus: String, Codable, Equatable, Sendable {
    case ok
    case unsupported
    case notInstalled
    case error
}

public struct AgentDiagnostic: Codable, Hashable, Sendable {
    public var agent: AgentKind
    public var status: DiagnosticStatus
    public var sessionCount: Int
    public var message: String?

    public init(
        agent: AgentKind,
        status: DiagnosticStatus,
        sessionCount: Int,
        message: String? = nil
    ) {
        self.agent = agent
        self.status = status
        self.sessionCount = sessionCount
        self.message = message
    }

    /// Whether this agent produced sessions or needs attention. Missing agents
    /// and installed agents with no sessions stay out of the diagnostics list.
    public var isDetected: Bool {
        sessionCount > 0 || status == .error || status == .unsupported
    }
}

public struct SharedState: Codable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var generatedAt: Date
    public var activityWindowDays: Int
    public var sessions: [AgentSession]
    public var diagnostics: [AgentDiagnostic]

    public init(
        schemaVersion: Int = SharedState.currentSchemaVersion,
        generatedAt: Date = Date(),
        activityWindowDays: Int = 7,
        sessions: [AgentSession] = [],
        diagnostics: [AgentDiagnostic] = []
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.activityWindowDays = activityWindowDays
        self.sessions = sessions
        self.diagnostics = diagnostics
    }

    public static func empty(activityWindowDays: Int = 7) -> SharedState {
        SharedState(activityWindowDays: activityWindowDays)
    }

    public var activityWindowFooterText: String {
        activityWindowDays == 1 ? "Last 24 hours" : "Last \(activityWindowDays) days"
    }

    public func sessions(withinDays days: Int, now: Date = Date()) -> [AgentSession] {
        let cutoff = now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
        return sessions
            .filter { $0.lastActive >= cutoff }
            .sorted { $0.lastActive > $1.lastActive }
    }
}

public enum DemoData {
    public static func make(projectPath: String, now: Date = Date()) -> SharedState {
        let sessions = [
            AgentSession(
                id: "ses_demo0000000000000000000001",
                agent: .opencode,
                projectName: "DAFE",
                projectPath: projectPath,
                title: "Feature generation",
                lastActive: now.addingTimeInterval(-20 * 60)
            ),
            AgentSession(
                id: "11111111-1111-4111-8111-111111111111",
                agent: .claude,
                projectName: "PruneGen",
                projectPath: projectPath,
                title: "Feature pruning",
                lastActive: now.addingTimeInterval(-2 * 60 * 60)
            ),
            AgentSession(
                id: "22222222-2222-4222-8222-222222222222",
                agent: .codex,
                projectName: "Decision Gateway",
                projectPath: projectPath,
                title: "Architecture",
                lastActive: now.addingTimeInterval(-2 * 24 * 60 * 60)
            )
        ]

        let diagnostics = [AgentKind.opencode, .claude, .codex].map {
            AgentDiagnostic(agent: $0, status: .ok, sessionCount: 1)
        }

        return SharedState(
            generatedAt: now,
            activityWindowDays: 7,
            sessions: sessions,
            diagnostics: diagnostics
        )
    }
}
