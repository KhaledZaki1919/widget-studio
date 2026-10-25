import SwiftUI
import WidgetKitCore

/// A saved (or edited) design rendered like its widget: the design's field values, theme,
/// colors and photo, at widget proportions, ticking every minute. Taps pass through.
struct DesignPreview: View {
    let design: SavedDesign
    let image: CGImage?
    let language: String

    var body: some View {
        let canvas = design.spec.family.canvas
        TimelineView(.everyMinute) { timeline in
            SpecView(spec: design.spec, context: design.renderContext(
                date: timeline.date, language: language, data: .sample(now: timeline.date), image: image
            ))
        }
        .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: design.name))
        .accessibilityAddTraits(.isImage)
    }
}
