import Foundation
import Testing
@testable import WidgetKitCore

private func spec(fields: [FieldSpec] = []) -> WidgetSpec {
    WidgetSpec(
        id: "test.render", name: .localized(en: "Test", ar: "اختبار"), family: .small,
        background: .solid("#000000"), fields: fields,
        layers: [Layer(frame: Frame(x: 0, y: 0, w: 10, h: 10), content: .shape(ShapeLayer(kind: .rect, fill: "#FFFFFF")))]
    )
}

/// 2026-10-21 14:05 UTC, a Wednesday.
private let fixedDate = Date(timeIntervalSince1970: 1_792_591_500)
private let utc = TimeZone(identifier: "UTC") ?? .current

private func resolver(_ spec: WidgetSpec = spec(), language: String = "en", data: DataSnapshot = .sample(now: fixedDate),
                      fields: [String: String] = [:]) -> BindingResolver {
    BindingResolver(spec: spec, context: RenderContext(date: fixedDate, language: language, timeZone: utc,
                                                       fieldValues: fields, data: data))
}

struct BindingResolverTests {
    @Test func rendersTimeWithLatinDigits() {
        #expect(resolver().render("{{time.hh}}:{{time.mm}}") == "14:05")
        #expect(resolver(language: "ar").render("{{time.hh}}:{{time.mm}}") == "14:05")
        #expect(resolver().render("{{time.h}}") == "2")
        #expect(resolver().render("{{date.d}}") == "21")
    }

    @Test func weekdayFollowsTheLanguage() {
        #expect(resolver().render("{{date.EEEE}}") == "Wednesday")
        #expect(resolver(language: "ar").render("{{date.EEEE}}") == "الأربعاء")
    }

    @Test func numbersAndMissingValues() {
        #expect(resolver().render("{{weather.temp}}°") == "30°")
        #expect(resolver().render("{{steps.today}}") == "5,543")
        #expect(resolver().render("{{battery.level}}%") == "87%")
        #expect(resolver(data: DataSnapshot()).render("{{weather.temp}}°") == "--°")
        #expect(resolver().render("{{nonsense}}") == "--")
    }

    @Test func ringProgressComesFromNumbers() {
        #expect(resolver().number("{{battery.level}}") == 0.87)
        #expect(resolver().number("0.25") == 0.25)
        #expect(resolver(data: DataSnapshot()).number("{{battery.level}}") == nil)
    }

    @Test func fieldsUseUserValueThenDefault() {
        let fields = [FieldSpec(key: "city", type: .city, label: .plain("City"), default: "Cairo")]
        #expect(resolver(spec(fields: fields)).render("{{field.city}}") == "Cairo")
        #expect(resolver(spec(fields: fields), fields: ["city": "Alexandria"]).render("{{field.city}}") == "Alexandria")
    }

    @Test func localizedDefaultsAndDataFollowTheLanguage() {
        let fields = [FieldSpec(key: "city", type: .city, label: "City", default: .localized(en: "Cairo", ar: "القاهرة"))]
        #expect(resolver(spec(fields: fields), language: "ar").render("{{field.city}}") == "القاهرة")
        #expect(resolver(spec(fields: fields), language: "en").render("{{field.city}}") == "Cairo")
        #expect(resolver(language: "ar").render("{{weather.cond}}") == "غائم جزئيًا")
        #expect(resolver(language: "ar").render("{{sleep.lastNight}}") == "7س 20د")
        #expect(resolver(language: "ar").render("{{date.MMM}}") == "أكتوبر")
    }

    @Test func dateFieldAndTimezoneTime() {
        let fields = [
            FieldSpec(key: "day", type: .date, label: .plain("Day"), default: "2026-12-31"),
            FieldSpec(key: "zone", type: .timezone, label: .plain("Zone"), default: "Asia/Tokyo"),
        ]
        let resolver = resolver(spec(fields: fields))
        #expect(resolver.date("{{field.day}}") != nil)
        #expect(resolver.render("{{tz.zone.time}}") == "23:05")
    }

    @Test func timesShowInTheRenderTimeZone() {
        // Prayer times come from sample data built in UTC here; they must print in that zone.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let data = DataSnapshot.sample(now: fixedDate, calendar: calendar)
        #expect(resolver(data: data).render("{{prayer.fajr}}") == "04:32")
    }

