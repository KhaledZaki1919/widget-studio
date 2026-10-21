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
            case .date(let date): BindingResolver.timeFormatter.string(from: date)
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
            case .binding(let name): value(of: name)?.display ?? Self.missing
            }
        }.joined()
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
        context.fieldValues[key] ?? spec.field(key)?.default
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
            return .text(format("HH:mm", zone: zone))
        case .builtin(let name):
            return builtin(name)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func builtin(_ name: String) -> Value? {
        let data = context.data
        switch name {
        case "time.h": return .text(format("h"))
        case "time.hh": return .text(format("HH"))
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
            return data.weather.map { .text(fieldValueOfType(.city) ?? $0.city) }
        case "steps.today": return data.stepsToday.map { number($0, digits: 0, grouped: true) }
        case "steps.streak": return data.stepsStreak.map { number($0, digits: 0) }
        case "steps.monthGrid": return data.stepsMonthGrid.map(Value.levels)
        case "sleep.lastNight": return data.sleepLastNight.map(Value.text)
        case "sleep.week": return data.sleepWeek.map(Value.levels)
        case "counter.value": return data.counter.map { number($0, digits: 0) }
        case "stopwatch.running": return .text(data.stopwatchStart == nil ? "0" : "1")
        case "stopwatch.start": return data.stopwatchStart.map(Value.date)
        case "focus.today": return data.focusToday.map(Value.text)
        case "focus.week": return data.focusWeek.map(Value.levels)
        case "prayer.next.name": return data.prayer.map { .text($0.nextName.resolved(language: context.language)) }
        case "prayer.next.time": return data.prayer.map { .date($0.nextTime) }
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
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouped
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return .number(value, display: formatter.string(from: NSNumber(value: value)) ?? String(value))
    }

    /// Fixed-format, Latin digits.
    private func format(_ pattern: String, zone: TimeZone? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone ?? context.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: context.date)
    }

    /// Words in the render language, digits Latin (`ar@numbers=latn`).
    private func localizedFormat(_ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: context.isArabic ? "ar_EG@numbers=latn" : "en_US")
        formatter.timeZone = context.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: context.date)
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

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
