import Foundation
import SwiftUI

/// The fonts a spec may name (brief §4.6, ADR-019). `dot` is Doto and `arabic` is IBM Plex Sans
/// Arabic; `hand` (Patrick Hand), `serif-display` (DM Serif Display) and `condensed` (Bebas Neue)
/// are Latin display faces. All OFL. Arabic text switches to an Arabic face: Aref Ruqaa for
/// `hand`, Amiri for `serif-display`, Lalezar for `condensed`, IBM Plex Sans Arabic otherwise.
///
/// The font files live in `ios/Fonts`, are bundled in the app and the widget extension, and are
/// declared in each target's `UIAppFonts` (ADR-010). Fonts are referenced by PostScript name
/// only: widgets can't use fonts registered at runtime or built with CoreText variations.
public enum FontRegistry {
    public static let families = [
        "system", "system-rounded", "system-serif", "system-mono", "dot", "arabic", "hand", "serif-display", "condensed",
    ]

    /// Every PostScript name the targets must provide through `UIAppFonts`.
    public static let bundledPostScriptNames = [
        "Doto-Regular", "Doto-Bold", "Doto-Black",
        "IBMPlexSansArabic-Regular", "IBMPlexSansArabic-Medium", "IBMPlexSansArabic-SemiBold", "IBMPlexSansArabic-Bold",
        "PatrickHand-Regular", "ArefRuqaa-Regular", "ArefRuqaa-Bold", "DMSerifDisplay-Regular", "Amiri-Regular", "Amiri-Bold",
        "BebasNeue-Regular", "Lalezar-Regular",
    ]

    /// True when `text` has Arabic letters, which switch any family to `arabic`.
    public static func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value)
            || (0x08A0...0x08FF).contains($0.value) || (0xFB50...0xFDFF).contains($0.value) || (0xFE70...0xFEFF).contains($0.value) }
    }

    /// The family actually used for `text`.
    public static func effectiveFamily(_ spec: FontSpec, for text: String) -> String {
        containsArabic(text) ? "arabic" : spec.family
    }

    /// The SwiftUI font for a spec font at `size` points (already scaled to the widget).
    public static func font(_ spec: FontSpec, size: CGFloat, for text: String) -> Font {
        let weight = spec.weight ?? .regular
        switch effectiveFamily(spec, for: text) {
        case "dot":
            return Font.custom(dotPostScriptName(weight), fixedSize: size)
        case "arabic":
            return Font.custom(arabicPostScriptName(weight, family: spec.family), fixedSize: size)
        case "hand":
            return Font.custom("PatrickHand-Regular", fixedSize: size)
        case "serif-display":
            return Font.custom("DMSerifDisplay-Regular", fixedSize: size)
        case "condensed":
            return Font.custom("BebasNeue-Regular", fixedSize: size)
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

    /// Doto ships as three static instances built from the variable font (`.github/workflows/fonts.yml`).
    static func dotPostScriptName(_ weight: FontWeightName) -> String {
        switch weight {
        case .ultraLight, .thin, .light, .regular, .medium: "Doto-Regular"
        case .semibold, .bold: "Doto-Bold"
        case .heavy, .black: "Doto-Black"
        }
    }

    /// The Arabic face for a spec family: the display families have their own; everything else
    /// uses IBM Plex Sans Arabic, which ships four static weights.
    static func arabicPostScriptName(_ weight: FontWeightName, family: String = "arabic") -> String {
        let bold = [.semibold, .bold, .heavy, .black].contains(weight)
        switch family {
        case "hand": return bold ? "ArefRuqaa-Bold" : "ArefRuqaa-Regular"
        case "serif-display": return bold ? "Amiri-Bold" : "Amiri-Regular"
        case "condensed": return "Lalezar-Regular"
        default: break
        }
        switch weight {
        case .ultraLight, .thin, .light, .regular: return "IBMPlexSansArabic-Regular"
        case .medium: return "IBMPlexSansArabic-Medium"
        case .semibold: return "IBMPlexSansArabic-SemiBold"
        case .bold, .heavy, .black: return "IBMPlexSansArabic-Bold"
        }
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
}
