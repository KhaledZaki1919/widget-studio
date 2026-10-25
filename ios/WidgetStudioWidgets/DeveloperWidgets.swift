#if WS_DEVELOPER
import AppIntents
import SwiftUI
import WidgetKit
import WidgetKitCore

// Developer mode only (ADR-014): the configurable widget from before ADR-013 (commit 997651a),
// extended to saved designs. One kind per size; Edit Widget lists "My widgets" (saved designs
// that fit, from SharedStore, which needs the App Group of a real Apple account) and every
// template that fits, grouped and searchable, with an Appearance option. Not built in store
// mode, because AppIntent widgets never render on the owner's Fast Store install (ADR-013).

struct DeveloperWidgets: WidgetBundle {
    var body: some Widget {
        SmallPickWidget()
        MediumPickWidget()
        LargePickWidget()
    }
}

struct SmallPickWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WidgetStudio.pick.small", intent: SmallPickIntent.self,
                               provider: PickProvider<SmallPickIntent>()) { PickWidgetView(entry: $0) }
            .configurationDisplayName("widget.pick.name")
            .description("widget.pick.description")
            .supportedFamilies([.systemSmall])
            .contentMarginsDisabled()
    }
}

struct MediumPickWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WidgetStudio.pick.medium", intent: MediumPickIntent.self,
                               provider: PickProvider<MediumPickIntent>()) { PickWidgetView(entry: $0) }
            .configurationDisplayName("widget.pick.name")
            .description("widget.pick.description")
            .supportedFamilies([.systemMedium])
            .contentMarginsDisabled()
    }
}

struct LargePickWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WidgetStudio.pick.large", intent: LargePickIntent.self,
                               provider: PickProvider<LargePickIntent>()) { PickWidgetView(entry: $0) }
            .configurationDisplayName("widget.pick.name")
            .description("widget.pick.description")
            .supportedFamilies([.systemLarge])
            .contentMarginsDisabled()
    }
}

// MARK: Configuration

protocol PickConfiguration: WidgetConfigurationIntent {
    static var size: SpecFamily { get }
    /// "design:<id>" or "template:<id>"; nil = newest design that fits, else the default template.
    var itemID: String? { get }
    var appearanceChoice: PickAppearance { get }
}

struct SmallPickIntent: PickConfiguration {
    static var title: LocalizedStringResource = "widget.pick.intent.title"
    static var description = IntentDescription("widget.pick.intent.description")
    static let size = SpecFamily.small

    @Parameter(title: "widget.pick.param")
    var item: SmallItemEntity?

    @Parameter(title: "widget.pick.appearance", default: .template)
    var appearance: PickAppearance

    var itemID: String? { item?.id }
    var appearanceChoice: PickAppearance { appearance }
}

struct MediumPickIntent: PickConfiguration {
    static var title: LocalizedStringResource = "widget.pick.intent.title"
    static var description = IntentDescription("widget.pick.intent.description")
    static let size = SpecFamily.medium

    @Parameter(title: "widget.pick.param")
    var item: MediumItemEntity?

    @Parameter(title: "widget.pick.appearance", default: .template)
    var appearance: PickAppearance

    var itemID: String? { item?.id }
    var appearanceChoice: PickAppearance { appearance }
}

struct LargePickIntent: PickConfiguration {
    static var title: LocalizedStringResource = "widget.pick.intent.title"
    static var description = IntentDescription("widget.pick.intent.description")
    static let size = SpecFamily.large

    @Parameter(title: "widget.pick.param")
    var item: LargeItemEntity?

    @Parameter(title: "widget.pick.appearance", default: .template)
    var appearance: PickAppearance

    var itemID: String? { item?.id }
    var appearanceChoice: PickAppearance { appearance }
}

enum PickAppearance: String, AppEnum {
    case template, system, light, dark

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.pick.appearance"
    static var caseDisplayRepresentations: [PickAppearance: DisplayRepresentation] = [
        .template: "widget.pick.appearance.template",
        .system: "widget.pick.appearance.system",
        .light: "widget.pick.appearance.light",
        .dark: "widget.pick.appearance.dark",
    ]
}

// MARK: Entities (one per size: the query must know what fits)

