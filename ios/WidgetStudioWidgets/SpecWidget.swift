import AppIntents
import os
import SwiftUI
import WidgetKit
import WidgetKitCore

// Template widgets (M2, ADR-011/012). One widget kind per size, so Edit Widget lists only
// templates that fit: a small widget offers small templates, a medium one small and medium,
// a large one all. Bundled templates need no App Group. Each step is written to `WidgetLog`
// (shown by the large check widget), and anything that goes wrong shows a plain error text.

struct SmallTemplateWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WidgetStudioSmall", intent: SmallTemplateIntent.self,
                               provider: TemplateProvider<SmallTemplateIntent>()) { TemplateWidgetView(entry: $0) }
            .configurationDisplayName("widget.template.name")
            .description("widget.template.description")
            .supportedFamilies([.systemSmall])
            .contentMarginsDisabled()
    }
}

struct MediumTemplateWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WidgetStudioMedium", intent: MediumTemplateIntent.self,
                               provider: TemplateProvider<MediumTemplateIntent>()) { TemplateWidgetView(entry: $0) }
            .configurationDisplayName("widget.template.name")
            .description("widget.template.description")
            .supportedFamilies([.systemMedium])
            .contentMarginsDisabled()
    }
}

struct LargeTemplateWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WidgetStudioLarge", intent: LargeTemplateIntent.self,
                               provider: TemplateProvider<LargeTemplateIntent>()) { TemplateWidgetView(entry: $0) }
            .configurationDisplayName("widget.template.name")
            .description("widget.template.description")
            .supportedFamilies([.systemLarge])
            .contentMarginsDisabled()
    }
}

// MARK: Configuration

/// What the provider needs from each size's configuration intent.
protocol TemplateConfiguration: WidgetConfigurationIntent {
    static var size: SpecFamily { get }
    var templateID: String? { get }
    var appearanceChoice: AppearanceOption { get }
}

struct SmallTemplateIntent: TemplateConfiguration {
    static var title: LocalizedStringResource = "widget.template.intent.title"
    static var description = IntentDescription("widget.template.intent.description")
    static let size = SpecFamily.small

    @Parameter(title: "widget.template.param")
    var template: SmallTemplateEntity?

    @Parameter(title: "widget.template.appearance", default: .template)
    var appearance: AppearanceOption

    var templateID: String? { template?.id }
    var appearanceChoice: AppearanceOption { appearance }
}

struct MediumTemplateIntent: TemplateConfiguration {
    static var title: LocalizedStringResource = "widget.template.intent.title"
    static var description = IntentDescription("widget.template.intent.description")
    static let size = SpecFamily.medium

    @Parameter(title: "widget.template.param")
    var template: MediumTemplateEntity?

    @Parameter(title: "widget.template.appearance", default: .template)
    var appearance: AppearanceOption

    var templateID: String? { template?.id }
    var appearanceChoice: AppearanceOption { appearance }
}

struct LargeTemplateIntent: TemplateConfiguration {
    static var title: LocalizedStringResource = "widget.template.intent.title"
    static var description = IntentDescription("widget.template.intent.description")
    static let size = SpecFamily.large

    @Parameter(title: "widget.template.param")
    var template: LargeTemplateEntity?

    @Parameter(title: "widget.template.appearance", default: .template)
    var appearance: AppearanceOption

    var templateID: String? { template?.id }
    var appearanceChoice: AppearanceOption { appearance }
}

/// Light / dark choice for a placed widget (templates resolve their color tokens per theme).
enum AppearanceOption: String, AppEnum {
    case template, system, light, dark

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.template.appearance"
    static var caseDisplayRepresentations: [AppearanceOption: DisplayRepresentation] = [
        .template: "widget.appearance.template",
        .system: "widget.appearance.system",
        .light: "widget.appearance.light",
        .dark: "widget.appearance.dark",
    ]
}

// MARK: Entities (one per size: the query must know which templates fit)

struct SmallTemplateEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.template.entity"
    static var defaultQuery = SmallTemplateQuery()
    let id: String
    let name: String
    let detail: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(detail)") }
}

struct MediumTemplateEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.template.entity"
    static var defaultQuery = MediumTemplateQuery()
    let id: String
    let name: String
    let detail: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(detail)") }
}

