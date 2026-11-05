import SwiftUI

/// A `stack` layer (M6.1): its children laid out by SwiftUI stacks or a grid inside the frame.
/// Mirrored (RTL `mirror`), horizontal items and grid rows run the other way and `start`/`end`
/// swap sides; the canvas stays left-to-right and nothing is flipped (ADR-010).
struct StackLayerView: View {
    let layer: StackLayer
    let resolver: BindingResolver
    let scale: CGFloat
    let mirrored: Bool

    var body: some View {
        // The content always fits the frame: if it doesn't at full size, the whole stack is drawn
        // smaller, step by step, instead of running past the frame and off the widget (eval
        // 2026-11-02: corner texts in one row lost "hello" and "Nov" at the edges). The last step
        // is used when nothing fits; its texts still shrink further on their own.
        ViewThatFits(in: fitAxes) {
            content(scale: scale)
            content(scale: scale * 0.85)
            content(scale: scale * 0.7)
            content(scale: scale * 0.55)
            content(scale: scale * 0.4)
        }
        .padding((layer.padding ?? 0) * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    /// The axis the items run along; texts wrap across it.
    private var fitAxes: Axis.Set {
        switch layer.axis {
        case .vertical: .vertical
        case .horizontal: .horizontal
        case .grid: [.horizontal, .vertical]
        }
    }

    private var visible: [Layer] {
        layer.children.filter { $0.when.map(resolver.isSatisfied) ?? true }
    }

    @ViewBuilder private func content(scale: CGFloat) -> some View {
        let spacing = (layer.spacing ?? StackLayer.defaultSpacing) * scale
        switch layer.axis {
        case .vertical:
            VStack(alignment: horizontal(layer.alignItems ?? .start), spacing: spacing) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, child in
                    StackChildView(layer: child, axis: .vertical, textAlign: textAlign, resolver: resolver, scale: scale, mirrored: mirrored)
                }
            }
        case .horizontal:
            HStack(alignment: vertical(layer.alignItems ?? .center), spacing: spacing) {
                ForEach(Array(ordered(visible).enumerated()), id: \.offset) { _, child in
                    StackChildView(layer: child, axis: .horizontal, textAlign: textAlign, resolver: resolver, scale: scale, mirrored: mirrored)
                }
            }
        case .grid:
            let rows = StackLayer(axis: .grid, columns: layer.columns, children: visible).rows
            Grid(alignment: Alignment(horizontal: horizontal(layer.alignItems ?? .start), vertical: .center),
                 horizontalSpacing: spacing, verticalSpacing: spacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(ordered(row).enumerated()), id: \.offset) { _, child in
                            StackChildView(layer: child, axis: .grid, textAlign: textAlign, resolver: resolver, scale: scale, mirrored: mirrored)
                        }
                    }
                }
            }
        }
    }

    private func ordered(_ children: [Layer]) -> [Layer] {
        mirrored ? children.reversed() : children
    }

    /// Texts without their own `align` follow the stack's cross alignment.
    private var textAlign: TextAlign {
        guard layer.axis != .horizontal else { return .leading }
        switch layer.alignItems ?? .start {
        case .start: return .leading
        case .center: return .center
        case .end: return .trailing
        }
    }

    private var frameAlignment: Alignment {
        let justify = layer.justify ?? .start
        switch layer.axis {
        case .vertical: return Alignment(horizontal: horizontal(layer.alignItems ?? .start), vertical: vertical(justify))
        case .horizontal: return Alignment(horizontal: horizontal(justify), vertical: vertical(layer.alignItems ?? .center))
        case .grid: return Alignment(horizontal: horizontal(justify), vertical: .top)
        }
    }

    private func horizontal(_ align: StackLayer.Align) -> HorizontalAlignment {
        switch align {
        case .start: mirrored ? .trailing : .leading
        case .center: .center
        case .end: mirrored ? .leading : .trailing
        }
    }

    private func vertical(_ align: StackLayer.Align) -> VerticalAlignment {
        switch align {
        case .start: .top
        case .center: .center
        case .end: .bottom
        }
    }
}

/// One child: its own size where given, else its natural size (texts wrap to the stack's width
/// in vertical stacks and grids; icons are as big as their symbol).
private struct StackChildView: View {
    let layer: Layer
    let axis: StackLayer.Axis
    let textAlign: TextAlign
    let resolver: BindingResolver
    let scale: CGFloat
    let mirrored: Bool

    var body: some View {
        sized
            .modifier(LayerRotation(degrees: layer.rotation.flatMap(resolver.number)))
            .opacity(layer.opacity ?? 1)
    }

    static func aligned(_ text: TextLayer, _ align: TextAlign) -> TextLayer {
        var text = text
        text.align = text.align ?? align
        return text
    }

    @ViewBuilder private var sized: some View {
        let width: CGFloat? = layer.frame.w > 0 ? CGFloat(layer.frame.w) * scale : nil
        let height: CGFloat? = layer.frame.h > 0 ? CGFloat(layer.frame.h) * scale : nil
        switch layer.content {
        case .spacer(let spacer):
            Spacer(minLength: (spacer.minLength ?? 0) * scale)
        case .text(let text):
            TextLayerView(layer: Self.aligned(text, textAlign), resolver: resolver, scale: scale, mirrored: mirrored,
                          fill: axis == .horizontal || width != nil ? [] : [.horizontal])
                .frame(width: width, height: height)
        case .icon(let icon):
            LayerView(layer: layer, resolver: resolver, scale: scale, mirrored: mirrored)
                .frame(width: width ?? icon.size * scale, height: height ?? icon.size * scale)
        default:
            LayerView(layer: layer, resolver: resolver, scale: scale, mirrored: mirrored)
                .frame(width: width, height: height)
                .frame(maxWidth: axis == .horizontal || width != nil ? nil : .infinity)
        }
    }
}

/// A state layer (ADR-028): the variant real data picks, fitted into the frame. The same layer
/// views draw it, so a variant renders and goes Tinted exactly like any other layer.
struct StatesLayerView: View {
    let layer: StatesLayer
    let frame: Frame
    let resolver: BindingResolver

    var body: some View {
        GeometryReader { proxy in
            if let variant = resolver.variant(of: layer) {
                let box = layer.boxSize(frame: frame)
                let scale = min(proxy.size.width / box.w, proxy.size.height / box.h)
                let left = (proxy.size.width - box.w * scale) / 2
                let top = (proxy.size.height - box.h * scale) / 2
                ZStack(alignment: .topLeading) {
                    ForEach(Array(variant.layers.enumerated()), id: \.offset) { _, child in
                        if child.when.map(resolver.isSatisfied) ?? true {
                            LayerView(layer: child, resolver: resolver, scale: scale, mirrored: false)
                                .frame(width: child.frame.w * scale, height: child.frame.h * scale)
                                .modifier(LayerRotation(degrees: child.rotation.flatMap(resolver.number)))
                                .opacity(child.opacity ?? 1)
                                .position(x: left + (child.frame.x + child.frame.w / 2) * scale, y: top + (child.frame.y + child.frame.h / 2) * scale)
                        }
                    }
                }
            }
        }
    }
}
