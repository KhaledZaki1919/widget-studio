import Foundation
import Testing
@testable import WidgetKitCore

/// Cairo, Egyptian General Authority of Survey. Reference times from adhan-swift's own test
/// suite (testEgyptian, 2020-01-01): Fajr 5:18, Dhuhr 11:59, Asr 2:47 PM, Maghrib 5:06 PM,
/// Isha 6:29 PM.
struct PrayerCalculatorTests {
    let cairo = TimeZone(identifier: "Africa/Cairo") ?? .current
    let latitude = 30.028703
    let longitude = 31.249528

    func at(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 1, year: Int = 2020) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = cairo
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    func hhmm(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return FormatterCache.date("HH:mm", locale: "en_US_POSIX", zone: cairo).string(from: date)
    }

    @Test func knownCairoTimes() throws {
        let prayer = try #require(PrayerCalculator.prayer(latitude: latitude, longitude: longitude, date: at(1, 8, 0),
                                                          timeZone: cairo))
        #expect(hhmm(prayer.times["fajr"]) == "05:18")
        #expect(hhmm(prayer.times["dhuhr"]) == "11:59")
        #expect(hhmm(prayer.times["asr"]) == "14:47")
        #expect(hhmm(prayer.times["maghrib"]) == "17:06")
        #expect(hhmm(prayer.times["isha"]) == "18:29")
    }

    @Test func nextPrayerDuringTheDay() throws {
        let prayer = try #require(PrayerCalculator.prayer(latitude: latitude, longitude: longitude, date: at(1, 12, 30),
                                                          timeZone: cairo))
        #expect(prayer.nextKey == "asr")
        #expect(prayer.nextName == .localized(en: "Asr", ar: "العصر"))
        #expect(hhmm(prayer.nextTime) == "14:47")
    }

    @Test func afterIshaTheNextIsTomorrowsFajr() throws {
        let night = at(1, 21, 0)
        let prayer = try #require(PrayerCalculator.prayer(latitude: latitude, longitude: longitude, date: night, timeZone: cairo))
        #expect(prayer.nextKey == "fajr")
        #expect(prayer.nextTime > night)
        #expect(prayer.nextTime.timeIntervalSince(night) < 10 * 3600)
        #expect(hhmm(prayer.nextTime).hasPrefix("05:1"))
    }

    @Test func methodChangesFajr() throws {
        let egyptian = try #require(PrayerCalculator.prayer(latitude: latitude, longitude: longitude, date: at(1, 8, 0),
                                                            timeZone: cairo))
        let ummAlQura = try #require(PrayerCalculator.prayer(latitude: latitude, longitude: longitude, date: at(1, 8, 0),
                                                             timeZone: cairo, method: "ummAlQura"))
        #expect(egyptian.times["fajr"] != ummAlQura.times["fajr"])
    }

    @Test func unknownMethodFallsBackToEgyptian() throws {
        let fallback = try #require(PrayerCalculator.prayer(latitude: latitude, longitude: longitude, date: at(1, 8, 0),
                                                            timeZone: cairo, method: "nope"))
        #expect(hhmm(fallback.times["fajr"]) == "05:18")
    }

    @Test func qiblaFromCairo() {
        let bearing = PrayerCalculator.qibla(latitude: latitude, longitude: longitude)
        #expect(abs(bearing - 136.1) < 0.5, "\(bearing)")
    }
}
