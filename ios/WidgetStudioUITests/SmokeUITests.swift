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
        // Signing sections (app + widget) sit above it since ADR-012.
        for _ in 0..<14 where !write.exists {
            app.collectionViews["ax.diag.list"].swipeUp()
        }
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        write.tap()
    }

    /// The library filters by category and opens a template's detail with every supported size.
    @MainActor
    private func browsesLibrary(language: String) {
        let app = launch(language: language)
        let chip = app.buttons["ax.library.chip.prayer"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "prayer chip not found")
        chip.tap()
        let template = app.buttons["ax.library.template.mono.prayer.day"]
        XCTAssertTrue(template.waitForExistence(timeout: 10), "prayer-day template not found after the chip")
        // Other categories are hidden while a chip is selected.
        XCTAssertFalse(app.buttons["ax.library.template.mono.clock.analog"].exists, "time templates still shown")
        template.tap()
        let medium = app.descendants(matching: .any)["ax.detail.preview.medium"]
        XCTAssertTrue(medium.waitForExistence(timeout: 10), "medium preview missing in detail")
        XCTAssertTrue(app.descendants(matching: .any)["ax.detail.preview.large"].exists, "large preview missing in detail")
        XCTAssertFalse(app.descendants(matching: .any)["ax.detail.preview.small"].exists, "small preview shown for a medium template")
    }

    @MainActor
    func testBrowsesLibraryInEnglish() {
        browsesLibrary(language: "en")
    }

    @MainActor
    func testBrowsesLibraryInArabic() {
        browsesLibrary(language: "ar")
    }

    /// The test designs gallery (now under Diagnostics) renders specs in both languages.
    @MainActor
    func testTestDesignsRenderInBothLanguages() {
        let app = launch(language: "en")
        let diagnostics = app.buttons["ax.home.diagnostics"]
        XCTAssertTrue(diagnostics.waitForExistence(timeout: 15))
        diagnostics.tap()
        let link = app.buttons["ax.diag.testSpecs"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
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
