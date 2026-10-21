import SwiftUI
import WidgetKit
import WidgetKitCore

/// Home until the template library arrives in M2: the M1 test designs and Diagnostics.
/// Diagnostics opens from the visible link (until M6), a long press on the version, or the
/// check widget (`widgetstudio://diagnostics`).
struct RootView: View {
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("home.m1.body")
                        .foregroundStyle(.secondary)
                    NavigationLink("home.testSpecs") {
                        TestSpecsView()
                    }
                    .accessibilityIdentifier("ax.home.testSpecs")
                    NavigationLink("home.diagnostics") {
                        DiagnosticsView()
                    }
                    .accessibilityIdentifier("ax.home.diagnostics")
                }
                Section {
                    LabeledContent("home.version", value: AppInfo.versionText)
                        .contentShape(Rectangle())
                        .onLongPressGesture { showDiagnostics = true }
                        .accessibilityIdentifier("ax.home.version")
                } header: {
                    Text("home.section.about")
                } footer: {
                    Text("home.version.footer")
                }
            }
            .navigationTitle("home.title")
            .navigationDestination(isPresented: $showDiagnostics) {
                DiagnosticsView()
            }
        }
        .onAppear(perform: AppInfo.touchHeartbeat)
        .onOpenURL { url in
            if url.scheme == "widgetstudio", url.host() == "diagnostics" { showDiagnostics = true }
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
