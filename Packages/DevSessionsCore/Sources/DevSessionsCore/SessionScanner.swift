import Foundation
import SQLite3

public struct SessionScanResult: Sendable {
    public let generatedAt: Date
    public let sessions: [AgentSession]
    public let diagnostics: [AgentDiagnostic]

    public init(
        generatedAt: Date,
        sessions: [AgentSession],
        diagnostics: [AgentDiagnostic]
    ) {
        self.generatedAt = generatedAt
        self.sessions = sessions
        self.diagnostics = diagnostics
    }

    public func sharedState(activityWindowDays: Int) -> SharedState {
        SharedState(
            generatedAt: generatedAt,
            activityWindowDays: activityWindowDays,
            sessions: sessions,
            diagnostics: diagnostics
        )
    }
}

private struct AdapterOutput {
    let sessions: [AgentSession]
    let status: DiagnosticStatus
    let message: String?

    static func ok(_ sessions: [AgentSession]) -> AdapterOutput {
        AdapterOutput(sessions: sessions, status: .ok, message: nil)
    }

    static func notInstalled(_ message: String) -> AdapterOutput {
        AdapterOutput(sessions: [], status: .notInstalled, message: message)
    }

    static func unsupported(_ message: String) -> AdapterOutput {
        AdapterOutput(sessions: [], status: .unsupported, message: message)
    }

    static func error(_ message: String) -> AdapterOutput {
        AdapterOutput(sessions: [], status: .error, message: message)
    }
}

