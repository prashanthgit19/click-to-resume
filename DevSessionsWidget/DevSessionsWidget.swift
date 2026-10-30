import DevSessionsCore
import SwiftUI
import WidgetKit

struct DevSessionsEntry: TimelineEntry {
    let date: Date
    let state: SharedState
    let theme: WidgetTheme
}

struct DevSessionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DevSessionsEntry {
        DevSessionsEntry(
            date: .now,
            state: DemoData.make(projectPath: "/tmp/DevSessionsPhase0"),
            theme: loadTheme()
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (DevSessionsEntry) -> Void
    ) {
        completion(
            DevSessionsEntry(
                date: .now,
                state: loadState(),
                theme: loadTheme()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<DevSessionsEntry>) -> Void
    ) {
        let entry = DevSessionsEntry(
            date: .now,
            state: loadState(),
            theme: loadTheme()
        )
        let next = Calendar.current.date(
            byAdding: .minute,
            value: 15,
            to: .now
        ) ?? .now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadTheme() -> WidgetTheme {
        SharedStore.appGroup()?.loadWidgetTheme() ?? .midnight
    }

    private func loadState() -> SharedState {
        guard let store = SharedStore.appGroup(),
              let state = try? store.load() else {
            return SharedState.empty()
        }
        return state
    }
}

struct DevSessionsWidget: Widget {
    private let kind = "DevSessionsWidgetV5"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DevSessionsProvider()) { entry in
            DevSessionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent DevSessions")
        .description("See recently active OpenCode, Claude Code, Codex, Pi, and Oh My Pi sessions.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