struct LargeTemplateEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.template.entity"
    static var defaultQuery = LargeTemplateQuery()
    let id: String
    let name: String
    let detail: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(detail)") }
}

struct SmallTemplateQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SmallTemplateEntity] {
        TemplateCatalog.entities(for: identifiers, size: .small, make: SmallTemplateEntity.init)
    }

    func suggestedEntities() async throws -> IntentItemCollection<SmallTemplateEntity> {
        TemplateCatalog.sections(size: .small, make: SmallTemplateEntity.init)
    }

    func entities(matching string: String) async throws -> IntentItemCollection<SmallTemplateEntity> {
        TemplateCatalog.search(string, size: .small, make: SmallTemplateEntity.init)
    }
}

struct MediumTemplateQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [MediumTemplateEntity] {
        TemplateCatalog.entities(for: identifiers, size: .medium, make: MediumTemplateEntity.init)
    }

    func suggestedEntities() async throws -> IntentItemCollection<MediumTemplateEntity> {
        TemplateCatalog.sections(size: .medium, make: MediumTemplateEntity.init)
    }

    func entities(matching string: String) async throws -> IntentItemCollection<MediumTemplateEntity> {
        TemplateCatalog.search(string, size: .medium, make: MediumTemplateEntity.init)
    }
}

struct LargeTemplateQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [LargeTemplateEntity] {
        TemplateCatalog.entities(for: identifiers, size: .large, make: LargeTemplateEntity.init)
    }

    func suggestedEntities() async throws -> IntentItemCollection<LargeTemplateEntity> {
        TemplateCatalog.sections(size: .large, make: LargeTemplateEntity.init)
    }

    func entities(matching string: String) async throws -> IntentItemCollection<LargeTemplateEntity> {
        TemplateCatalog.search(string, size: .large, make: LargeTemplateEntity.init)
    }
}

/// Shared query logic. Listing loads the whole library (only while editing a widget);
/// timelines load just the selected template.
enum TemplateCatalog {
    typealias Make<Entity> = (_ id: String, _ name: String, _ detail: String) -> Entity

    static func entities<Entity>(for identifiers: [String], size: SpecFamily, make: Make<Entity>) -> [Entity] {
        identifiers.compactMap { id in
            guard let spec = TemplateLibrary.template(id: id), spec.family.rank <= size.rank else { return nil }
            return entity(spec, make: make)
        }
    }

    static func sections<Entity: AppEntity>(size: SpecFamily, make: Make<Entity>) -> IntentItemCollection<Entity> {
        let language = RenderContext.preferredLanguage
        let fitting = TemplateLibrary.fitting(size)
        WidgetLog.add("query \(size.rawValue): \(fitting.count) templates")
        let sections = SpecCategory.allCases.compactMap { category -> IntentItemSection<Entity>? in
            let items = fitting.filter { $0.category == category }.map { IntentItem(entity($0, make: make)) }
            guard !items.isEmpty else { return nil }
            return IntentItemSection(LocalizedStringResource(stringLiteral: category.title.resolved(language: language)), items: items)
        }
        return IntentItemCollection(sections: sections)
    }

    static func search<Entity: AppEntity>(_ string: String, size: SpecFamily, make: Make<Entity>) -> IntentItemCollection<Entity> {
        let query = string.trimmingCharacters(in: .whitespaces).lowercased()
        let matches = TemplateLibrary.fitting(size).filter { spec in
            query.isEmpty || (spec.name.allValues + (spec.category?.title.allValues ?? [])).contains { $0.lowercased().contains(query) }
        }
        return IntentItemCollection(items: matches.map { entity($0, make: make) })
    }

    static func entity<Entity>(_ spec: WidgetSpec, make: Make<Entity>) -> Entity {
        let language = RenderContext.preferredLanguage
        let size = TemplateEntityText.sizeName(spec.family, language: language)
        let detail = [spec.category?.title.resolved(language: language), size].compactMap { $0 }.joined(separator: " · ")
        return make(spec.id, spec.name.resolved(language: language), detail)
    }
}

