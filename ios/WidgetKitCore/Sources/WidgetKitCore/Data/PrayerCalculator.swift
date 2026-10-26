import Adhan
import Foundation

/// Prayer times and Qibla, computed offline from coordinates (brief §4.5, M4) with adhan-swift.
/// Default method: Egyptian General Authority of Survey.
public enum PrayerCalculator {
    /// Methods the Settings screen offers (adhan-swift names), Egyptian first.
    public static let methods: [String] = [
        "egyptian", "muslimWorldLeague", "ummAlQura", "dubai", "kuwait", "qatar", "karachi",
        "northAmerica", "moonsightingCommittee", "singapore", "turkey", "tehran",
    ]
    public static let defaultMethod = "egyptian"

    static let keys: [(Prayer, String, LocalizedText)] = [
        (.fajr, "fajr", .localized(en: "Fajr", ar: "الفجر")),
        (.dhuhr, "dhuhr", .localized(en: "Dhuhr", ar: "الظهر")),
        (.asr, "asr", .localized(en: "Asr", ar: "العصر")),
        (.maghrib, "maghrib", .localized(en: "Maghrib", ar: "المغرب")),
        (.isha, "isha", .localized(en: "Isha", ar: "العشاء")),
    ]

    /// The five prayers of `date`'s day in `timeZone`, and the next one after `date` (tomorrow's
    /// Fajr after Isha).
    public static func prayer(latitude: Double, longitude: Double, date: Date, timeZone: TimeZone,
                              method: String = defaultMethod) -> DataSnapshot.Prayer? {
        guard let today = times(latitude: latitude, longitude: longitude, day: date, timeZone: timeZone, method: method) else {
            return nil
        }
        var dict: [String: Date] = [:]
        for (prayer, key, _) in keys { dict[key] = today.time(for: prayer) }
        if let next = keys.first(where: { today.time(for: $0.0) > date }) {
            return DataSnapshot.Prayer(times: dict, nextName: next.2, nextKey: next.1, nextTime: today.time(for: next.0))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: date),
              let tomorrow = times(latitude: latitude, longitude: longitude, day: tomorrowDate, timeZone: timeZone, method: method)
        else { return nil }
        let fajr = keys[0]
        return DataSnapshot.Prayer(times: dict, nextName: fajr.2, nextKey: fajr.1, nextTime: tomorrow.time(for: .fajr))
    }

    public static func qibla(latitude: Double, longitude: Double) -> Double {
        Qibla(coordinates: Coordinates(latitude: latitude, longitude: longitude)).direction
    }

    static func times(latitude: Double, longitude: Double, day: Date, timeZone: TimeZone, method: String) -> PrayerTimes? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let params = (CalculationMethod(rawValue: method) ?? .egyptian).params
        return PrayerTimes(coordinates: Coordinates(latitude: latitude, longitude: longitude), date: components,
                           calculationParameters: params)
    }
}
