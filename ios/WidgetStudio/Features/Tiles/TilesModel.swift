import Observation
import UIKit
import WidgetKitCore

/// Shortcut tiles in the app (M4 feedback, ADR-017): a tap on a tile comes here; a tile that
/// isn't set up yet (or whose Shortcut failed) opens its setup screen, a ready one runs its
/// Shortcut. Kept in the app's own container: tile taps always reach the app.
@MainActor
@Observable
final class TilesModel {
    private(set) var state: TileSetupState
    /// The setup screen to show (a tap on a tile that isn't ready, or a Shortcuts error).
    var request: TileSetupRequest?

    @ObservationIgnored private let cache = DataCache()

    init() {
        state = TileSetupState.load(cache)
    }

    func status(_ name: String) -> TileSetupState.Status {
        state.status(name)
    }

    /// A tile tap: run the Shortcut when set up, else show its setup screen.
    func tap(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if state.shouldRun(trimmed) {
            run(trimmed)
        } else {
            request = TileSetupRequest(name: trimmed, failed: state.status(trimmed) == .failed)
        }
    }

    /// Shortcuts called back with an error: the Shortcut is missing or failed.
    func shortcutFailed(_ name: String) {
        change { $0.recordError(name) }
        request = TileSetupRequest(name: name, failed: true)
    }

    /// "I created it": mark ready and run it once, so a wrong name shows up right away.
    func confirm(_ name: String) {
        change { $0.confirm(name) }
        request = nil
        run(name)
    }

    func forget(_ name: String) {
        change { $0.forget(name) }
    }

    func run(_ name: String) {
        guard let url = ShortcutLinks.run(name: name) else { return }
        change { $0.recordRun(name) }
        UIApplication.shared.open(url)
    }

    /// Every tile name the user may meet: the tile templates' defaults, saved designs' tiles,
    /// and any name tapped before.
    func knownNames(designs: [SavedDesign], language: String) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        func add(_ name: String) {
            if seen.insert(TileSetupState.key(name)).inserted { names.append(name) }
        }
        for spec in TemplateLibrary.all() { ShortcutLinks.names(in: spec, language: language).forEach(add) }
        for design in designs {
            ShortcutLinks.names(in: design.spec, fieldValues: design.fieldValues, language: language).forEach(add)
        }
        state.entries.values.compactMap(\.name).sorted().forEach(add)
        return names
    }

    private func change(_ update: (inout TileSetupState) -> Void) {
        update(&state)
        try? state.save(cache)
    }
}

struct TileSetupRequest: Identifiable, Equatable {
    let name: String
    var failed = false
    var id: String { TileSetupState.key(name) }
}
