import SwiftUI

/// The in-app logo (M6): the app icon's 2×2 grid of widget shapes, drawn as vectors so it is
/// sharp at any size. Same geometry as `scripts/make-icon.ps1` (unit square: margin 0.19,
/// gap 0.0625, tile 0.28). `onDark` draws white shapes for dark backgrounds.
struct LogoMark: View {
    var onDark = false

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
            let tile = side * 0.28
            let gap = side * 0.0625
            let margin = side * 0.19
            func rect(_ column: Int, _ row: Int) -> CGRect {
                CGRect(x: origin.x + margin + CGFloat(column) * (tile + gap), y: origin.y + margin + CGFloat(row) * (tile + gap),
                       width: tile, height: tile)
            }
            let background = onDark ? Color(red: 0.055, green: 0.055, blue: 0.055) : Color.white
            let ink = onDark ? Color.white : Color(red: 0.055, green: 0.055, blue: 0.055)
            let card = rect(0, 0)
            context.fill(Path(roundedRect: card, cornerRadius: tile * 0.26, style: .continuous), with: .color(ink))
            let dot = tile * 0.12
            let step = tile * 0.25
            for column in -1...1 {
                for row in -1...1 {
                    let center = CGPoint(x: card.midX + CGFloat(column) * step, y: card.midY + CGFloat(row) * step)
                    context.fill(Path(ellipseIn: CGRect(x: center.x - dot / 2, y: center.y - dot / 2, width: dot, height: dot)),
                                 with: .color(background))
                }
            }
            context.fill(Path(ellipseIn: rect(1, 0)), with: .color(ink))
            let width = tile * 0.16
            context.stroke(Path(ellipseIn: rect(0, 1).insetBy(dx: width / 2, dy: width / 2)), with: .color(ink), lineWidth: width)
            context.fill(Path(ellipseIn: rect(1, 1)), with: .color(Color(red: 0.886, green: 0.137, blue: 0.102)))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("common.appName"))
        .accessibilityAddTraits(.isImage)
    }
}
