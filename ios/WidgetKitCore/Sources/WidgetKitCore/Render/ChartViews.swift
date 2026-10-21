import SwiftUI

/// Hour and minute hands only: widgets update once a minute, so there is no seconds hand (brief §2).
struct AnalogClockView: View {
    let layer: AnalogClockLayer
    let resolver: BindingResolver

    var body: some View {
        let dark = resolver.spec.theme == .dark
        let face = Color(hex: layer.faceColor ?? (dark ? "#1A1A1A" : "#FFFFFF"))
        let ink = Color(hex: layer.tickColor ?? (dark ? "#FFFFFF" : "#0E0E0E"))
        let hour = Color(hex: layer.hourColor ?? (dark ? "#FFFFFF" : "#0E0E0E"))
        let minute = Color(hex: layer.minuteColor ?? (dark ? "#FFFFFF" : "#0E0E0E"))
        let accent = Color(hex: layer.accentColor ?? "#E31C24")
        let clock = time
        Canvas { context, size in
            let hours = clock.hours
            let minutes = clock.minutes
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side / 2
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: side, height: side)), with: .color(face))

            for tick in 0..<60 {
                let isHour = tick % 5 == 0
                if layer.style == .dot && !isHour { continue }
                let angle = Double(tick) / 60 * 2 * .pi
                let direction = CGPoint(x: sin(angle), y: -cos(angle))
                if layer.style == .dot {
                    let dot = radius * 0.07
                    let point = CGPoint(x: center.x + direction.x * radius * 0.82, y: center.y + direction.y * radius * 0.82)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot)), with: .color(ink))
                } else {
                    let outer = radius * 0.92
                    let inner = radius * (isHour ? 0.76 : 0.86)
                    var path = Path()
                    path.move(to: CGPoint(x: center.x + direction.x * inner, y: center.y + direction.y * inner))
                    path.addLine(to: CGPoint(x: center.x + direction.x * outer, y: center.y + direction.y * outer))
                    context.stroke(path, with: .color(ink), lineWidth: radius * (isHour ? 0.035 : 0.015))
                }
            }

            Self.hand(in: &context, center: center, radius: radius,
                      fraction: (Double(hours % 12) + Double(minutes) / 60) / 12, length: 0.5, width: 0.07, color: hour)
            Self.hand(in: &context, center: center, radius: radius,
                      fraction: Double(minutes) / 60, length: 0.75, width: 0.045, color: minute)
            let pin = radius * 0.09
            context.fill(Path(ellipseIn: CGRect(x: center.x - pin / 2, y: center.y - pin / 2, width: pin, height: pin)), with: .color(accent))
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // swiftlint:disable:next function_parameter_count
    private static func hand(in context: inout GraphicsContext, center: CGPoint, radius: Double,
                             fraction: Double, length: Double, width: Double, color: Color) {
        let angle = fraction * 2 * .pi
        var path = Path()
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x + sin(angle) * radius * length, y: center.y - cos(angle) * radius * length))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: radius * width, lineCap: .round))
    }

    /// Hours and minutes in the clock's time zone (a timezone field, an IANA name or the device's).
    private var time: (hours: Int, minutes: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = layer.timezone.flatMap(zone) ?? resolver.context.timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: resolver.context.date)
        return (parts.hour ?? 0, parts.minute ?? 0)
    }

    private func zone(_ value: String) -> TimeZone? {
        if let raw = Bindings.soleBinding(value), case .field(let key)? = Bindings.Name(raw) {
            return resolver.fieldValue(key).flatMap(TimeZone.init(identifier:))
        }
        return TimeZone(identifier: value)
    }
}

