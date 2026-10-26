import Foundation

/// Whether each data source worked, and when it last updated, as seen by one process (the app
/// or the widget extension). The widget writes `widget-status`; the large check widget shows it,
/// and Diagnostics shows it too when an App Group makes it readable (ADR-016).
public struct SourceStatus: Codable, Sendable, Equatable {
    public enum Source: String, Codable, Sendable, CaseIterable {
        case location, weather, prayer, health, battery, counter, stopwatch
    }

    public struct Entry: Codable, Sendable, Equatable {
        public var ok: Bool
        /// Short English detail ("fetched", "cached 23 min", "no permission").
        public var detail: String
        /// When the data itself was last updated (fetch, fix, read).
        public var updated: Date?
        /// When this status was written.
        public var checked: Date

        public init(ok: Bool, detail: String, updated: Date?, checked: Date) {
            self.ok = ok
            self.detail = detail
            self.updated = updated
            self.checked = checked
        }
    }

    public var entries: [Source: Entry] = [:]

    public init(entries: [Source: Entry] = [:]) {
        self.entries = entries
    }

    public static let widgetCacheName = "widget-status"

    /// Merges new results into the stored status (sources a timeline didn't touch keep theirs).
    public static func record(_ updates: [Source: Entry], cache: DataCache = DataCache(), name: String = widgetCacheName) {
        var status = cache.read(SourceStatus.self, name) ?? SourceStatus()
        for (source, entry) in updates { status.entries[source] = entry }
        try? cache.write(status, name)
    }

    public static func load(cache: DataCache = DataCache(), name: String = widgetCacheName) -> SourceStatus? {
        cache.read(SourceStatus.self, name)
    }
}
