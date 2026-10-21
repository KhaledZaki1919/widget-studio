import Foundation

/// One problem found in a spec. `path` is JSON-like (`layers[3].font.family`).
public struct SpecIssue: Error, Sendable, Equatable, CustomStringConvertible {
    public let path: String
    public let message: String

    public init(_ path: String, _ message: String) {
        self.path = path
        self.message = message
    }

    public var description: String { path.isEmpty ? message : "\(path): \(message)" }
}

/// Every issue of one failed validation (a `Result` failure must be an `Error`).
public struct SpecIssues: Error, Sendable, Equatable, CustomStringConvertible {
    public let issues: [SpecIssue]

    public init(_ issues: [SpecIssue]) {
        self.issues = issues
    }

    public var description: String { SpecValidator.describe(issues) }
}

/// Validation rules of brief §4.6. Pure Swift, so the app, the widget and the tests share it.
/// `validate` returns the spec with frames clamped to the canvas, or every issue found.
public struct SpecValidator: Sendable {
    public enum Mode: Sendable {
        /// Bundled templates and specs the user edited.
        case standard
        /// AI output (brief §5.1): only `open.app` buttons and time / date / weather bindings.
        case ai
    }

    public static let maxLayers = 30
    public static let maxTextLength = 200
    public static let fontSizes: ClosedRange<Double> = 6...200
    public static let minAIFontSize: Double = 11

    public let mode: Mode

    public init(mode: Mode = .standard) {
        self.mode = mode
    }

    public func validate(data: Data) -> Result<WidgetSpec, SpecIssues> {
        do {
            return validate(try JSONDecoder().decode(WidgetSpec.self, from: data))
        } catch let error as DecodingError {
            return .failure(SpecIssues([Self.issue(from: error)]))
        } catch {
            return .failure(SpecIssues([SpecIssue("", "not valid JSON")]))
        }
    }

    public func validate(_ spec: WidgetSpec) -> Result<WidgetSpec, SpecIssues> {
        var check = Check(spec: spec, mode: mode)
        check.run()
        guard check.issues.isEmpty else { return .failure(SpecIssues(check.issues)) }
        var normalized = spec
        let canvas = spec.family.canvas
        for index in normalized.layers.indices {
            normalized.layers[index].frame = normalized.layers[index].frame.clamped(to: canvas)
        }
        return .success(normalized)
    }

    /// Readable text for the AI retry ("Your previous reply was not valid: …").
    public static func describe(_ issues: [SpecIssue]) -> String {
        issues.prefix(20).map(\.description).joined(separator: "; ")
    }

    static func issue(from error: DecodingError) -> SpecIssue {
        func path(_ codingPath: [CodingKey]) -> String {
            codingPath.reduce(into: "") { result, key in
                if let index = key.intValue {
                    result += "[\(index)]"
                } else {
                    result += result.isEmpty ? key.stringValue : ".\(key.stringValue)"
                }
            }
        }
        switch error {
        case .keyNotFound(let key, let context):
            let parent = path(context.codingPath)
            return SpecIssue(parent, "missing \"\(key.stringValue)\"")
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return SpecIssue(path(context.codingPath), "wrong type")
        case .dataCorrupted(let context):
            let detail = context.debugDescription
            if context.codingPath.isEmpty { return SpecIssue("", "not valid JSON") }
            if detail.contains("Cannot initialize") { return SpecIssue(path(context.codingPath), "unknown value") }
            return SpecIssue(path(context.codingPath), detail)
        @unknown default:
            return SpecIssue("", "invalid spec")
        }
    }
}

/// Collects issues for one spec.
private struct Check {
    let spec: WidgetSpec
    let mode: SpecValidator.Mode
    var issues: [SpecIssue] = []

    init(spec: WidgetSpec, mode: SpecValidator.Mode) {
        self.spec = spec
        self.mode = mode
    }

    mutating func fail(_ path: String, _ message: String) {
        issues.append(SpecIssue(path, message))
    }

