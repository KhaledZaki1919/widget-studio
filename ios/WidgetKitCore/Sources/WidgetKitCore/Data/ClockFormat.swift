import Foundation

/// 12- or 24-hour clock: follow the device (default), or force one (Settings default, and per
/// design in the editor). In store mode the widget can't see the app's settings, so it follows
/// the device (ADR-017).
public enum ClockFormat: String, Codable, Sendable, CaseIterable {
    case device, h12, h24

    /// Whether this format shows 24-hour time; `device` reads the locale's preference.
    public func uses24Hour(locale: Locale = .current) -> Bool {
        switch self {
        case .h12: false
        case .h24: true
        case .device: Self.deviceUses24Hour(locale: locale)
        }
    }

    /// The device's 12/24-hour setting, as reflected in the current locale ("j" → "a" means 12h).
    public static func deviceUses24Hour(locale: Locale = .current) -> Bool {
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "HH"
        return !pattern.contains("a")
    }
}
