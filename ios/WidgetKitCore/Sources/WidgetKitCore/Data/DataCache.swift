import Foundation

/// Small JSON files for live data (ADR-016): `<container>/Data/<name>.json`, in the container the
/// resolver picks. Without an App Group the app and the widget each have their own; with one
/// (developer mode) they share it, so settings and caches reach the widget with no extra code.
public struct DataCache: Sendable {
    public let directory: URL

    public init(location: StoreLocation = AppGroupResolver.resolve()) {
        directory = location.directory.appendingPathComponent("Data", isDirectory: true)
    }

    init(directory: URL) {
        self.directory = directory
    }

    public func read<Value: Decodable>(_ type: Value.Type, _ name: String) -> Value? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? Self.decoder.decode(type, from: data)
    }

    public func write<Value: Encodable>(_ value: Value, _ name: String) throws {
        try FileProtection.write(try Self.encoder.encode(value), to: url(name))
    }

    public func remove(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }

    func url(_ name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// User settings (brief §7.6). Saved in the store's container: in store mode the widget only
/// sees its own (defaults); with an App Group it sees the app's.
public struct AppSettings: Codable, Sendable, Equatable {
    public enum TemperatureUnit: String, Codable, Sendable, CaseIterable {
        case celsius, fahrenheit
    }

    public var temperatureUnit: TemperatureUnit = .celsius
    /// adhan-swift method name (`PrayerCalculator.methods`).
    public var prayerMethod: String = PrayerCalculator.defaultMethod
    /// Daily steps that count for the streak and the month grid.
    public var stepGoal: Int = 8000

    public init() {}

    public static let cacheName = "settings"

    public static func load(_ cache: DataCache = DataCache()) -> AppSettings {
        cache.read(AppSettings.self, cacheName) ?? AppSettings()
    }

    public func save(_ cache: DataCache = DataCache()) throws {
        try cache.write(self, Self.cacheName)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        temperatureUnit = (try? container.decode(TemperatureUnit.self, forKey: .temperatureUnit)) ?? .celsius
        prayerMethod = (try? container.decode(String.self, forKey: .prayerMethod)) ?? PrayerCalculator.defaultMethod
        stepGoal = (try? container.decode(Int.self, forKey: .stepGoal)) ?? 8000
    }
}

/// The last known location (from the app, or from the widget's own fix).
public struct StoredLocation: Codable, Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double?
    /// Reverse-geocoded place name, in the language it was looked up in.
    public var city: LocalizedText?
    public var updated: Date

    public init(latitude: Double, longitude: Double, altitude: Double?, city: LocalizedText? = nil, updated: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.city = city
        self.updated = updated
    }

    public static let cacheName = "location"

    /// Kilometres to another point (haversine), for "has the device moved".
    public func distance(toLatitude lat: Double, longitude lon: Double) -> Double {
        let radius = 6371.0
        let dLat = (lat - latitude) * .pi / 180
        let dLon = (lon - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(latitude * .pi / 180) * cos(lat * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return radius * 2 * atan2(a.squareRoot(), (1 - a).squareRoot())
    }
}
