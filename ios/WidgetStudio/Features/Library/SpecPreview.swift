import SwiftUI
import WidgetKitCore

/// A spec rendered like a home screen widget: widget proportions for `family` (the spec's own
/// size by default), rounded corners, ticking every minute, with the app's real data (M4); the
/// M1 test designs pass `sample: true`. Taps pass through, so preview buttons never fire inside
/// the app.
struct SpecPreview: View {
    @Environment(LiveDataModel.self) private var live
    let spec: WidgetSpec
    let language: String
    var family: SpecFamily?
    var theme: SpecTheme?
    var sample = false

    var body: some View {
        let canvas = (family ?? spec.family).canvas
        TimelineView(.everyMinute) { timeline in
            SpecView(spec: spec, context: Self.context(
                date: timeline.date, language: language, theme: theme,
                data: sample ? .sample(now: timeline.date) : live.snapshot(now: timeline.date)
            ))
        }
        .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .allowsHitTesting(false)
        // One accessibility element per preview, read as the template name (and findable in UI tests).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spec.name.resolved(language: language)))
        .accessibilityAddTraits(.isImage)
    }

    static func context(date: Date, language: String, theme: SpecTheme?, data: DataSnapshot) -> RenderContext {
        var context = RenderContext(date: date, language: language, data: data)
        context.theme = theme
        return context
    }
}
