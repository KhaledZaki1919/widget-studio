import SwiftUI
import WidgetKitCore

/// Saved designs (brief §7.4): preview, rename, duplicate, edit again, delete. Without an App
/// Group the home screen can't show them yet (ADR-014), which the banner explains.
struct MyWidgetsView: View {
    @Environment(DesignsModel.self) private var designs
    @State private var editing: SavedDesign?
    @State private var renaming: SavedDesign?
    @State private var newName = ""
    @State private var deleting: SavedDesign?
    private let language = RenderContext.preferredLanguage

    var body: some View {
        List {
            if !designs.isShared {
                Section {
                    Label("mywidgets.storeMode", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ax.mywidgets.storeMode")
                }
            }
            if designs.designs.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("mywidgets.empty.title").font(.headline)
                        Text("mywidgets.empty.body").font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("ax.mywidgets.empty")
                }
            }
            ForEach(designs.designs) { design in
                row(design)
            }
        }
        .accessibilityIdentifier("ax.mywidgets.list")
        .navigationTitle("mywidgets.title")
        .onAppear { designs.reload() }
        .sheet(item: $editing) { design in
            EditorView(design: design, isNew: false)
        }
        .alert("mywidgets.rename.title", isPresented: renameBinding) {
            TextField("mywidgets.rename.placeholder", text: $newName)
                .accessibilityIdentifier("ax.mywidgets.rename.field")
            Button("common.cancel", role: .cancel) {}
            Button("common.save") {
                if let renaming { designs.rename(renaming, to: newName) }
            }
            .accessibilityIdentifier("ax.mywidgets.rename.save")
        }
        .confirmationDialog("mywidgets.delete.title", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("mywidgets.delete.confirm", role: .destructive) {
                if let deleting { designs.delete(deleting) }
            }
            .accessibilityIdentifier("ax.mywidgets.delete.confirm")
        }
    }

    private func row(_ design: SavedDesign) -> some View {
        Button {
            editing = design
        } label: {
            HStack(spacing: 14) {
                DesignPreview(design: design, image: designs.image(for: design), language: language)
                    .frame(width: design.spec.family == .small ? 76 : 150)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: design.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(verbatim: subtitle(design))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: design.name))
        .accessibilityIdentifier("ax.mywidgets.design")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleting = design } label: { Label("mywidgets.delete", systemImage: "trash") }
            Button { startRename(design) } label: { Label("mywidgets.rename", systemImage: "pencil") }
                .tint(.orange)
        }
        .contextMenu {
            Button { editing = design } label: { Label("mywidgets.edit", systemImage: "slider.horizontal.3") }
            Button { startRename(design) } label: { Label("mywidgets.rename", systemImage: "pencil") }
            Button { designs.duplicate(design, name: copyName(design)) } label: {
                Label("mywidgets.duplicate", systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) { deleting = design } label: { Label("mywidgets.delete", systemImage: "trash") }
        }
    }

    /// "Weather · Medium".
    private func subtitle(_ design: SavedDesign) -> String {
        let size = switch design.spec.family {
        case .small: language == "ar" ? "صغير" : "Small"
        case .medium: language == "ar" ? "متوسط" : "Medium"
        case .large: language == "ar" ? "كبير" : "Large"
        }
        return [design.spec.category?.title.resolved(language: language), size].compactMap { $0 }.joined(separator: " · ")
    }

    private func copyName(_ design: SavedDesign) -> String {
        language == "ar" ? "\(design.name) (نسخة)" : "\(design.name) (copy)"
    }

    private func startRename(_ design: SavedDesign) {
        newName = design.name
        renaming = design
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }
}
