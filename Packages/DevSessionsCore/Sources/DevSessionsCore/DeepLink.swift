import Foundation

public enum DeepLink: Equatable, Sendable {
    public static let scheme = "devsessions"

    case resume(agent: AgentKind, sessionID: String)
    case settings

    public static func parse(_ url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == scheme else {
            return nil
        }

        switch components.host?.lowercased() {
        case "resume":
            guard let items = components.queryItems,
                  let agentValue = items.first(where: { $0.name == "agent" })?.value,
                  let agent = AgentKind(rawValue: agentValue),
                  let id = items.first(where: { $0.name == "id" })?.value,
                  SessionIDValidator.isValid(id, for: agent) else {
                return nil
            }
            return .resume(agent: agent, sessionID: id)

        case "settings":
            return .settings

        default:
            return nil
        }
    }

    public static func resumeURL(agent: AgentKind, sessionID: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "resume"
        components.queryItems = [
            URLQueryItem(name: "agent", value: agent.rawValue),
            URLQueryItem(name: "id", value: sessionID)
        ]
        return components.url!
    }

    public static var settingsURL: URL {
        URL(string: "\(scheme)://settings")!
    }
}

public enum SessionIDValidator {
    public static func isValid(_ id: String, for agent: AgentKind) -> Bool {
        switch agent {
        case .opencode:
            return id.range(
                of: #"^ses_[A-Za-z0-9]+$"#,
                options: .regularExpression
            ) != nil
        case .claude, .codex:
            return UUID(uuidString: id) != nil
        case .pi, .omp:
            return id.range(
                of: #"^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$"#,
                options: .regularExpression
            ) != nil
        }
    }
}
