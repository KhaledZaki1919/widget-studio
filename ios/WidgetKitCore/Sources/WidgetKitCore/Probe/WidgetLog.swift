import Foundation

/// A short step log of the widget extension (ADR-012): the template widgets record each step
/// (placeholder, snapshot, timeline start/end, render), and the check widget, which renders on
/// every install so far, shows the last lines. Both run in the same extension process, so they
/// share its container even without an App Group. Keeps the last `capacity` lines.
public enum WidgetLog {
    public static let capacity = 40
    private static let lock = NSLock()

    /// `<container>/Logs/template-widgets.log`: the App Group when there is one, else the extension's own.
    public static var url: URL { fileURL }

    /// Resolved once per process: resolving writes a probe file, too costly for every line.
    private static let fileURL = AppGroupResolver.resolve().directory
        .appendingPathComponent("Logs", isDirectory: true)
        .appendingPathComponent("template-widgets.log")

    /// Appends "HH:mm:ss.SSS message"; never throws (logging must not break a widget).
    public static func add(_ message: String, now: Date = .now) {
        lock.lock()
        defer { lock.unlock() }
        var lines = read(url: url)
        lines.append("\(stamp(now)) \(message)")
        if lines.count > capacity { lines.removeFirst(lines.count - capacity) }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(lines.joined(separator: "\n").utf8).write(to: url, options: .atomic)
    }

    /// The last `count` lines, oldest first.
    public static func last(_ count: Int) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(read(url: url).suffix(count))
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    static func read(url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }

    static func stamp(_ date: Date) -> String {
        FormatterCache.date("HH:mm:ss.SSS", locale: "en_US_POSIX", zone: .current).string(from: date)
    }

    /// Milliseconds since `start`, for "timeline done in 12 ms".
    public static func elapsed(since start: Date) -> Int {
        Int(Date.now.timeIntervalSince(start) * 1000)
    }
}
