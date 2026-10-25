import SwiftUI
import WidgetKitCore

/// The template library (brief §7.2): category chips and a grid of live previews. Small
/// templates sit two per row, medium ones span the width. Tap → `TemplateDetailView`.
struct LibraryView: View {
    /// Long-pressing the version opens Diagnostics (brief §7.7).
    var onLongPressVersion: () -> Void = {}
    @State private var category: SpecCategory?
    private let templates = TemplateLibrary.all()
    private let language = RenderContext.preferredLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                chips
                ForEach(visibleCategories, id: \.self) { category in
                    section(category)
                }
                Text(verbatim: "Widget Studio \(AppInfo.versionText)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .contentShape(Rectangle())
                    .onLongPressGesture(perform: onLongPressVersion)
                    .accessibilityIdentifier("ax.home.version")
            }
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("ax.library.list")
    }

    private var visibleCategories: [SpecCategory] {
        category.map { [$0] } ?? SpecCategory.allCases.filter { !TemplateLibrary.templates(in: $0).isEmpty }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: Text("library.all"), selected: category == nil, id: "all") { category = nil }
                ForEach(SpecCategory.allCases, id: \.self) { item in
                    chip(title: Text(verbatim: item.title.resolved(language: language)), selected: category == item,
                         id: item.rawValue) { category = item }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(title: Text, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            title
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color(uiColor: .systemBackground) : .primary)
                .background(Capsule().fill(selected ? Color.primary : Color(uiColor: .secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ax.library.chip.\(id)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func section(_ category: SpecCategory) -> some View {
        let items = templates.filter { $0.category == category }
        let small = items.filter { $0.family == .small }
        let wide = items.filter { $0.family != .small }
        return VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: category.title.resolved(language: language))
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 16)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
                ForEach(small, id: \.id) { cell($0) }
            }
            .padding(.horizontal, 16)
            ForEach(wide, id: \.id) { cell($0).padding(.horizontal, 16) }
        }
    }

    private func cell(_ spec: WidgetSpec) -> some View {
        NavigationLink {
            TemplateDetailView(spec: spec)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                SpecPreview(spec: spec, language: language)
                Text(verbatim: spec.name.resolved(language: language))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ax.library.template.\(spec.id)")
    }
}
