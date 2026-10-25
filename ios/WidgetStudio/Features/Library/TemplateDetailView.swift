import SwiftUI
import WidgetKitCore

/// One template (brief §7.3): a live preview in every size it supports, light or dark, the
/// fields the editor will offer (M3), and how to add it to the home screen.
struct TemplateDetailView: View {
    let spec: WidgetSpec
    @State private var theme: SpecTheme
    private let language = RenderContext.preferredLanguage

    init(spec: WidgetSpec) {
        self.spec = spec
        _theme = State(initialValue: spec.theme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("detail.appearance", selection: $theme) {
                    Text("detail.light").tag(SpecTheme.light)
                    Text("detail.dark").tag(SpecTheme.dark)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("ax.detail.theme")

                ForEach(spec.family.supportedFamilies, id: \.self) { family in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Self.sizeName(family))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        SpecPreview(spec: spec, language: language, family: family, theme: theme)
                            .frame(maxWidth: family == .small ? 180 : .infinity)
                            .id("\(family.rawValue).\(theme.rawValue)")
                            .accessibilityIdentifier("ax.detail.preview.\(family.rawValue)")
                    }
                }

                if !spec.fields.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("detail.fields")
                            .font(.subheadline.weight(.semibold))
                        Text(verbatim: spec.fields.map { $0.label.resolved(language: language) }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("detail.fields.footer")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("detail.howTo.title")
                        .font(.subheadline.weight(.semibold))
                    Text("detail.howTo.body")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("detail.sampleData")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .navigationTitle(Text(verbatim: spec.name.resolved(language: language)))
        .navigationBarTitleDisplayMode(.inline)
    }

    static func sizeName(_ family: SpecFamily) -> LocalizedStringKey {
        switch family {
        case .small: "detail.size.small"
        case .medium: "detail.size.medium"
        case .large: "detail.size.large"
        }
    }
}
