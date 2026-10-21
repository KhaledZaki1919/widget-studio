import SwiftUI

struct TextLayerView: View {
    let layer: TextLayer
    let resolver: BindingResolver
    let scale: CGFloat

    var body: some View {
        let raw = layer.value.resolved(language: resolver.context.language)
        let value = resolver.render(raw)
        content(value)
            .font(FontRegistry.font(layer.font, size: layer.font.size * scale, for: value))
            .tracking((layer.tracking ?? 0) * scale)
            .foregroundStyle(Color(hex: layer.color))
            .multilineTextAlignment(textAlignment)
            .lineLimit(layer.maxLines ?? 1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder private func content(_ value: String) -> some View {
        let now = resolver.context.date
        switch layer.live?.kind {
        case .time?:
            Text(now, style: .time)
        case .relative?:
            if let target = layer.live?.target.flatMap(resolver.date) {
                Text(target, style: .relative)
            } else {
                Text(verbatim: BindingResolver.missing)
            }
        case .timer?:
            if let target = layer.live?.target.flatMap(resolver.date) {
                // Counts down to a future target, up from a past one.
                Text(timerInterval: min(now, target)...max(now, target), countsDown: target > now)
            } else {
                Text(verbatim: BindingResolver.missing)
            }
        case nil:
            Text(verbatim: value)
        }
    }

    private var textAlignment: TextAlignment {
        switch layer.align ?? .leading {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch layer.align ?? .leading {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

struct ImageLayerView: View {
    let layer: ImageLayer
    let image: CGImage?
    let scale: CGFloat

    var body: some View {
        picture
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(mask)
    }

    @ViewBuilder private var picture: some View {
        if layer.source == "user_image", let image {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: layer.fit == .fit ? .fit : .fill)
        } else {
            // No photo yet (or an asset that arrives with the template library): a neutral placeholder.
            ZStack {
                Color.gray.opacity(0.25)
                Image(systemName: "photo")
                    .font(.system(size: 18 * scale))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mask: AnyShape {
        switch layer.mask ?? .rect {
        case .rect: AnyShape(Rectangle())
        case .roundedRect: AnyShape(RoundedRectangle(cornerRadius: (layer.cornerRadius ?? 16) * scale, style: .continuous))
        case .circle: AnyShape(Circle())
        }
    }
}

struct ShapeLayerView: View {
    let layer: ShapeLayer
    let scale: CGFloat

    var body: some View {
        ZStack {
            if let fill = layer.fill {
                shape.fill(Color(hex: fill))
            }
            if let stroke = layer.stroke {
                shape.stroke(Color(hex: stroke.color), style: StrokeStyle(
                    lineWidth: stroke.width * scale,
                    dash: (stroke.dash ?? []).map { $0 * scale }
                ))
            }
        }
    }

    private var shape: AnyShape {
        switch layer.kind {
        case .rect: AnyShape(Rectangle())
        case .roundedRect: AnyShape(RoundedRectangle(cornerRadius: (layer.cornerRadius ?? 16) * scale, style: .continuous))
        case .circle: AnyShape(Circle())
        case .capsule: AnyShape(Capsule())
        }
    }
}

struct IconLayerView: View {
    let layer: IconLayer
    let resolver: BindingResolver
    let scale: CGFloat

    var body: some View {
        let symbol = resolver.soleValue(layer.symbol)?.display ?? layer.symbol
        Image(systemName: Icons.isAllowed(symbol) ? symbol : "questionmark")
            .font(.system(size: layer.size * scale))
            .foregroundStyle(Color(hex: layer.color))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RingView: View {
    let layer: RingLayer
    let progress: Double
    let scale: CGFloat

    var body: some View {
        let width = layer.lineWidth * scale
        ZStack {
            Circle()
                .stroke(Color(hex: layer.trackColor ?? "#FFFFFF33"), lineWidth: width)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color(hex: layer.color), style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(width / 2)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Invisible tap area (brief §4.4). Taps open the app with the action; the app performs it
/// (interactive AppIntents for counter / stopwatch arrive in M4).
struct ButtonLayerView: View {
    let layer: ButtonLayer
    let resolver: BindingResolver

    var body: some View {
        if let url = actionURL {
            Link(destination: url) {
                Color.clear.contentShape(Rectangle())
            }
        } else {
            Color.clear
        }
    }

    /// `widgetstudio://action/<action>?arg=<value>&spec=<id>`
    var actionURL: URL? {
        var components = URLComponents()
        components.scheme = "widgetstudio"
        components.host = "action"
        components.path = "/" + layer.action.rawValue
        var items = [URLQueryItem(name: "spec", value: resolver.spec.id)]
        if let arg = layer.arg { items.append(URLQueryItem(name: "arg", value: resolver.render(arg))) }
        components.queryItems = items
        return components.url
    }
}
