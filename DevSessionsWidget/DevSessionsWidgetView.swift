import AppKit
import DevSessionsCore
import SwiftUI
import WidgetKit

struct DevSessionsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    let entry: DevSessionsEntry

    private var palette: WidgetPalette {
        WidgetPalette.resolve(
            theme: entry.theme,
            colorScheme: colorScheme,
            renderingMode: renderingMode
        )
    }

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
                WidgetBackground(palette: palette)
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
                            lineWidth: 3,
                            palette: palette
                        )

                        HStack(alignment: .center, spacing: 6) {
                            Text(session.projectName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(palette.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)

                            Spacer(minLength: 4)

                            RedirectArrow(palette: palette, size: 22)
                        }

                        HStack(spacing: 4) {
                            Text(session.agent.displayName)
                                .foregroundStyle(palette.accent(for: session.agent))
                                .widgetAccentable()
                            Text("·")
                                .foregroundStyle(palette.tertiary)
                            Text(session.title)
                                .foregroundStyle(palette.secondary)
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
                        .foregroundStyle(palette.secondary)
                    Spacer(minLength: 4)
                    Text(windowLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.tertiary)
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
                            timeSize: 10,
                            palette: palette
                        )

                        if session.cacheKey != sessions.last?.cacheKey {
                            RowDivider(palette: palette)
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
            .foregroundStyle(palette.tertiary)
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
                            timeSize: 10,
                            palette: palette
                        )

                        if session.cacheKey != sessions.last?.cacheKey {
                            RowDivider(palette: palette)
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
                    .foregroundStyle(palette.secondary)
                Spacer()
                Text(windowLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.tertiary)
            }

            ActivitySparkline(
                values: activityValues(),
                windowLabel: windowLabel,
                totalSessions: totalSessions,
                agentCount: agentCount,
                palette: palette
            )
            .frame(height: 30)

            HStack {
                Text("\(totalSessions) sessions")
                Spacer()
                Text("\(agentCount) agents")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(palette.tertiary)
        }
    }

    // MARK: - Shared pieces

    private var header: some View {
        HStack(spacing: 5) {
            BrandMark(palette: palette, size: 11)

            Text("DevSessions")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(palette.primary)

            Spacer(minLength: 4)

            Link(destination: DeepLink.settingsURL) {
                Image(systemName: "gearshape")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.tertiary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            BrandMark(palette: palette, size: 24)

            Text("No sessions yet")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text("Open DevSessions to scan.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.secondary)
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
    let palette: WidgetPalette

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
                    lineWidth: max(2, ringSize * 0.075),
                    palette: palette
                )

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(session.projectName)
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(palette.primary)
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        Text(session.agent.displayName)
                            .foregroundStyle(palette.accent(for: session.agent))
                            .widgetAccentable()
                        Text("·")
                            .foregroundStyle(palette.tertiary)
                        Text(session.title)
                            .foregroundStyle(palette.secondary)
                    }
                    .font(.system(size: subtitleSize, weight: .medium))
                    .lineLimit(1)
                }

                Spacer(minLength: 3)

                HStack(spacing: 6) {
                    Text(session.lastActive, style: .relative)
                        .font(.system(size: timeSize, weight: .medium))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)

                    RedirectArrow(
                        palette: palette,
                        size: ringSize > 28 ? 20 : 18
                    )
                }
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
    let palette: WidgetPalette

    var body: some View {
        Rectangle()
            .fill(palette.separator)
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
    let palette: WidgetPalette

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.ringTrack, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(
                    AngularGradient(
                        colors: [
                            palette.accent(for: session.agent).opacity(0.35),
                            palette.accent(for: session.agent)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()

            Text(session.agent.monogram)
                .font(
                    .system(
                        size: max(8, diameter * 0.28),
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(palette.accent(for: session.agent))
                .widgetAccentable()
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

// MARK: - Brand mark

private struct BrandMark: View {
    let palette: WidgetPalette
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.86)
                .stroke(
                    LinearGradient(
                        colors: [palette.brandStart, palette.brandEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: max(1.2, size * 0.12),
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-20))
                .widgetAccentable()

            Circle()
                .fill(palette.brandDot)
                .frame(
                    width: max(2.4, size * 0.22),
                    height: max(2.4, size * 0.22)
                )
                .offset(x: size * 0.34, y: -size * 0.34)
                .widgetAccentable()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Redirect arrow

private struct RedirectArrow: View {
    let palette: WidgetPalette
    let size: CGFloat

    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(palette.primary.opacity(0.92))
            .frame(width: size, height: size)
            .background(Circle().fill(palette.arrowBackground))
            .overlay(Circle().stroke(palette.separator, lineWidth: 0.5))
            .widgetAccentable()
            .accessibilityHidden(true)
    }
}

// MARK: - Activity chart

private struct ActivitySparkline: View {
    let values: [Double]
    let windowLabel: String
    let totalSessions: Int
    let agentCount: Int
    let palette: WidgetPalette

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
                .stroke(palette.separator, lineWidth: 0.5)

                areaPath(points, in: size)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.chartStart.opacity(0.30),
                                palette.chartEnd.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                linePath(points)
                    .stroke(
                        LinearGradient(
                            colors: [palette.chartStart, palette.chartEnd],
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
                    .fill(palette.chartEnd)
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

// MARK: - Background

private struct WidgetBackground: View {
    let palette: WidgetPalette

    var body: some View {
        if palette.isTransparent {
            Color.clear
        } else {
            ZStack {
                LinearGradient(
                    colors: palette.background,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [palette.glow.opacity(0.22), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 220
                )

                RadialGradient(
                    colors: [palette.glowSecondary.opacity(0.10), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 180
                )
            }
        }
    }
}

// MARK: - Agent monogram

private extension AgentKind {
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