struct SmallItemEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.pick.entity"
    static var defaultQuery = SmallItemQuery()
    let id: String
    let name: String
    let detail: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(detail)") }
}

struct MediumItemEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.pick.entity"
    static var defaultQuery = MediumItemQuery()
    let id: String
    let name: String
    let detail: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(detail)") }
}

struct LargeItemEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.pick.entity"
    static var defaultQuery = LargeItemQuery()
    let id: String
    let name: String
    let detail: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(detail)") }
}

struct SmallItemQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SmallItemEntity] {
        PickCatalog.entities(for: identifiers, size: .small, make: SmallItemEntity.init)
    }

    func suggestedEntities() async throws -> IntentItemCollection<SmallItemEntity> {
        PickCatalog.sections(size: .small, make: SmallItemEntity.init)
    }

    func entities(matching string: String) async throws -> IntentItemCollection<SmallItemEntity> {
        PickCatalog.search(string, size: .small, make: SmallItemEntity.init)
    }
}

struct MediumItemQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [MediumItemEntity] {
        PickCatalog.entities(for: identifiers, size: .medium, make: MediumItemEntity.init)
    }

    func suggestedEntities() async throws -> IntentItemCollection<MediumItemEntity> {
        PickCatalog.sections(size: .medium, make: MediumItemEntity.init)
    }

    func entities(matching string: String) async throws -> IntentItemCollection<MediumItemEntity> {
        PickCatalog.search(string, size: .medium, make: MediumItemEntity.init)
    }
}

struct LargeItemQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [LargeItemEntity] {
        PickCatalog.entities(for: identifiers, size: .large, make: LargeItemEntity.init)
    }

    func suggestedEntities() async throws -> IntentItemCollection<LargeItemEntity> {
        PickCatalog.sections(size: .large, make: LargeItemEntity.init)
    }

    func entities(matching string: String) async throws -> IntentItemCollection<LargeItemEntity> {
        PickCatalog.search(string, size: .large, make: LargeItemEntity.init)
    }
}

/// Saved designs and templates as pickable items.
enum PickCatalog {
    typealias Make<Entity> = (_ id: String, _ name: String, _ detail: String) -> Entity

    struct Item {
        let id: String
        let name: LocalizedText
        let category: SpecCategory?
        let family: SpecFamily
        let isDesign: Bool
    }

    static func items(size: SpecFamily) -> [Item] {
        let designs = SharedStore().designs(fitting: size).map {
            Item(id: "design:\($0.id)", name: .plain($0.name), category: $0.spec.category, family: $0.spec.family, isDesign: true)
        }
        let templates = TemplateLibrary.fitting(size).map {
            Item(id: "template:\($0.id)", name: $0.name, category: $0.category, family: $0.family, isDesign: false)
        }
        return designs + templates
    }

    static func entities<Entity>(for identifiers: [String], size: SpecFamily, make: Make<Entity>) -> [Entity] {
        let all = items(size: size)
        return identifiers.compactMap { id in all.first { $0.id == id }.map { entity($0, make: make) } }
    }

    static func sections<Entity: AppEntity>(size: SpecFamily, make: Make<Entity>) -> IntentItemCollection<Entity> {
        let language = RenderContext.preferredLanguage
        let all = items(size: size)
        var sections: [IntentItemSection<Entity>] = []
        let designs = all.filter(\.isDesign).map { IntentItem(entity($0, make: make)) }
        if !designs.isEmpty {
            sections.append(IntentItemSection(LocalizedStringResource(stringLiteral: language == "ar" ? "ودجتاتي" : "My widgets"),
                                              items: designs))
        }
        for category in SpecCategory.allCases {
            let items = all.filter { !$0.isDesign && $0.category == category }.map { IntentItem(entity($0, make: make)) }
            if !items.isEmpty {
                sections.append(IntentItemSection(LocalizedStringResource(stringLiteral: category.title.resolved(language: language)),
                                                  items: items))
            }
        }
        return IntentItemCollection(sections: sections)
    }

    static func search<Entity: AppEntity>(_ string: String, size: SpecFamily, make: Make<Entity>) -> IntentItemCollection<Entity> {
        let query = string.trimmingCharacters(in: .whitespaces).lowercased()
        let matches = items(size: size).filter { item in
            query.isEmpty || (item.name.allValues + (item.category?.title.allValues ?? [])).contains { $0.lowercased().contains(query) }
        }
        return IntentItemCollection(items: matches.map { entity($0, make: make) })
    }

