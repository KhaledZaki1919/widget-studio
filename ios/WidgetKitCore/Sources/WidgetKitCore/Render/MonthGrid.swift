import Foundation

/// Lays out per-day values as a month calendar for `dotGrid` (`{{steps.monthGrid}}`): 7 cells per
/// week starting at the calendar's first weekday, padded with -1 (no dot) before day 1 and after
/// the last day, so a 7-column grid shows a real month.
public enum MonthGrid {
    public static func levels(perDay: [Double], monthOf date: Date, calendar: Calendar = .current) -> [Double] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date)?.count else { return [] }
        let weekday = calendar.component(.weekday, from: month.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells = Array(repeating: -1.0, count: leading)
        cells += (0..<days).map { $0 < perDay.count ? min(max(perDay[$0], 0), 1) : 0 }
        let trailing = (7 - cells.count % 7) % 7
        return cells + Array(repeating: -1.0, count: trailing)
    }
}
