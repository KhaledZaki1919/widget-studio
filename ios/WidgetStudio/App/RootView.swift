import SwiftUI
import UIKit
import WidgetKit
import WidgetKitCore

/// Three tabs: the template library, My widgets (M3) and Settings (M4). Diagnostics (with the M1 test designs)
/// opens from the Library toolbar button (until M6), a long press on the version, or the check
/// widget (`widgetstudio://diagnostics`).
struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var showDiagnostics = false
    @State private var showQibla = false

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

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("tab.settings", systemImage: "gearshape") }
            .tag(AppState.Tab.settings)
        }
        .sheet(isPresented: $showQibla) {
            NavigationStack {
                QiblaView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("common.done") { showQibla = false }
                        }
                    }
            }
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
            case "settings":
                appState.tab = .settings
            case "qibla":
                showQibla = true
            case "action":
                WidgetActions.perform(url)
            default:
                break
            }
        }
    }
}

/// Actions a widget button sends to the app (`widgetstudio://action/<action>?arg=…`, ADR-016).
/// Shortcut tiles run the Shortcut by name right away; links open only http/https pages.
/// Counter and stopwatch buttons are interactive in the widget itself and don't come here.
enum WidgetActions {
    @MainActor
    static func perform(_ url: URL) {
        let action = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let arg = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "arg" }?.value ?? ""
        switch action {
        case ButtonLayer.Action.shortcutRun.rawValue:
            guard let target = shortcutURL(name: arg) else { return }
            UIApplication.shared.open(target)
        case ButtonLayer.Action.openURL.rawValue:
            guard let target = URL(string: arg), let scheme = target.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
                return
            }
            UIApplication.shared.open(target)
        default:
            break
        }
    }

    /// `shortcuts://run-shortcut?name=<name>` for a non-empty Shortcut name.
    static func shortcutURL(name: String) -> URL? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: trimmed)]
        return components.url
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
