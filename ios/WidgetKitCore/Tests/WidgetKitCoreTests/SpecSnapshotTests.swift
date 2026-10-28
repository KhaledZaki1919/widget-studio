import CoreGraphics
import Foundation
import Testing
@testable import WidgetKitCore

/// `SpecSnapshot`, the render the AI review round and the eval send (ADR-019).
struct SpecSnapshotTests {
    /// RGBA of one pixel.
    func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: 4)
        data.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        }
        return data
    }

    /// A full-size button must stay invisible: ImageRenderer can't draw `Link` and painted a
    /// yellow "unsupported" sign over the whole render (eval run 5).
    @Test @MainActor func buttonsRenderInvisible() throws {
        let spec = WidgetSpec(id: "test.snapshot", name: "t", family: .small, background: .solid("#FFFFFF"), layers: [
            Layer(frame: Frame(x: 0, y: 0, w: 170, h: 170), content: .button(ButtonLayer(action: .openApp))),
        ])
        let image = try #require(SpecSnapshot.render(spec, scale: 1))
        #expect(image.width == 170 && image.height == 170)
        let center = pixel(image, x: 85, y: 85)
        #expect(center[0] > 240 && center[1] > 240 && center[2] > 240, "center pixel is \(center)")
    }
}