    static func entity<Entity>(_ item: Item, make: Make<Entity>) -> Entity {
        let language = RenderContext.preferredLanguage
        let kind = item.isDesign ? (language == "ar" ? "تصميمي" : "My design") : item.category?.title.resolved(language: language)
        return make(item.id, item.name.resolved(language: language), [kind].compactMap { $0 }.joined())
    }
}

// MARK: Timeline

struct PickEntry: TimelineEntry {
    let date: Date
    let spec: WidgetSpec?
    let design: SavedDesign?
    let image: CGImage?
    let problem: String?
    let appearance: PickAppearance
}

struct PickProvider<Configuration: PickConfiguration>: AppIntentTimelineProvider {
    typealias Entry = PickEntry
    typealias Intent = Configuration

    func placeholder(in context: Context) -> PickEntry {
        Self.entry(itemID: nil, appearance: .template, date: .now)
    }

    func snapshot(for configuration: Configuration, in context: Context) async -> PickEntry {
        Self.entry(itemID: configuration.itemID, appearance: configuration.appearanceChoice, date: .now)
    }

    func timeline(for configuration: Configuration, in context: Context) async -> Timeline<PickEntry> {
        let first = Self.entry(itemID: configuration.itemID, appearance: configuration.appearanceChoice, date: .now)
        let schedule = SpecTimeline.schedule(for: first.spec?.refresh ?? .none, from: .now)
        let entries = schedule.dates.map {
            PickEntry(date: $0, spec: first.spec, design: first.design, image: first.image, problem: first.problem,
                      appearance: first.appearance)
        }
        WidgetLog.add("pick \(Configuration.size.rawValue) \(configuration.itemID ?? "default") \(first.problem ?? "ok")")
        return Timeline(entries: entries, policy: schedule.reloadAfter.map { .after($0) } ?? .never)
    }

    static func entry(itemID: String?, appearance: PickAppearance, date: Date) -> PickEntry {
        let size = Configuration.size
        let store = SharedStore()
        func templateEntry(_ id: String) -> PickEntry {
            switch TemplateLibrary.load(id: id) {
            case .success(let spec):
                return PickEntry(date: date, spec: spec, design: nil, image: nil, problem: nil, appearance: appearance)
            case .failure(let issues):
                return PickEntry(date: date, spec: nil, design: nil, image: nil, problem: issues.description, appearance: appearance)
            }
        }
        func designEntry(_ design: SavedDesign) -> PickEntry {
            PickEntry(date: date, spec: design.spec, design: design, image: design.imageFile.flatMap(store.image(named:)),
                      problem: nil, appearance: appearance)
        }
        guard let itemID else {
            if let newest = store.designs(fitting: size).first { return designEntry(newest) }
            return templateEntry(TemplateLibrary.defaultID(for: size))
        }
        if itemID.hasPrefix("design:") {
            let id = String(itemID.dropFirst("design:".count))
            guard let design = store.design(id: id) else {
                return PickEntry(date: date, spec: nil, design: nil, image: nil,
                                 problem: "The saved design was deleted. Pick another one in Edit Widget.", appearance: appearance)
            }
            return designEntry(design)
        }
        return templateEntry(String(itemID.dropFirst("template:".count)))
    }
}

struct PickWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PickEntry

    var body: some View {
        if let problem = entry.problem {
            WidgetProblemView(title: "Widget Studio", message: problem)
        } else {
            SpecWidgetContent(spec: entry.spec, context: context)
        }
    }

    private var context: RenderContext {
        let language = RenderContext.preferredLanguage
        let data = DataSnapshot.sample(now: entry.date)
        var context = entry.design?.renderContext(date: entry.date, language: language, data: data, image: entry.image)
            ?? RenderContext(date: entry.date, language: language, data: data)
        switch entry.appearance {
        case .template: break
        case .system: context.theme = colorScheme == .dark ? .dark : .light
        case .light: context.theme = .light
        case .dark: context.theme = .dark
        }
        return context
    }
}
#endif
