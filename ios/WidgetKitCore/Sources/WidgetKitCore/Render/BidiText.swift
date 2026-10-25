import Foundation

/// Keeps numbers intact inside Arabic text. In a right-to-left paragraph the Unicode bidi
/// algorithm moves neutral marks next to numbers ("33° / 21°" shows as "°21 / 33°"), so each
/// number run (digits with `° % : . ,`) is wrapped in a left-to-right isolate (LRI … PDI).
public enum BidiText {
    static let leftToRightIsolate: Character = "\u{2066}"
    static let popDirectionalIsolate: Character = "\u{2069}"
    private static let numberMarks: Set<Character> = ["°", "%", ":", ".", ","]

    /// Isolates number runs when `text` has Arabic letters; returns other text unchanged.
    public static func isolatingNumbers(_ text: String) -> String {
        guard FontRegistry.containsArabic(text) else { return text }
        var result = ""
        var run = ""
        func flush() {
            guard !run.isEmpty else { return }
            // Separators can't end a number ("5," in "5, 6"): keep them outside the isolate.
            var trailing = ""
            while let last = run.last, numberMarks.contains(last), last != "°", last != "%" {
                trailing.insert(last, at: trailing.startIndex)
                run.removeLast()
            }
            result.append(leftToRightIsolate)
            result += run
            result.append(popDirectionalIsolate)
            result += trailing
            run = ""
        }
        for character in text {
            if character.isASCII && character.isNumber {
                run.append(character)
            } else if !run.isEmpty && numberMarks.contains(character) {
                run.append(character)
            } else {
                flush()
                result.append(character)
            }
        }
        flush()
        return result
    }
}
