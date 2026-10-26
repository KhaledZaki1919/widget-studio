import SwiftUI
import UIKit
import WidgetKitCore

/// One tile's setup (M4 feedback): why a Shortcut is needed, the exact name, and how to build
/// it with the exact Shortcuts action. "I created it" marks the tile ready and runs it once.
struct TileSetupView: View {
    @Environment(TilesModel.self) private var tiles
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    let name: String
    var failed = false
    @State private var copied = false

    private var recipe: ShortcutRecipe { ShortcutRecipe.forName(name) }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: recipe.symbol)
                        .font(.system(size: 34))
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color.accentColor.opacity(0.15)))
                    Text(verbatim: name).font(.title2.weight(.semibold))
                    statusBadge
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            if failed {
                Section {
                    Label("tiles.failed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }
            Section("tiles.why.title") {
                Text("tiles.why").font(.callout)
            }
            Section {
                HStack {
                    Text(verbatim: name)
                        .font(.body.monospaced().weight(.semibold))
                        .textSelection(.enabled)
                        .accessibilityIdentifier("ax.tiles.name")
                    Spacer()
                    Button {
                        UIPasteboard.general.string = name
                        copied = true
                    } label: {
                        Label(copied ? "tiles.copied" : "tiles.copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("tiles.name.title")
            } footer: {
                Text("tiles.name.footer")
            }
            Section("guide.steps") {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Label {
                        Text(step)
                    } icon: {
                        Text(verbatim: "\(index + 1)")
                            .font(.caption.weight(.bold))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.accentColor.opacity(0.2)))
                    }
                }
            }
            Section {
                Button {
                    UIPasteboard.general.string = name
                    if let url = ShortcutLinks.create { openURL(url) }
                } label: {
                    Label("tiles.openShortcuts", systemImage: "square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("ax.tiles.openShortcuts")
                Button {
                    tiles.confirm(name)
                    dismiss()
                } label: {
                    Label("tiles.created", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("ax.tiles.created")
            } footer: {
                Text("tiles.created.footer")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        }
        .navigationTitle("tiles.setup.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var statusBadge: some View {
        switch tiles.status(name) {
        case .ready: Label("tiles.status.ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.footnote)
        case .failed: Label("tiles.status.failed", systemImage: "xmark.circle.fill").foregroundStyle(.orange).font(.footnote)
        case .notSetUp: Label("tiles.status.notSetUp", systemImage: "circle.dashed").foregroundStyle(.secondary).font(.footnote)
        }
    }

    /// The steps, with the exact action and option for known tiles.
    private var steps: [LocalizedStringKey] {
        var steps: [LocalizedStringKey] = ["tiles.step.open"]
        if let action = recipe.action {
            steps.append("tiles.step.search \(action)")
            if let option = recipe.option { steps.append("tiles.step.option \(option)") }
        } else {
            steps.append("tiles.step.custom")
        }
        steps += ["tiles.step.rename \(name)", "tiles.step.done"]
        return steps
    }
}

/// Every tile Shortcut and whether it is set up (Settings → Tiles setup).
struct TilesListView: View {
    @Environment(TilesModel.self) private var tiles
    @Environment(DesignsModel.self) private var designs
    private let language = RenderContext.preferredLanguage

    var body: some View {
        List {
            Section {
                ForEach(tiles.knownNames(designs: designs.designs, language: language), id: \.self) { name in
                    NavigationLink {
                        TileSetupView(name: name, failed: tiles.status(name) == .failed)
                    } label: {
                        row(name)
                    }
                    .swipeActions {
                        if tiles.status(name) != .notSetUp {
                            Button("tiles.forget", role: .destructive) { tiles.forget(name) }
                        }
                    }
                }
            } footer: {
                Text("tiles.list.footer")
            }
        }
        .navigationTitle("tiles.list.title")
    }

    private func row(_ name: String) -> some View {
        HStack {
            Image(systemName: ShortcutRecipe.forName(name).symbol)
                .frame(width: 28)
                .foregroundStyle(Color.accentColor)
            Text(verbatim: name)
            Spacer()
            switch tiles.status(name) {
            case .ready: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                .accessibilityLabel(Text("tiles.status.ready"))
            case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.orange)
                .accessibilityLabel(Text("tiles.status.failed"))
            case .notSetUp: Text("tiles.status.notSetUp").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
