import XCTest

/// Drives the system file picker for real (the owner's report: tapping a file does nothing). The
/// runner writes files straight into the Simulator's "On My iPhone" storage, then Import opens the
/// picker and taps them. Each case records what it saw, so a failure says where the path stopped.
final class ImportPickerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let widget = """
    {"inventory":["time"],"name":{"en":"Probe","ar":"Probe"},"family":"small","theme":"dark",\
    "palette":{"bg":"#101418","fg":"#F5F5F5","accent":"#FF5A36"},\
    "background":{"type":"solid","color":"@bg","colors":null,"angle":null,"outerColor":null},"fields":[],\
    "layers":[{"type":"stack","axis":"vertical","spacing":4,"padding":null,"alignItems":"center","justify":"center","columns":null,\
    "frame":{"x":12,"y":40,"w":146,"h":90},"opacity":null,"mirror":null,"children":[\
    {"type":"text","value":{"en":"{{time.hh}}:{{time.mm}}","ar":"{{time.hh}}:{{time.mm}}"},"font":{"family":"dot","size":44,"weight":"black"},\
    "color":"@fg","align":"center","maxLines":1,"live":null}]}]}
    """

    /// "On My iPhone" on this Simulator: the Files app's local storage container.
    private func localStorage() throws -> URL {
        // Opening Files once creates the container.
        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.launch()
        _ = files.wait(for: .runningForeground, timeout: 10)
        files.terminate()
        let shared = try XCTUnwrap(ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"], "not on a Simulator")
        let groups = URL(fileURLWithPath: shared).appendingPathComponent("Containers/Shared/AppGroup")
        let manager = FileManager.default
        for group in (try? manager.contentsOfDirectory(at: groups, includingPropertiesForKeys: nil)) ?? [] {
            let plist = group.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard let data = try? Data(contentsOf: plist),
                  let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  (info["MCMMetadataIdentifier"] as? String)?.contains("FileProvider.LocalStorage") == true else { continue }
            let storage = group.appendingPathComponent("File Provider Storage")
            try manager.createDirectory(at: storage, withIntermediateDirectories: true)
            return storage
        }
        throw XCTSkip("no local storage container on this Simulator")
    }

    /// The picker may live in the app or in its own service process, depending on the iOS version.
    private func picker(_ app: XCUIApplication) -> [XCUIApplication] {
        [app, XCUIApplication(bundleIdentifier: "com.apple.DocumentManagerUICore.Service")]
    }

    private func element(named name: String, in apps: [XCUIApplication], timeout: TimeInterval = 15) -> XCUIElement? {
        let end = Date.now.addingTimeInterval(timeout)
        repeat {
            for app in apps {
                for query in [app.cells, app.buttons, app.staticTexts] {
                    let match = query.matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", name, name)).firstMatch
                    if match.exists { return match }
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date.now < end
        return nil
    }

    private func attach(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Opens Import and taps `file`; true when the picker closed.
    private func pick(_ file: String, app: XCUIApplication) throws -> Bool {
        let create = app.buttons["ax.library.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 15))
        create.tap()
        let external = app.buttons["ax.create.external"]
        for _ in 0..<6 where !(external.exists && external.isHittable) { app.swipeUp() }
        external.tap()
        let open = app.buttons["ax.create.external.file"]
        for _ in 0..<8 where !(open.exists && open.isHittable) { app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 10), "Import from file button missing")
        open.tap()
        sleep(2)
        let apps = picker(app)
        if let browse = element(named: "Browse", in: apps, timeout: 6) { browse.tap() }
        if let local = element(named: "On My iPhone", in: apps, timeout: 6) { local.tap() }
        guard let cell = element(named: (file as NSString).deletingPathExtension, in: apps) else {
            attach(apps.map(\.debugDescription).joined(separator: "\n\n"), name: "picker tree, \(file) not found")
            throw XCTSkip("the picker didn't list \(file) on this Simulator")
        }
        cell.tap()
        sleep(3)
        attach(apps.map(\.debugDescription).joined(separator: "\n\n"), name: "after tapping \(file)")
        return element(named: (file as NSString).deletingPathExtension, in: apps, timeout: 1) == nil
    }

    /// A plain `.json` file: the case that must work.
    @MainActor
    func testTappingAJsonFileImportsIt() throws {
        let storage = try localStorage()
        try Self.widget.write(to: storage.appendingPathComponent("probe-json.json"), atomically: true, encoding: .utf8)
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingStubAI", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(try pick("probe-json.json", app: app), "the picker stayed open after tapping a .json file")
        XCTAssertTrue(app.buttons["ax.editor.save"].waitForExistence(timeout: 10)
                      || app.staticTexts["ax.bulk.summary"].waitForExistence(timeout: 2),
                      "the file was picked but nothing was imported")
    }
}
