import CoreText
import Foundation
import SwiftUI

/// The fonts a spec may name (brief §4.6). `dot` is Doto and `arabic` is IBM Plex Sans Arabic,
/// both OFL and bundled in `Resources/Fonts`. Arabic text always uses `arabic`; `dot` is for
/// Latin digits and letters only.
public enum FontRegistry {
    public static let families = ["system", "system-rounded", "system-serif", "system-mono", "dot", "arabic"]

    private static let lock = NSLock()
    nonisolated(unsafe) private static var registered = false

    /// Registers the bundled fonts for this process (app and widget extension). Safe to call often.
    public static func registerBundledFonts() {
        lock.lock()
        defer { lock.unlock() }
        guard !registered else { return }
        registered = true
        let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// True when `text` has Arabic letters, which switch any family to `arabic`.
    public static func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value)
            || (0x08A0...0x08FF).contains($0.value) || (0xFB50...0xFDFF).contains($0.value) || (0xFE70...0xFEFF).contains($0.value) }
    }

    /// The SwiftUI font for a spec font at `size` points (already scaled to the widget).
    public static func font(_ spec: FontSpec, size: CGFloat, for text: String) -> Font {
        registerBundledFonts()
        let weight = spec.weight ?? .regular
        let family = containsArabic(text) ? "arabic" : spec.family
        switch family {
        case "dot":
            return dotFont(size: size, weight: weight)
        case "arabic":
            return Font.custom(arabicPostScriptName(weight), fixedSize: size)
        case "system-rounded":
            return .system(size: size, weight: weight.swiftUI, design: .rounded)
        case "system-serif":
            return .system(size: size, weight: weight.swiftUI, design: .serif)
        case "system-mono":
            return .system(size: size, weight: weight.swiftUI, design: .monospaced)
        default:
            return .system(size: size, weight: weight.swiftUI)
        }
    }

    /// IBM Plex Sans Arabic ships four static weights.
    static func arabicPostScriptName(_ weight: FontWeightName) -> String {
        switch weight {
        case .ultraLight, .thin, .light, .regular: "IBMPlexSansArabic-Regular"
        case .medium: "IBMPlexSansArabic-Medium"
        case .semibold: "IBMPlexSansArabic-SemiBold"
        case .bold, .heavy, .black: "IBMPlexSansArabic-Bold"
        }
    }

    /// Doto is a variable font (default instance Black); the weight is set on its `wght` axis.
    static func dotFont(size: CGFloat, weight: FontWeightName) -> Font {
        let wghtAxis = 0x7767_6874 // 'wght'
        let attributes: [CFString: Any] = [
            kCTFontNameAttribute: "Doto-Black" as CFString,
            kCTFontVariationAttribute: [wghtAxis: weight.dotAxisValue] as CFDictionary,
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }
}

extension FontWeightName {
    var swiftUI: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }

    /// Doto's `wght` axis runs from 100 to 900.
    var dotAxisValue: Double {
        switch self {
        case .ultraLight: 100
        case .thin: 200
        case .light: 300
        case .regular: 400
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        }
    }
}
