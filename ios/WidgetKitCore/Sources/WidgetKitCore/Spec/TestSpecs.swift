import Foundation

/// The 10 hand-written M1 test specs in `Resources/TestSpecs` (brief §10, M1). Together they use
/// every layer type, both themes, all three families and both languages. They are bundled, so
/// the widget can show them even without an App Group (ADR-005 device findings).
public enum TestSpecs {
    public struct Entry: Sendable {
        public let fileName: String
        public let result: Result<WidgetSpec, SpecIssues>

        public var spec: WidgetSpec? { try? result.get() }
    }

    /// Every bundled test spec, validated, sorted by file name.
    public static func load() -> [Entry] {
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "TestSpecs") ?? []
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

    /// Only the valid specs.
    public static func all() -> [WidgetSpec] {
        load().compactMap(\.spec)
    }

    public static func spec(id: String) -> WidgetSpec? {
        all().first { $0.id == id }
    }
}

/// `Resources/Spec/widget-spec.v1.schema.json`: the structure of v1 for AI providers with
/// structured output (brief §4.6). `SpecValidator` remains the authority.
public enum SpecSchema {
    public static var url: URL? {
        Bundle.module.url(forResource: "widget-spec.v1.schema", withExtension: "json", subdirectory: "Spec")
    }

    public static func data() -> Data? {
        url.flatMap { try? Data(contentsOf: $0) }
    }
}
