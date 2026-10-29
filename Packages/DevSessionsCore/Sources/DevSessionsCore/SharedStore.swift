import Foundation

public enum AppGroup {
    /// Must match Config/DevSessions.entitlements and Config/DevSessionsWidget.entitlements.
    /// Change this if your team requires a team-scoped App Group identifier.
    public static let identifier = "67Z29VG25Z.com.devsessions.shared2"
}

public struct SharedStore: Sendable {
    public let directoryURL: URL

    public var fileURL: URL {
        directoryURL.appendingPathComponent("state.json")
    }

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public static func appGroup() -> SharedStore? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            return nil
        }
        return SharedStore(
            directoryURL: container.appendingPathComponent("DevSessions", isDirectory: true)
        )
    }

    public func load() throws -> SharedState {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SharedState.self, from: data)
    }

    public func save(_ state: SharedState) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directoryURL.path
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}
