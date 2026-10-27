import SwiftUI

/// `calendarMonth` (ADR-019): title, weekday row and day grid of the render date's month.
/// `mirrored` reverses the column order (right-to-left week); digits keep their shape.
struct CalendarMonthView: View {
    let layer: CalendarMonthLayer
    let resolver: BindingResolver
    let scale: CGFloat
    let mirrored: Bool

    var body: some View {
        let context = resolver.context
        let layout = CalendarMonthLayout(layer: layer, date: context.date, timeZone: context.timeZone,
                                         localeIdentifier: context.localeIdentifier)
        GeometryReader { proxy in
            let titleHeight = layout.title.isEmpty ? 0 : layer.effectiveTitleFont.size * 1.35 * scale
            let headerHeight = layout.weekdays.isEmpty ? 0 : layer.effectiveWeekdayFont.size * 1.7 * scale
            let cellWidth = proxy.size.width / 7
            let cellHeight = max(0, (proxy.size.height - titleHeight - headerHeight) / CGFloat(max(layout.rows.count, 1)))
            let columns = mirrored ? Array((0..<7).reversed()) : Array(0..<7)
            VStack(spacing: 0) {
                if !layout.title.isEmpty {
                    title(layout.title, inset: cellWidth * 0.18)
                        .frame(width: proxy.size.width, height: titleHeight)
                }
                if !layout.weekdays.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.self) { column in
                            label(layout.weekdays[column], font: layer.effectiveWeekdayFont,
                                  color: layout.weekendColumns[column] ? layer.weekendColor ?? weekdayColor : weekdayColor)
                                .frame(width: cellWidth, height: headerHeight)
                        }
                    }
                }
                ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.self) { column in
                            cell(row[column], width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private var weekdayColor: String { layer.weekdayColor ?? layer.color }

    private func title(_ text: String, inset: CGFloat) -> some View {
        let align: TextAlign = {
            let align = layer.titleAlign ?? .leading
            guard mirrored else { return align }
            return align == .leading ? .trailing : align == .trailing ? .leading : .center
        }()
        let font = layer.effectiveTitleFont
        return Text(verbatim: text)
            .font(FontRegistry.font(font, size: font.size * scale, for: text))
            .foregroundStyle(Color(hex: layer.titleColor ?? layer.color))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, inset)
            .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : align == .trailing ? .trailing : .center)
    }

    private func label(_ text: String, font: FontSpec, color: String) -> some View {
        Text(verbatim: text)
            .font(FontRegistry.font(font, size: font.size * scale, for: text))
            .foregroundStyle(Color(hex: color))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    @ViewBuilder private func cell(_ cell: CalendarMonthLayout.Cell, width: CGFloat, height: CGFloat) -> some View {
        let side = min(width, height) * 0.86
        let style = layer.todayStyle ?? .filled
        let highlight = Color(hex: layer.todayColor ?? layer.color)
        let onHighlight = cell.isToday && (style == .filled || style == .circle)
        ZStack {
            if cell.isToday {
                switch style {
                case .filled: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous).fill(highlight).frame(width: side, height: side)
                case .circle: Circle().fill(highlight).frame(width: side, height: side)
                case .ring: Circle().stroke(highlight, lineWidth: max(1, 1.5 * scale)).frame(width: side, height: side)
                case .dot: Circle().fill(highlight).frame(width: side * 0.16, height: side * 0.16).offset(y: side * 0.42)
                case .none: EmptyView()
                }
            }
            if let day = cell.day {
                let color = onHighlight ? layer.todayTextColor ?? "#FFFFFF" : cell.isWeekend ? layer.weekendColor ?? layer.color : layer.color
                label("\(day)", font: layer.font, color: color)
                    .opacity(cell.isOtherMonth ? 0.3 : 1)
            }
        }
        .frame(width: width, height: height)
    }
}

