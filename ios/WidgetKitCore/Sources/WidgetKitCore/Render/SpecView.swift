import SwiftUI

/// Draws a validated spec (brief §3.2). The same view renders the in-app preview and the real
/// widget, so the preview is exact. Positions are canvas units scaled uniformly to the space
/// offered. The canvas is laid out left-to-right; in RTL, layers with `mirror: true` move to
/// the other side and lay out their own content right-to-left. Numbers and clocks never mirror.
public struct SpecView: View {
    let spec: WidgetSpec
    let context: RenderContext
    /// False inside a widget, which draws `SpecBackground` through `containerBackground`.
    let drawsBackground: Bool

    public init(spec: WidgetSpec, context: RenderContext, drawsBackground: Bool = true) {
        self.spec = spec
        self.context = context
        self.drawsBackground = drawsBackground
    }

    public var body: some View {
        GeometryReader { proxy in
            let canvas = spec.family.canvas
            let scale = min(proxy.size.width / canvas.width, proxy.size.height / canvas.height)
            let resolver = BindingResolver(spec: spec, context: context)
            ZStack(alignment: .topLeading) {
                if drawsBackground {
                    SpecBackground(spec: spec)
                        .frame(width: canvas.width * scale, height: canvas.height * scale)
                }
                ForEach(Array(spec.layers.enumerated()), id: \.offset) { _, layer in
                    let mirrored = context.isArabic && layer.mirror == true
                    let frame = mirrored ? layer.frame.mirrored(canvasWidth: canvas.width) : layer.frame
                    LayerView(layer: layer, resolver: resolver, scale: scale)
                        .environment(\.layoutDirection, mirrored ? .rightToLeft : .leftToRight)
                        .frame(width: frame.w * scale, height: frame.h * scale)
                        .opacity(layer.opacity ?? 1)
                        .position(x: (frame.x + frame.w / 2) * scale, y: (frame.y + frame.h / 2) * scale)
                }
            }
            .frame(width: canvas.width * scale, height: canvas.height * scale)
            .environment(\.layoutDirection, .leftToRight)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .environment(\.colorScheme, spec.theme == .dark ? .dark : .light)
    }
}

/// The spec's background. With `outerColor` (circle templates), the widget is filled with the
/// outer color and the background is drawn as the largest centered circle (brief §2).
public struct SpecBackground: View {
    let spec: WidgetSpec

    public init(spec: WidgetSpec) {
        self.spec = spec
    }

    public var body: some View {
        if let outer = spec.background.outerColor {
            ZStack {
                Color(hex: outer)
                fill.clipShape(Circle()).aspectRatio(1, contentMode: .fit)
            }
        } else {
            fill
        }
    }

    @ViewBuilder private var fill: some View {
        switch spec.background.type {
        case .solid:
            Color(hex: spec.background.color ?? "#000000")
        case .gradient:
            let angle = Angle(degrees: spec.background.angle ?? 90)
            let dx = cos(angle.radians) / 2
            let dy = sin(angle.radians) / 2
            LinearGradient(
                colors: (spec.background.colors ?? []).map { Color(hex: $0) },
                startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
                endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
            )
        }
    }
}

extension Color {
    /// A spec color; invalid strings (already rejected by the validator) draw as clear.
    public init(hex: String) {
        if let color = HexColor.parse(hex) {
            self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
        } else {
            self = .clear
        }
    }
}

/// One layer, filling the frame it is given.
struct LayerView: View {
    let layer: Layer
    let resolver: BindingResolver
    let scale: CGFloat

    var body: some View {
        switch layer.content {
        case .text(let text): TextLayerView(layer: text, resolver: resolver, scale: scale)
        case .image(let image): ImageLayerView(layer: image, image: resolver.context.userImage, scale: scale)
        case .shape(let shape): ShapeLayerView(layer: shape, scale: scale)
        case .icon(let icon): IconLayerView(layer: icon, resolver: resolver, scale: scale)
        case .analogClock(let clock): AnalogClockView(layer: clock, resolver: resolver)
        case .dotGrid(let grid): DotGridView(layer: grid, levels: resolver.levels(grid.values), scale: scale)
        case .dotBars(let bars): DotBarsView(layer: bars, resolver: resolver, scale: scale)
        case .ring(let ring): RingView(layer: ring, progress: resolver.number(ring.progress) ?? 0, scale: scale)
        case .forecastRow(let row): ForecastRowView(layer: row, resolver: resolver, scale: scale)
        case .button(let button): ButtonLayerView(layer: button, resolver: resolver)
        case .unknown: Color.clear
        }
    }
}
