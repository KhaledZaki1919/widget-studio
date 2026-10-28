import XCTest

/// App Store screenshots (M6), 5 per language, taken on a 6.9" Simulator by the manual
/// "Screenshots" workflow (`SCREENSHOTS=1`). Skipped in every other test run. Uses sample data,
/// seeded designs and the canned AI provider, so no permission, key or network is needed.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS"] == "1", "only in the Screenshots workflow")
        continueAfterFailure = true
    }

    @MainActor
    func testArabicScreenshots() {
        shoot(language: "ar")
    }

    @MainActor
    func testEnglishScreenshots() {
        shoot(language: "en")
    }

    @MainActor
    private func shoot(language: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingSampleData", "-uiTestingSeedDesigns", "-uiTestingStubAI", "-uiTestingStubCalendar",
                               "-AppleLanguages", "(\(language))", "-AppleLocale", language == "ar" ? "ar_EG" : "en_US"]
        app.launch()

        // 1. Library
        XCTAssertTrue(app.buttons["ax.library.create"].waitForExistence(timeout: 20))
        settle()
        snap("01-library", language)

        // 2. A template in every size
        app.buttons["ax.library.chip.prayer"].tap()
        let prayer = app.buttons["ax.library.template.mono.prayer.day"]
        XCTAssertTrue(prayer.waitForExistence(timeout: 10))
        prayer.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ax.detail.preview.medium"].waitForExistence(timeout: 10))
        settle()
        snap("02-template", language)

        // 3. The editor
        app.buttons["ax.detail.customize"].tap()
        XCTAssertTrue(app.buttons["ax.editor.save"].waitForExistence(timeout: 10))
        settle()
        snap("03-editor", language)
        app.buttons["ax.editor.cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 4. Create from image: the result in the editor
        app.buttons["ax.library.chip.all"].tap()
        let create = app.buttons["ax.library.create"]
        for _ in 0..<4 where !create.isHittable { app.swipeDown() }
        create.tap()
        let sample = app.buttons["ax.create.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()
        let generate = app.buttons["ax.create.generate"]
        for _ in 0..<6 where !(generate.exists && generate.isHittable) { app.swipeUp() }
        generate.tap()
        let allow = app.buttons["ax.create.consent.allow"]
        if allow.waitForExistence(timeout: 10) { allow.tap() }
        XCTAssertTrue(app.buttons["ax.editor.regenerate"].waitForExistence(timeout: 30))
        settle()
        snap("04-create-from-image", language)
        app.buttons["ax.editor.cancel"].tap()

        // 5. My widgets with saved designs
        app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "ax.mywidgets.design").firstMatch.waitForExistence(timeout: 10))
        settle()
        snap("05-my-widgets", language)
    }

    /// Lets previews and animations finish before the screenshot.
    private func settle() {
        Thread.sleep(forTimeInterval: 1.5)
    }

    @MainActor
    private func snap(_ name: String, _ language: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(language)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
