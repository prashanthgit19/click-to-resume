import Darwin
import Foundation
import DevSessionsCore

var failures = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() {
        return
    }
    failures += 1
    fputs("FAIL: \(message)\n", stderr)
}

func runChecks() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("DevSessionsChecks-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    // Shared state round trip and activity-window filtering.
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let state = DemoData.make(projectPath: "/tmp/DevSessionsPhase0", now: now)
    let store = SharedStore(directoryURL: tempRoot.appendingPathComponent("shared", isDirectory: true))

    try store.save(state)
    let loaded = try store.load()

    expect(loaded.schemaVersion == SharedState.currentSchemaVersion, "schema version survives round trip")
    expect(loaded.activityWindowDays == 7, "activity window survives round trip")
    expect(loaded.sessions.map(\.cacheKey) == state.sessions.map(\.cacheKey), "session identity survives round trip")
    expect(loaded.sessions.map(\.title) == state.sessions.map(\.title), "titles survive round trip")
    expect(
        loaded.sessions(withinDays: 1, now: now).map(\.agent) == [.opencode, .claude],
        "1-day filter keeps the two recent demo sessions"
    )
    expect(loaded.sessions(withinDays: 3, now: now).count == 3, "3-day filter keeps all demo sessions")

    // Owner-only cache permissions.
    let attributes = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
    let permissions = attributes[.posixPermissions] as? NSNumber
    expect(permissions?.intValue == 0o600, "state file is 0600")

    let directoryAttributes = try FileManager.default.attributesOfItem(atPath: store.directoryURL.path)
    let directoryPermissions = directoryAttributes[.posixPermissions] as? NSNumber
    expect(directoryPermissions?.intValue == 0o700, "state directory is 0700")

    // URL scheme round trip and validation.
    let claudeID = "11111111-1111-4111-8111-111111111111"
    let resumeURL = DeepLink.resumeURL(agent: .claude, sessionID: claudeID)
    expect(
        DeepLink.parse(resumeURL) == .resume(agent: .claude, sessionID: claudeID),
        "resume deep link round trips"
    )
    expect(DeepLink.parse(DeepLink.settingsURL) == .settings, "settings deep link parses")
    expect(
        DeepLink.parse(URL(string: "devsessions://resume?agent=opencode&id=bad")!) == nil,
        "invalid session id is rejected by deep link parser"
    )
    expect(
        DeepLink.parse(URL(string: "https://example.com")!) == nil,
        "foreign URL is rejected"
    )

    // Session ID formats.
    expect(SessionIDValidator.isValid("ses_abc123", for: .opencode), "valid OpenCode id accepted")
    expect(!SessionIDValidator.isValid("ses_", for: .opencode), "empty OpenCode id rejected")
    expect(!SessionIDValidator.isValid("ses_abc-123", for: .opencode), "malformed OpenCode id rejected")
    expect(SessionIDValidator.isValid(claudeID, for: .codex), "UUID accepted for Codex")
    expect(!SessionIDValidator.isValid("not-a-uuid", for: .claude), "invalid Claude id rejected")

    // Resume commands.
    expect(
        ResumeCommand.arguments(for: .opencode, sessionID: "ses_abc123")
            == ["--session", "ses_abc123"],
        "OpenCode resume arguments"
    )
    expect(
        ResumeCommand.arguments(for: .claude, sessionID: claudeID)
            == ["--resume", claudeID],
        "Claude resume arguments"
    )
    let codexID = "22222222-2222-4222-8222-222222222222"
    expect(
        ResumeCommand.arguments(for: .codex, sessionID: codexID)
            == ["resume", codexID],
        "Codex resume arguments"
    )

    // Shell quoting and the Phase 0 hand-off script.
    expect(CommandScriptBuilder.shellQuote("a'b") == "'a'\\''b'", "single quotes are escaped")
    let session = AgentSession(
        id: "ses_abc123",
        agent: .opencode,
        projectName: "DAFE",
        projectPath: "/tmp/a'b $HOME",
        title: "Feature generation",
        lastActive: Date()
    )
    let script = CommandScriptBuilder.demoScript(for: session)
    expect(script.hasPrefix("#!/bin/zsh -l\n"), "script has zsh shebang")
    expect(
        script.contains("cd -- " + CommandScriptBuilder.shellQuote(session.projectPath)),
        "script quotes the project path"
    )
    expect(script.contains("Directory: $(pwd)"), "script prints the working directory")
}

do {
    try runChecks()
    if failures > 0 {
        fputs("\(failures) check(s) failed.\n", stderr)
        exit(1)
    }
    print("All DevSessionsCore checks passed.")
} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1)
}
