import SwiftUI

@main
struct WidgetStudioApp: App {
    @State private var designs = DesignsModel()
    @State private var appState = AppState()

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
        }
    }
}
