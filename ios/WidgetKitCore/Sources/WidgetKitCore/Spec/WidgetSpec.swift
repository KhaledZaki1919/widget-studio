import Foundation

/// Widget Spec v1 (brief §4): one widget = this JSON + an optional user image, drawn by
/// `SpecRenderer`. Decoding ignores unknown keys. Unknown layer types decode as `.unknown`
/// and unknown enum values fail decoding; `SpecValidator` turns both into issues, never a crash.
public struct WidgetSpec: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var id: String
    public var name: LocalizedText
    public var family: SpecFamily
    public var theme: SpecTheme
    public var refresh: RefreshPolicy
    public var background: Background
    public var fields: [FieldSpec]
    public var layers: [Layer]

    public init(schemaVersion: Int = 1, id: String, name: LocalizedText, family: SpecFamily,
                theme: SpecTheme = .dark, refresh: RefreshPolicy = .none, background: Background,
                fields: [FieldSpec] = [], layers: [Layer]) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.family = family
        self.theme = theme
        self.refresh = refresh
        self.background = background
        self.fields = fields
        self.layers = layers
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, family, theme, refresh, background, fields, layers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(LocalizedText.self, forKey: .name)
        family = try container.decode(SpecFamily.self, forKey: .family)
        theme = try container.decodeIfPresent(SpecTheme.self, forKey: .theme) ?? .dark
        refresh = try container.decodeIfPresent(RefreshPolicy.self, forKey: .refresh) ?? .none
        background = try container.decode(Background.self, forKey: .background)
        fields = try container.decodeIfPresent([FieldSpec].self, forKey: .fields) ?? []
        layers = try container.decode([Layer].self, forKey: .layers)
    }

    public func field(_ key: String) -> FieldSpec? {
        fields.first { $0.key == key }
    }
}

/// Canvas units per family (brief §4.2).
public enum SpecFamily: String, Codable, Sendable, CaseIterable {
    case small, medium, large

    public var canvas: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        }
    }
}

public enum SpecTheme: String, Codable, Sendable, CaseIterable {
    case light, dark
}

public enum RefreshPolicy: String, Codable, Sendable, CaseIterable {
    case none, minute, hourly, daily
}

/// A string, or `{ "en": …, "ar": … }`.
public enum LocalizedText: Codable, Sendable, Equatable {
    case plain(String)
    case localized(en: String, ar: String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .plain(text)
            return
        }
        let pair = try container.decode([String: String].self)
        guard let en = pair["en"], let ar = pair["ar"] else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "needs both \"en\" and \"ar\"")
        }
        self = .localized(en: en, ar: ar)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .plain(let text): try container.encode(text)
        case .localized(let en, let ar): try container.encode(["en": en, "ar": ar])
        }
    }

    /// Arabic for `ar*` language codes, English otherwise.
    public func resolved(language: String) -> String {
        switch self {
        case .plain(let text): text
        case .localized(let en, let ar): language.hasPrefix("ar") ? ar : en
        }
    }

    public var allValues: [String] {
        switch self {
        case .plain(let text): [text]
        case .localized(let en, let ar): [en, ar]
        }
    }
}

public struct Background: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case solid, gradient }

    public var type: Kind
    public var color: String?
    public var colors: [String]?
    /// Degrees, 0 = left to right, 90 = top to bottom.
    public var angle: Double?
    /// Drawn behind circle templates, because a widget is always a rounded square (brief §2).
    public var outerColor: String?

    public init(type: Kind, color: String? = nil, colors: [String]? = nil, angle: Double? = nil, outerColor: String? = nil) {
        self.type = type
        self.color = color
        self.colors = colors
        self.angle = angle
        self.outerColor = outerColor
    }

    public static func solid(_ color: String) -> Background { Background(type: .solid, color: color) }
}

/// A user-editable value (brief §4.3), referenced as `{{field.<key>}}`.
public struct FieldSpec: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case text, number, date, color, image, timezone, city, shortcut, url
    }

    public var key: String
    public var type: Kind
    public var label: LocalizedText
    /// Dates are ISO 8601 (`2026-12-31` or `2026-12-31T20:00:00Z`).
    public var `default`: String?

    public init(key: String, type: Kind, label: LocalizedText, default: String? = nil) {
        self.key = key
        self.type = type
        self.label = label
        self.default = `default`
    }
}

public struct Frame: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    /// Clamped so the frame lies inside the canvas (brief §4.6).
    public func clamped(to canvas: CGSize) -> Frame {
        let width = min(max(w, 0), canvas.width)
        let height = min(max(h, 0), canvas.height)
        return Frame(
            x: min(max(x, 0), canvas.width - width),
            y: min(max(y, 0), canvas.height - height),
            w: width,
            h: height
        )
    }

    /// The same frame on the other side of the canvas (RTL `mirror`).
    public func mirrored(canvasWidth: Double) -> Frame {
        Frame(x: canvasWidth - x - w, y: y, w: w, h: h)
    }
}
