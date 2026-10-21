import SwiftUI
import UIKit
import WidgetKitCore
import XCTest

/// Renders SwiftUI views to bitmaps and compares them with reference PNGs (ADR-010).
///
/// - References live in `WidgetStudioTests/Snapshots/<name>.png` and ship in the test bundle.
/// - Every render is also written to `$SNAPSHOT_DIR` (CI: `ios/build/snapshots`, uploaded as the
///   `snapshots` artifact), so new or changed images can be reviewed and committed.
/// - A missing reference skips the test ("recorded"); a different image fails it and writes
///   `<name>.diff.png` next to the render.
@MainActor
enum Snapshot {
    /// 2026-10-21 14:05 in Cairo (UTC+3), a Wednesday.
    static let date = Date(timeIntervalSince1970: 1_792_580_700)
    static let timeZone = TimeZone(identifier: "Africa/Cairo") ?? .current

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 7 // Saturday, as in Egypt
        return calendar
    }

    /// Fixed date, zone, data and frozen live text, so renders are identical on every run.
    static func context(language: String) -> RenderContext {
        var context = RenderContext(date: date, language: language, timeZone: timeZone,
                                    data: .sample(now: date, calendar: calendar))
        context.freezesLiveText = true
        return context
    }

    static func render<Content: View>(_ view: Content, size: CGSize, scale: CGFloat = 2) -> CGImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.isOpaque = false
        return renderer.cgImage
    }

    static var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    static func write(_ image: CGImage, name: String) {
        guard let directory = outputDirectory, let data = UIImage(cgImage: image).pngData() else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("\(name).png"))
    }

    static func reference(named name: String) -> CGImage? {
        final class Marker {}
        guard let url = Bundle(for: Marker.self).url(forResource: name, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        return image.cgImage
    }

    /// Compares with the reference; throws `XCTSkip` when there is none yet.
    static func assertMatches(_ image: CGImage, name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        write(image, name: name)
        guard let reference = reference(named: name) else {
            throw XCTSkip("No reference for \(name) yet; the render was written to SNAPSHOT_DIR")
        }
        let result = Pixels.compare(image, reference)
        if !result.matches {
            if let diff = result.diff { write(diff, name: "\(name).diff") }
            XCTFail("\(name) differs from its reference: \(result.summary)", file: file, line: line)
        }
    }
}

/// RGBA8 pixel access and comparison.
enum Pixels {
    struct Comparison {
        let matches: Bool
        let summary: String
        let diff: CGImage?
    }

    static func rgba(_ image: CGImage) -> [UInt8] {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

    /// Pixels whose channels differ by more than `tolerance`, as a share of all pixels, must stay
    /// under `maxShare`. Exact comparison: `tolerance: 0, maxShare: 0`.
    static func compare(_ lhs: CGImage, _ rhs: CGImage, tolerance: Int = 24, maxShare: Double = 0.002) -> Comparison {
        guard lhs.width == rhs.width, lhs.height == rhs.height else {
            return Comparison(matches: false, summary: "size \(lhs.width)×\(lhs.height) vs \(rhs.width)×\(rhs.height)", diff: nil)
        }
        let left = rgba(lhs)
        let right = rgba(rhs)
        var diff = [UInt8](repeating: 0, count: left.count)
        var changed = 0
        for pixel in stride(from: 0, to: left.count, by: 4) {
            let delta = (0..<4).map { abs(Int(left[pixel + $0]) - Int(right[pixel + $0])) }.max() ?? 0
            if delta > tolerance {
                changed += 1
                diff[pixel] = 255
                diff[pixel + 3] = 255
            }
        }
        let share = Double(changed) / Double(lhs.width * lhs.height)
        let summary = String(format: "%d pixels (%.3f%%) differ", changed, share * 100)
        return Comparison(matches: share <= maxShare, summary: summary, diff: image(from: diff, width: lhs.width, height: lhs.height))
    }

    /// The number of distinct colors, capped; 1 means the render is blank.
    static func distinctColors(_ image: CGImage, cap: Int = 8) -> Int {
        let pixels = rgba(image)
        var seen = Set<UInt32>()
        for pixel in stride(from: 0, to: pixels.count, by: 4) {
            seen.insert(UInt32(pixels[pixel]) << 24 | UInt32(pixels[pixel + 1]) << 16 | UInt32(pixels[pixel + 2]) << 8 | UInt32(pixels[pixel + 3]))
            if seen.count >= cap { break }
        }
        return seen.count
    }

    static func image(from pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        var copy = pixels
        return copy.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
    }
}
