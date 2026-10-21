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

/// A grid of dots; each value 0…1 blends from `offColor` (0) to `onColor` (1).
struct DotGridView: View {
    let layer: DotGridLayer
    let levels: [Double]
    let scale: CGFloat

    var body: some View {
        let on = Color(hex: layer.onColor)
        let off = Color(hex: layer.offColor)
        Canvas { context, size in
            let dot = layer.dotSize * scale
            let gap = layer.gap * scale
            let width = CGFloat(layer.cols) * dot + CGFloat(layer.cols - 1) * gap
            let height = CGFloat(layer.rows) * dot + CGFloat(layer.rows - 1) * gap
            let origin = CGPoint(x: (size.width - width) / 2, y: (size.height - height) / 2)
            for row in 0..<layer.rows {
                for col in 0..<layer.cols {
                    let index = row * layer.cols + col
                    let level = index < levels.count ? min(max(levels[index], 0), 1) : 0
                    let rect = CGRect(x: origin.x + CGFloat(col) * (dot + gap), y: origin.y + CGFloat(row) * (dot + gap), width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect), with: .color(off))
                    if level > 0 {
                        context.fill(Path(ellipseIn: rect), with: .color(on.opacity(level)))
                    }
                }
            }
        }
    }
}

/// A dot-matrix bar chart: each bar is a column of `maxDots` dots, lit from the bottom.
struct DotBarsView: View {
    let layer: DotBarsLayer
    let resolver: BindingResolver
    let scale: CGFloat

    var body: some View {
        let levels = resolver.levels(layer.values)
        let labels = self.labels
        let color = Color(hex: layer.color)
        let off = Color(hex: layer.offColor ?? "#FFFFFF26")
        VStack(spacing: 4 * scale) {
            Canvas { context, size in
                let bars = CGFloat(layer.bars)
                let rows = CGFloat(layer.maxDots)
                let dot = min(size.width / (bars * 1.6), size.height / (rows * 1.4))
                let columnWidth = size.width / bars
                let rowHeight = size.height / rows
                for bar in 0..<layer.bars {
                    let level = bar < levels.count ? min(max(levels[bar], 0), 1) : 0
                    let lit = Int((level * Double(layer.maxDots)).rounded())
                    for row in 0..<layer.maxDots {
                        let x = CGFloat(bar) * columnWidth + (columnWidth - dot) / 2
                        let y = size.height - CGFloat(row + 1) * rowHeight + (rowHeight - dot) / 2
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: .color(row < lit ? color : off))
                    }
                }
            }
            if !labels.isEmpty {
                HStack(spacing: 0) {
                    ForEach(0..<layer.bars, id: \.self) { index in
                        Text(verbatim: index < labels.count ? labels[index] : "")
                            .font(FontRegistry.font(FontSpec(family: "system", size: 8, weight: .medium), size: 8 * scale,
                                                    for: index < labels.count ? labels[index] : ""))
                            .foregroundStyle(color.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var labels: [String] {
        guard let labels = layer.labels else { return [] }
        return resolver.render(labels).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

/// n days of weather: day name, symbol, high and low.
struct ForecastRowView: View {
    let layer: ForecastRowLayer
    let resolver: BindingResolver
    let scale: CGFloat

    var body: some View {
        let days = Array((resolver.context.data.weather?.forecast ?? []).prefix(layer.days))
        let color = Color(hex: layer.color)
        HStack(spacing: 0) {
            if days.isEmpty {
                Text(verbatim: BindingResolver.missing)
                    .frame(maxWidth: .infinity)
            }
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 3 * scale) {
                    Text(verbatim: dayName(day.date))
                        .font(.system(size: 9 * scale, weight: .medium))
                        .opacity(0.7)
                    Image(systemName: Icons.isAllowed(day.symbol) ? day.symbol : "questionmark")
                        .font(.system(size: 15 * scale))
                    Text(verbatim: "\(Int(day.high.rounded()))°")
                        .font(FontRegistry.font(FontSpec(family: "dot", size: 13, weight: .bold), size: 13 * scale, for: ""))
                    Text(verbatim: "\(Int(day.low.rounded()))°")
                        .font(.system(size: 9 * scale))
                        .opacity(0.6)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Days run in reading order: right to left in Arabic.
        .environment(\.layoutDirection, resolver.context.isArabic ? .rightToLeft : .leftToRight)
    }

    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: resolver.context.isArabic ? "ar_EG@numbers=latn" : "en_US")
        formatter.timeZone = resolver.context.timeZone
        formatter.dateFormat = resolver.context.isArabic ? "EEEE" : "EEE"
        return formatter.string(from: date)
    }
}
