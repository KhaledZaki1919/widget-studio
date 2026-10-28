import Foundation

/// What "My widget" offers in Edit Widget (developer mode, ADR-014, M6): every saved design that
/// fits the widget (templates the user customized and AI-made designs alike, newest first), then
/// every template that fits, searchable in both languages. Nothing is ever chosen automatically:
/// a widget without a choice asks the user to pick one.
public enum WidgetPicker {
    public struct Item: Equatable, Sendable {
        /// "design:<id>" or "template:<id>", the entity identifier Edit Widget stores.
        public let id: String
        public let name: LocalizedText
        public let category: SpecCategory?
        public let family: SpecFamily
        public let isDesign: Bool
    }

    /// What a stored choice points to.
    public enum Selection: Equatable, Sendable {
        /// No choice yet: show "pick a design in Edit Widget", never a design picked for the user.
        case none
        case design(SavedDesign)
        case template(WidgetSpec)
        /// The saved design was deleted after it was picked.
        case missingDesign
        case invalidTemplate(String)
    }

    public static func items(size: SpecFamily, store: SharedStore = SharedStore(),
                             templates: [WidgetSpec]? = nil) -> [Item] {
        let designs = store.designs(fitting: size).map {
            Item(id: "design:\($0.id)", name: .plain($0.name), category: $0.spec.category, family: $0.spec.family, isDesign: true)
        }
        let specs = templates ?? TemplateLibrary.fitting(size)
        let library = specs.map {
            Item(id: "template:\($0.id)", name: $0.name, category: $0.category, family: $0.family, isDesign: false)
        }
        return designs + library
    }

    /// Items whose name (either language) or category contains `query`; all items for an empty query.
    public static func search(_ query: String, in items: [Item]) -> [Item] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return items }
        return items.filter { item in
            (item.name.allValues + (item.category?.title.allValues ?? [])).contains { $0.lowercased().contains(needle) }
        }
    }

    public static func resolve(itemID: String?, store: SharedStore = SharedStore()) -> Selection {
        guard let itemID else { return .none }
        if itemID.hasPrefix("design:") {
            return store.design(id: String(itemID.dropFirst("design:".count))).map(Selection.design) ?? .missingDesign
        }
        let templateID = itemID.hasPrefix("template:") ? String(itemID.dropFirst("template:".count)) : itemID
        switch TemplateLibrary.load(id: templateID) {
        case .success(let spec): return .template(spec)
        case .failure(let issues): return .invalidTemplate(issues.description)
        }
    }
}
