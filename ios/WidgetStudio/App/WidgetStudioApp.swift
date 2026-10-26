import SwiftUI

@main
struct WidgetStudioApp: App {
    @State private var designs = DesignsModel()
    @State private var appState = AppState()
    /// Real data for previews and Settings (M4, ADR-016).
    @State private var live = LiveDataModel()
    /// Shortcut tiles' setup and runs (ADR-017).
    @State private var tiles = TilesModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // UI tests launch with -uiTesting and start without saved designs.
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            let model = DesignsModel()
            model.deleteAll()
            _designs = State(initialValue: model)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(designs)
                .environment(appState)
                .environment(live)
                .environment(tiles)
                .task { await live.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await live.refresh() } }
                }
        }
    }
}