    mutating func run() {
        if spec.schemaVersion != 1 { fail("schemaVersion", "must be 1") }
        if !Self.isValidID(spec.id) { fail("id", "use lowercase letters, digits, dots, dashes or underscores (max 64)") }
        if case .plain = spec.name { fail("name", "needs both \"en\" and \"ar\"") }
        for value in spec.name.allValues { text(path: "name", value, allowBindings: false) }
        checkBackground()
        checkFields()
        if spec.layers.isEmpty { fail("layers", "needs at least one layer") }
        if spec.layers.count > SpecValidator.maxLayers { fail("layers", "at most \(SpecValidator.maxLayers) layers") }
        for (index, layer) in spec.layers.enumerated() {
            checkLayer(layer, path: "layers[\(index)]")
        }
    }

    static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && id.unicodeScalars.allSatisfy {
            ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "." || $0 == "-" || $0 == "_"
        }
    }

    // MARK: Values

    mutating func color(_ path: String, _ value: String?) {
        guard let value else { return }
        if HexColor.parse(value) == nil { fail(path, "color must be #RRGGBB or #RRGGBBAA") }
    }

    mutating func number(_ path: String, _ value: Double?, in range: ClosedRange<Double>) {
        guard let value else { return }
        if !value.isFinite || !range.contains(value) {
            fail(path, "must be between \(Self.format(range.lowerBound)) and \(Self.format(range.upperBound))")
        }
    }

    mutating func count(_ path: String, _ value: Int, in range: ClosedRange<Int>) {
        if !range.contains(value) { fail(path, "must be between \(range.lowerBound) and \(range.upperBound)") }
    }

    static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }

    /// Length, remote URLs and bindings of a user-visible string.
    mutating func text(path: String, _ value: String, allowBindings: Bool = true, expecting kinds: Set<Bindings.Kind>? = nil) {
        if value.count > SpecValidator.maxTextLength { fail(path, "at most \(SpecValidator.maxTextLength) characters") }
        if Self.containsURL(value) { fail(path, "remote URLs are not allowed in specs") }
        let names = Bindings.names(in: value)
        if !allowBindings && !names.isEmpty {
            fail(path, "bindings are not allowed here")
            return
        }
        for raw in names {
            binding(path: path, raw, expecting: kinds)
        }
    }

    static func containsURL(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("://") || lower.hasPrefix("www.") || lower.contains(" www.")
    }

    /// Checks one binding name: known, allowed in this mode, field exists, right kind.
    mutating func binding(path: String, _ raw: String, expecting kinds: Set<Bindings.Kind>?) {
        guard let name = Bindings.Name(raw) else {
            fail(path, "unknown binding {{\(raw)}}")
            return
        }
        if mode == .ai, name.group != .time, name.group != .weather {
            fail(path, "binding {{\(raw)}} is not allowed in AI output")
        }
        let kind: Bindings.Kind
        switch name {
        case .field(let key), .timezoneTime(let key):
            guard let field = spec.field(key) else {
                fail(path, "{{\(raw)}} refers to a missing field")
                return
            }
            if case .timezoneTime = name {
                if field.type != .timezone { fail(path, "{{\(raw)}} needs a timezone field") }
                kind = .text
            } else {
                kind = field.type == .date ? .date : field.type == .number ? .number : .text
            }
        case .builtin:
            kind = name.builtinKind ?? .text
        }
        guard let kinds, !kinds.contains(kind) else { return }
        fail(path, "{{\(raw)}} doesn't give the right kind of value here")
    }

    /// A value that must be exactly one binding of an allowed kind, or a literal accepted by `literal`.
    mutating func bindingOrLiteral(path: String, _ value: String, kinds: Set<Bindings.Kind>, literal: (String) -> Bool) {
        if let raw = Bindings.soleBinding(value) {
            binding(path: path, raw, expecting: kinds)
        } else if !literal(value) {
            fail(path, "must be a binding like {{…}} or a valid literal")
        }
    }

    // MARK: Parts

    mutating func checkBackground() {
        let background = spec.background
        switch background.type {
        case .solid:
            if background.color == nil { fail("background.color", "required for a solid background") }
            color("background.color", background.color)
        case .gradient:
            let colors = background.colors ?? []
            if !(2...4).contains(colors.count) { fail("background.colors", "a gradient needs 2 to 4 colors") }
            for (index, value) in colors.enumerated() { color("background.colors[\(index)]", value) }
            number("background.angle", background.angle, in: -360...360)
        }
        color("background.outerColor", background.outerColor)
    }

    mutating func checkFields() {
        var keys = Set<String>()
        for (index, field) in spec.fields.enumerated() {
            let path = "fields[\(index)]"
            if !Bindings.isValidKey(field.key) { fail("\(path).key", "letters, digits and underscores, starting with a letter") }
            if !keys.insert(field.key).inserted { fail("\(path).key", "duplicate key \"\(field.key)\"") }
            for value in field.label.allValues { text(path: "\(path).label", value, allowBindings: false) }
            guard let value = field.default else { continue }
            if value.count > SpecValidator.maxTextLength { fail("\(path).default", "at most \(SpecValidator.maxTextLength) characters") }
            switch field.type {
            case .date: if FieldValues.date(value) == nil { fail("\(path).default", "must be an ISO 8601 date") }
            case .number: if Double(value) == nil { fail("\(path).default", "must be a number") }
            case .color: color("\(path).default", value)
            case .timezone: if TimeZone(identifier: value) == nil { fail("\(path).default", "unknown time zone") }
            // A user field may hold a URL (open.url), but a spec's default may not.
            case .url: if !value.isEmpty { fail("\(path).default", "URL fields can't have a default") }
            case .text, .city, .shortcut, .image:
                if Self.containsURL(value) { fail("\(path).default", "remote URLs are not allowed in specs") }
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    mutating func checkLayer(_ layer: Layer, path: String) {
        let frame = layer.frame
        if ![frame.x, frame.y, frame.w, frame.h].allSatisfy(\.isFinite) || frame.w <= 0 || frame.h <= 0 {
            fail("\(path).frame", "w and h must be positive numbers")
        }
        number("\(path).opacity", layer.opacity, in: 0...1)

        switch layer.content {
        case .unknown(let type):
            fail("\(path).type", "unknown layer type \"\(type)\"")
        case .text(let text):
            checkText(text, path: path)
        case .image(let image):
            if image.source != "user_image" && !Self.isAssetSource(image.source) {
                fail("\(path).source", "must be \"user_image\" or \"asset:<id>\"")
            }
            number("\(path).cornerRadius", image.cornerRadius, in: 0...200)
        case .shape(let shape):
            if shape.fill == nil && shape.stroke == nil { fail(path, "a shape needs a fill or a stroke") }
            color("\(path).fill", shape.fill)
            if let stroke = shape.stroke {
                color("\(path).stroke.color", stroke.color)
                number("\(path).stroke.width", stroke.width, in: 0...40)
                if let dash = stroke.dash, dash.count > 8 || dash.contains(where: { !(0...100).contains($0) }) {
                    fail("\(path).stroke.dash", "up to 8 lengths between 0 and 100")
                }
            }
            number("\(path).cornerRadius", shape.cornerRadius, in: 0...200)
        case .icon(let icon):
            if let raw = Bindings.soleBinding(icon.symbol) {
                binding(path: "\(path).symbol", raw, expecting: [.symbol])
            } else if !Icons.isAllowed(icon.symbol) {
                fail("\(path).symbol", "\"\(icon.symbol)\" is not in the icon whitelist")
            }
            number("\(path).size", icon.size, in: 4...200)
            color("\(path).color", icon.color)
        case .analogClock(let clock):
            for (key, value) in [("faceColor", clock.faceColor), ("tickColor", clock.tickColor), ("hourColor", clock.hourColor),
                                 ("minuteColor", clock.minuteColor), ("accentColor", clock.accentColor)] {
                color("\(path).\(key)", value)
            }
            if let zone = clock.timezone {
                bindingOrLiteral(path: "\(path).timezone", zone, kinds: [.text]) { TimeZone(identifier: $0) != nil }
                if let raw = Bindings.soleBinding(zone), case .field(let key)? = Bindings.Name(raw), spec.field(key)?.type != .timezone {
                    fail("\(path).timezone", "needs a timezone field")
                }
            }
        case .dotGrid(let grid):
            count("\(path).rows", grid.rows, in: 1...40)
            count("\(path).cols", grid.cols, in: 1...40)
            if grid.rows * grid.cols > 600 { fail(path, "at most 600 dots") }
            number("\(path).dotSize", grid.dotSize, in: 0.5...60)
            number("\(path).gap", grid.gap, in: 0...60)
            color("\(path).onColor", grid.onColor)
            color("\(path).offColor", grid.offColor)
            bindingOrLiteral(path: "\(path).values", grid.values, kinds: [.levels]) { SpecLiterals.dotPattern($0) != nil }
        case .dotBars(let bars):
            count("\(path).bars", bars.bars, in: 1...31)
            count("\(path).maxDots", bars.maxDots, in: 1...24)
            bindingOrLiteral(path: "\(path).values", bars.values, kinds: [.levels]) { SpecLiterals.levels($0) != nil }
            color("\(path).color", bars.color)
            color("\(path).offColor", bars.offColor)
            if let labels = bars.labels { text(path: "\(path).labels", labels, expecting: [.text]) }
        case .ring(let ring):
            bindingOrLiteral(path: "\(path).progress", ring.progress, kinds: [.number]) { value in
                Double(value).map { (0...1).contains($0) } ?? false
            }
            color("\(path).color", ring.color)
            color("\(path).trackColor", ring.trackColor)
            number("\(path).lineWidth", ring.lineWidth, in: 0.5...60)
        case .forecastRow(let row):
            count("\(path).days", row.days, in: 1...7)
            color("\(path).color", row.color)
        case .button(let button):
            checkButton(button, path: path)
        }
    }

    mutating func checkText(_ text: TextLayer, path: String) {
        for value in text.value.allValues {
            self.text(path: "\(path).value", value)
        }
        if !FontRegistry.families.contains(text.font.family) {
            fail("\(path).font.family", "unknown font \"\(text.font.family)\"; use \(FontRegistry.families.joined(separator: ", "))")
        }
        number("\(path).font.size", text.font.size, in: SpecValidator.fontSizes)
        if mode == .ai, text.font.size < SpecValidator.minAIFontSize {
            fail("\(path).font.size", "at least \(Int(SpecValidator.minAIFontSize))")
        }
        color("\(path).color", text.color)
        if let lines = text.maxLines { count("\(path).maxLines", lines, in: 1...10) }
        number("\(path).tracking", text.tracking, in: -10...40)
        if let live = text.live {
            switch live.kind {
            case .time:
                break
            case .timer, .relative:
                guard let target = live.target, let raw = Bindings.soleBinding(target) else {
                    fail("\(path).live.target", "needs a date binding like {{field.date}}")
                    return
                }
                binding(path: "\(path).live.target", raw, expecting: [.date])
            }
        }
    }

    mutating func checkButton(_ button: ButtonLayer, path: String) {
        if mode == .ai, button.action != .openApp {
            fail("\(path).action", "only open.app is allowed in AI output")
            return
        }
        switch button.action {
        case .openURL, .shortcutRun:
            let required: FieldSpec.Kind = button.action == .openURL ? .url : .shortcut
            guard let arg = button.arg, let raw = Bindings.soleBinding(arg),
                  case .field(let key)? = Bindings.Name(raw), let field = spec.field(key), field.type == required
            else {
                fail("\(path).arg", "must be {{field.<key>}} of a \(required.rawValue) field")
                return
            }
        case .counterIncrement, .counterReset, .stopwatchToggle, .openApp:
            if let arg = button.arg, !arg.isEmpty { text(path: "\(path).arg", arg) }
        }
    }

    static func isAssetSource(_ source: String) -> Bool {
        guard source.hasPrefix("asset:") else { return false }
        let id = source.dropFirst("asset:".count)
        return !id.isEmpty && isValidID(String(id))
    }
}