/// `list` (ADR-019): equal-height rows with marker, title and trailing detail. `mirrored`
/// reverses each row's order and alignment.
struct ListLayerView: View {
    let layer: ListLayer
    let resolver: BindingResolver
    let scale: CGFloat
    let mirrored: Bool

    var body: some View {
        GeometryReader { proxy in
            let rowHeight = proxy.size.height / CGFloat(max(layer.items.count, 1))
            VStack(spacing: 0) {
                ForEach(Array(layer.items.enumerated()), id: \.offset) { index, item in
                    row(item, height: rowHeight)
                        .frame(width: proxy.size.width, height: rowHeight)
                        .overlay(alignment: .bottom) {
                            if let divider = layer.dividerColor, index < layer.items.count - 1 {
                                Rectangle().fill(Color(hex: divider)).frame(height: max(0.5, 0.75 * scale))
                            }
                        }
                }
            }
        }
    }

    private var size: CGFloat { layer.font.size * scale }

    @ViewBuilder private func row(_ item: ListLayer.Item, height: CGFloat) -> some View {
        let title = text(item.title, color: Color(hex: layer.color))
        let detail = item.detail.map { text($0, color: layer.detailColor.map(Color.init(hex:)) ?? Color(hex: layer.color).opacity(0.6)) }
        HStack(spacing: 8 * scale) {
            if mirrored {
                detail
                Spacer(minLength: 4 * scale)
                title
                marker(item, height: height)
            } else {
                marker(item, height: height)
                title
                Spacer(minLength: 4 * scale)
                detail
            }
        }
    }

    private func text(_ value: LocalizedText, color: Color) -> some View {
        let rendered = BidiText.isolatingNumbers(resolver.render(value.resolved(language: resolver.context.language)))
        return Text(verbatim: rendered)
            .font(FontRegistry.font(layer.font, size: size, for: rendered))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    @ViewBuilder private func marker(_ item: ListLayer.Item, height: CGFloat) -> some View {
        let color = Color(hex: item.color ?? layer.markerColor ?? layer.color)
        switch layer.marker ?? .none {
        case .none: EmptyView()
        case .dot: Circle().fill(color).frame(width: size * 0.45, height: size * 0.45)
        case .circle: Circle().stroke(color, lineWidth: max(1, 1.5 * scale)).frame(width: size * 0.95, height: size * 0.95)
        case .check: Image(systemName: "checkmark.circle.fill").font(.system(size: size)).foregroundStyle(color)
        case .icon:
            Image(systemName: item.icon.flatMap { Icons.isAllowed($0) ? $0 : nil } ?? "circle.fill")
                .font(.system(size: size * 0.9))
                .foregroundStyle(color)
                .frame(width: size * 1.2)
        case .bar: RoundedRectangle(cornerRadius: 1.5 * scale).fill(color).frame(width: 3 * scale, height: height * 0.6)
        }
    }
}

/// `progressBar` (ADR-019): continuous or segmented; `mirrored` fills from the right.
struct ProgressBarView: View {
    let layer: ProgressBarLayer
    let progress: Double
    let scale: CGFloat
    let mirrored: Bool

    var body: some View {
        GeometryReader { proxy in
            let value = min(max(progress, 0), 1)
            let radius = layer.cornerRadius.map { $0 * scale } ?? proxy.size.height / 2
            let fill = Color(hex: layer.color)
            let track = Color(hex: layer.trackColor ?? "#8080804D")
            let segments = layer.segments ?? 1
            if segments > 1 {
                let lit = Int((value * Double(segments)).rounded())
                HStack(spacing: max(1, 2 * scale)) {
                    ForEach(0..<segments, id: \.self) { index in
                        let on = mirrored ? index >= segments - lit : index < lit
                        RoundedRectangle(cornerRadius: min(radius, proxy.size.height / 2), style: .continuous).fill(on ? fill : track)
                    }
                }
            } else {
                ZStack(alignment: mirrored ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(track)
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                        .frame(width: proxy.size.width * value)
                }
            }
        }
    }
}
