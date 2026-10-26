import Foundation
import Testing
@testable import WidgetKitCore

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private func tempCache() throws -> DataCache {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("DataCache-\(UUID().uuidString)", isDirectory: true)
    return DataCache(directory: url)
}

/// 2026-10-26 12:00 Cairo (UTC+3).
private let noon = Date(timeIntervalSince1970: 1_793_005_200)

/// Open-Meteo parsing and caching (ADR-016). The fixture is a real response for Cairo.
struct WeatherTests {
    @Test func parsesTheRealResponse() throws {
        let report = try OpenMeteo.parse(try fixture("open-meteo-cairo"), fetched: noon, latitude: 30.04, longitude: 31.24,
                                         unit: .celsius)
        #expect(report.temperature == 24.2)
        #expect(report.code == 3)
        #expect(report.isDay)
        #expect(report.timeZone == "Africa/Cairo")
        #expect(report.days.count == 7)
        #expect(report.days[0] == WeatherReport.Day(date: "2026-10-26", code: 3, high: 27.5, low: 19.3))
    }

    @Test func snapshotStartsToday() throws {
        let report = try OpenMeteo.parse(try fixture("open-meteo-cairo"), fetched: noon, latitude: 30.04, longitude: 31.24,
                                         unit: .celsius)
        let weather = report.snapshot(now: noon, city: .localized(en: "Cairo", ar: "القاهرة"))
        #expect(weather.temperature == 24.2 && weather.high == 27.5 && weather.low == 19.3)
        #expect(weather.symbol == "cloud.fill")
        #expect(weather.condition == .localized(en: "Overcast", ar: "غائم"))
        #expect(weather.forecast.count == 7)
        // Two days later the forecast starts at the 28th.
        let later = report.snapshot(now: noon.addingTimeInterval(2 * 86_400), city: nil)
        #expect(later.forecast.count == 5)
        #expect(later.high == 28.5)
    }

    @Test func unreadableResponsesThrow() {
        #expect(throws: OpenMeteo.Failure.unreadable) {
            try OpenMeteo.parse(Data("{\"error\":true}".utf8), fetched: noon, latitude: 0, longitude: 0, unit: .celsius)
        }
    }

    @Test func requestURL() throws {
        let url = try #require(OpenMeteo.url(latitude: 30.044419, longitude: 31.235712, unit: .fahrenheit))
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let items = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
        #expect(url.host == "api.open-meteo.com")
        #expect(items["latitude"] == "30.0444" && items["longitude"] == "31.2357")
        #expect(items["temperature_unit"] == "fahrenheit")
        #expect(items["timezone"] == "auto")
    }

    @Test func freshnessByAgePlaceAndUnit() throws {
        let report = try OpenMeteo.parse(try fixture("open-meteo-cairo"), fetched: noon, latitude: 30.04, longitude: 31.24,
                                         unit: .celsius)
        #expect(report.isFresh(now: noon.addingTimeInterval(30 * 60), latitude: 30.04, longitude: 31.24, unit: .celsius))
        #expect(!report.isFresh(now: noon.addingTimeInterval(60 * 60), latitude: 30.04, longitude: 31.24, unit: .celsius))
        #expect(!report.isFresh(now: noon, latitude: 31.2, longitude: 29.9, unit: .celsius))   // Alexandria
        #expect(!report.isFresh(now: noon, latitude: 30.04, longitude: 31.24, unit: .fahrenheit))
    }

    @Test func cacheRoundTrip() throws {
        let cache = try tempCache()
        let report = try OpenMeteo.parse(try fixture("open-meteo-cairo"), fetched: noon, latitude: 30.04, longitude: 31.24,
                                         unit: .celsius)
        try cache.write(report, WeatherReport.cacheName)
        #expect(cache.read(WeatherReport.self, WeatherReport.cacheName) == report)
        cache.remove(WeatherReport.cacheName)
        #expect(cache.read(WeatherReport.self, WeatherReport.cacheName) == nil)
    }

    @Test func everyCodeMapsToAWhitelistedSymbol() {
        for code in [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99, 123] {
            for isDay in [true, false] {
                #expect(Icons.isAllowed(WeatherCode.describe(code, isDay: isDay).symbol), "\(code)")
            }
        }
    }

    @Test func settingsDefaultsAndPartialFiles() throws {
        let cache = try tempCache()
        #expect(AppSettings.load(cache) == AppSettings())
        var settings = AppSettings()
        settings.temperatureUnit = .fahrenheit
        settings.prayerMethod = "ummAlQura"
        try settings.save(cache)
        #expect(AppSettings.load(cache) == settings)
        try FileManager.default.createDirectory(at: cache.directory, withIntermediateDirectories: true)
        try Data("{\"stepGoal\":10000}".utf8).write(to: cache.url(AppSettings.cacheName))
        let partial = AppSettings.load(cache)
        #expect(partial.stepGoal == 10000 && partial.temperatureUnit == .celsius && partial.prayerMethod == "egyptian")
    }

    @Test func distanceBetweenCairoAndAlexandria() {
        let cairo = StoredLocation(latitude: 30.0444, longitude: 31.2357, altitude: nil, updated: noon)
        #expect(abs(cairo.distance(toLatitude: 31.2001, longitude: 29.9187) - 179) < 5)
    }
}
