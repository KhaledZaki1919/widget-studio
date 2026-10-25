import CoreGraphics
import Foundation

/// Photo processing for saved designs (brief §2, §4.4; ADR-015): downscale to the widget's pixel
/// size (the widget extension has ~30 MB), and apply `mono` / `halftone` once when saving, never
/// in the widget.
public enum ImageProcessing {
    /// Points → pixels on current iPhones.
    public static let screenScale: CGFloat = 3
    public static let maxSide = 1024

    /// The photo for an image layer: cropped to fill (or fitted) at the layer's pixel size, then filtered.
    public static func prepare(_ image: CGImage, frame: Frame, layer: ImageLayer, scale: CGFloat = screenScale) -> CGImage? {
        let size = pixelSize(for: frame, scale: scale)
        guard let sized = layer.fit == .fit ? fit(image, in: size) : fill(image, size: size) else { return nil }
        switch layer.filter ?? .none {
        case .none: return sized
        case .mono: return mono(sized)
        case .halftone: return halftone(sized)
        }
    }

    /// The layer frame in pixels, longest side capped at `maxSide`.
    public static func pixelSize(for frame: Frame, scale: CGFloat = screenScale) -> CGSize {
        var width = max(1, frame.w * scale)
        var height = max(1, frame.h * scale)
        let longest = max(width, height)
        if longest > CGFloat(maxSide) {
            width *= CGFloat(maxSide) / longest
            height *= CGFloat(maxSide) / longest
        }
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    /// Scales to cover `size` and crops the center.
    public static func fill(_ image: CGImage, size: CGSize) -> CGImage? {
        let ratio = max(size.width / CGFloat(image.width), size.height / CGFloat(image.height))
        let drawn = CGSize(width: CGFloat(image.width) * ratio, height: CGFloat(image.height) * ratio)
        let origin = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)
        return draw(size: size) { $0.draw(image, in: CGRect(origin: origin, size: drawn)) }
    }

    /// Scales to fit inside `size` (no crop), keeping the aspect ratio.
    public static func fit(_ image: CGImage, in size: CGSize) -> CGImage? {
        let ratio = min(size.width / CGFloat(image.width), size.height / CGFloat(image.height), 1)
        let target = CGSize(width: max(1, (CGFloat(image.width) * ratio).rounded()), height: max(1, (CGFloat(image.height) * ratio).rounded()))
        return draw(size: target) { $0.draw(image, in: CGRect(origin: .zero, size: target)) }
    }

    /// Grayscale, as RGB so every widget renderer handles it the same way.
    public static func mono(_ image: CGImage) -> CGImage? {
        guard let gray = luminance(image) else { return nil }
        var pixels = [UInt8](repeating: 255, count: gray.count * 4)
        for (index, value) in gray.enumerated() {
            let byte = UInt8(max(0, min(255, (value * 255).rounded())))
            pixels[index * 4] = byte
            pixels[index * 4 + 1] = byte
            pixels[index * 4 + 2] = byte
        }
        return pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                      bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }

    /// Black dots on white: one dot per cell, its area following the cell's darkness.
    public static func halftone(_ image: CGImage, cellsAcross: Int = 44) -> CGImage? {
        guard let gray = luminance(image) else { return nil }
        let width = image.width
        let height = image.height
        let cell = max(3, width / cellsAcross)
        return draw(size: CGSize(width: width, height: height)) { context in
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            for top in stride(from: 0, to: height, by: cell) {
                for left in stride(from: 0, to: width, by: cell) {
                    var sum = 0.0
                    var count = 0
                    for y in top..<min(top + cell, height) {
                        for x in left..<min(left + cell, width) {
                            sum += gray[y * width + x]
                            count += 1
                        }
                    }
                    let darkness = 1 - sum / Double(max(count, 1))
                    guard darkness > 0.04 else { continue }
                    // Area ∝ darkness; at full black neighbouring dots touch.
                    let radius = CGFloat(cell) / 2 * CGFloat(min(1.15, (darkness * 1.3).squareRoot()))
                    let center = CGPoint(x: CGFloat(left) + CGFloat(cell) / 2, y: CGFloat(height - top) - CGFloat(cell) / 2)
                    context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                }
            }
        }
    }

    /// Per-pixel luminance 0…1, rows top to bottom.
    static func luminance(_ image: CGImage) -> [Double]? {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        return stride(from: 0, to: pixels.count, by: 4).map { index in
            (0.2126 * Double(pixels[index]) + 0.7152 * Double(pixels[index + 1]) + 0.0722 * Double(pixels[index + 2])) / 255
        }
    }

    static func draw(size: CGSize, _ body: (CGContext) -> Void) -> CGImage? {
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        body(context)
        return context.makeImage()
    }
}
