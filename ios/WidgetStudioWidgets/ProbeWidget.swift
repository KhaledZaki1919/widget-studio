import SwiftUI
import WidgetKit
import WidgetKitCore

/// M0 probe widget (ADR-004, ADR-005): shows whether it shares the app's App Group container,
/// the test value the app wrote there, and whether location and battery work inside the
/// extension. It also saves a `WidgetReport` for the app's Diagnostics screen. Tapping it opens
/// Diagnostics. The real widgets arrive in M1–M3.
struct ProbeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WidgetStudioProbe", provider: ProbeProvider()) { entry in
            ProbeWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.probe.name")
        .description("widget.probe.description")
        // Large shows the template widgets' step log (ADR-012).
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ProbeEntry: TimelineEntry {
    let date: Date
    /// The App Group this extension resolved; nil when it fell back to its own container.
    let groupID: String?
    let report: WidgetReport?
    /// The last lines of `WidgetLog` (template widget steps).
    var log: [String] = []
    /// The widget's data sources (ADR-016).
    var sources: SourceStatus?

    var isShared: Bool { groupID != nil }
}

struct ProbeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProbeEntry {
        ProbeEntry(date: .now, groupID: "group.com.khaled.widgetstudio", report: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProbeEntry) -> Void) {
        // The widget gallery needs an answer quickly: show the last saved report.
        let location = AppGroupResolver.resolve()
        completion(ProbeEntry(date: .now, groupID: location.appGroupID,
                              report: ProbeStore(location: location).readWidgetReport(), log: WidgetLog.last(8), sources: SourceStatus.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProbeEntry>) -> Void) {
        Task { @MainActor in
            let entry = await Self.measure()
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(15 * 60))))
        }
    }

    @MainActor
    private static func measure() async -> ProbeEntry {
        let location = AppGroupResolver.resolve()
        let store = ProbeStore(location: location)
        let (authorized, fix) = await WidgetProbes.location()
        let report = WidgetReport(
            date: .now,
            bundleID: Bundle.main.bundleIdentifier ?? "",
            appGroupID: location.appGroupID,
            appHeartbeat: store.readAppHeartbeat(),
            locationAuthorizedForWidget: authorized,
            location: fix,
            battery: WidgetProbes.battery()
        )
        try? store.writeWidgetReport(report)
        return ProbeEntry(date: report.date, groupID: location.appGroupID, report: report, log: WidgetLog.last(8), sources: SourceStatus.load())
    }
}

struct ProbeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ProbeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("widget.probe.title")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text(entry.date, style: .time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            // The resolved group name, or a "no group" note (the M0 device test showed none).
            Group {
                if let groupID = entry.groupID {
                    Text(verbatim: groupID)
                } else {
                    Text("widget.probe.noGroup")
                }
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            row("widget.probe.group", ok: entry.isShared, detail: groupDetail)
            row("widget.probe.location", ok: entry.report?.location.isOK, detail: detail(entry.report?.location))
            row("widget.probe.battery", ok: entry.report?.battery.isOK, detail: detail(entry.report?.battery))
            if family == .systemLarge {
                sourcesView
                logView
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color(white: 0.055), for: .widget)
        .widgetURL(URL(string: "widgetstudio://diagnostics"))
    }

    /// Each data source as the widget sees it: ✓/✕, detail, last update.
    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Divider().overlay(Color.white.opacity(0.3)).padding(.vertical, 4)
            Text("widget.probe.sources")
                .font(.caption2.weight(.semibold))
            ForEach(SourceStatus.Source.allCases, id: \.self) { source in
                let status = entry.sources?.entries[source]
                HStack(spacing: 4) {
                    Image(systemName: status == nil ? "circle.dotted" : status?.ok == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(status == nil ? .gray : status?.ok == true ? .green : .red)
                    Text(verbatim: source.rawValue)
                    Spacer(minLength: 2)
                    Text(verbatim: [status?.detail, status?.updated.map { $0.formatted(date: .omitted, time: .shortened) }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 8, design: .monospaced))
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    /// The template widgets' last steps, newest at the bottom (system fonts only, so it renders
    /// whatever breaks the template widgets).
    private var logView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Divider().overlay(Color.white.opacity(0.3)).padding(.vertical, 4)
            Text("widget.probe.log")
                .font(.caption2.weight(.semibold))
            if entry.log.isEmpty {
                Text("widget.probe.log.empty")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(entry.log.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line)
                    .font(.system(size: 8, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.secondary)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    /// The app's test value when the widget can read it.
    private var groupDetail: String {
        guard entry.isShared else { return "—" }
        return entry.report?.appHeartbeat.map { "#\($0.testValue)" } ?? "…"
    }

    private func detail(_ outcome: ProbeOutcome?) -> String {
        switch outcome {
        case .ok(let text)?: family == .systemSmall ? String(text.prefix(12)) : text
        case .failed(let reason)?: family == .systemSmall ? "✕" : reason
        case .notRun?, nil: "…"
        }
    }

    private func row(_ title: LocalizedStringKey, ok: Bool?, detail: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: ok == true ? "checkmark.circle.fill" : ok == false ? "xmark.circle.fill" : "circle.dotted")
                .foregroundStyle(ok == true ? .green : ok == false ? .red : .gray)
            Text(title)
            Spacer(minLength: 2)
            Text(verbatim: detail)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
    }
}
