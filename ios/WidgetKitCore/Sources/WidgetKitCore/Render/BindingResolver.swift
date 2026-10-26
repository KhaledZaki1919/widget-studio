import Foundation

/// Turns bindings into values for one render (brief §4.5). Digits are always Latin, so they
/// suit the `dot` font and never mirror; weekday and month names follow the language.
public struct BindingResolver {
    public enum Value: Equatable {
        case text(String)
        case number(Double, display: String)
        case levels([Double])
        case date(Date)

        public var display: String {
            switch self {
            case .text(let text): text
            case .number(_, let display): display
            case .levels(let levels): levels.map { String(format: "%.2f", $0) }.joined(separator: ",")
            case .date(let date): FormatterCache.date("HH:mm", locale: "en_US_POSIX", zone: .current).string(from: date)
            }
        }
    }

    public static let missing = "--"

    public let spec: WidgetSpec
    public let context: RenderContext

    public init(spec: WidgetSpec, context: RenderContext) {
        self.spec = spec
        self.context = context
    }

    /// `"{{weather.temp}}°"` → `"30°"`. Unknown or missing values render as "--".
    public func render(_ template: String) -> String {
        Bindings.tokenize(template).map { token in
            switch token {
            case .literal(let text): text
            case .binding(let name): value(of: name).map(display) ?? Self.missing
            }
        }.joined()
    }

    /// Text for a value; times show in the render's time zone (prayer times, stopwatch start).
    public func display(_ value: Value) -> String {
        if case .date(let date) = value {
            return FormatterCache.date(context.timePattern, locale: "en_US_POSIX", zone: context.timeZone).string(from: date)
        }
        return value.display
    }

    /// Resolves `text` when it is exactly one binding.
    public func soleValue(_ text: String) -> Value? {
        Bindings.soleBinding(text).flatMap(value(of:))
    }

    /// A number from a literal ("0.4") or a binding.
    public func number(_ text: String) -> Double? {
        if let value = Double(text.trimmingCharacters(in: .whitespaces)) { return value }
        if case .number(let value, _)? = soleValue(text) { return value }
        return nil
    }

    /// Levels from a binding, a "0.2,0.5" list or a "0110" dot pattern.
    public func levels(_ text: String) -> [Double] {
        if case .levels(let levels)? = soleValue(text) { return levels }
        return SpecLiterals.levels(text) ?? SpecLiterals.dotPattern(text) ?? []
    }

    public func date(_ text: String) -> Date? {
        if case .date(let date)? = soleValue(text) { return date }
        return nil
    }

    /// A field's current value: the user's, else the spec's default.
    public func fieldValue(_ key: String) -> String? {
        (context.fieldValues[key] ?? spec.field(key)?.default)?.resolved(language: context.language)
    }

