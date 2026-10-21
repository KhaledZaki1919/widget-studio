import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// What the spec widget draws for one timeline entry. It lives in the package (not the
/// extension) so the app's tests render exactly the widget's view for every spec (ADR-010).
public struct SpecWidgetContent: View {
    let spec: WidgetSpec?
    let context: RenderContext

    public init(spec: WidgetSpec?, context: RenderContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        if let spec {
            SpecView(spec: spec, context: context, drawsBackground: false)
                .widgetBackground { SpecBackground(spec: spec) }
        } else {
            Text(verbatim: "—")
                .font(.footnote)
                .foregroundStyle(.white)
                .widgetBackground { Color(white: 0.055) }
        }
    }
}

extension View {
    /// `containerBackground(for: .widget)` where WidgetKit exists; a plain background elsewhere.
    @ViewBuilder func widgetBackground<Background: View>(@ViewBuilder _ background: () -> Background) -> some View {
        #if canImport(WidgetKit)
        containerBackground(for: .widget, content: background)
        #else
        self.background(background())
        #endif
    }
}
