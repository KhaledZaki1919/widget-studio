import CoreGraphics
import Foundation

/// Data the bindings read (brief §4.5). Every part is optional: a missing value renders as "--".
/// M1 renders `DataSnapshot.sample`; the real providers (weather, HealthKit, prayer, …) fill it in M4.
public struct DataSnapshot: Sendable, Equatable {
    public struct DayForecast: Sendable, Equatable {
        public var date: Date
        public var symbol: String
        public var high: Double
        public var low: Double

        public init(date: Date, symbol: String, high: Double, low: Double) {
            self.date = date
            self.symbol = symbol
            self.high = high
            self.low = low
        }
    }

    public struct Weather: Sendable, Equatable {
        public var temperature: Double
        public var high: Double
        public var low: Double
        public var condition: LocalizedText
        public var symbol: String
        public var city: String
        public var forecast: [DayForecast]

        public init(temperature: Double, high: Double, low: Double, condition: LocalizedText, symbol: String,
                    city: String, forecast: [DayForecast]) {
            self.temperature = temperature
            self.high = high
            self.low = low
            self.condition = condition
            self.symbol = symbol
            self.city = city
            self.forecast = forecast
        }
    }

    public struct Prayer: Sendable, Equatable {
        public var times: [String: Date]
        public var nextName: LocalizedText
        public var nextTime: Date

        public init(times: [String: Date], nextName: LocalizedText, nextTime: Date) {
            self.times = times
            self.nextName = nextName
            self.nextTime = nextTime
        }
    }

    public var weather: Weather?
    public var stepsToday: Double?
    public var stepsStreak: Double?
    /// Levels 0…1 per day of the month.
    public var stepsMonthGrid: [Double]?
    public var sleepLastNight: String?
    public var sleepWeek: [Double]?
    public var counter: Double?
    public var stopwatchStart: Date?
    public var focusToday: String?
    public var focusWeek: [Double]?
    public var prayer: Prayer?
    public var qiblaBearing: Double?
    public var latitude: Double?
    public var longitude: Double?
    public var altitude: Double?
    /// 0…1.
    public var batteryLevel: Double?

    public init() {}

    /// Plausible values for previews and the M1 test specs (Cairo, mid-October).
    public static func sample(now: Date = .now, calendar: Calendar = .current) -> DataSnapshot {
        var data = DataSnapshot()
        let start = calendar.startOfDay(for: now)
        let symbols = ["sun.max.fill", "cloud.sun.fill", "cloud.fill", "sun.max.fill", "cloud.rain.fill", "sun.max.fill", "cloud.sun.fill"]
        data.weather = Weather(
            temperature: 30, high: 33, low: 21,
            condition: .localized(en: "Partly cloudy", ar: "غائم جزئيًا"),
            symbol: "cloud.sun.fill", city: "Cairo",
            forecast: (0..<7).map { offset in
                DayForecast(
                    date: calendar.date(byAdding: .day, value: offset, to: start) ?? start,
                    symbol: symbols[offset], high: Double(33 - offset % 3), low: Double(21 - offset % 2)
                )
            }
        )
        data.stepsToday = 5_543
        data.stepsStreak = 3
        data.stepsMonthGrid = (0..<31).map { day in [0.0, 0.3, 0.6, 1.0][(day * 7 + 3) % 4] }
        data.sleepLastNight = "7h 20m"
        data.sleepWeek = [0.7, 0.85, 0.6, 0.9, 0.75, 0.5, 0.8]
        data.counter = 33
        data.stopwatchStart = now.addingTimeInterval(-754)
        data.focusToday = "1h 45m"
        data.focusWeek = [0.4, 0.8, 0.6, 1.0, 0.3, 0.0, 0.5]
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        }
        let times = ["fajr": at(4, 32), "dhuhr": at(11, 42), "asr": at(14, 58), "maghrib": at(17, 21), "isha": at(18, 38)]
        let names: [(String, LocalizedText)] = [
            ("fajr", .localized(en: "Fajr", ar: "الفجر")), ("dhuhr", .localized(en: "Dhuhr", ar: "الظهر")),
            ("asr", .localized(en: "Asr", ar: "العصر")), ("maghrib", .localized(en: "Maghrib", ar: "المغرب")),
            ("isha", .localized(en: "Isha", ar: "العشاء")),
        ]
        let next = names.first { (times[$0.0] ?? now) > now } ?? names[0]
        let nextTime = times[next.0].map { $0 > now ? $0 : calendar.date(byAdding: .day, value: 1, to: $0) ?? $0 } ?? now
        data.prayer = Prayer(times: times, nextName: next.1, nextTime: nextTime)
        data.qiblaBearing = 136
        data.latitude = 30.04
        data.longitude = 31.24
        data.altitude = 23
        data.batteryLevel = 0.87
        return data
    }
}

/// Everything a spec needs to render once: time, language, field values, data and the user image.
public struct RenderContext {
    public var date: Date
    /// "ar" or "en".
    public var language: String
    public var timeZone: TimeZone
    /// User values by field key; missing keys use the field's default.
    public var fieldValues: [String: String]
    public var data: DataSnapshot
    public var userImage: CGImage?

    public init(date: Date = .now, language: String = "ar", timeZone: TimeZone = .current,
                fieldValues: [String: String] = [:], data: DataSnapshot = DataSnapshot(), userImage: CGImage? = nil) {
        self.date = date
        self.language = language
        self.timeZone = timeZone
        self.fieldValues = fieldValues
        self.data = data
        self.userImage = userImage
    }

    public var isArabic: Bool { language.hasPrefix("ar") }

    /// The app's language, as the system picked it from the app's localizations.
    public static var preferredLanguage: String {
        (Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "ar").hasPrefix("en") ? "en" : "ar"
    }
}
