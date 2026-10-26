import SwiftUI
import WidgetKit
import WidgetKitCore

// Store mode (ADR-014): one "My widget" per size, StaticConfiguration (the path that renders on
// Fast Store installs, ADR-013). It shows the most recently saved design that fits the size,
// read from SharedStore. Without an App Group the extension can't see the app's designs, so it
// says so in plain text instead of staying gray.

struct SmallMyWidget: Widget {
    var body: some WidgetConfiguration {
        MyWidgetConfiguration.make(kind: "WidgetStudio.my.small", size: .small)
    }
}

struct MediumMyWidget: Widget {
    var body: some WidgetConfiguration {
        MyWidgetConfiguration.make(kind: "WidgetStudio.my.medium", size: .medium)
    }
}

struct LargeMyWidget: Widget {
    var body: some WidgetConfiguration {
        MyWidgetConfiguration.make(kind: "WidgetStudio.my.large", size: .large)
    }
}

struct MyWidgets: WidgetBundle {
    var body: some Widget {
        SmallMyWidget()
        MediumMyWidget()
        LargeMyWidget()
    }
}

enum MyWidgetConfiguration {
    static func make(kind: String, size: SpecFamily) -> some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MyWidgetProvider(size: size)) { MyWidgetView(entry: $0) }
            .configurationDisplayName("widget.mywidget.name")
            .description("widget.mywidget.description")
            .supportedFamilies([WidgetFamily(size)])
            .contentMarginsDisabled()
    }
}

extension WidgetFamily {
    init(_ size: SpecFamily) {
        switch size {
        case .small: self = .systemSmall
        case .medium: self = .systemMedium
        case .large: self = .systemLarge
        }
    }
}

struct MyWidgetEntry: TimelineEntry {
    enum Content {
        case design(SavedDesign, CGImage?)
        /// The extension can't see the app's container (no App Group, ADR-005).
        case noAppGroup
        /// Shared, but no saved design fits this size yet.
        case noDesign
    }

    let date: Date
    let content: Content
    /// Real data for a design (ADR-016).
    var inputs = LiveInputs()
    var gap: DataGap?
}

struct MyWidgetProvider: TimelineProvider {
    let size: SpecFamily

    func placeholder(in context: Context) -> MyWidgetEntry {
        MyWidgetEntry(date: .now, content: .noDesign)
    }

    func getSnapshot(in context: Context, completion: @escaping (MyWidgetEntry) -> Void) {
        completion(Self.entry(size: size, date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MyWidgetEntry>) -> Void) {
        Task {
            let now = Date.now
            let first = Self.entry(size: size, date: now)
            guard case .design(let design, _) = first.content else {
                WidgetLog.add("my \(size.rawValue): \(Self.describe(first.content))")
                // The app reloads all timelines when a design changes; also check hourly.
                completion(Timeline(entries: [first], policy: .after(now.addingTimeInterval(3600))))
                return
            }
            let inputs = await WidgetData.inputs(for: DataRequirements.groups(for: design.spec), now: now)
            let gap = LiveData.gap(for: design.spec, inputs)
            let (dates, reload) = LiveSchedule.make(for: design.spec, inputs: inputs, now: now)
            let entries = dates.map { MyWidgetEntry(date: $0, content: first.content, inputs: inputs, gap: gap) }
            WidgetLog.add("my \(size.rawValue): \(Self.describe(first.content)), \(entries.count) entries")
            completion(Timeline(entries: entries, policy: .after(min(reload, now.addingTimeInterval(3600)))))
        }
    }

    static func entry(size: SpecFamily, date: Date) -> MyWidgetEntry {
        let store = SharedStore()
        guard store.isShared else { return MyWidgetEntry(date: date, content: .noAppGroup) }
        guard let design = store.designs(fitting: size).first else { return MyWidgetEntry(date: date, content: .noDesign) }
        let image = design.imageFile.flatMap(store.image(named:))
        return MyWidgetEntry(date: date, content: .design(design, image))
    }

    static func describe(_ content: MyWidgetEntry.Content) -> String {
        switch content {
        case .design(let design, _): "design \(design.templateID)"
        case .noAppGroup: "no App Group"
        case .noDesign: "no design"
        }
    }
}

struct MyWidgetView: View {
    let entry: MyWidgetEntry

    var body: some View {
        switch entry.content {
        case .design(let design, let image):
            if let gap = entry.gap {
                DataGapView(gap: gap, title: design.name)
            } else {
                SpecWidgetContent(spec: design.spec, context: design.renderContext(
                    date: entry.date, language: RenderContext.preferredLanguage,
                    data: LiveData.snapshot(entry.inputs, now: entry.date), image: image
                ))
                .environment(\.specActionButton, WidgetActionButtons.make)
            }
        case .noAppGroup:
            MyWidgetMessage(text: "widget.mywidget.noAppGroup")
        case .noDesign:
            MyWidgetMessage(text: "widget.mywidget.empty")
        }
    }
}

/// Plain text in system fonts, in the app's language; renders on every install.
struct MyWidgetMessage: View {
    let text: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "rectangle.stack")
                .font(.title3)
                .foregroundStyle(Color(hex: "#E2231A"))
            Text("widget.mywidget.name")
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .containerBackground(Color(white: 0.055), for: .widget)
        .widgetURL(URL(string: "widgetstudio://mywidgets"))
    }
}
