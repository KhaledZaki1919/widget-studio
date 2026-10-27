import SwiftUI

/// Draws a spec to an image with the real renderer, at the family's canvas size, for the AI
/// self-review round and the AI eval job (ADR-019). Uses sample data, like gallery previews,
/// so bindings show realistic values; live texts are frozen.
public enum SpecSnapshot {
    @MainActor
    public static func render(_ spec: WidgetSpec, colors: [String: String] = [:], language: String = "en",
                              date: Date = .now, scale: CGFloat = 3, userImage: CGImage? = nil) -> CGImage? {
        var context = RenderContext(date: date, language: language, data: .sample(now: date), userImage: userImage)
        context.tokenOverrides = colors
        context.freezesLiveText = true
        let canvas = spec.family.canvas
        let view = SpecView(spec: spec, context: context)
            .frame(width: canvas.width, height: canvas.height)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.cgImage
    }
}
