import Foundation
import Testing
@testable import WidgetKitCore

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    calendar.firstWeekday = 1
    return calendar
}

/// 2026-10-21 14:05 UTC, a Wednesday.
private let wednesday = Date(timeIntervalSince1970: 1_792_591_500)

private func day(_ offset: Int) -> String {
    let date = utcCalendar.date(byAdding: .day, value: offset, to: wednesday) ?? wednesday
    return HealthSummary.key(date, utcCalendar)
}

private func tempCache() -> DataCache {
    DataCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("Live-\(UUID().uuidString)"))
}

struct HealthSummaryTests {
    @Test func streakCountsTodayOnlyWhenReached() {
        var summary = HealthSummary(steps: [day(-1): 9000, day(-2): 8500, day(-3): 7000, day(0): 3000], sleep: [:], fetched: wednesday)
        #expect(summary.streak(now: wednesday, goal: 8000, calendar: utcCalendar) == 2)
        summary.steps[day(0)] = 8100
        #expect(summary.streak(now: wednesday, goal: 8000, calendar: utcCalendar) == 3)
        #expect(HealthSummary(steps: [:], sleep: [:], fetched: wednesday).streak(now: wednesday, goal: 8000, calendar: utcCalendar) == 0)
    }

    @Test func monthGridAndTotal() {
        // October 2026: the 21st is today.
        let summary = HealthSummary(steps: [day(-1): 4000, day(-20): 8000, day(0): 1234], sleep: [:], fetched: wednesday)
        let cells = summary.monthLevels(now: wednesday, goal: 8000, calendar: utcCalendar)
        // Sunday-first: 1 Oct 2026 is a Thursday, so 4 padding cells.
        #expect(Array(cells.prefix(5)) == [-1, -1, -1, -1, 1])
        #expect(cells[4 + 19] == 0.5)                 // the 20th
        #expect(cells[4 + 20] == MonthGrid.highlight) // today
        #expect(cells[4 + 21] == 0)                   // tomorrow
        #expect(summary.monthTotal(now: wednesday, calendar: utcCalendar) == 4000 + 8000 + 1234)
        #expect(summary.stepsToday(now: wednesday, calendar: utcCalendar) == 1234)
    }

    @Test func sleepWeekSundayToSaturday() {
        let summary = HealthSummary(steps: [:], sleep: [day(0): 450, day(-3): 540, day(-4): 999], fetched: wednesday)
        let week = summary.sleepWeek(now: wednesday, calendar: utcCalendar)
        #expect(week.count == 7)
        #expect(week[0] == 1)            // Sunday the 18th: 9 h
        #expect(week[3] == 450.0 / 540)  // Wednesday (today)
        #expect(week[4] == 0)            // Thursday hasn't happened
        #expect(summary.sleepLastNight(now: wednesday, calendar: utcCalendar) == 450)
        #expect(HealthSummary.duration(minutes: 440) == .localized(en: "7h 20m", ar: "7س 20د"))
    }
}

struct ActivityStateTests {
    @Test func counterIncrementsResetsAndPersists() throws {
        let cache = tempCache()
        var counter = CounterState.load(cache)
        #expect(counter.value == 0)
        counter.increment(now: wednesday)
        counter.increment(now: wednesday)
        try counter.save(cache)
        #expect(CounterState.load(cache).value == 2)
        counter.reset(now: wednesday)
        try counter.save(cache)
        #expect(CounterState.load(cache) == CounterState(value: 0, updated: wednesday))
    }

    @Test func stopwatchTogglesAndRecordsSessions() throws {
        let cache = tempCache()
        var stopwatch = StopwatchState.load(cache)
        #expect(!stopwatch.isRunning)
        stopwatch.toggle(now: wednesday)
        #expect(stopwatch.start == wednesday)
        stopwatch.toggle(now: wednesday.addingTimeInterval(25 * 60))
        #expect(!stopwatch.isRunning)
        #expect(stopwatch.sessions.count == 1)
        try stopwatch.save(cache)
        #expect(StopwatchState.load(cache) == stopwatch)
        #expect(stopwatch.minutes(on: wednesday, now: wednesday, calendar: utcCalendar) == 25)
    }

