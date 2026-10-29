import AppKit
import DevSessionsCore
import SwiftUI
import WidgetKit

struct DevSessionsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DevSessionsEntry

    private var sessions: [AgentSession] {
        // Phase 0 uses conservative counts so the skeleton never clips.
        // Phase 3 tunes these against the shipping widget sizes.
        let limit: Int
        switch family {
        case .systemSmall:
            limit = 1
        case .systemMedium:
            limit = 2
        case .systemLarge:
            limit = 6
        default:
            limit = 2
        }
        return Array(
            entry.state
                .sessions(withinDays: entry.state.activityWindowDays)
                .prefix(limit)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if sessions.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sessions, id: \.cacheKey) { session in
                        SessionRowView(session: session)
                    }
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 0)

            Text(entry.state.activityWindowFooterText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal.fill")
                .font(.caption)
            Text("DevSessions")
                .font(.headline)
            Spacer(minLength: 4)
            Link(destination: DeepLink.settingsURL) {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Text("No sessions")
                .font(.subheadline.weight(.semibold))
            Text("Open DevSessions to scan.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }
}

private struct SessionRowView: View {
    let session: AgentSession

    var body: some View {
        Link(destination: DeepLink.resumeURL(agent: session.agent, sessionID: session.id)) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(session.projectName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(session.lastActive, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text("\(session.agent.displayName) · \(session.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume \(session.title) in \(session.projectName)")
    }
}
