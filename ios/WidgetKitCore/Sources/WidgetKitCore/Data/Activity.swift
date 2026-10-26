import Foundation

/// The tasbeeh counter (ADR-016), kept by whoever runs the button: the widget extension (in its
/// own container, no App Group needed) or the app.
public struct CounterState: Codable, Sendable, Equatable {
    public var value: Int = 0
    public var updated: Date = .distantPast

    public static let cacheName = "counter"

    public init(value: Int = 0, updated: Date = .distantPast) {
        self.value = value
        self.updated = updated
    }

    public mutating func increment(now: Date = .now) {
        value += 1
        updated = now
    }

    public mutating func reset(now: Date = .now) {
        value = 0
        updated = now
    }

    public static func load(_ cache: DataCache = DataCache()) -> CounterState {
        cache.read(CounterState.self, cacheName) ?? CounterState()
    }

    public func save(_ cache: DataCache = DataCache()) throws {
        try cache.write(self, Self.cacheName)
    }
}

/// The stopwatch: running since `start`, plus finished sessions (14 days), which also feed Focus
/// Today (`focus.today`, `focus.week`).
public struct StopwatchState: Codable, Sendable, Equatable {
    public struct Session: Codable, Sendable, Equatable {
        public var start: Date
        public var end: Date
    }

    public var start: Date?
    public var sessions: [Session] = []

    public static let cacheName = "stopwatch"
    static let keepDays: TimeInterval = 14 * 86_400

    public init(start: Date? = nil, sessions: [Session] = []) {
        self.start = start
        self.sessions = sessions
    }

    public var isRunning: Bool { start != nil }

    /// Starts, or stops and records the session.
    public mutating func toggle(now: Date = .now) {
        if let start {
            if now > start { sessions.append(Session(start: start, end: now)) }
            self.start = nil
        } else {
            start = now
        }
        sessions.removeAll { now.timeIntervalSince($0.end) > Self.keepDays }
    }

    /// Minutes recorded on `day` (sessions split at midnight; a running session counts until now).
    public func minutes(on day: Date, now: Date, calendar: Calendar) -> Double {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return 0 }
        let all = sessions + (start.map { [Session(start: $0, end: now)] } ?? [])
        return all.reduce(0) { total, session in
            let overlap = min(session.end, interval.end).timeIntervalSince(max(session.start, interval.start))
            return total + max(0, overlap) / 60
        }
    }

    /// The last 7 days, oldest first, as 0…1 of the busiest day (at least one hour).
    public func week(now: Date, calendar: Calendar) -> [Double] {
        let minutes = (0..<7).reversed().map { offset -> Double in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return 0 }
            return self.minutes(on: day, now: now, calendar: calendar)
        }
        let top = max(minutes.max() ?? 0, 60)
        return minutes.map { $0 / top }
    }

    public static func load(_ cache: DataCache = DataCache()) -> StopwatchState {
        cache.read(StopwatchState.self, cacheName) ?? StopwatchState()
    }

    public func save(_ cache: DataCache = DataCache()) throws {
        try cache.write(self, Self.cacheName)
    }
}
