import SwiftUI
import WidgetKit
import WidgetKitCore

/// M0 home: a placeholder until the template library arrives in M2.
struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("home.m0.body")
                        .foregroundStyle(.secondary)
                }
                Section("home.section.about") {
                    LabeledContent("home.version", value: AppInfo.versionText)
                        .accessibilityIdentifier("ax.home.version")
                }
            }
            .navigationTitle("home.title")
        }
        .onAppear(perform: AppInfo.touchHeartbeat)
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
