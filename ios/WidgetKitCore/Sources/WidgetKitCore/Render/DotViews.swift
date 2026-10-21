import SwiftUI

/// A grid of dots, filled row by row; each value 0…1 blends from `offColor` (0) to `onColor` (1),
/// and a negative value leaves the cell empty (month padding, `MonthGrid`). Mirrored, each row
/// runs right to left, like an Arabic calendar.
struct DotGridView: View {
    let layer: DotGridLayer
    let levels: [Double]
    let scale: CGFloat
    let mirrored: Bool

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
                    let level = index < levels.count ? min(levels[index], 1) : 0
                    if level < 0 { continue }
                    let column = mirrored ? layer.cols - 1 - col : col
                    let rect = CGRect(x: origin.x + CGFloat(column) * (dot + gap), y: origin.y + CGFloat(row) * (dot + gap),
                                      width: dot, height: dot)
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
/// Mirrored, the bars (and their labels) run right to left.
struct DotBarsView: View {
    let layer: DotBarsLayer
    let resolver: BindingResolver
    let scale: CGFloat
    let mirrored: Bool

    var body: some View {
        let levels = ordered(resolver.levels(layer.values), count: layer.bars, filler: 0)
        let labels = ordered(self.labels, count: layer.bars, filler: "")
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
                    let lit = Int((min(max(levels[bar], 0), 1) * Double(layer.maxDots)).rounded())
                    for row in 0..<layer.maxDots {
                        let x = CGFloat(bar) * columnWidth + (columnWidth - dot) / 2
                        let y = size.height - CGFloat(row + 1) * rowHeight + (rowHeight - dot) / 2
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: .color(row < lit ? color : off))
                    }
                }
            }
            if labels.contains(where: { !$0.isEmpty }) {
                HStack(spacing: 0) {
                    ForEach(0..<layer.bars, id: \.self) { index in
                        Text(verbatim: labels[index])
                            .font(FontRegistry.font(FontSpec(family: "system", size: 8, weight: .medium), size: 8 * scale, for: labels[index]))
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
        guard let labels = layer.labels?.resolved(language: resolver.context.language) else { return [] }
        return resolver.render(labels).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Exactly `count` items, in reading order.
    private func ordered<T>(_ items: [T], count: Int, filler: T) -> [T] {
        let padded = Array(items.prefix(count)) + Array(repeating: filler, count: max(0, count - items.count))
        return mirrored ? padded.reversed() : padded
    }
}

/// n days of weather: day name, symbol, high and low. Mirrored, today is on the right.
struct ForecastRowView: View {
    let layer: ForecastRowLayer
    let resolver: BindingResolver
    let scale: CGFloat
    let mirrored: Bool

    var body: some View {
        let next = Array((resolver.context.data.weather?.forecast ?? []).prefix(layer.days))
        let days = mirrored ? next.reversed() : next
        let color = Color(hex: layer.color)
        HStack(spacing: 0) {
            if days.isEmpty {
                Text(verbatim: BindingResolver.missing)
                    .frame(maxWidth: .infinity)
            }
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 3 * scale) {
                    let name = dayName(day.date)
                    Text(verbatim: name)
                        .font(FontRegistry.font(FontSpec(family: "system", size: 9, weight: .medium), size: 9 * scale, for: name))
                        .opacity(0.7)
                    Image(systemName: Icons.isAllowed(day.symbol) ? day.symbol : "questionmark")
                        .font(.system(size: 15 * scale))
                    highText(day.high)
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
    }

    /// The high in the dot font; the degree sign in the system font (Doto's looks wrong).
    private func highText(_ value: Double) -> Text {
        let digits = Text(verbatim: "\(Int(value.rounded()))")
            .font(FontRegistry.font(FontSpec(family: "dot", size: 13, weight: .bold), size: 13 * scale, for: ""))
        let degree = Text(verbatim: "°").font(.system(size: 11 * scale, weight: .bold))
        return digits + degree
    }

    /// "Wed" / "الأربعاء".
    private func dayName(_ date: Date) -> String {
        let context = resolver.context
        return FormatterCache.date(context.isArabic ? "EEEE" : "EEE", locale: context.localeIdentifier, zone: context.timeZone)
            .string(from: date)
    }
}