public struct SessionScanner: Sendable {
    public let homeDirectory: URL
    public let windowDays: Int

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        windowDays: Int = 30
    ) {
        self.homeDirectory = homeDirectory
        self.windowDays = windowDays
    }

    public func scan(now: Date = Date()) -> SessionScanResult {
        let days = max(1, min(windowDays, 30))
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)

        let adapters: [(AgentKind, () throws -> AdapterOutput)] = [
            (.opencode, { try scanOpenCode(now: now, cutoff: cutoff) }),
            (.claude, { try scanClaude(now: now, cutoff: cutoff) }),
            (.codex, { try scanCodex(now: now, cutoff: cutoff) }),
            (.pi, {
                try scanPiFamily(
                    agent: .pi,
                    root: homeDirectory
                        .appendingPathComponent(".pi", isDirectory: true)
                        .appendingPathComponent("agent", isDirectory: true)
                        .appendingPathComponent("sessions", isDirectory: true),
                    useTitleSlot: false,
                    now: now,
                    cutoff: cutoff
                )
            }),
            (.omp, {
                try scanPiFamily(
                    agent: .omp,
                    root: homeDirectory
                        .appendingPathComponent(".omp", isDirectory: true)
                        .appendingPathComponent("agent", isDirectory: true)
                        .appendingPathComponent("sessions", isDirectory: true),
                    useTitleSlot: true,
                    now: now,
                    cutoff: cutoff
                )
            })
        ]

        var allSessions: [AgentSession] = []
        var diagnostics: [AgentDiagnostic] = []

        for (agent, run) in adapters {
            do {
                let output = try run()
                allSessions.append(contentsOf: output.sessions)
                diagnostics.append(
                    AgentDiagnostic(
                        agent: agent,
                        status: output.status,
                        sessionCount: output.sessions.count,
                        message: output.message
                    )
                )
            } catch {
                diagnostics.append(
                    AgentDiagnostic(
                        agent: agent,
                        status: .error,
                        sessionCount: 0,
                        message: error.localizedDescription
                    )
                )
            }
        }

        var unique: [String: AgentSession] = [:]
        for session in allSessions where session.lastActive >= cutoff {
            unique[session.cacheKey] = session
        }

        let sorted = unique.values.sorted {
            if $0.lastActive == $1.lastActive {
                return $0.cacheKey < $1.cacheKey
            }
            return $0.lastActive > $1.lastActive
        }

        // Flat global recency order. No per-agent quota or classification.
        return SessionScanResult(
            generatedAt: now,
            sessions: Array(sorted.prefix(200)),
            diagnostics: diagnostics
        )
    }

    // MARK: - OpenCode

    private func scanOpenCode(now: Date, cutoff: Date) throws -> AdapterOutput {
        let databaseURL = homeDirectory
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("opencode", isDirectory: true)
            .appendingPathComponent("opencode.db")

        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return .notInstalled("OpenCode database not found.")
        }

        do {
            let database = try SQLiteDatabase(path: databaseURL.path)
            let table: String
            if try database.tableExists("session_v2") {
                table = "session_v2"
            } else if try database.tableExists("session") {
                table = "session"
            } else {
                return .unsupported("OpenCode session table not found.")
            }

            var sessions: [AgentSession] = []
            let cutoffMilliseconds = Int64(cutoff.timeIntervalSince1970 * 1_000)
            let sql = """
                SELECT id, title, slug, directory, time_updated
                FROM \(table)
                WHERE parent_id IS NULL
                  AND time_archived IS NULL
                  AND time_updated >= ?
                ORDER BY time_updated DESC
                LIMIT 200
                """

            try database.query(
                sql,
                bind: { statement in
                    sqlite3_bind_int64(statement, 1, cutoffMilliseconds)
                },
                row: { statement in
                    guard let id = database.text(statement, 0),
                          SessionIDValidator.isValid(id, for: .opencode),
                          let directory = database.text(statement, 3),
                          !directory.isEmpty else {
                        return
                    }

                    let milliseconds = database.int64(statement, 4)
                    guard milliseconds > 0 else { return }

                    let title = normalizedTitle(database.text(statement, 1))
                        ?? normalizedTitle(database.text(statement, 2))
                        ?? "Untitled session"

                    sessions.append(
                        AgentSession(
                            id: id,
                            agent: .opencode,
                            projectName: projectName(for: directory),
                            projectPath: directory,
                            title: title,
                            lastActive: Date(
                                timeIntervalSince1970: Double(milliseconds) / 1_000
                            )
                        )
                    )
                }
            )

            return .ok(sessions)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Claude Code

    private func scanClaude(now: Date, cutoff: Date) throws -> AdapterOutput {
        let projectsURL = homeDirectory
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)

        guard FileManager.default.fileExists(atPath: projectsURL.path) else {
            return .notInstalled("Claude Code projects directory not found.")
        }

        var sessions: [AgentSession] = []

        for file in recentJSONLFiles(in: projectsURL, cutoff: cutoff) {
            let id = file.url.deletingPathExtension().lastPathComponent
            guard SessionIDValidator.isValid(id, for: .claude) else { continue }

            let entries: [[String: Any]]
            do {
                entries = parseJSONLines(try readJSONLHead(of: file.url))
            } catch {
                continue
            }

            var cwd: String?
            var slug: String?
            var summary: String?
            var firstPrompt: String?
            var isSidechain = false

            for entry in entries {
                switch entry["type"] as? String {
                case "summary":
                    if let rawSummary = entry["summary"] as? String {
                        summary = normalizedTitle(rawSummary)
                    }

                case "user":
                    if entry["isSidechain"] as? Bool == true {
                        isSidechain = true
                    }
                    if cwd == nil, let rawCwd = entry["cwd"] as? String {
                        cwd = rawCwd
                    }
                    if slug == nil, let rawSlug = entry["slug"] as? String {
                        slug = rawSlug
                    }
                    if firstPrompt == nil,
                       let message = entry["message"] as? [String: Any] {
                        firstPrompt = firstSubstantivePrompt(from: message["content"])
                    }

                default:
                    break
                }
            }

            guard !isSidechain,
                  let cwd,
                  !cwd.isEmpty else {
                continue
            }

            guard summary != nil || firstPrompt != nil || slug != nil else {
                continue
            }

            let title = summary
                ?? firstPrompt
                ?? normalizedTitle(slug)
                ?? "Untitled session"

            sessions.append(
                AgentSession(
                    id: id,
                    agent: .claude,
                    projectName: projectName(for: cwd),
                    projectPath: cwd,
                    title: title,
                    lastActive: file.modified
                )
            )
        }

        return .ok(sessions)
    }

    // MARK: - Codex

    private func scanCodex(now: Date, cutoff: Date) throws -> AdapterOutput {
        let codexURL = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        guard FileManager.default.fileExists(atPath: codexURL.path) else {
            return .notInstalled("Codex data directory not found.")
        }

        let stateFiles = ((try? FileManager.default.contentsOfDirectory(
            at: codexURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter {
                $0.lastPathComponent.hasPrefix("state_")
                    && $0.pathExtension == "sqlite"
            }
            .sorted { stateVersion(of: $0) > stateVersion(of: $1) }

        guard !stateFiles.isEmpty else {
            return .notInstalled("Codex state database not found.")
        }

        var lastError: Error?
        for stateFile in stateFiles {
            do {
                let database = try SQLiteDatabase(path: stateFile.path, readOnly: false)
                guard try database.tableExists("threads") else { continue }

                var sessions: [AgentSession] = []
                let cutoffMilliseconds = Int64(cutoff.timeIntervalSince1970 * 1_000)
                let timestampSQL = "COALESCE(NULLIF(updated_at_ms, 0), updated_at * 1000)"
                let sql = """
                    SELECT id, cwd, title, name, \(timestampSQL)
                    FROM threads
                    WHERE archived = 0
                      AND \(timestampSQL) >= ?
                    ORDER BY \(timestampSQL) DESC
                    LIMIT 200
                    """

                try database.query(
                    sql,
                    bind: { statement in
                        sqlite3_bind_int64(statement, 1, cutoffMilliseconds)
                    },
                    row: { statement in
                        guard let id = database.text(statement, 0),
                              SessionIDValidator.isValid(id, for: .codex),
                              let cwd = database.text(statement, 1),
                              !cwd.isEmpty else {
                            return
                        }

                        let milliseconds = database.int64(statement, 4)
                        guard milliseconds > 0 else { return }

                        let title = normalizedTitle(database.text(statement, 3))
                            ?? normalizedTitle(database.text(statement, 2))
                            ?? "Untitled session"

                        sessions.append(
                            AgentSession(
                                id: id,
                                agent: .codex,
                                projectName: projectName(for: cwd),
                                projectPath: cwd,
                                title: title,
                                lastActive: Date(
                                    timeIntervalSince1970: Double(milliseconds) / 1_000
                                )
                            )
                        )
                    }
                )

                return .ok(sessions)
            } catch {
                lastError = error
            }
        }

        if let lastError {
            return .error(lastError.localizedDescription)
        }
        return .unsupported("Codex threads table not found.")
    }

    private func stateVersion(of url: URL) -> Int {
        let name = url.deletingPathExtension().lastPathComponent
        return Int(name.split(separator: "_").last ?? "") ?? 0
    }

    // MARK: - Pi and Oh My Pi

    private func scanPiFamily(
        agent: AgentKind,
        root: URL,
        useTitleSlot: Bool,
        now: Date,
        cutoff: Date
    ) throws -> AdapterOutput {
        guard FileManager.default.fileExists(atPath: root.path) else {
            return .notInstalled("\(agent.displayName) sessions directory not found.")
        }

        var sessions: [AgentSession] = []

        for file in recentJSONLFiles(in: root, cutoff: cutoff) {
            let entries: [[String: Any]]
            do {
                entries = parseJSONLines(try readJSONLHead(of: file.url))
            } catch {
                continue
            }

            var headerID: String?
            var headerCwd: String?
            var headerTitle: String?
            var titleSlot: String?
            var sessionInfo: String?
            var firstPrompt: String?

            for entry in entries {
                switch entry["type"] as? String {
                case "title":
                    if useTitleSlot,
                       let rawTitle = entry["title"] as? String {
                        titleSlot = normalizedTitle(rawTitle)
                    }

                case "session":
                    if headerID == nil {
                        headerID = entry["id"] as? String
                        headerCwd = entry["cwd"] as? String
                        headerTitle = normalizedTitle(entry["title"] as? String)
                    }

                case "session_info":
                    if let rawName = entry["name"] as? String,
                       !rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sessionInfo = normalizedTitle(rawName)
                    }

                case "message":
                    if firstPrompt == nil,
                       let message = entry["message"] as? [String: Any],
                       message["role"] as? String == "user" {
                        firstPrompt = firstSubstantivePrompt(from: message["content"])
                    }

                default:
                    break
                }
            }

            guard let headerID,
                  SessionIDValidator.isValid(headerID, for: agent),
                  let cwd = headerCwd,
                  !cwd.isEmpty else {
                continue
            }

            let candidates: [String?]
            if useTitleSlot {
                candidates = [titleSlot, headerTitle, sessionInfo, firstPrompt]
            } else {
                candidates = [sessionInfo, headerTitle, firstPrompt]
            }

            guard let title = candidates.compactMap({ $0 }).first else {
                continue
            }

            sessions.append(
                AgentSession(
                    id: headerID,
                    agent: agent,
                    projectName: projectName(for: cwd),
                    projectPath: cwd,
                    title: title,
                    lastActive: file.modified
                )
            )
        }

        return .ok(sessions)
    }
}
