import Foundation
import DevSessionsCore

func runScannerChecks() throws {
    let fileManager = FileManager.default
    let home = fileManager.temporaryDirectory
        .appendingPathComponent("DevSessionsScannerChecks-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: home) }

    let now = Date()
    let recent = now.addingTimeInterval(-30 * 60)
    let old = now.addingTimeInterval(-40 * 24 * 60 * 60)

    let opencodeID = "ses_fixture0000000000000000000001"
    let claudeID = "11111111-1111-4111-8111-111111111111"
    let codexID = "22222222-2222-4222-8222-222222222222"
    let piID = "33333333-3333-4333-8333-333333333333"
    let ompID = "44444444-4444-4444-8444-444444444444"
    let oldClaudeID = "55555555-5555-4555-8555-555555555555"
    let sidechainClaudeID = "66666666-6666-4666-8666-666666666666"
    let opencodeChildID = "ses_fixturechild000000000000000001"
    let opencodeArchivedID = "ses_fixturearchived00000000000001"
    let codexArchivedID = "77777777-7777-4777-8777-777777777777"

    try makeOpenCodeFixture(
        home: home,
        now: now,
        id: opencodeID,
        childID: opencodeChildID,
        archivedID: opencodeArchivedID
    )
    try makeCodexFixture(
        home: home,
        now: now,
        id: codexID,
        archivedID: codexArchivedID
    )
    try makeClaudeFixture(
        home: home,
        id: claudeID,
        modified: recent,
        cwd: "/tmp/claude-project",
        prompt: "Claude fixture prompt",
        summary: "Claude fixture summary",
        isSidechain: false
    )
    try makeClaudeFixture(
        home: home,
        id: oldClaudeID,
        modified: old,
        cwd: "/tmp/claude-old-project",
        prompt: "Old Claude prompt",
        summary: "Old Claude summary",
        isSidechain: false
    )
    try makeClaudeFixture(
        home: home,
        id: sidechainClaudeID,
        modified: recent,
        cwd: "/tmp/claude-sidechain-project",
        prompt: "Sidechain prompt",
        summary: "Sidechain summary",
        isSidechain: true
    )
    try makePiFixture(
        home: home,
        id: piID,
        modified: recent,
        cwd: "/tmp/pi-project",
        sessionInfoName: "Pi fixture session",
        prompt: "Pi fixture prompt"
    )
    try makeOMPFixture(
        home: home,
        id: ompID,
        modified: recent,
        cwd: "/tmp/omp-project",
        title: "OMP fixture session",
        prompt: "OMP fixture prompt"
    )

    let scanner = SessionScanner(homeDirectory: home, windowDays: 30)
    let result = scanner.scan(now: now)

    expect(result.sessions.count == 5, "scanner returns exactly five fixture sessions")
    expect(result.diagnostics.count == 5, "scanner returns five diagnostics")
    expect(
        result.diagnostics.allSatisfy { $0.status == .ok },
        "all five agents report ok for valid fixtures"
    )

    func session(for agent: AgentKind) -> AgentSession? {
        result.sessions.first { $0.agent == agent }
    }

    expect(session(for: .opencode)?.id == opencodeID, "OpenCode fixture is discovered")
    expect(
        session(for: .opencode)?.title == "OpenCode fixture session",
        "OpenCode fixture title"
    )
    expect(session(for: .claude)?.id == claudeID, "Claude fixture is discovered")
    expect(
        session(for: .claude)?.title == "Claude fixture summary",
        "Claude summary wins over the prompt"
    )
    expect(session(for: .codex)?.id == codexID, "Codex fixture is discovered")
    expect(
        session(for: .codex)?.title == "Codex fixture session",
        "Codex name wins over title"
    )
    expect(session(for: .pi)?.id == piID, "Pi fixture is discovered")
    expect(
        session(for: .pi)?.title == "Pi fixture session",
        "Pi session_info name wins over the prompt"
    )
    expect(session(for: .omp)?.id == ompID, "Oh My Pi fixture is discovered")
    expect(
        session(for: .omp)?.title == "OMP fixture session",
        "Oh My Pi title slot wins"
    )

    expect(
        result.sessions.map(\.projectName).sorted()
            == ["claude-project", "codex-project", "omp-project", "opencode-project", "pi-project"],
        "project names are derived from session cwd"
    )
    expect(
        result.sessions.allSatisfy { $0.lastActive >= now.addingTimeInterval(-30 * 86_400) },
        "sessions are filtered by the 30-day window"
    )
    expect(
        !result.sessions.contains { $0.id == oldClaudeID },
        "old Claude session is excluded"
    )
    expect(
        !result.sessions.contains { $0.id == sidechainClaudeID },
        "Claude sidechain session is excluded"
    )
    expect(
        !result.sessions.contains { $0.id == opencodeChildID || $0.id == opencodeArchivedID },
        "OpenCode child and archived sessions are excluded"
    )
    expect(
        !result.sessions.contains { $0.id == codexArchivedID },
        "Codex archived session is excluded"
    )

    let sorted = result.sessions.map(\.lastActive)
    expect(sorted == sorted.sorted(by: >), "sessions are sorted newest first")
}

// MARK: - Fixtures

private func writeJSONL(_ objects: [[String: Any]], to url: URL, modified: Date) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let lines = try objects.map { object -> String in
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
    try (lines.joined(separator: "\n") + "\n").write(
        to: url,
        atomically: true,
        encoding: .utf8
    )
    try fileManager.setAttributes(
        [.modificationDate: modified],
        ofItemAtPath: url.path
    )
}

private func makeOpenCodeFixture(
    home: URL,
    now: Date,
    id: String,
    childID: String,
    archivedID: String
) throws {
    let directory = home
        .appendingPathComponent(".local", isDirectory: true)
        .appendingPathComponent("share", isDirectory: true)
        .appendingPathComponent("opencode", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let milliseconds = Int64(now.timeIntervalSince1970 * 1_000)
    let sql = """
        CREATE TABLE session_v2 (
            id TEXT PRIMARY KEY,
            title TEXT,
            slug TEXT,
            directory TEXT,
            parent_id TEXT,
            time_updated INTEGER,
            time_archived INTEGER
        );
        INSERT INTO session_v2 VALUES ('\(id)', 'OpenCode fixture session', 'fixture', '/tmp/opencode-project', NULL, \(milliseconds), NULL);
        INSERT INTO session_v2 VALUES ('\(childID)', 'OpenCode child', 'child', '/tmp/opencode-project', '\(id)', \(milliseconds), NULL);
        INSERT INTO session_v2 VALUES ('\(archivedID)', 'OpenCode archived', 'archived', '/tmp/opencode-project', NULL, \(milliseconds), \(milliseconds));
        """

    try runSQLite(at: directory.appendingPathComponent("opencode.db"), sql: sql)
}

private func makeCodexFixture(
    home: URL,
    now: Date,
    id: String,
    archivedID: String
) throws {
    let directory = home.appendingPathComponent(".codex", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let milliseconds = Int64(now.timeIntervalSince1970 * 1_000)
    let seconds = Int64(now.timeIntervalSince1970)
    let sql = """
        CREATE TABLE threads (
            id TEXT PRIMARY KEY,
            cwd TEXT,
            title TEXT,
            name TEXT,
            updated_at_ms INTEGER,
            updated_at INTEGER,
            archived INTEGER
        );
        INSERT INTO threads VALUES ('\(id)', '/tmp/codex-project', 'Codex fixture title', 'Codex fixture session', \(milliseconds), \(seconds), 0);
        INSERT INTO threads VALUES ('\(archivedID)', '/tmp/codex-project', 'Codex archived title', NULL, \(milliseconds), \(seconds), 1);
        """

    try runSQLite(at: directory.appendingPathComponent("state_5.sqlite"), sql: sql)
}

private func makeClaudeFixture(
    home: URL,
    id: String,
    modified: Date,
    cwd: String,
    prompt: String,
    summary: String,
    isSidechain: Bool
) throws {
    let directory = home
        .appendingPathComponent(".claude", isDirectory: true)
        .appendingPathComponent("projects", isDirectory: true)
        .appendingPathComponent("-tmp-claude-project", isDirectory: true)
    let file = directory.appendingPathComponent("\(id).jsonl")

    let objects: [[String: Any]] = [
        [
            "type": "user",
            "cwd": cwd,
            "slug": "fixture-slug",
            "isSidechain": isSidechain,
            "message": [
                "role": "user",
                "content": prompt
            ]
        ],
        [
            "type": "summary",
            "summary": summary
        ]
    ]

    try writeJSONL(objects, to: file, modified: modified)
}

private func makePiFixture(
    home: URL,
    id: String,
    modified: Date,
    cwd: String,
    sessionInfoName: String,
    prompt: String
) throws {
    let directory = home
        .appendingPathComponent(".pi", isDirectory: true)
        .appendingPathComponent("agent", isDirectory: true)
        .appendingPathComponent("sessions", isDirectory: true)
        .appendingPathComponent("--tmp-pi-project--", isDirectory: true)
    let file = directory.appendingPathComponent("2026-10-30T00-00-00-000Z_\(id).jsonl")

    let objects: [[String: Any]] = [
        [
            "type": "session",
            "version": 3,
            "id": id,
            "timestamp": "2026-10-30T00:00:00.000Z",
            "cwd": cwd
        ],
        [
            "type": "session_info",
            "name": sessionInfoName
        ],
        [
            "type": "message",
            "message": [
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt]
                ]
            ]
        ]
    ]

    try writeJSONL(objects, to: file, modified: modified)

    // A nested subagent transcript must not be treated as a top-level session.
    try writeJSONL(
        [
            [
                "type": "session",
                "version": 3,
                "id": "88888888-8888-4888-8888-888888888888",
                "timestamp": "2026-10-30T00:00:00.000Z",
                "cwd": cwd
            ],
            [
                "type": "session_info",
                "name": "Nested Pi subagent"
            ]
        ],
        to: directory
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("subagent.jsonl"),
        modified: modified
    )
}

private func makeOMPFixture(
    home: URL,
    id: String,
    modified: Date,
    cwd: String,
    title: String,
    prompt: String
) throws {
    let directory = home
        .appendingPathComponent(".omp", isDirectory: true)
        .appendingPathComponent("agent", isDirectory: true)
        .appendingPathComponent("sessions", isDirectory: true)
        .appendingPathComponent("--tmp-omp-project--", isDirectory: true)
    let file = directory.appendingPathComponent("2026-10-30T00-00-00-000Z_\(id).jsonl")

    let titleLine = #"{"type":"title","title":"\#(title)"}"#
        .padding(toLength: 255, withPad: " ", startingAt: 0)
    let header = try JSONSerialization.data(
        withJSONObject: [
            "type": "session",
            "version": 3,
            "id": id,
            "timestamp": "2026-10-30T00:00:00.000Z",
            "cwd": cwd,
            "title": "OMP header title"
        ],
        options: [.sortedKeys]
    )
    let message = try JSONSerialization.data(
        withJSONObject: [
            "type": "message",
            "message": [
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt]
                ]
            ]
        ],
        options: [.sortedKeys]
    )

    let contents = titleLine + "\n"
        + String(decoding: header, as: UTF8.self) + "\n"
        + String(decoding: message, as: UTF8.self) + "\n"

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try contents.write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.modificationDate: modified],
        ofItemAtPath: file.path
    )
}

private func runSQLite(at url: URL, sql: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [url.path]

    let input = Pipe()
    let error = Pipe()
    process.standardInput = input
    process.standardError = error

    try process.run()
    input.fileHandleForWriting.write(Data(sql.utf8))
    try input.fileHandleForWriting.close()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let message = String(
            decoding: error.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        throw NSError(
            domain: "DevSessionsScannerChecks",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
