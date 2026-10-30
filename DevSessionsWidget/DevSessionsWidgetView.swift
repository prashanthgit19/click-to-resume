import AppKit
import DevSessionsCore
import SwiftUI
import WidgetKit

struct DevSessionsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DevSessionsEntry

    private var sessions: [AgentSession] {
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
        return Array(allSessions.prefix(limit))
    }

    private var allSessions: [AgentSession] {
        entry.state.sessions(
            withinDays: entry.state.activityWindowDays,
            now: entry.date
        )
    }

    private var totalSessions: Int { allSessions.count }

    private var agentCount: Int {
        Set(allSessions.map(\.agent)).count
    }

    private var windowLabel: String {
        entry.state.activityWindowFooterText
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                WidgetBackground()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemMedium:
            mediumLayout
        case .systemLarge:
            largeLayout
        default:
            mediumLayout
        }
    }

    // MARK: - Small

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)

            if let session = sessions.first {
                Link(
                    destination: DeepLink.resumeURL(
                        agent: session.agent,
                        sessionID: session.id
                    )
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        SessionRing(
                            session: session,
                            progress: recency(for: session),
                            diameter: 46,
                            lineWidth: 3
                        )

                        Text(session.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)

                        HStack(spacing: 4) {
                            Text(session.agent.displayName)
                                .foregroundStyle(session.agent.accent)
                            Text("·")
                                .foregroundStyle(Theme.tertiary)
                            Text(session.projectName)
                                .foregroundStyle(Theme.secondary)
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Resume \(session.title) in \(session.projectName), "
                        + "\(session.agent.displayName), "
                        + "active \(relativeDescription(for: session))"
                )

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Text(session.lastActive, style: .relative)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                    Spacer(minLength: 4)
                    Text(windowLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
            } else {
                Spacer(minLength: 0)
                emptyState
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 2)

            if sessions.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions, id: \.cacheKey) { session in
                        SessionRow(
                            session: session,
                            progress: recency(for: session),
                            ringSize: 30,
                            titleSize: 12.5,
                            subtitleSize: 10,
                            timeSize: 10
                        )

                        if session.cacheKey != sessions.last?.cacheKey {
                            RowDivider()
                        }
                    }
                }
            }

            Spacer(minLength: 2)

            HStack(spacing: 4) {
                Text("\(totalSessions) sessions")
                Text("·")
                Text(windowLabel)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.tertiary)
        }
    }

    // MARK: - Large

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 2)

            if sessions.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions, id: \.cacheKey) { session in
                        SessionRow(
                            session: session,
                            progress: recency(for: session),
                            ringSize: 26,
                            titleSize: 11.5,
                            subtitleSize: 10,
                            timeSize: 10
                        )

                        if session.cacheKey != sessions.last?.cacheKey {
                            RowDivider()
                        }
                    }
                }

                Spacer(minLength: 3)
                activitySection
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text(windowLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
            }

            ActivitySparkline(
                values: activityValues(),
                windowLabel: windowLabel,
                totalSessions: totalSessions,
                agentCount: agentCount
            )
            .frame(height: 30)

            HStack {
                Text("\(totalSessions) sessions")
                Spacer()
                Text("\(agentCount) agents")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.tertiary)
        }
    }

    // MARK: - Shared pieces

    private var header: some View {
        HStack(spacing: 5) {
            BrandMark(size: 11)

            Text("DevSessions")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.primary)

            Spacer(minLength: 4)

            Link(destination: DeepLink.settingsURL) {
                Image(systemName: "gearshape")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            BrandMark(size: 24)

            Text("No sessions yet")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.primary)

            Text("Open DevSessions to scan.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func recency(for session: AgentSession) -> Double {
        let days = max(entry.state.activityWindowDays, 1)
        let span = Double(days) * 86_400
        let age = max(0, entry.date.timeIntervalSince(session.lastActive))
        return max(0.12, min(1, 1 - age / span))
    }

    private func relativeDescription(for session: AgentSession) -> String {
        session.lastActive.formatted(.relative(presentation: .named))
    }

    private func activityValues(bucketCount: Int = 16) -> [Double] {
        let days = max(entry.state.activityWindowDays, 1)
        let span = Double(days) * 86_400
        let start = entry.date.addingTimeInterval(-span)
        var counts = Array(repeating: 0, count: bucketCount)

        for session in allSessions {
            let offset = session.lastActive.timeIntervalSince(start)
            guard offset >= 0, offset < span else { continue }
            let index = min(
                bucketCount - 1,
                Int(offset / span * Double(bucketCount))
            )
            counts[index] += 1
        }

        return counts.map(Double.init)
    }
}

// MARK: - Row

private struct SessionRow: View {
    let session: AgentSession
    let progress: Double
    let ringSize: CGFloat
    let titleSize: CGFloat
    let subtitleSize: CGFloat
    let timeSize: CGFloat

