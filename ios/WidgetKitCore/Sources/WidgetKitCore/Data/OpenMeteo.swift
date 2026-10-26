import Foundation

/// A weather report from Open-Meteo (no API key; brief §2), as cached (ADR-016).
public struct WeatherReport: Codable, Sendable, Equatable {
    public struct Day: Codable, Sendable, Equatable {
        /// "yyyy-MM-dd" in the report's time zone.
        public var date: String
        public var code: Int
        public var high: Double
        public var low: Double
    }

    public var fetched: Date
    public var latitude: Double
    public var longitude: Double
    public var unit: AppSettings.TemperatureUnit
    public var timeZone: String
    public var temperature: Double
    public var code: Int
    public var isDay: Bool
    public var days: [Day]

    public static let cacheName = "weather"
    /// Hourly refresh (brief §4.5); a little early so the hourly timeline reload fetches.
    public static let maxAge: TimeInterval = 55 * 60

    /// Fresh enough for `now` at this place and unit (moved less than 5 km).
    public func isFresh(now: Date, latitude lat: Double, longitude lon: Double, unit wanted: AppSettings.TemperatureUnit) -> Bool {
        let place = StoredLocation(latitude: latitude, longitude: longitude, altitude: nil, updated: fetched)
        return now.timeIntervalSince(fetched) < Self.maxAge && now >= fetched && unit == wanted
            && place.distance(toLatitude: lat, longitude: lon) < 5
    }

    /// The renderer's weather: today's high/low and the days from today on.
    public func snapshot(now: Date, city: LocalizedText?) -> DataSnapshot.Weather {
        let zone = TimeZone(identifier: timeZone) ?? .current
        let today = FormatterCache.date("yyyy-MM-dd", locale: "en_US_POSIX", zone: zone).string(from: now)
        let upcoming = days.filter { $0.date >= today }
        let first = upcoming.first ?? days.last
        let condition = WeatherCode.describe(code, isDay: isDay)
        return DataSnapshot.Weather(
            temperature: temperature, high: first?.high ?? temperature, low: first?.low ?? temperature,
            condition: condition.text, symbol: condition.symbol, city: city ?? .plain(""),
            forecast: upcoming.compactMap { day in
                guard let date = FormatterCache.date("yyyy-MM-dd", locale: "en_US_POSIX", zone: zone).date(from: day.date) else {
                    return nil
                }
                return DataSnapshot.DayForecast(date: date, symbol: WeatherCode.describe(day.code, isDay: true).symbol,
                                                high: day.high, low: day.low)
            }
        )
    }
}

/// Open-Meteo forecast API: current temperature and code, 7 days of code, high and low.
public enum OpenMeteo {
    public static func url(latitude: Double, longitude: Double, unit: AppSettings.TemperatureUnit) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "temperature_unit", value: unit.rawValue),
        ]
        return components?.url
    }

    public enum Failure: Error, Equatable {
        case badURL
        case http(Int)
        case unreadable
    }

    struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int?
        }

        struct Daily: Decodable {
            let time: [String]
            let weather_code: [Int]
            let temperature_2m_max: [Double?]
            let temperature_2m_min: [Double?]
        }

        let timezone: String?
        let current: Current
        let daily: Daily
    }

    public static func parse(_ data: Data, fetched: Date, latitude: Double, longitude: Double,
                             unit: AppSettings.TemperatureUnit) throws -> WeatherReport {
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else { throw Failure.unreadable }
        let daily = response.daily
        let count = min(daily.time.count, daily.weather_code.count, daily.temperature_2m_max.count, daily.temperature_2m_min.count)
        let days = (0..<count).compactMap { index -> WeatherReport.Day? in
            guard let high = daily.temperature_2m_max[index], let low = daily.temperature_2m_min[index] else { return nil }
            return WeatherReport.Day(date: daily.time[index], code: daily.weather_code[index], high: high, low: low)
        }
        return WeatherReport(
            fetched: fetched, latitude: latitude, longitude: longitude, unit: unit,
            timeZone: response.timezone ?? TimeZone.current.identifier,
            temperature: response.current.temperature_2m, code: response.current.weather_code,
            isDay: (response.current.is_day ?? 1) == 1, days: days
        )
    }

    /// Downloads a report (15 s timeout: a widget timeline has little time).
    public static func fetch(latitude: Double, longitude: Double, unit: AppSettings.TemperatureUnit,
                             session: URLSession = .shared, now: Date = .now) async throws -> WeatherReport {
        guard let url = url(latitude: latitude, longitude: longitude, unit: unit) else { throw Failure.badURL }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("WidgetStudio/1.0 (iOS widget)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw Failure.http(http.statusCode) }
        return try parse(data, fetched: now, latitude: latitude, longitude: longitude, unit: unit)
    }
}

/// WMO weather interpretation codes (Open-Meteo) → whitelisted SF Symbol and ar/en text.
public enum WeatherCode {
    public static func describe(_ code: Int, isDay: Bool) -> (symbol: String, text: LocalizedText) {
        switch code {
        case 0: return (isDay ? "sun.max.fill" : "moon.fill", .localized(en: "Clear", ar: "صافٍ"))
        case 1: return (isDay ? "sun.max.fill" : "moon.stars.fill", .localized(en: "Mainly clear", ar: "صافٍ غالبًا"))
        case 2: return (isDay ? "cloud.sun.fill" : "cloud.moon.fill", .localized(en: "Partly cloudy", ar: "غائم جزئيًا"))
        case 3: return ("cloud.fill", .localized(en: "Overcast", ar: "غائم"))
        case 45, 48: return ("cloud.fog.fill", .localized(en: "Fog", ar: "ضباب"))
        case 51, 53, 55, 56, 57: return ("cloud.drizzle.fill", .localized(en: "Drizzle", ar: "رذاذ"))
        case 61, 63, 66, 80, 81: return ("cloud.rain.fill", .localized(en: "Rain", ar: "مطر"))
        case 65, 67, 82: return ("cloud.heavyrain.fill", .localized(en: "Heavy rain", ar: "مطر غزير"))
        case 71, 73, 75, 77, 85, 86: return ("cloud.snow.fill", .localized(en: "Snow", ar: "ثلج"))
        case 95, 96, 99: return ("cloud.bolt.rain.fill", .localized(en: "Thunderstorm", ar: "عاصفة رعدية"))
        default: return ("cloud.fill", .localized(en: "Cloudy", ar: "غائم"))
        }
    }
}