    @Test func focusSplitsAtMidnightAndCountsRunningTime() {
        let lateStart = utcCalendar.date(bySettingHour: 23, minute: 30, second: 0, of: wednesday) ?? wednesday
        var stopwatch = StopwatchState()
        stopwatch.toggle(now: lateStart)
        let next = lateStart.addingTimeInterval(60 * 60) // 00:30 Thursday
        #expect(stopwatch.minutes(on: wednesday, now: next, calendar: utcCalendar) == 30)
        #expect(stopwatch.minutes(on: next, now: next, calendar: utcCalendar) == 30)
        let week = stopwatch.week(now: next, calendar: utcCalendar)
        #expect(week.count == 7)
        #expect(week[6] == 0.5 && week[5] == 0.5)  // 30 min of the 60 min floor
    }

    @Test func oldSessionsAreDropped() {
        var stopwatch = StopwatchState(sessions: [.init(start: wednesday.addingTimeInterval(-20 * 86_400),
                                                        end: wednesday.addingTimeInterval(-20 * 86_400 + 60))])
        stopwatch.toggle(now: wednesday)
        #expect(stopwatch.sessions.isEmpty)
    }
}

struct LiveDataTests {
    let cairo = StoredLocation(latitude: 30.0444, longitude: 31.2357, altitude: 23,
                               city: .localized(en: "Cairo", ar: "القاهرة"), updated: wednesday)

    @Test func requirementsPerTemplate() throws {
        func groups(_ id: String) throws -> Set<Bindings.Group> {
            DataRequirements.groups(for: try TemplateLibrary.load(id: id).get())
        }
        #expect(try groups("mono.weather.forecast").contains(.weather))
        #expect(try groups("mono.steps.streak").contains(.health))
        #expect(try groups("mono.prayer.day").contains(.prayer))
        #expect(try groups("mono.location.coords").contains(.location))
        #expect(try groups("mono.stopwatch").contains(.app))
        #expect(try groups("mono.clock.analog").isDisjoint(with: [.weather, .health, .prayer, .location, .device]))
    }

    @Test func gapsNameWhatIsMissing() throws {
        let forecast = try TemplateLibrary.load(id: "mono.weather.forecast").get()
        let steps = try TemplateLibrary.load(id: "mono.steps.streak").get()
        let clock = try TemplateLibrary.load(id: "mono.clock.digital").get()
        #expect(LiveData.gap(for: forecast, LiveInputs()) == .noLocation)
        #expect(LiveData.gap(for: forecast, LiveInputs(location: cairo)) == .noWeather)
        #expect(LiveData.gap(for: steps, LiveInputs(health: .failure(.noData))) == .noHealth)
        #expect(LiveData.gap(for: steps, LiveInputs(health: .success(HealthSummary(steps: [:], sleep: [:], fetched: wednesday)))) == nil)
        #expect(LiveData.gap(for: clock, LiveInputs()) == nil)
    }

    @Test func snapshotUsesOnlyRealInputs() {
        let empty = LiveData.snapshot(LiveInputs(), now: wednesday, calendar: utcCalendar)
        #expect(empty.weather == nil && empty.prayer == nil && empty.stepsToday == nil && empty.batteryLevel == nil)
        #expect(empty.counter == 0)

        var inputs = LiveInputs(location: cairo, battery: 0.42)
        inputs.counter.increment(now: wednesday)
        inputs.health = .success(HealthSummary(steps: [day(0): 5000], sleep: [day(0): 420], fetched: wednesday))
        let data = LiveData.snapshot(inputs, now: wednesday, calendar: utcCalendar)
        #expect(data.latitude == 30.0444 && data.altitude == 23)
        #expect(data.prayer != nil)
        #expect(abs((data.qiblaBearing ?? 0) - 136) < 1)
        #expect(data.batteryLevel == 0.42)
        #expect(data.counter == 1)
        #expect(data.stepsToday == 5000)
        #expect(data.sleepLastNight == .localized(en: "7h 0m", ar: "7س 0د"))
    }
}
