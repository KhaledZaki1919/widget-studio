import Foundation

/// What the app writes for the widget: a heartbeat plus a test value the widget displays,
/// proving the widget reads App Group data written by the app (M0 dummy widget).
public struct AppHeartbeat: Codable, Sendable, Equatable {
    public let date: Date
    public let bundleID: String
    public let appGroupID: String?
    /// Increased by Diagnostics → "Write test value".
    public let testValue: Int

    public init(date: Date, bundleID: String, appGroupID: String?, testValue: Int) {
        self.date = date
        self.bundleID = bundleID
        self.appGroupID = appGroupID
        self.testValue = testValue
    }
}

/// What the widget extension found on its last timeline reload (ADR-005). Location and
/// battery are measured inside the extension process, which is what the templates need.
public struct WidgetReport: Codable, Sendable, Equatable {
    public let date: Date
    public let bundleID: String
    public let appGroupID: String?
    /// The app heartbeat the widget could read, if any.
    public let appHeartbeat: AppHeartbeat?
    /// `CLLocationManager.isAuthorizedForWidgetUpdates` inside the extension.
    public let locationAuthorizedForWidget: Bool
    public let location: ProbeOutcome
    public let battery: ProbeOutcome

    public init(date: Date, bundleID: String, appGroupID: String?, appHeartbeat: AppHeartbeat?,
                locationAuthorizedForWidget: Bool, location: ProbeOutcome, battery: ProbeOutcome) {
        self.date = date
        self.bundleID = bundleID
        self.appGroupID = appGroupID
        self.appHeartbeat = appHeartbeat
        self.locationAuthorizedForWidget = locationAuthorizedForWidget
        self.location = location
        self.battery = battery
    }
}

/// Reads and writes the probe files in `<store>/Probe/`. App and widget only see each other's
/// files when they resolve the same App Group container.
public struct ProbeStore: Sendable {
    public let directory: URL

    public init(location: StoreLocation) {
        self.init(directory: location.directory.appendingPathComponent("Probe", isDirectory: true))
    }

    init(directory: URL) {
        self.directory = directory
    }

    public func writeAppHeartbeat(_ heartbeat: AppHeartbeat) throws {
        try write(heartbeat, to: "app-heartbeat.json")
    }

    public func readAppHeartbeat() -> AppHeartbeat? {
        read(AppHeartbeat.self, from: "app-heartbeat.json")
    }

    public func writeWidgetReport(_ report: WidgetReport) throws {
        try write(report, to: "widget-report.json")
    }

    public func readWidgetReport() -> WidgetReport? {
        read(WidgetReport.self, from: "widget-report.json")
    }

    /// Writes a random token, reads it back and deletes it.
    public func readWriteTest() -> ProbeOutcome {
        let url = directory.appendingPathComponent("rw-test-\(UUID().uuidString).txt")
        let token = UUID().uuidString
        do {
            try FileProtection.write(Data(token.utf8), to: url)
            let back = String(decoding: try Data(contentsOf: url), as: UTF8.self)
            try FileManager.default.removeItem(at: url)
            return back == token ? .ok(directory.deletingLastPathComponent().lastPathComponent) : .failed("read back a different value")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func write<T: Encodable>(_ value: T, to name: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        try FileProtection.write(try encoder.encode(value), to: directory.appendingPathComponent(name))
    }

    private func read<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(type, from: data)
    }
}