    @Test func gmtOffsets() {
        #expect(BindingResolver.offset(utc, at: fixedDate) == "GMT")
        #expect(BindingResolver.offset(TimeZone(secondsFromGMT: 7200) ?? utc, at: fixedDate) == "GMT+2")
        #expect(BindingResolver.offset(TimeZone(secondsFromGMT: -12600) ?? utc, at: fixedDate) == "GMT-3:30")
    }

    @Test func levelsFromBindingListOrPattern() {
        #expect(resolver().levels("{{sleep.week}}").count == 7)
        #expect(resolver().levels("0.5,1") == [0.5, 1])
        #expect(resolver().levels("01 10") == [0, 1, 1, 0])
    }
}

struct BidiTextTests {
    private let lri = "\u{2066}"
    private let pdi = "\u{2069}"

    @Test func numbersInArabicTextAreIsolated() {
        #expect(BidiText.isolatingNumbers("غائم · 33° / 21°") == "غائم · \(lri)33°\(pdi) / \(lri)21°\(pdi)")
        #expect(BidiText.isolatingNumbers("القبلة 136°") == "القبلة \(lri)136°\(pdi)")
        #expect(BidiText.isolatingNumbers("الساعة 12:30، ثم") == "الساعة \(lri)12:30\(pdi)، ثم")
    }

    @Test func trailingSeparatorsStayOutside() {
        #expect(BidiText.isolatingNumbers("أيام 5, 6") == "أيام \(lri)5\(pdi), \(lri)6\(pdi)")
    }

    @Test func latinTextIsUnchanged() {
        #expect(BidiText.isolatingNumbers("Partly cloudy · 33° / 21°") == "Partly cloudy · 33° / 21°")
        #expect(BidiText.isolatingNumbers("5,543") == "5,543")
    }
}

struct MonthGridTests {
    @Test func octoberStartsOnThursdayWithSundayFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        calendar.firstWeekday = 1
        let cells = MonthGrid.levels(perDay: Array(repeating: 1, count: 31), monthOf: fixedDate, calendar: calendar)
        // 1 Oct 2026 is a Thursday: Sun…Wed are padding.
        #expect(Array(cells.prefix(5)) == [-1, -1, -1, -1, 1])
        #expect(cells.count % 7 == 0)
        #expect(cells.filter { $0 >= 0 }.count == 31)
    }

    @Test func saturdayFirstShiftsThePadding() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        calendar.firstWeekday = 7
        let cells = MonthGrid.levels(perDay: [], monthOf: fixedDate, calendar: calendar)
        // Sat, Sun, Mon, Tue, Wed padding, then Thursday the 1st (level 0: no data).
        #expect(Array(cells.prefix(6)) == [-1, -1, -1, -1, -1, 0])
    }
}

struct SpecTimelineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar
    }

    @Test func minuteRefreshBuilds60Entries() {
        let schedule = SpecTimeline.schedule(for: .minute, from: fixedDate, calendar: calendar)
        #expect(schedule.dates.count == 60)
        #expect(schedule.dates.first == fixedDate)
        #expect(schedule.reloadAfter == fixedDate.addingTimeInterval(60 * 60))
    }

    @Test func hourlyAndDailyReloadAtTheNextBoundary() {
        #expect(SpecTimeline.schedule(for: .hourly, from: fixedDate, calendar: calendar).reloadAfter
            == fixedDate.addingTimeInterval(55 * 60))
        let daily = SpecTimeline.schedule(for: .daily, from: fixedDate, calendar: calendar)
        #expect(daily.dates == [fixedDate])
        #expect(daily.reloadAfter == calendar.startOfDay(for: fixedDate).addingTimeInterval(86_400))
        #expect(SpecTimeline.schedule(for: .none, from: fixedDate, calendar: calendar).reloadAfter == nil)
    }
}

struct FontRegistryTests {
    @Test func arabicTextIsDetected() {
        #expect(FontRegistry.containsArabic("الأربعاء"))
        #expect(!FontRegistry.containsArabic("12:45 PM"))
    }

    @Test func everyWeightMapsToABundledFont() {
        for weight in FontWeightName.allCases {
            #expect(FontRegistry.bundledPostScriptNames.contains(FontRegistry.dotPostScriptName(weight)))
            #expect(FontRegistry.bundledPostScriptNames.contains(FontRegistry.arabicPostScriptName(weight)))
        }
    }
}
