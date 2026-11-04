import Foundation

/// "Use another AI" (ADR-023): the user copies self-contained instructions into ChatGPT, Claude or
/// Gemini on the web together with their image, and imports the JSON that comes back. The reply
/// goes through exactly the checks of the app's own AI flow: fences and extra text are stripped,
/// it is validated in AI mode (recreate only: the external AI never sends a photo), and the
/// layout is repaired locally (`AILayoutFix`). It is only ever a widget spec, never code.
public enum ExternalAI {
    /// Larger replies are rejected before parsing (a widget spec is a few KB).
    public static let maxImportBytes = 200_000

    public enum ImportError: Error, Equatable, Sendable {
        case empty
        case tooLarge
        /// No `{ … }` object in the text.
        case noJSON
        /// The JSON failed the checks; the text says what (English, for the fix request).
        case invalid(String)
        /// A picked or shared file couldn't be read.
        case unreadable
    }

    /// Everything the external AI needs, in one paste: our rules (the app's system prompt), the
    /// task for `options`, the JSON Schema of the answer, a short example and the reply rules.
    public static func instructions(options: GenerationOptions, today: Date = .now) -> String {
        var recreate = options
        recreate.mode = .recreate
        var task = WidgetPrompt.userText(options: recreate, imageWidth: 0, imageHeight: 0, today: today)
        if recreate.size.family == nil, let line = task.components(separatedBy: "\n\n").first(where: { $0.hasPrefix("Size: the image is") }) {
            task = task.replacingOccurrences(of: line, with: "Size: pick \"family\" from the image's shape: \"small\" when it is about "
                + "square, \"medium\" when it is wide, \"large\" when it is tall.")
        }
        return [
            "You are designing an iOS home-screen widget for the app Widget Studio. The user attached an image of the widget "
                + "they want. Follow every rule below and answer with one JSON object that the app imports.",
            WidgetPrompt.system,
            "# Task\n\n" + task,
            "# Answer format\n\nReply with only the JSON object: no explanation before or after it, no code fences, no code of any "
                + "kind. It must match this JSON Schema:\n\n" + AIWidgetSchema.schema(mode: .recreate).jsonString(),
            "# Example of the shape (not of the design)\n\n" + example,
        ].joined(separator: "\n\n")
    }

    /// A small valid answer (texts inside a stack, palette tokens), so the external AI sees the exact shape.
    static let example = """
    {"inventory":["big time","weekday under it"],"wiring":[{"element":"big time","shows":"{{time.hh}}:{{time.mm}}","tap":null,"decorative":null},\
    {"element":"weekday","shows":"{{date.EEEE}}","tap":null,"decorative":null}],"name":{"en":"Clock","ar":"الساعة"},"family":"small","theme":"dark",\
    "palette":{"bg":"#101418","fg":"#F5F5F5","accent":"#FF5A36"},\
    "background":{"type":"solid","color":"@bg","colors":null,"angle":null,"outerColor":null},"fields":[],\
    "layers":[{"type":"stack","axis":"vertical","spacing":4,"padding":null,"alignItems":"center","justify":"center","columns":null,\
    "frame":{"x":12,"y":40,"w":146,"h":90},"opacity":null,"mirror":null,"children":[\
    {"type":"text","value":{"en":"{{time.hh}}:{{time.mm}}","ar":"{{time.hh}}:{{time.mm}}"},"font":{"family":"dot","size":44,"weight":"black"},\
    "color":"@fg","align":"center","maxLines":1,"live":null},\
    {"type":"text","value":{"en":"{{date.EEEE}}","ar":"{{date.EEEE}}"},"font":{"family":"system","size":13,"weight":"semibold"},\
    "color":"@accent","align":"center","maxLines":1,"live":null}]}]}
    """

    /// The pasted or opened reply → a validated widget, with the layout repaired like the app's
    /// own AI results. Throws `ImportError`.
    public static func importWidget(_ text: String, size: SizeChoice = .auto) throws -> GeneratedWidget {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImportError.empty }
        guard trimmed.utf8.count <= maxImportBytes else { throw ImportError.tooLarge }
        guard StructuredAI.extractJSON(trimmed) != nil else { throw ImportError.noJSON }
        let id = "ai." + UUID().uuidString.prefix(8).lowercased()
        do {
            let parsed = try AIWidgetParser.parseWidget(trimmed, options: GenerationOptions(mode: .recreate, size: size), id: id,
                                                        enforceLayout: false)
            return GeneratedWidget(spec: parsed.spec, colors: parsed.colors, model: "external", attempts: 1, layout: parsed.layout,
                                   autoWired: parsed.autoWired)
        } catch let error as AIValidationError {
            if error.description.contains("no JSON object found") { throw ImportError.noJSON }
            throw ImportError.invalid(error.description)
        }
    }

    /// What the user sends back to the external AI when the import fails.
    public static func fixRequest(for error: ImportError) -> String {
        switch error {
        case .empty, .noJSON:
            return "Reply again with only the widget JSON object, exactly as the schema in my first message describes: "
                + "no explanation, no code fences."
        case .unreadable:
            return "The file could not be read. Reply again with the whole JSON object as text."
        case .tooLarge:
            return "That reply is too long. Simplify the design (fewer layers) and reply with only the JSON object."
        case .invalid(let problems):
            return "Widget Studio could not import your JSON. These problems were found:\n\n\(problems)\n\n"
                + "Fix only these problems, keep everything else, and reply with the whole corrected JSON object only."
        }
    }
}
