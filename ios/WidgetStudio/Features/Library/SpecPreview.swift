import SwiftUI
import WidgetKitCore

/// A spec rendered like a home screen widget: widget proportions for `family` (the spec's own
/// size by default), rounded corners, ticking every minute. Taps pass through, so preview
/// buttons never fire inside the app.
struct SpecPreview: View {
    let spec: WidgetSpec
    let language: String
    var family: SpecFamily?
    var theme: SpecTheme?

    var body: some View {
        let canvas = (family ?? spec.family).canvas
        TimelineView(.everyMinute) { timeline in
            SpecView(spec: spec, context: Self.context(date: timeline.date, language: language, theme: theme))
        }
        .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .allowsHitTesting(false)
    }

    static func context(date: Date, language: String, theme: SpecTheme?) -> RenderContext {
        var context = RenderContext(date: date, language: language, data: .sample(now: date))
        context.theme = theme
        return context
    }
}
