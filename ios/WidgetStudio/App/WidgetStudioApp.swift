import SwiftUI
import WidgetKitCore

@main
struct WidgetStudioApp: App {
    @State private var designs = DesignsModel()
    @State private var appState = AppState()
    /// Real data for previews and Settings (M4, ADR-016).
    @State private var live = LiveDataModel()
    /// Shortcut tiles' setup and runs (ADR-017).
    @State private var tiles = TilesModel()
    /// Online/offline for the AI flow's notice (M6).
    @State private var network = NetworkStatus()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // UI tests launch with -uiTesting and start without saved designs.
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            let model = DesignsModel()
            model.deleteAll()
            // AI starts from defaults, so the consent sheet shows every run.
            AISettings().save()
            // The introduction only when a test asks for it.
            UserDefaults.standard.set(!ProcessInfo.processInfo.arguments.contains("-uiTestingOnboarding"),
                                      forKey: AppState.onboardingDoneKey)
            _appState = State(initialValue: AppState())
            _designs = State(initialValue: model)
        }
        // UI tests of Create from image: canned replies, no key, no network.
        if ProcessInfo.processInfo.arguments.contains("-uiTestingStubAI") {
            AIService.overrideProvider = UITestingAIProvider()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(designs)
                .environment(appState)
                .environment(live)
                .environment(tiles)
                .environment(network)
                .task { await live.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await live.refresh() } }
                }
        }
    }
}
