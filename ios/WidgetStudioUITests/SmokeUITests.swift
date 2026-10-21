import XCTest

/// Simulator smoke test (brief §9): the app launches in both languages and Diagnostics opens.
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
    private func opensDiagnostics(language: String) {
        let app = launch(language: language)
        let link = app.buttons["ax.home.diagnostics"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        link.tap()
        XCTAssertTrue(app.collectionViews["ax.diag.list"].waitForExistence(timeout: 10))
        // List cells exist only on screen, so scroll down to the App Group button.
        let write = app.buttons["ax.diag.writeValue"]
        for _ in 0..<6 where !write.exists {
            app.collectionViews["ax.diag.list"].swipeUp()
        }
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        write.tap()
    }

    /// The test designs gallery renders specs in both languages.
    @MainActor
    func testTestDesignsRenderInBothLanguages() {
        let app = launch(language: "en")
        let link = app.buttons["ax.home.testSpecs"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        link.tap()
        XCTAssertTrue(app.collectionViews["ax.specs.list"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["ax.specs.preview.test.clock.digital"].waitForExistence(timeout: 10))
        app.buttons["العربية"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ax.specs.preview.test.clock.digital"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testOpensDiagnosticsInArabic() {
        opensDiagnostics(language: "ar")
    }

    @MainActor
    func testOpensDiagnosticsInEnglish() {
        opensDiagnostics(language: "en")
    }
}
