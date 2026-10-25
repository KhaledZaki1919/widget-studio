import Foundation

/// Spec JSON files bundled in a resource folder, each validated on load.
public enum BundledSpecs {
    public struct Entry: Sendable {
        public let fileName: String
        public let result: Result<WidgetSpec, SpecIssues>

        public var spec: WidgetSpec? { try? result.get() }
    }

    /// Every `.json` in `folder`, sorted by file name.
    public static func load(folder: String) -> [Entry] {
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: folder) ?? []
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { url in
            let result: Result<WidgetSpec, SpecIssues>
            if let data = try? Data(contentsOf: url) {
                result = SpecValidator().validate(data: data)
            } else {
                result = .failure(SpecIssues([SpecIssue("", "unreadable file")]))
            }
            return Entry(fileName: url.lastPathComponent, result: result)
        }
    }
}

/// The default "Mono" template library (TEMPLATES.md), bundled in `Resources/Templates`, so the
/// app and the widget can offer every template without an App Group (ADR-005, ADR-011).
public enum TemplateLibrary {
    public static func load() -> [BundledSpecs.Entry] {
        BundledSpecs.load(folder: "Templates")
    }

    /// The valid templates in library order: by category, then by catalog order within it.
    public static func all() -> [WidgetSpec] {
        let specs = load().compactMap(\.spec)
        return SpecCategory.allCases.flatMap { category in
            specs.filter { $0.category == category }.sorted { order($0.id) < order($1.id) }
        }
    }

    public static func template(id: String) -> WidgetSpec? {
        all().first { $0.id == id }
    }

    public static func templates(in category: SpecCategory) -> [WidgetSpec] {
        all().filter { $0.category == category }
    }

    /// Library order: `SpecCategory` order, then TEMPLATES.md order within each category.
    /// Ids not listed sort last, by id.
    static let catalogOrder = [
        "mono.clock.analog", "mono.clock.dotAnalog", "mono.clock.digital", "mono.date.big", "mono.date.dayZone",
        "mono.weather.hiLo", "mono.weather.temp", "mono.weather.forecast", "mono.location.coords",
        "mono.steps.streak", "mono.steps.month", "mono.sleep.week",
        "mono.prayer.next", "mono.prayer.day", "mono.qibla",
        "mono.focus.today", "mono.countdown.red", "mono.countdown.trip", "mono.stopwatch",
        "mono.photo.square", "mono.photo.circle", "mono.photo.halftone", "mono.music.card",
        "mono.tiles.pills2", "mono.tiles.pills4", "mono.tiles.round", "mono.tiles.hero",
        "mono.counter.tasbeeh",
    ]

    static func order(_ id: String) -> String {
        catalogOrder.firstIndex(of: id).map { String(format: "%03d", $0) } ?? "999\(id)"
    }
}
