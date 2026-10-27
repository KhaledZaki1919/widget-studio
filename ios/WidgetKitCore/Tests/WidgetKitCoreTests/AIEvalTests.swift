import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import WidgetKitCore

/// The AI eval (ADR-019), run only by the `ai-eval` workflow (`AI_EVAL=1`) with the repository
/// secret `GEMINI_API_KEY`: for every case in `docs/ai-eval/cases.json`, generate a spec with the
/// app's real prompt, schema and parser, render it with the real renderer, and write a
/// side-by-side PNG (original | render), the spec and a summary. Never prints the key; a failed
/// case is written to the summary, not thrown, so one bad case doesn't hide the others.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["AI_EVAL"] == "1"))
struct AIEvalTests {
    struct Case: Decodable {
        let file: String
        let mode: String
        let size: String
        let note: String?
    }

    let environment = ProcessInfo.processInfo.environment

    @Test @MainActor func generateAndRenderEveryCase() async throws {
        let key = try #require(environment["GEMINI_API_KEY"].flatMap { $0.isEmpty ? nil : $0 }, "GEMINI_API_KEY is not set")
        let input = URL(fileURLWithPath: try #require(environment["AI_EVAL_DIR"]))
        let output = URL(fileURLWithPath: environment["AI_EVAL_OUT"] ?? NSTemporaryDirectory() + "ai-eval")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        if let fonts = environment["AI_EVAL_FONTS"] { registerFonts(in: URL(fileURLWithPath: fonts)) }

        let model = environment["AI_EVAL_MODEL"].flatMap { $0.isEmpty ? nil : $0 } ?? AIProviderKind.gemini.recommendedModel
        let review = environment["AI_EVAL_REVIEW"] == "1"
        let only = environment["AI_EVAL_CASES"].map { Set($0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }) }
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: input.appendingPathComponent("cases.json")))

        let keys = AIKeyStore(storage: MemoryKeyStorage())
        try keys.save(key, for: .gemini)
        let defaults = testDefaults()
        AISettings(provider: .gemini, models: ["gemini": model]).save(to: defaults)
        let service = AIService(keyStore: keys, defaults: defaults)
        service.structuredFirst = environment["AI_EVAL_STRUCTURED"] != "0"
        let generator = WidgetGenerator(service: service)

        var summary = ["# AI eval", "", "Model: `\(model)` · prompt `\(WidgetPrompt.version)` · review: \(review ? "on" : "off") · structured: \(service.structuredFirst)", ""]
        for item in cases where only.map({ $0.contains(item.file) || $0.isEmpty }) ?? true {
            let name = (item.file as NSString).deletingPathExtension
            summary.append("## \(name)")
            if let note = item.note { summary.append("_\(note)_") }
            guard let data = try? Data(contentsOf: input.appendingPathComponent(item.file)),
                  let original = AIImage.upright(data: data, maxSide: 1024), let prepared = AIImage.prepare(data: data) else {
                summary += ["- could not read the image", ""]
                continue
            }
            let options = GenerationOptions(mode: GenerationMode(rawValue: item.mode) ?? .recreate, size: SizeChoice(rawValue: item.size) ?? .auto)
            let photo = options.mode == .photo ? original : nil
            var renderer: SpecRenderer?
            if review {
                renderer = { spec, colors in
                    await MainActor.run { () -> PreparedImage? in
                        guard let image = SpecSnapshot.render(spec, colors: colors, userImage: photo) else { return nil }
                        return AIImage.prepare(image: image)
                    }
                }
            }
            let started = Date()
            do {
                let result = try await generator.generate(image: prepared, options: options, review: renderer)
                let seconds = Int(Date().timeIntervalSince(started))
                let spec = result.spec
                let rendered = SpecSnapshot.render(spec, colors: result.colors, userImage: photo)
                if let rendered, let combined = sideBySide(original, rendered) {
                    try png(combined).write(to: output.appendingPathComponent("\(name).png"))
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                try encoder.encode(spec).write(to: output.appendingPathComponent("\(name).json"))
                summary.append("- \(result.spec.family.rawValue), \(result.spec.layers.count) layers, "
                    + "\(result.attempts) answer(s), \(seconds) s, reviewed: \(result.reviewed)")
                summary.append("- layers: " + result.spec.layers.map(\.content.typeName).joined(separator: ", "))
                for difference in result.differences { summary.append("  - fixed: \(difference)") }
            } catch {
                summary.append("- FAILED: \(error)")
                if let diagnostic = AIDiagnosticsStore.load(from: defaults) {
                    summary += ["```", diagnostic.report(), "```"]
                }
            }
            summary.append("")
            // Free Gemini keys allow few requests per minute.
            try await Task.sleep(nanoseconds: UInt64((Double(environment["AI_EVAL_PAUSE"] ?? "") ?? 8) * 1_000_000_000))
        }
        try summary.joined(separator: "\n").write(to: output.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
    }

    /// Bundled fonts by file, so renders match the app (the eval process has no UIAppFonts).
    func registerFonts(in folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where ["ttf", "otf"].contains(file.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
    }

    /// Original (left) and render (right) at the same height on a light gray sheet.
    func sideBySide(_ left: CGImage, _ right: CGImage, height: CGFloat = 510, padding: CGFloat = 30) -> CGImage? {
        func width(_ image: CGImage) -> CGFloat { CGFloat(image.width) * height / CGFloat(max(image.height, 1)) }
        let size = CGSize(width: width(left) + width(right) + padding * 3, height: height + padding * 2)
        return ImageProcessing.draw(size: size) { context in
            context.setFillColor(CGColor(red: 0.9, green: 0.91, blue: 0.93, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
            context.interpolationQuality = .high
            context.draw(left, in: CGRect(x: padding, y: padding, width: width(left), height: height))
            context.draw(right, in: CGRect(x: padding * 2 + width(left), y: padding, width: width(right), height: height))
        }
    }

    func png(_ image: CGImage) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw AIValidationError("no PNG encoder")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw AIValidationError("PNG encoding failed") }
        return output as Data
    }
}
