import XCTest

/// Simulator smoke test (brief §9): the app launches in both languages.
final class SmokeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language == "ar" ? "ar_EG" : "en_US"]
        app.launch()
        return app
    }

    @MainActor
    func testLaunchesInArabic() {
        let app = launch(language: "ar")
        XCTAssertTrue(app.staticTexts["ax.home.version"].waitForExistence(timeout: 10)
            || app.otherElements["ax.home.version"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchesInEnglish() {
        let app = launch(language: "en")
        XCTAssertTrue(app.staticTexts["ax.home.version"].waitForExistence(timeout: 10)
            || app.otherElements["ax.home.version"].waitForExistence(timeout: 2))
    }
}
