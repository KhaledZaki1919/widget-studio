import Foundation
import Testing
@testable import WidgetKitCore

struct TileSetupTests {
    let now = Date(timeIntervalSince1970: 1_792_591_500)

    @Test func templateNamesGetTheirExactActions() {
        #expect(ShortcutRecipe.forName("Wi-Fi").action == "Set Wi-Fi")
        #expect(ShortcutRecipe.forName("Torch").action == "Set Flashlight")
        #expect(ShortcutRecipe.forName("Dark Mode").action == "Set Appearance")
        #expect(ShortcutRecipe.forName("Airplane Mode").action == "Set Airplane Mode")
        #expect(ShortcutRecipe.forName("Rotation Lock").action == "Set Orientation Lock")
        #expect(ShortcutRecipe.forName("Mute").action == "Set Silent Mode")
        #expect(ShortcutRecipe.forName("Scan QR").kind == .qr)
        #expect(ShortcutRecipe.forName("Camera").kind == .camera)
        #expect(ShortcutRecipe.forName("bluetooth").option == "Toggle")
        #expect(ShortcutRecipe.forName("Low Power").kind == .lowPower)
        #expect(ShortcutRecipe.forName("Mobile Data").kind == .cellular)
        #expect(ShortcutRecipe.forName("الكشاف").kind == .torch)
        #expect(ShortcutRecipe.forName("Morning routine").kind == .custom)
        #expect(ShortcutRecipe.forName("Morning routine").action == nil)
    }

    @Test func aTileRunsOnlyAfterSetupAndNotAfterAnError() {
        var state = TileSetupState()
        #expect(state.status("Torch") == .notSetUp)
        #expect(!state.shouldRun("Torch"))
        state.confirm("Torch", now: now)
        #expect(state.shouldRun("torch "))
        state.recordError("Torch", now: now.addingTimeInterval(5))
        #expect(state.status("Torch") == .failed)
        state.confirm("Torch", now: now.addingTimeInterval(60))
        #expect(state.status("Torch") == .ready)
        #expect(state.entries["torch"]?.name == "Torch")
        state.forget("TORCH")
        #expect(state.status("Torch") == .notSetUp)
    }

    @Test func runLinkCallsBackOnError() throws {
        let url = try #require(ShortcutLinks.run(name: "Dark Mode"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.scheme == "shortcuts")
        #expect(url.host == "x-callback-url")
        #expect(url.path == "/run-shortcut")
        #expect(items.first { $0.name == "name" }?.value == "Dark Mode")
        let error = try #require(items.first { $0.name == "x-error" }?.value.flatMap(URL.init(string:)))
        #expect(error.host == "tiles")
        let errorItems = URLComponents(url: error, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(errorItems.first { $0.name == "name" }?.value == "Dark Mode")
        #expect(errorItems.contains { $0.name == "error" })
        #expect(ShortcutLinks.run(name: "  ") == nil)
    }

    @Test func tileNamesComeFromTheSpecAndTheDesign() throws {
        let spec = try TemplateLibrary.load(id: "mono.tiles.pills4").get()
        #expect(ShortcutLinks.names(in: spec, language: "en") == ["Torch", "Wi-Fi", "Dark Mode", "Airplane Mode"])
        let custom = ShortcutLinks.names(in: spec, fieldValues: ["shortcut2": "My Wifi"], language: "en")
        #expect(custom[1] == "My Wifi")
    }
}
