import SwiftUI
import UIKit
import WidgetKit
import WidgetKitCore

// Diagnostic widgets for the gray template widget (ADR-012). Each isolates one suspect, so a
// device screenshot tells which one fails:
// - "Test · Fonts": only the bundled fonts (registered through UIAppFonts in the extension?).
// - "Test · Template": a template through the same renderer, with StaticConfiguration
//   (no AppIntent, no entity query).
// If both render but the template widgets stay gray, the AppIntent path is at fault; if
// "Test · Template" is gray too, the renderer is; if "Test · Fonts" is gray, the fonts are.

struct FontTestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WidgetStudioTestFonts", provider: FontTestProvider()) { FontTestView(entry: $0) }
            .configurationDisplayName("widget.test.fonts.name")
            .description("widget.test.fonts.description")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FontTestEntry: TimelineEntry {
    struct Check: Hashable {
        let name: String
        /// Registered in this process (UIAppFonts of the extension).
        let ok: Bool
    }

    let date: Date
    let available: [Check]
}

struct FontTestProvider: TimelineProvider {
    func placeholder(in context: Context) -> FontTestEntry { Self.entry() }

    func getSnapshot(in context: Context, completion: @escaping (FontTestEntry) -> Void) {
        completion(Self.entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FontTestEntry>) -> Void) {
        let entry = Self.entry()
        WidgetLog.add("fonts timeline: " + entry.available.map { "\($0.name)=\($0.ok ? "ok" : "MISSING")" }.joined(separator: " "))
        completion(Timeline(entries: [entry], policy: .never))
    }

    static func entry() -> FontTestEntry {
        FontTestEntry(date: .now, available: FontRegistry.bundledPostScriptNames.map {
            FontTestEntry.Check(name: $0, ok: UIFont(name: $0, size: 12) != nil)
        })
    }
}

struct FontTestView: View {
    let entry: FontTestEntry

    var body: some View {
        let _ = WidgetLog.add("fonts render")
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: "Fonts").font(.caption.weight(.semibold))
            ForEach(entry.available, id: \.name) { font in
                HStack(spacing: 4) {
                    Image(systemName: font.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(font.ok ? .green : .red)
                        .font(.system(size: 9))
                    Text(verbatim: font.name.hasPrefix("Doto") ? "12:34" : "مرحبا 12")
                        .font(.custom(font.name, fixedSize: 12))
                    Text(verbatim: font.name).font(.system(size: 7)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color(white: 0.055), for: .widget)
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct StaticTemplateTestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WidgetStudioTestTemplate", provider: StaticTemplateProvider()) { StaticTemplateView(entry: $0) }
            .configurationDisplayName("widget.test.template.name")
            .description("widget.test.template.description")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled()
    }
}

struct StaticTemplateEntry: TimelineEntry {
    let date: Date
    let id: String
    let spec: WidgetSpec?
    let problem: String?
}

struct StaticTemplateProvider: TimelineProvider {
    func placeholder(in context: Context) -> StaticTemplateEntry { Self.entry(context.family) }

    func getSnapshot(in context: Context, completion: @escaping (StaticTemplateEntry) -> Void) {
        completion(Self.entry(context.family))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StaticTemplateEntry>) -> Void) {
        let entry = Self.entry(context.family)
        WidgetLog.add("static timeline \(entry.id) \(entry.problem ?? "ok")")
        completion(Timeline(entries: [entry], policy: .never))
    }

    /// Light-theme, non-minute templates per size: steps (small), forecast (medium), prayer day (large).
    static func entry(_ family: WidgetFamily) -> StaticTemplateEntry {
        let id = switch family {
        case .systemMedium: "mono.weather.forecast"
        case .systemLarge: "mono.prayer.day"
        default: "mono.steps.streak"
        }
        switch TemplateLibrary.load(id: id) {
        case .success(let spec): return StaticTemplateEntry(date: .now, id: id, spec: spec, problem: nil)
        case .failure(let issues): return StaticTemplateEntry(date: .now, id: id, spec: nil, problem: issues.description)
        }
    }
}

struct StaticTemplateView: View {
    let entry: StaticTemplateEntry

    var body: some View {
        let _ = WidgetLog.add("static render \(entry.id)")
        if let problem = entry.problem {
            WidgetProblemView(title: entry.id, message: problem)
        } else {
            SpecWidgetContent(spec: entry.spec, context: RenderContext(
                date: entry.date, language: RenderContext.preferredLanguage, data: .sample(now: entry.date)
            ))
        }
    }
}
