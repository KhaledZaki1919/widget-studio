import SwiftUI
import WidgetKitCore

/// Hidden screen (long-press the version number; in M0 also linked from Home) that shows which
/// capabilities work on this sideloaded install (ADR-005), with a shareable report.
struct DiagnosticsView: View {
    @State private var model = DiagnosticsModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            buildSection
            appGroupSection
            widgetSection
            locationSection
            healthSection
            Section("diag.section.battery") {
                outcomeRow("diag.battery.app", model.battery)
            }
            Section {
                Button("diag.refresh", action: model.refresh)
                    .accessibilityIdentifier("ax.diag.refresh")
                ShareLink(item: model.reportText) {
                    Label("diag.share", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("ax.diag.share")
            } footer: {
                Text("diag.share.footer")
            }
        }
        .navigationTitle("diag.title")
        .onAppear(perform: model.refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }

    private var buildSection: some View {
        Section("diag.section.build") {
            valueRow("diag.version", AppInfo.versionText)
            valueRow("diag.bundleID", Bundle.main.bundleIdentifier ?? "—")
            valueRow("diag.profile", DiagnosticsModel.describe(model.profileStatus))
            valueRow("diag.team", model.profile?.teamIdentifiers.joined(separator: ", ") ?? "—")
            valueRow("diag.profileGroups", model.profile.map { $0.appGroups.isEmpty ? "—" : $0.appGroups.joined(separator: "\n") } ?? "—")
            valueRow("diag.entitlements", model.profile?.entitlementKeys.joined(separator: "\n") ?? "—")
        }
    }

    private var appGroupSection: some View {
        Section {
            valueRow("diag.group.resolved", model.store.appGroupID ?? "—")
                .accessibilityIdentifier("ax.diag.groupName")
            valueRow("diag.group.source", model.store.source?.rawValue ?? "—")
            valueRow("diag.group.candidates", model.candidates.isEmpty ? "—"
                : model.candidates.map { "\($0.id) (\($0.source.rawValue))" }.joined(separator: "\n"))
            statusRow("diag.group.shared", ok: model.store.isShared)
                .accessibilityIdentifier("ax.diag.appGroup")
            outcomeRow("diag.group.readWrite", model.appGroupTest)
            valueRow("diag.group.value", model.testValue.map { "#\($0)" } ?? "—")
            Button("diag.group.write", action: model.writeTestValue)
                .accessibilityIdentifier("ax.diag.writeValue")
        } header: {
            Text("diag.section.appGroup")
        } footer: {
            Text("diag.group.footer")
        }
    }

    private var widgetSection: some View {
        Section {
            if let report = model.widgetReport {
                valueRow("diag.widget.lastReport", report.date.formatted(date: .abbreviated, time: .standard))
                statusRow("diag.widget.sawApp", ok: report.appHeartbeat != nil,
                          detail: report.appHeartbeat.map { "#\($0.testValue)" })
                statusRow("diag.widget.locationAuthorized", ok: report.locationAuthorizedForWidget)
                outcomeRow("diag.widget.location", report.location)
                outcomeRow("diag.widget.battery", report.battery)
            } else {
                Text(model.store.isShared ? LocalizedStringKey("diag.widget.none") : "diag.widget.notShared")
                    .foregroundStyle(.secondary)
            }
            if let reloaded = model.widgetReloadedAt {
                valueRow("diag.widget.reloadRequested", reloaded.formatted(date: .omitted, time: .standard))
            }
        } header: {
            Text("diag.section.widget")
        } footer: {
            Text("diag.widget.footer")
        }
    }

    private var locationSection: some View {
        Section {
            statusRow("diag.location.permission", ok: model.locationAllowed,
                      detail: DiagnosticsModel.describe(model.locationStatus))
            if model.locationStatus == .notDetermined {
                Button("diag.location.request", action: model.requestLocation)
                    .accessibilityIdentifier("ax.diag.location")
            }
        } header: {
            Text("diag.section.location")
        } footer: {
            Text("diag.location.footer")
        }
    }

    private var healthSection: some View {
        Section("diag.section.health") {
            statusRow("diag.health.available", ok: model.healthAvailable)
            if let granted = model.profileGrantsHealthKit {
                statusRow("diag.health.entitlement", ok: granted)
            }
            outcomeRow("diag.health.steps", model.health)
            Button {
                Task { await model.runHealthKit() }
            } label: {
                HStack {
                    Text("diag.health.run")
                    if model.healthRunning { Spacer(); ProgressView() }
                }
            }
            .disabled(model.healthRunning)
            .accessibilityIdentifier("ax.diag.health")
        }
    }

    // MARK: Rows

    private func valueRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        } label: {
            Text(title)
        }
    }

    private func statusRow(_ title: LocalizedStringKey, ok: Bool, detail: String? = nil) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                if let detail { Text(verbatim: detail).foregroundStyle(.secondary) }
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(ok ? .green : .red)
                    .accessibilityLabel(Text(ok ? LocalizedStringKey("common.yes") : "common.no"))
            }
        } label: {
            Text(title)
        }
    }

    private func outcomeRow(_ title: LocalizedStringKey, _ outcome: ProbeOutcome) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                switch outcome {
                case .ok: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                case .notRun: Text("diag.notRun").foregroundStyle(.secondary)
                }
            }
            switch outcome {
            case .ok(let detail), .failed(let detail):
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            case .notRun:
                EmptyView()
            }
        }
    }
}