    var body: some View {
        Link(
            destination: DeepLink.resumeURL(
                agent: session.agent,
                sessionID: session.id
            )
        ) {
            HStack(spacing: 9) {
                SessionRing(
                    session: session,
                    progress: progress,
                    diameter: ringSize,
                    lineWidth: max(2, ringSize * 0.075)
                )

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(session.title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        Text(session.agent.displayName)
                            .foregroundStyle(session.agent.accent)
                        Text("·")
                            .foregroundStyle(Theme.tertiary)
                        Text(session.projectName)
                            .foregroundStyle(Theme.secondary)
                    }
                    .font(.system(size: subtitleSize, weight: .medium))
                    .lineLimit(1)
                }

                Spacer(minLength: 3)

                Text(session.lastActive, style: .relative)
                    .font(.system(size: timeSize, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 26, alignment: .trailing)
            }
            .padding(.vertical, ringSize > 30 ? 7 : 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Resume \(session.title) in \(session.projectName), "
                + "\(session.agent.displayName), "
                + "active \(session.lastActive.formatted(.relative(presentation: .named)))"
        )
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 0.5)
            .padding(.leading, 35)
    }
}

// MARK: - Ring

private struct SessionRing: View {
    let session: AgentSession
    let progress: Double
    let diameter: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(
                    AngularGradient(
                        colors: [
                            session.agent.accent.opacity(0.35),
                            session.agent.accent
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            Text(session.agent.monogram)
                .font(
                    .system(
                        size: max(8, diameter * 0.28),
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(session.agent.accent)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

// MARK: - Brand mark

private struct BrandMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.86)
                .stroke(
                    LinearGradient(
                        colors: [Theme.violet, Theme.rose],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: max(1.2, size * 0.12),
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-20))

            Circle()
                .fill(Theme.peach)
                .frame(
                    width: max(2.4, size * 0.22),
                    height: max(2.4, size * 0.22)
                )
                .offset(x: size * 0.34, y: -size * 0.34)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Activity chart

private struct ActivitySparkline: View {
    let values: [Double]
    let windowLabel: String
    let totalSessions: Int
    let agentCount: Int

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let points = makePoints(in: size)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height - 0.5))
                    path.addLine(
                        to: CGPoint(x: size.width, y: size.height - 0.5)
                    )
                }
                .stroke(Theme.separator, lineWidth: 0.5)

                areaPath(points, in: size)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.violet.opacity(0.30),
                                Theme.rose.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                linePath(points)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.violet, Theme.rose],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 1.6,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                Circle()
                    .fill(Theme.rose)
                    .frame(width: 3.2, height: 3.2)
                    .position(points.last ?? .zero)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Session activity over the \(windowLabel.lowercased()). "
                + "\(totalSessions) sessions from \(agentCount) agents."
        )
    }

    private func makePoints(in size: CGSize) -> [CGPoint] {
        let maxValue = max(values.max() ?? 0, 1)
        let step = values.count > 1
            ? size.width / CGFloat(values.count - 1)
            : 0

        return values.enumerated().map { index, value in
            let x = CGFloat(index) * step
            let normalized = value / maxValue
            let y = size.height - 2 - CGFloat(normalized) * (size.height - 4)
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else {
            return path
        }

        path.move(to: first)

        guard points.count > 2 else {
            path.addLine(to: last)
            return path
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(
                x: (previous.x + current.x) / 2,
                y: (previous.y + current.y) / 2
            )
            path.addQuadCurve(to: midpoint, control: previous)
        }

        path.addLine(to: last)
        return path
    }

    private func areaPath(_ points: [CGPoint], in size: CGSize) -> Path {
        var path = linePath(points)
        guard let first = points.first, let last = points.last else {
            return path
        }

        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Theme

private enum Theme {
    static let primary = Color(hex: 0xF7F3FC)
    static let secondary = Color(hex: 0xC2B7D0)
    static let tertiary = Color(hex: 0x9E92AD)
    static let separator = Color.white.opacity(0.08)
    static let ringTrack = Color.white.opacity(0.10)
    static let violet = Color(hex: 0x9B8CFF)
    static let rose = Color(hex: 0xF3A6C8)
    static let peach = Color(hex: 0xFFC29B)
}

private struct WidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1A1128), Color(hex: 0x28163A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(hex: 0x8B5CF6).opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 220
            )

            RadialGradient(
                colors: [Color(hex: 0xE879B9).opacity(0.10), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 180
            )
        }
    }
}

// MARK: - Agent identity

private extension AgentKind {
    var accent: Color {
        switch self {
        case .opencode:
            return Color(hex: 0xB4A7FF)
        case .claude:
            return Color(hex: 0xFFC29B)
        case .codex:
            return Color(hex: 0x8BE8D6)
        case .pi:
            return Color(hex: 0xFFE08A)
        case .omp:
            return Color(hex: 0xF5A8C8)
        }
    }

    var monogram: String {
        switch self {
        case .opencode:
            return "O"
        case .claude:
            return "C"
        case .codex:
            return "X"
        case .pi:
            return "π"
        case .omp:
            return "Ω"
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
