import AppIntents
import SwiftUI
import WidgetKit
import WidgetKitCore

/// M1 spec widget: shows any bundled test spec, picked in the widget's edit menu. Bundled specs
/// need no App Group, so this works on free-Apple-ID installs (ADR-005). Data is sample data
/// until the providers arrive in M4.
struct SpecWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WidgetStudioSpec", intent: SelectSpecIntent.self, provider: SpecProvider()) { entry in
            SpecWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.spec.name")
        .description("widget.spec.description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // The spec canvas covers the whole widget; the spec places its own margins.
        .contentMarginsDisabled()
    }
}

struct SelectSpecIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "widget.spec.intent.title"
    static var description = IntentDescription("widget.spec.intent.description")

    @Parameter(title: "widget.spec.param")
    var spec: TestSpecEntity?
}

struct TestSpecEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.spec.entity"
    static var defaultQuery = TestSpecQuery()

    let id: String
    let name: String
    let family: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(family)")
    }

    init(spec: WidgetSpec) {
        id = spec.id
        name = spec.name.resolved(language: RenderContext.preferredLanguage)
        family = spec.family.rawValue
    }
}

struct TestSpecQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TestSpecEntity] {
        SpecProvider.specs.filter { identifiers.contains($0.id) }.map(TestSpecEntity.init(spec:))
    }

    func suggestedEntities() async throws -> [TestSpecEntity] {
        SpecProvider.specs.map(TestSpecEntity.init(spec:))
    }
}

struct SpecEntry: TimelineEntry {
    let date: Date
    let spec: WidgetSpec?
}

struct SpecProvider: AppIntentTimelineProvider {
    /// Loaded and validated once per extension process, not on every reload.
    static let specs = TestSpecs.all()

    func placeholder(in context: Context) -> SpecEntry {
        SpecEntry(date: .now, spec: Self.spec(for: nil, family: context.family))
    }

    func snapshot(for configuration: SelectSpecIntent, in context: Context) async -> SpecEntry {
        SpecEntry(date: .now, spec: Self.spec(for: configuration, family: context.family))
    }

    func timeline(for configuration: SelectSpecIntent, in context: Context) async -> Timeline<SpecEntry> {
        let spec = Self.spec(for: configuration, family: context.family)
        let schedule = SpecTimeline.schedule(for: spec?.refresh ?? .none, from: .now)
        let entries = schedule.dates.map { SpecEntry(date: $0, spec: spec) }
        return Timeline(entries: entries, policy: schedule.reloadAfter.map { .after($0) } ?? .never)
    }

    /// The chosen spec, else the first test spec made for this widget size.
    static func spec(for configuration: SelectSpecIntent?, family: WidgetFamily) -> WidgetSpec? {
        if let id = configuration?.spec?.id, let chosen = specs.first(where: { $0.id == id }) {
            return chosen
        }
        let wanted: SpecFamily = switch family {
        case .systemMedium: .medium
        case .systemLarge, .systemExtraLarge: .large
        default: .small
        }
        return specs.first { $0.family == wanted } ?? specs.first
    }
}

/// Renders the entry with the package view the tests also render (`SpecWidgetContent`).
struct SpecWidgetView: View {
    let entry: SpecEntry

    var body: some View {
        SpecWidgetContent(spec: entry.spec, context: RenderContext(
            date: entry.date, language: RenderContext.preferredLanguage, data: .sample(now: entry.date)
        ))
    }
}
