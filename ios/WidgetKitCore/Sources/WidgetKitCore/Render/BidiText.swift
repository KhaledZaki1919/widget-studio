import Foundation

/// Keeps numbers and Latin words intact inside Arabic text. In a right-to-left paragraph the
/// Unicode bidi algorithm reorders neutral marks and separate Latin pieces ("33° / 21°" shows as
/// "°21 / 33°", "رحلة XY 123" as "رحلة 123 XY"), so each Latin run is wrapped in a
/// left-to-right isolate (LRI … PDI).
///
/// A run is ASCII letters and digits with `° % : . ,` inside, and continues across a single space
/// when either side has a Latin letter ("XY 123", "FLIGHT XY 123"). It never crosses Arabic text
/// or "/", so "33° / 21°" keeps its Arabic reading order (two runs).
public enum BidiText {
    static let leftToRightIsolate: Character = "\u{2066}"
    static let popDirectionalIsolate: Character = "\u{2069}"
    private static let numberMarks: Set<Character> = ["°", "%", ":", ".", ","]

    /// Isolates Latin runs when `text` has Arabic letters; returns other text unchanged.
    public static func isolatingNumbers(_ text: String) -> String {
        guard FontRegistry.containsArabic(text) else { return text }
        let characters = Array(text)
        var result = ""
        var run = ""
        var index = 0

        func flush() {
            guard !run.isEmpty else { return }
            // Separators can't end a run ("5," in "5, 6"): keep them outside the isolate.
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

        while index < characters.count {
            let character = characters[index]
            if isLatin(character) {
                run.append(character)
            } else if !run.isEmpty && numberMarks.contains(character) {
                run.append(character)
            } else if !run.isEmpty, character == " ", index + 1 < characters.count, isLatin(characters[index + 1]),
                      run.contains(where: isLetter) || isLetter(characters[index + 1]) {
                run.append(character)
            } else {
                flush()
                result.append(character)
            }
            index += 1
        }
        flush()
        return result
    }

    private static func isLatin(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber)
    }

    private static func isLetter(_ character: Character) -> Bool {
        character.isASCII && character.isLetter
    }
}
