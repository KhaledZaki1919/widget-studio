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
        public var city: LocalizedText
        public var forecast: [DayForecast]

        public init(temperature: Double, high: Double, low: Double, condition: LocalizedText, symbol: String,
                    city: LocalizedText, forecast: [DayForecast]) {
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
        /// `fajr` … `isha` (for `when: "{{prayer.next.key}} == asr"`).
        public var nextKey: String
        public var nextTime: Date

        public init(times: [String: Date], nextName: LocalizedText, nextKey: String, nextTime: Date) {
            self.times = times
            self.nextName = nextName
            self.nextKey = nextKey
            self.nextTime = nextTime
        }
    }

    public var weather: Weather?
    public var stepsToday: Double?
    public var stepsStreak: Double?
    public var stepsMonth: Double?
    /// A month calendar: one level 0…1 per cell, 7 cells per week, -1 for cells outside the month
    /// (see `MonthGrid`).
    public var stepsMonthGrid: [Double]?
    public var sleepLastNight: LocalizedText?
    public var sleepWeek: [Double]?
    public var counter: Double?
    public var stopwatchStart: Date?
    public var focusToday: LocalizedText?
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
            symbol: "cloud.sun.fill", city: .localized(en: "Cairo", ar: "القاهرة"),
            forecast: (0..<7).map { offset in
                DayForecast(
                    date: calendar.date(byAdding: .day, value: offset, to: start) ?? start,
                    symbol: symbols[offset], high: Double(33 - offset % 3), low: Double(21 - offset % 2)
                )
            }
        )
        data.stepsToday = 5_543
        data.stepsStreak = 3
        data.stepsMonth = 128_430
        // Varied levels for the days so far, today highlighted (2), nothing for the days to come.
        let today = calendar.component(.day, from: now)
        let perDay = (1...31).map { day -> Double in
            day > today ? 0 : day == today ? 2 : [0.25, 1.0, 0.6, 0.9, 0.4, 1.0, 0.75][(day * 5) % 7]
        }
        data.stepsMonthGrid = MonthGrid.levels(perDay: perDay, monthOf: now, calendar: calendar)
        data.sleepLastNight = .localized(en: "7h 20m", ar: "7س 20د")
        data.sleepWeek = [0.7, 0.85, 0.6, 0.9, 0.75, 0.5, 0.8]
        data.counter = 33
        data.stopwatchStart = now.addingTimeInterval(-754)
        data.focusToday = .localized(en: "6h 20m", ar: "6س 20د")
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
        data.prayer = Prayer(times: times, nextName: next.1, nextKey: next.0, nextTime: nextTime)
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
    public var fieldValues: [String: LocalizedText]
    public var data: DataSnapshot
    public var userImage: CGImage?
    /// Renders live texts (relative, timer) as fixed text measured from `date`, because SwiftUI's
    /// live styles measure from the real clock. For snapshot tests only.
    public var freezesLiveText = false
    /// 24-hour clock (true) or 12-hour (false), resolved from `ClockFormat` by the app and the
    /// widget. nil (tests, snapshots) keeps "HH" bindings and the locale's own live time.
    public var uses24Hour: Bool?
    /// Overrides the spec's theme (detail previews, the widget's Appearance option); color
    /// tokens resolve for this theme (ADR-011).
    public var theme: SpecTheme?
    /// Color token overrides from a saved design (`accent`, `bg`, `fg` → hex), applied on top of
    /// the theme (M3 editor, ADR-015).
    public var tokenOverrides: [String: String] = [:]

    public init(date: Date = .now, language: String = "ar", timeZone: TimeZone = .current,
                fieldValues: [String: LocalizedText] = [:], data: DataSnapshot = DataSnapshot(), userImage: CGImage? = nil) {
        self.date = date
        self.language = language
        self.timeZone = timeZone
        self.fieldValues = fieldValues
        self.data = data
        self.userImage = userImage
    }

    public var isArabic: Bool { language.hasPrefix("ar") }

    /// Words in the render language with Latin digits, so numbers suit the `dot` font.
    public var localeIdentifier: String { isArabic ? "ar_EG@numbers=latn" : "en_US" }

    /// The render locale with the clock's hour cycle, for live `.time` text.
    public var locale: Locale {
        guard let uses24Hour else { return Locale(identifier: localeIdentifier) }
        var components = Locale.Components(locale: Locale(identifier: localeIdentifier))
        components.hourCycle = uses24Hour ? .zeroToTwentyThree : .oneToTwelve
        return Locale(components: components)
    }

    /// "HH:mm" or "h:mm" (times of prayers, world clocks, stopwatch start).
    public var timePattern: String { uses24Hour == false ? "h:mm" : "HH:mm" }

    /// The app's language, as the system picked it from the app's localizations.
    public static var preferredLanguage: String {
        (Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "ar").hasPrefix("en") ? "en" : "ar"
    }
}
