import SwiftUI
import WidgetKitCore

/// M1 gallery: every bundled test spec rendered by the same `SpecView` the widget uses, in
/// Arabic or English, at widget proportions. Invalid specs show their validation issues.
struct TestSpecsView: View {
    @State private var language = RenderContext.preferredLanguage
    private let entries = TestSpecs.load()

    var body: some View {
        List {
            Section {
                Picker("specs.language", selection: $language) {
                    Text(verbatim: "العربية").tag("ar")
                    Text(verbatim: "English").tag("en")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("ax.specs.language")
            } footer: {
                Text("specs.footer")
            }
            ForEach(entries, id: \.fileName) { entry in
                Section {
                    switch entry.result {
                    case .success(let spec):
                        SpecPreview(spec: spec, language: language)
                            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                            .listRowBackground(Color.clear)
                    case .failure(let failure):
                        Label("specs.invalid", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(verbatim: failure.description)
                            .font(.footnote.monospaced())
                    }
                } header: {
                    Text(verbatim: header(entry))
                }
            }
        }
        .accessibilityIdentifier("ax.specs.list")
        .navigationTitle("specs.title")
        .environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight)
    }

    private func header(_ entry: TestSpecs.Entry) -> String {
        guard let spec = entry.spec else { return entry.fileName }
        return "\(spec.name.resolved(language: language)) · \(spec.family.rawValue)"
    }
}

/// One spec at widget proportions, ticking every minute like the widget.
struct SpecPreview: View {
    let spec: WidgetSpec
    let language: String

    var body: some View {
        let canvas = spec.family.canvas
        TimelineView(.everyMinute) { timeline in
            SpecView(spec: spec, context: RenderContext(
                date: timeline.date, language: language, data: .sample(now: timeline.date)
            ))
        }
        .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
        .frame(maxWidth: spec.family == .small ? 200 : .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("ax.specs.preview.\(spec.id)")
    }
}
