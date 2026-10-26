import XCTest
@testable import WidgetStudio

/// Shortcut tiles run `shortcuts://run-shortcut?name=…` (ADR-016).
final class WidgetActionsTests: XCTestCase {
    func testShortcutURLEncodesTheName() throws {
        let url = try XCTUnwrap(WidgetActions.shortcutURL(name: "Torch"))
        XCTAssertEqual(url.absoluteString, "shortcuts://run-shortcut?name=Torch")
        let arabic = try XCTUnwrap(WidgetActions.shortcutURL(name: " الكشاف السريع "))
        let name = URLComponents(url: arabic, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
        XCTAssertEqual(name, "الكشاف السريع")
        XCTAssertEqual(arabic.scheme, "shortcuts")
    }

    func testEmptyShortcutNamesDoNothing() {
        XCTAssertNil(WidgetActions.shortcutURL(name: ""))
        XCTAssertNil(WidgetActions.shortcutURL(name: "   "))
    }
}