enum TemplateEntityText {
    static func sizeName(_ family: SpecFamily, language: String) -> String {
        let arabic = language == "ar"
        switch family {
        case .small: return arabic ? "صغير" : "Small"
        case .medium: return arabic ? "متوسط" : "Medium"
        case .large: return arabic ? "كبير" : "Large"
        }
    }
}

// MARK: Timeline

struct TemplateEntry: TimelineEntry {
    let date: Date
    /// The widget's size.
    let size: SpecFamily
    let templateID: String
    let spec: WidgetSpec?
    /// Why nothing can be drawn; shown as plain text instead of a gray widget (ADR-012).
    let problem: String?
    let appearance: AppearanceOption
}

struct TemplateProvider<Configuration: TemplateConfiguration>: AppIntentTimelineProvider {
    typealias Entry = TemplateEntry
    typealias Intent = Configuration

    func placeholder(in context: Context) -> TemplateEntry {
        WidgetLog.add("placeholder \(Configuration.size.rawValue)")
        return Self.entry(id: nil, appearance: .template, date: .now)
    }

    func snapshot(for configuration: Configuration, in context: Context) async -> TemplateEntry {
        let start = Date.now
        let entry = Self.entry(id: configuration.templateID, appearance: configuration.appearanceChoice, date: .now)
        WidgetLog.add("snapshot \(Configuration.size.rawValue) \(entry.templateID) \(entry.problem == nil ? "ok" : "problem") "
            + "\(WidgetLog.elapsed(since: start))ms preview=\(context.isPreview)")
        return entry
    }

    func timeline(for configuration: Configuration, in context: Context) async -> Timeline<TemplateEntry> {
        let start = Date.now
        WidgetLog.add("timeline \(Configuration.size.rawValue) start id=\(configuration.templateID ?? "default") \(Self.memory())")
        let first = Self.entry(id: configuration.templateID, appearance: configuration.appearanceChoice, date: .now)
        let schedule = SpecTimeline.schedule(for: first.spec?.refresh ?? .none, from: .now)
        let entries = schedule.dates.map {
            TemplateEntry(date: $0, size: first.size, templateID: first.templateID, spec: first.spec, problem: first.problem,
                          appearance: first.appearance)
        }
        WidgetLog.add("timeline \(Configuration.size.rawValue) \(first.templateID) \(entries.count) entries "
            + "\(first.problem.map { "PROBLEM: \($0)" } ?? "ok") \(WidgetLog.elapsed(since: start))ms \(Self.memory())")
        return Timeline(entries: entries, policy: schedule.reloadAfter.map { .after($0) } ?? .never)
    }

    /// Loads only the selected template and checks it fits; failures become `problem`.
    static func entry(id: String?, appearance: AppearanceOption, date: Date) -> TemplateEntry {
        let size = Configuration.size
        let templateID = id ?? TemplateLibrary.defaultID(for: size)
        var spec: WidgetSpec?
        var problem: String?
        switch TemplateLibrary.load(id: templateID) {
        case .success(let loaded):
            if loaded.family.rank > size.rank {
                problem = "\(templateID) is a \(loaded.family.rawValue) template; it doesn't fit a \(size.rawValue) widget."
            } else {
                spec = loaded
            }
        case .failure(let issues):
            problem = "\(templateID): \(issues.description)"
        }
        return TemplateEntry(date: date, size: size, templateID: templateID, spec: spec, problem: problem, appearance: appearance)
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
    @Environment(\.colorScheme) private var colorScheme
    let entry: TemplateEntry

    var body: some View {
        let _ = WidgetLog.add("render \(entry.size.rawValue) \(entry.templateID) \(entry.problem == nil ? "body" : "problem")")
        if let problem = entry.problem {
            WidgetProblemView(title: entry.templateID, message: problem)
        } else {
            SpecWidgetContent(spec: entry.spec, context: context)
        }
    }

    private var context: RenderContext {
        var context = RenderContext(date: entry.date, language: RenderContext.preferredLanguage, data: .sample(now: entry.date))
        context.theme = switch entry.appearance {
        case .template: nil
        case .system: colorScheme == .dark ? .dark : .light
        case .light: .light
        case .dark: .dark
        }
        return context
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
