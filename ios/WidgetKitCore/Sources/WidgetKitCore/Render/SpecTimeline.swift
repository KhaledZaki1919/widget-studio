import Foundation

/// When a widget showing a spec needs new entries (brief §4.3 `refresh`).
public enum SpecTimeline {
    /// Entry dates starting at `now`, and when to ask for the next timeline.
    public static func schedule(for refresh: RefreshPolicy, from now: Date,
                                calendar: Calendar = .current) -> (dates: [Date], reloadAfter: Date?) {
        switch refresh {
        case .none:
            return ([now], nil)
        case .minute:
            // 60 entries, one per minute boundary, then reload (brief §4.3).
            let start = calendar.dateInterval(of: .minute, for: now)?.start ?? now
            let dates = [now] + (1..<60).compactMap { calendar.date(byAdding: .minute, value: $0, to: start) }
            return (dates, calendar.date(byAdding: .minute, value: 60, to: start))
        case .hourly:
            let start = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            return ([now], calendar.date(byAdding: .hour, value: 1, to: start))
        case .daily:
            let start = calendar.startOfDay(for: now)
            return ([now], calendar.date(byAdding: .day, value: 1, to: start))
        }
    }
}
