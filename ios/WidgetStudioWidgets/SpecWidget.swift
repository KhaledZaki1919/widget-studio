import os
import SwiftUI
import WidgetKit
import WidgetKitCore

// Template widgets (ADR-013): one StaticConfiguration widget per template, in the template's
// own size. The owner's M2 device test showed StaticConfiguration rendering a template on the
// Fast Store install while every AppIntentConfiguration widget stayed gray, even in the gallery.
// The user picks a template by swiping the widget gallery, which previews each real design.
// Each step is written to `WidgetLog` (shown by the large check widget), and anything that goes
// wrong shows a plain error text.

struct TemplateWidget<ID: TemplateIdentity>: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WidgetStudio.\(ID.id)", provider: TemplateProvider(templateID: ID.id)) {
            TemplateWidgetView(entry: $0)
        }
        .configurationDisplayName(Self.name)
        .description(Self.summary)
        .supportedFamilies(Self.families)
        .contentMarginsDisabled()
    }

    private static var spec: WidgetSpec? { TemplateLibrary.template(id: ID.id) }

    static var name: String {
        spec?.name.resolved(language: RenderContext.preferredLanguage) ?? ID.id
    }

    /// "Weather · Widget Studio".
    static var summary: String {
        [spec?.category?.title.resolved(language: RenderContext.preferredLanguage), "Widget Studio"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// The template's own size only: nothing is shrunk or stretched.
    static var families: [WidgetFamily] {
        switch spec?.family {
        case .medium?: [.systemMedium]
        case .large?: [.systemLarge]
        default: [.systemSmall]
        }
    }
}

// MARK: Bundles per category (a widget bundle block takes at most 10 widgets)

struct TimeTemplateWidgets: WidgetBundle {
    var body: some Widget {
        TemplateWidget<TemplateIDs.ClockAnalog>()
        TemplateWidget<TemplateIDs.ClockDotAnalog>()
        TemplateWidget<TemplateIDs.ClockDigital>()
        TemplateWidget<TemplateIDs.DateBig>()
        TemplateWidget<TemplateIDs.DateDayZone>()
    }
}

struct WeatherTemplateWidgets: WidgetBundle {
    var body: some Widget {
        TemplateWidget<TemplateIDs.WeatherHiLo>()
        TemplateWidget<TemplateIDs.WeatherTemp>()
        TemplateWidget<TemplateIDs.WeatherForecast>()
        TemplateWidget<TemplateIDs.LocationCoords>()
    }
}

struct HealthTemplateWidgets: WidgetBundle {
    var body: some Widget {
        TemplateWidget<TemplateIDs.StepsStreak>()
        TemplateWidget<TemplateIDs.StepsMonth>()
        TemplateWidget<TemplateIDs.SleepWeek>()
    }
}

struct PrayerTemplateWidgets: WidgetBundle {
    var body: some Widget {
        TemplateWidget<TemplateIDs.PrayerNext>()
        TemplateWidget<TemplateIDs.PrayerDay>()
        TemplateWidget<TemplateIDs.Qibla>()
    }
}

struct CountdownTemplateWidgets: WidgetBundle {
    var body: some Widget {
        TemplateWidget<TemplateIDs.FocusToday>()
        TemplateWidget<TemplateIDs.CountdownRed>()
        TemplateWidget<TemplateIDs.CountdownTrip>()
        TemplateWidget<TemplateIDs.Stopwatch>()
    }
}

struct PhotoTemplateWidgets: WidgetBundle {
    var body: some Widget {
        TemplateWidget<TemplateIDs.PhotoSquare>()
        TemplateWidget<TemplateIDs.PhotoCircle>()
        TemplateWidget<TemplateIDs.PhotoHalftone>()
        TemplateWidget<TemplateIDs.MusicCard>()
    }
}

struct TilesTemplateWidgets: WidgetBundle {
    var body: some Widget {
        TemplateWidget<TemplateIDs.TilesPills2>()
        TemplateWidget<TemplateIDs.TilesPills4>()
        TemplateWidget<TemplateIDs.TilesRound>()
        TemplateWidget<TemplateIDs.TilesHero>()
    }
}

struct CounterTemplateWidgets: WidgetBundle {
    var body: some Widget {
        TemplateWidget<TemplateIDs.CounterTasbeeh>()
    }
}

// MARK: Timeline

struct TemplateEntry: TimelineEntry {
    let date: Date
    let templateID: String
    let spec: WidgetSpec?
    /// Why nothing can be drawn; shown as plain text instead of a gray widget (ADR-012).
    let problem: String?
}

struct TemplateProvider: TimelineProvider {
    let templateID: String

    func placeholder(in context: Context) -> TemplateEntry {
        entry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (TemplateEntry) -> Void) {
        let start = Date.now
        let entry = entry(date: .now)
        WidgetLog.add("snapshot \(templateID) \(entry.problem == nil ? "ok" : "problem") "
            + "\(WidgetLog.elapsed(since: start))ms preview=\(context.isPreview)")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TemplateEntry>) -> Void) {
        let start = Date.now
        let first = entry(date: .now)
        let schedule = SpecTimeline.schedule(for: first.spec?.refresh ?? .none, from: .now)
        let entries = schedule.dates.map { TemplateEntry(date: $0, templateID: templateID, spec: first.spec, problem: first.problem) }
        WidgetLog.add("timeline \(templateID) \(entries.count) entries \(first.problem.map { "PROBLEM: \($0)" } ?? "ok") "
            + "\(WidgetLog.elapsed(since: start))ms \(Self.memory())")
        completion(Timeline(entries: entries, policy: schedule.reloadAfter.map { .after($0) } ?? .never))
    }

    /// Loads only this template; failures become `problem`.
    func entry(date: Date) -> TemplateEntry {
        switch TemplateLibrary.load(id: templateID) {
        case .success(let spec):
            return TemplateEntry(date: date, templateID: templateID, spec: spec, problem: nil)
        case .failure(let issues):
            return TemplateEntry(date: date, templateID: templateID, spec: nil, problem: issues.description)
        }
    }

    /// "free 23.4 MB" (the extension's remaining memory budget).
    static func memory() -> String {
        String(format: "free %.1f MB", Double(os_proc_available_memory()) / 1_048_576)
    }
}

// MARK: View

/// Draws the template with the package view the tests also render (`SpecWidgetContent`), or the
/// problem as plain system text.
struct TemplateWidgetView: View {
    let entry: TemplateEntry

    var body: some View {
        let _ = WidgetLog.add("render \(entry.templateID) \(entry.problem == nil ? "body" : "problem")")
        if let problem = entry.problem {
            WidgetProblemView(title: entry.templateID, message: problem)
        } else {
            SpecWidgetContent(spec: entry.spec, context: RenderContext(
                date: entry.date, language: RenderContext.preferredLanguage, data: .sample(now: entry.date)
            ))
        }
    }
}

/// Plain text in system fonts: renders even when a template can't.
struct WidgetProblemView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text("widget.problem.title")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.yellow)
            Text(verbatim: title)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(verbatim: message)
                .font(.system(size: 10))
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .containerBackground(Color(white: 0.1), for: .widget)
        .environment(\.layoutDirection, .leftToRight)
    }
}
