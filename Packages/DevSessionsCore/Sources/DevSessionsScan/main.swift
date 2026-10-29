import Foundation
import DevSessionsCore

let arguments = CommandLine.arguments
var days = 30

if let index = arguments.firstIndex(of: "--days"),
   index + 1 < arguments.count,
   let value = Int(arguments[index + 1]) {
    days = value
}

let scanner = SessionScanner(windowDays: days)
let result = scanner.scan()
let formatter = ISO8601DateFormatter()

print("Scanned \(result.sessions.count) session(s) within \(days) day(s)")
print("Generated: \(formatter.string(from: result.generatedAt))")
print("")

for diagnostic in result.diagnostics {
    let suffix = diagnostic.message.map { " — \($0)" } ?? ""
    print("\(diagnostic.agent.displayName): \(diagnostic.status.rawValue) (\(diagnostic.sessionCount))\(suffix)")
}

print("")
for session in result.sessions {
    print(
        "\(session.agent.displayName)\t\(session.projectName)\t\(session.title)\t\(formatter.string(from: session.lastActive))\t\(session.id)"
    )
}
