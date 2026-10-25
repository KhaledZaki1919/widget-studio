import AppIntents
import SwiftUI
import WidgetKit
import WidgetKitCore

/// The main widget (M2): shows any template from the bundled library, picked in Edit Widget.
/// Bundled templates need no App Group, so this works on free-Apple-ID installs (ADR-005,
/// ADR-011). Data is sample data until the providers arrive in M4. The kind stays
/// "WidgetStudioSpec" so widgets placed in M1 keep working.
struct SpecWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WidgetStudioSpec", intent: SelectTemplateIntent.self, provider: SpecProvider()) { entry in
            SpecWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.spec.name")
        .description("widget.spec.description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // The spec canvas covers the whole widget; the spec places its own margins.
        .contentMarginsDisabled()
    }
}

struct SelectTemplateIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "widget.spec.intent.title"
    static var description = IntentDescription("widget.spec.intent.description")

    @Parameter(title: "widget.spec.param")
    var template: TemplateEntity?

    @Parameter(title: "widget.spec.appearance", default: .template)
    var appearance: AppearanceOption
}

/// Light / dark choice for a placed widget (templates resolve their color tokens per theme).
enum AppearanceOption: String, AppEnum {
    case template, system, light, dark

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.spec.appearance"
    static var caseDisplayRepresentations: [AppearanceOption: DisplayRepresentation] = [
        .template: "widget.appearance.template",
        .system: "widget.appearance.system",
        .light: "widget.appearance.light",
        .dark: "widget.appearance.dark",
    ]
}

struct TemplateEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.spec.entity"
    static var defaultQuery = TemplateQuery()

    let id: String
    let name: String
    let detail: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(detail)")
    }

    init(spec: WidgetSpec) {
        let language = RenderContext.preferredLanguage
        id = spec.id
        name = spec.name.resolved(language: language)
        detail = [spec.category?.title.resolved(language: language), Self.sizeName(spec.family, language: language)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    static func sizeName(_ family: SpecFamily, language: String) -> String {
        let arabic = language == "ar"
        switch family {
        case .small: return arabic ? "صغير" : "Small"
        case .medium: return arabic ? "متوسط" : "Medium"
        case .large: return arabic ? "كبير" : "Large"
        }
    }
}

/// Lists templates grouped by category, and searches names in both languages.
struct TemplateQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [TemplateEntity] {
        SpecProvider.templates.filter { identifiers.contains($0.id) }.map(TemplateEntity.init(spec:))
    }

    func suggestedEntities() async throws -> IntentItemCollection<TemplateEntity> {
        let language = RenderContext.preferredLanguage
        let sections = SpecCategory.allCases.compactMap { category -> IntentItemSection<TemplateEntity>? in
            let items = SpecProvider.templates.filter { $0.category == category }.map { IntentItem(TemplateEntity(spec: $0)) }
            guard !items.isEmpty else { return nil }
            return IntentItemSection(LocalizedStringResource(stringLiteral: category.title.resolved(language: language)), items: items)
        }
        return IntentItemCollection(sections: sections)
    }

    func entities(matching string: String) async throws -> IntentItemCollection<TemplateEntity> {
        let query = string.trimmingCharacters(in: .whitespaces).lowercased()
        let matches = SpecProvider.templates.filter { spec in
            query.isEmpty || (spec.name.allValues + (spec.category?.title.allValues ?? []))
                .contains { $0.lowercased().contains(query) }
        }
        return IntentItemCollection(items: matches.map { IntentItem(TemplateEntity(spec: $0)) })
    }
}

struct SpecEntry: TimelineEntry {
    let date: Date
    let spec: WidgetSpec?
    let appearance: AppearanceOption
}

struct SpecProvider: AppIntentTimelineProvider {
    /// Loaded and validated once per extension process, not on every reload.
    static let templates = TemplateLibrary.all()

    func placeholder(in context: Context) -> SpecEntry {
        SpecEntry(date: .now, spec: Self.spec(for: nil, family: context.family), appearance: .template)
    }

    func snapshot(for configuration: SelectTemplateIntent, in context: Context) async -> SpecEntry {
        SpecEntry(date: .now, spec: Self.spec(for: configuration, family: context.family), appearance: configuration.appearance)
    }

    func timeline(for configuration: SelectTemplateIntent, in context: Context) async -> Timeline<SpecEntry> {
        let spec = Self.spec(for: configuration, family: context.family)
        let schedule = SpecTimeline.schedule(for: spec?.refresh ?? .none, from: .now)
        let entries = schedule.dates.map { SpecEntry(date: $0, spec: spec, appearance: configuration.appearance) }
        return Timeline(entries: entries, policy: schedule.reloadAfter.map { .after($0) } ?? .never)
    }

    /// The chosen template, else a default made for this widget size.
    static func spec(for configuration: SelectTemplateIntent?, family: WidgetFamily) -> WidgetSpec? {
        if let id = configuration?.template?.id, let chosen = templates.first(where: { $0.id == id }) {
            return chosen
        }
        let fallback = switch family {
        case .systemMedium: "mono.weather.forecast"
        case .systemLarge, .systemExtraLarge: "mono.prayer.day"
        default: "mono.clock.digital"
        }
        return templates.first { $0.id == fallback } ?? templates.first
    }
}

/// Renders the entry with the package view the tests also render (`SpecWidgetContent`).
struct SpecWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: SpecEntry

    var body: some View {
        SpecWidgetContent(spec: entry.spec, context: context)
    }

    private var context: RenderContext {
        var context = RenderContext(date: entry.date, language: RenderContext.preferredLanguage, data: .sample(now: entry.date))
        context.theme = theme
        return context
    }

    private var theme: SpecTheme? {
        switch entry.appearance {
        case .template: nil
        case .system: colorScheme == .dark ? .dark : .light
        case .light: .light
        case .dark: .dark
        }
    }
}
