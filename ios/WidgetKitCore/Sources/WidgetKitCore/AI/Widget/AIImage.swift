import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The image as sent to the provider: JPEG, longest side ≤ 1024 px, orientation applied,
/// no metadata (no EXIF, no GPS), brief §5 step 2.
public struct PreparedImage: Sendable, Equatable {
    public let jpeg: Data
    public let width: Int
    public let height: Int

    public init(jpeg: Data, width: Int, height: Int) {
        self.jpeg = jpeg
        self.width = width
        self.height = height
    }
}

public enum AIImage {
    public static let maxSide = 1024
    public static let quality = 0.8

    /// From picked file data (JPEG, HEIC, PNG…). Nil if it isn't an image.
    public static func prepare(data: Data, maxSide: Int = maxSide) -> PreparedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // The thumbnail API downsamples without decoding the full image and applies the EXIF
        // orientation, so the result is upright.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return encode(image)
    }

    /// The picked file as an upright image (orientation applied), longest side ≤ `maxSide`;
    /// used for previews and for the photo the design keeps.
    public static func upright(data: Data, maxSide: Int = 2048) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// From an already decoded, upright image.
    public static func prepare(image: CGImage, maxSide: Int = maxSide) -> PreparedImage? {
        let longest = max(image.width, image.height)
        guard longest > maxSide else { return encode(image) }
        let scale = Double(maxSide) / Double(longest)
        let size = CGSize(width: max(1, (Double(image.width) * scale).rounded()), height: max(1, (Double(image.height) * scale).rounded()))
        guard let scaled = ImageProcessing.draw(size: size, { $0.draw(image, in: CGRect(origin: .zero, size: size)) }) else { return nil }
        return encode(scaled)
    }

    /// JPEG without any metadata dictionary, on an opaque white background (JPEG has no alpha).
    static func encode(_ image: CGImage) -> PreparedImage? {
        let size = CGSize(width: image.width, height: image.height)
        guard let opaque = ImageProcessing.draw(size: size, { context in
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
            context.draw(image, in: CGRect(origin: .zero, size: size))
        }) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, opaque, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return PreparedImage(jpeg: output as Data, width: image.width, height: image.height)
    }
}