    public func value(of raw: String) -> Value? {
        guard let name = Bindings.Name(raw) else { return nil }
        switch name {
        case .field(let key):
            guard let field = spec.field(key), let value = fieldValue(key) else { return nil }
            switch field.type {
            case .date: return FieldValues.date(value).map(Value.date)
            case .number: return Double(value).map { .number($0, display: value) }
            default: return .text(value)
            }
        case .timezoneTime(let key):
            guard let zone = fieldValue(key).flatMap(TimeZone.init(identifier:)) else { return nil }
            return .text(format(context.timePattern, zone: zone))
        case .daysUntil(let key):
            guard let target = fieldValue(key).flatMap(FieldValues.date) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = context.timeZone
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: context.date),
                                               to: calendar.startOfDay(for: target)).day ?? 0
            return number(Double(max(days, 0)), digits: 0)
        case .builtin(let name):
            return builtin(name)
        }
    }

    /// Whether a layer's `when` condition holds (ADR-011). Unknown or missing values are falsy.
    public func isSatisfied(_ text: String) -> Bool {
        guard let condition = SpecCondition(text) else { return true }
        let value = value(of: condition.binding)
        switch condition.test {
        case .truthy: return Self.isTruthy(value)
        case .falsy: return !Self.isTruthy(value)
        case .equals(let expected): return value.map(display) == expected
        }
    }

    static func isTruthy(_ value: Value?) -> Bool {
        switch value {
        case .text(let text)?: !text.isEmpty && text != "0"
        case .number(let number, _)?: number != 0
        case .levels(let levels)?: !levels.isEmpty
        case .date?: true
        case nil: false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func builtin(_ name: String) -> Value? {
        let data = context.data
        switch name {
        case "time.h": return .text(format("h"))
        // The big clock hour follows the 12/24-hour choice (M4 feedback); 12-hour has no leading zero.
        case "time.hh": return .text(format(context.uses24Hour == false ? "h" : "HH"))
        case "time.mm": return .text(format("mm"))
        case "time.ampm": return .text(localizedFormat("a"))
        case "date.d": return .text(format("d"))
        case "date.EEEE": return .text(localizedFormat("EEEE"))
        case "date.MMM": return .text(localizedFormat("MMM"))
        case "tz.offset": return .text(Self.offset(context.timeZone, at: context.date))
        case "weather.temp": return data.weather.map { number($0.temperature, digits: 0) }
        case "weather.hi": return data.weather.map { number($0.high, digits: 0) }
        case "weather.lo": return data.weather.map { number($0.low, digits: 0) }
        case "weather.cond": return data.weather.map { .text($0.condition.resolved(language: context.language)) }
        case "weather.symbol": return data.weather.map { .text($0.symbol) }
        case "weather.city":
            return data.weather.map { .text(fieldValueOfType(.city) ?? $0.city.resolved(language: context.language)) }
        case "steps.today": return data.stepsToday.map { number($0, digits: 0, grouped: true) }
        case "steps.streak": return data.stepsStreak.map { number($0, digits: 0) }
        case "steps.monthGrid": return data.stepsMonthGrid.map(Value.levels)
        case "steps.month": return data.stepsMonth.map { number($0, digits: 0, grouped: true) }
        case "sleep.lastNight": return data.sleepLastNight.map { .text($0.resolved(language: context.language)) }
        case "sleep.week": return data.sleepWeek.map(Value.levels)
        case "counter.value": return data.counter.map { number($0, digits: 0) }
        case "counter.progress":
            guard let count = data.counter, let target = fieldValue("target").flatMap(Double.init), target > 0 else { return nil }
            return number(min(count / target, 1), digits: 2)
        case "stopwatch.running": return .text(data.stopwatchStart == nil ? "0" : "1")
        case "stopwatch.start": return data.stopwatchStart.map(Value.date)
        case "focus.today": return data.focusToday.map { .text($0.resolved(language: context.language)) }
        case "focus.week": return data.focusWeek.map(Value.levels)
        case "prayer.next.name": return data.prayer.map { .text($0.nextName.resolved(language: context.language)) }
        case "prayer.next.time": return data.prayer.map { .date($0.nextTime) }
        case "prayer.next.key": return data.prayer.map { .text($0.nextKey) }
        case "qibla.bearing": return data.qiblaBearing.map { number($0, digits: 0) }
        case "location.lat": return data.latitude.map { number($0, digits: 2) }
        case "location.lon": return data.longitude.map { number($0, digits: 2) }
        case "location.alt": return data.altitude.map { number($0, digits: 0) }
        case "battery.level": return data.batteryLevel.map { .number($0, display: String(Int(($0 * 100).rounded()))) }
        default:
            if name.hasPrefix("prayer."), let time = data.prayer?.times[String(name.dropFirst("prayer.".count))] {
                return .date(time)
            }
            return nil
        }
    }

    private func fieldValueOfType(_ type: FieldSpec.Kind) -> String? {
        spec.fields.first { $0.type == type }.flatMap { fieldValue($0.key) }
    }

    private func number(_ value: Double, digits: Int, grouped: Bool = false) -> Value {
        let formatter = FormatterCache.number(digits: digits, grouped: grouped)
        return .number(value, display: formatter.string(from: NSNumber(value: value)) ?? String(value))
    }

    /// Fixed-format, Latin digits.
    private func format(_ pattern: String, zone: TimeZone? = nil) -> String {
        FormatterCache.date(pattern, locale: "en_US_POSIX", zone: zone ?? context.timeZone).string(from: context.date)
    }

    /// Words in the render language, digits Latin (`ar@numbers=latn`).
    private func localizedFormat(_ pattern: String) -> String {
        FormatterCache.date(pattern, locale: context.localeIdentifier, zone: context.timeZone).string(from: context.date)
    }

    /// "GMT+2", "GMT-3:30", "GMT".
    static func offset(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        guard seconds != 0 else { return "GMT" }
        let sign = seconds > 0 ? "+" : "-"
        let hours = abs(seconds) / 3600
        let minutes = abs(seconds) % 3600 / 60
        return minutes == 0 ? "GMT\(sign)\(hours)" : String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }
}

/// Formatters are expensive to create and a widget renders up to 60 entries per timeline, so
/// they are created once per pattern, locale and time zone.
enum FormatterCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var dates: [String: DateFormatter] = [:]
    nonisolated(unsafe) private static var numbers: [String: NumberFormatter] = [:]

    static func date(_ pattern: String, locale: String, zone: TimeZone) -> DateFormatter {
        let key = "\(pattern)|\(locale)|\(zone.identifier)"
        lock.lock()
        defer { lock.unlock() }
        if let formatter = dates[key] { return formatter }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        dates[key] = formatter
        return formatter
    }

    static func number(digits: Int, grouped: Bool) -> NumberFormatter {
        let key = "\(digits)|\(grouped)"
        lock.lock()
        defer { lock.unlock() }
        if let formatter = numbers[key] { return formatter }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouped
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        numbers[key] = formatter
        return formatter
    }
}
