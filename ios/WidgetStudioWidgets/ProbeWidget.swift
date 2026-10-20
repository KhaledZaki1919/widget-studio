import SwiftUI
import WidgetKit
import WidgetKitCore

/// M0 probe widget: shows whether it shares the app's App Group container and the test value
/// the app wrote there (ADR-004, ADR-005). The real widgets arrive in M1–M3.
struct ProbeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WidgetStudioProbe", provider: ProbeProvider()) { entry in
            ProbeWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.probe.name")
        .description("widget.probe.description")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ProbeEntry: TimelineEntry {
    let date: Date
    let isShared: Bool
    let appHeartbeat: AppHeartbeat?
}

struct ProbeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProbeEntry {
        ProbeEntry(date: .now, isShared: true, appHeartbeat: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProbeEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProbeEntry>) -> Void) {
        let entry = makeEntry()
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(15 * 60))))
    }

    private func makeEntry() -> ProbeEntry {
        let location = AppGroupResolver.resolve()
        let store = ProbeStore(location: location)
        return ProbeEntry(date: .now, isShared: location.isShared, appHeartbeat: store.readAppHeartbeat())
    }
}

struct ProbeWidgetView: View {
    let entry: ProbeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("widget.probe.title")
                .font(.headline)
            Spacer(minLength: 0)
            if !entry.isShared {
                Text("widget.probe.noGroup")
                    .font(.footnote)
            } else if let heartbeat = entry.appHeartbeat {
                Text("widget.probe.value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(heartbeat.testValue)")
                    .font(.title2.monospacedDigit())
            } else {
                Text("widget.probe.openApp")
                    .font(.footnote)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color(white: 0.055), for: .widget)
    }
}
