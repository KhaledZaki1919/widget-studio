import Foundation

/// Theme color tokens (TEMPLATES.md "Style tokens", ADR-011). A spec color may be `#RRGGBB(AA)`
/// or one of these tokens; tokens resolve per theme, so one template renders light and dark,
/// and the editor can change `accent` later.
public enum SpecTokens {
    public static let names = ["bg", "fg", "muted", "accent", "outer", "line", "dim", "onAccent"]

    public static func isToken(_ value: String) -> Bool {
        value.hasPrefix("@") && names.contains(String(value.dropFirst()))
    }

    /// The hex value of a token for a theme.
    public static func hex(_ name: String, theme: SpecTheme) -> String? {
        let light = theme == .light
        switch name {
        case "bg": return light ? "#FFFFFF" : "#0E0E0E"
        case "fg": return light ? "#0E0E0E" : "#FFFFFF"
        case "muted": return light ? "#8A8A8A" : "#7A7A7A"
        case "accent": return "#E2231A"
        case "outer": return light ? "#E6E9EC" : "#000000"
        // Dividers and tracks.
        case "line": return light ? "#0E0E0E1F" : "#FFFFFF26"
        // Unlit dots.
        case "dim": return light ? "#0E0E0E1A" : "#FFFFFF26"
        case "onAccent": return "#FFFFFF"
        default: return nil
        }
    }
}

extension WidgetSpec {
    /// The same spec with every color token replaced by its hex value for `theme` (and `theme`
    /// set). Tokens appear only as whole JSON string values, so a JSON round trip is exact.
    public func resolvingTokens(theme: SpecTheme? = nil) -> WidgetSpec {
        let theme = theme ?? self.theme
        guard var json = (try? JSONEncoder().encode(self)).flatMap({ String(data: $0, encoding: .utf8) }) else { return self }
        for name in SpecTokens.names {
            if let hex = SpecTokens.hex(name, theme: theme) {
                json = json.replacingOccurrences(of: "\"@\(name)\"", with: "\"\(hex)\"")
            }
        }
        guard var resolved = try? JSONDecoder().decode(WidgetSpec.self, from: Data(json.utf8)) else { return self }
        resolved.theme = theme
        return resolved
    }
}

/// A parsed layer `when` condition (ADR-011).
public struct SpecCondition: Sendable, Equatable {
    public enum Test: Sendable, Equatable {
        case truthy
        case falsy
        case equals(String)
    }

    public let binding: String
    public let test: Test

    /// `"{{b}}"`, `"!{{b}}"` or `"{{b}} == value"`; nil for anything else.
    public init?(_ text: String) {
        var rest = text.trimmingCharacters(in: .whitespaces)
        var negated = false
        if rest.hasPrefix("!") {
            negated = true
            rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        guard rest.hasPrefix("{{"), let close = rest.range(of: "}}") else { return nil }
        binding = String(rest[rest.index(rest.startIndex, offsetBy: 2)..<close.lowerBound]).trimmingCharacters(in: .whitespaces)
        let tail = rest[close.upperBound...].trimmingCharacters(in: .whitespaces)
        if tail.isEmpty {
            test = negated ? .falsy : .truthy
        } else if !negated, tail.hasPrefix("==") {
            let value = tail.dropFirst(2).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { return nil }
            test = .equals(value)
        } else {
            return nil
        }
        guard !binding.isEmpty else { return nil }
    }
}
