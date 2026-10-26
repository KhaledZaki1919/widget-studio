import Foundation
import Testing
@testable import WidgetKitCore

/// 12/24-hour clocks (ADR-017). 2026-10-21 14:05 UTC.
struct ClockFormatTests {
    let date = Date(timeIntervalSince1970: 1_792_591_500)
    let utc = TimeZone(identifier: "UTC") ?? .current

    func resolver(uses24Hour: Bool?, fields: [FieldSpec] = []) -> BindingResolver {
        let spec = WidgetSpec(id: "test.clock", name: .localized(en: "C", ar: "س"), family: .small,
                              background: .solid("#000000"), fields: fields,
                              layers: [Layer(frame: Frame(x: 0, y: 0, w: 10, h: 10), content: .shape(ShapeLayer(kind: .rect, fill: "#FFFFFF")))])
        var context = RenderContext(date: date, language: "en", timeZone: utc,
                                    data: .sample(now: date, calendar: { var c = Calendar(identifier: .gregorian); c.timeZone = utc; return c }()))
        context.uses24Hour = uses24Hour
        return BindingResolver(spec: spec, context: context)
    }

    @Test func hourBindingFollowsTheChoice() {
        #expect(resolver(uses24Hour: true).render("{{time.hh}}:{{time.mm}}") == "14:05")
        #expect(resolver(uses24Hour: false).render("{{time.hh}}:{{time.mm}}") == "2:05")
        // Unset (tests, snapshots) keeps 24-hour.
        #expect(resolver(uses24Hour: nil).render("{{time.hh}}") == "14")
    }

    @Test func prayerAndZoneTimesFollowTheChoice() {
        let zone = [FieldSpec(key: "zone", type: .timezone, label: "Zone", default: "Asia/Tokyo")]
        #expect(resolver(uses24Hour: true, fields: zone).render("{{tz.zone.time}}") == "23:05")
        #expect(resolver(uses24Hour: false, fields: zone).render("{{tz.zone.time}}") == "11:05")
        #expect(resolver(uses24Hour: false).render("{{prayer.asr}}") == "2:58")
        #expect(resolver(uses24Hour: true).render("{{prayer.asr}}") == "14:58")
    }

    @Test func explicitFormatsIgnoreTheDevice() {
        #expect(ClockFormat.h12.uses24Hour() == false)
        #expect(ClockFormat.h24.uses24Hour() == true)
        #expect(ClockFormat.device.uses24Hour(locale: Locale(identifier: "en_US")) == false)
        #expect(ClockFormat.device.uses24Hour(locale: Locale(identifier: "en_GB")) == true)
    }

    @Test func liveTimeLocaleCarriesTheHourCycle() {
        var context = RenderContext(language: "en")
        context.uses24Hour = true
        #expect(context.locale.hourCycle == .zeroToTwentyThree)
        context.uses24Hour = false
        #expect(context.locale.hourCycle == .oneToTwelve)
    }

    @Test func designsUseTheirChoiceElseTheDefault() throws {
        var design = SavedDesign.new(from: try TemplateLibrary.load(id: "mono.clock.digital").get(), language: "en")
        #expect(design.renderContext(language: "en", data: DataSnapshot(), defaultClock: .h12).uses24Hour == false)
        design.clockFormat = .h24
        #expect(design.renderContext(language: "en", data: DataSnapshot(), defaultClock: .h12).uses24Hour == true)
    }

    @Test func settingsDecodeOldFilesWithDeviceDefault() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{\"stepGoal\":9000}".utf8))
        #expect(settings.clockFormat == .device)
    }
}
