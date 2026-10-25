import SwiftUI
import WidgetKit
import WidgetKitCore

/// Two tabs: the template library and My widgets (M3). Diagnostics (with the M1 test designs)
/// opens from the Library toolbar button (until M6), a long press on the version, or the check
/// widget (`widgetstudio://diagnostics`).
struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var showDiagnostics = false

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.tab) {
            NavigationStack {
                LibraryView(onLongPressVersion: { showDiagnostics = true })
                    .navigationTitle("library.title")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showDiagnostics = true
                            } label: {
                                Label("home.diagnostics", systemImage: "stethoscope")
                            }
                            .accessibilityIdentifier("ax.home.diagnostics")
                        }
                    }
                    .navigationDestination(isPresented: $showDiagnostics) {
                        DiagnosticsView()
                    }
            }
            .tabItem { Label("tab.library", systemImage: "square.grid.2x2") }
            .tag(AppState.Tab.library)

            NavigationStack {
                MyWidgetsView()
            }
            .tabItem { Label("tab.myWidgets", systemImage: "rectangle.stack") }
            .tag(AppState.Tab.myWidgets)
        }
        .onAppear(perform: AppInfo.touchHeartbeat)
        .onOpenURL { url in
            guard url.scheme == "widgetstudio" else { return }
            switch url.host() {
            case "diagnostics":
                appState.tab = .library
                showDiagnostics = true
            case "mywidgets":
                appState.tab = .myWidgets
            default:
                break
            }
        }
    }
}

enum AppInfo {
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// Refreshes the app heartbeat (keeping the test value) and asks the widget to reload.
    static func touchHeartbeat() {
        writeHeartbeat(changeValue: 0)
    }

    @discardableResult
    static func writeHeartbeat(changeValue delta: Int) -> Error? {
        let location = AppGroupResolver.resolve()
        let store = ProbeStore(location: location)
        let value = (store.readAppHeartbeat()?.testValue ?? 0) + delta
        do {
            try store.writeAppHeartbeat(AppHeartbeat(
                date: .now,
                bundleID: Bundle.main.bundleIdentifier ?? "",
                appGroupID: location.appGroupID,
                testValue: value
            ))
        } catch {
            return error
        }
        WidgetCenter.shared.reloadAllTimelines()
        return nil
    }
}
