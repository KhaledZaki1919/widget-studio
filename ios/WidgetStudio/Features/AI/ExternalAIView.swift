import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WidgetKitCore

/// "Use another AI" (ADR-023), inside Create from image: copy self-contained instructions for
/// ChatGPT, Claude or Gemini on the web, then import the JSON they return (paste, a .json file,
/// or a file shared to the app). The import runs the app's own checks and layout fix, and the
/// result opens in the editor. Nothing here calls an AI or runs code.
struct ExternalAIView: View {
    /// Text that arrived from the share sheet (a .json file opened in the app).
    let initialText: String?
    let onImported: (SavedDesign, LayoutRepair) -> Void

    @State private var size = SizeChoice.auto
    @State private var copied = false
    @State private var pasted = ""
    @State private var error: ExternalAI.ImportError?
    @State private var fixCopied = false
    @State private var picksFile = false
    @State private var fileUnreadable = false
    private let language = RenderContext.preferredLanguage

    var body: some View {
        Form {
            Section {
                Picker("create.size", selection: $size) {
                    Text("create.size.auto").tag(SizeChoice.auto)
                    Text("detail.size.small").tag(SizeChoice.small)
                    Text("detail.size.medium").tag(SizeChoice.medium)
                    Text("detail.size.large").tag(SizeChoice.large)
                }
                .pickerStyle(.segmented)
                Button {
                    UIPasteboard.general.string = ExternalAI.instructions(options: GenerationOptions(size: size))
                    copied = true
                } label: {
                    Label(copied ? LocalizedStringKey("create.external.copied") : "create.external.copy",
                          systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .accessibilityIdentifier("ax.create.external.copy")
            } header: {
                Text("create.external.step1")
            } footer: {
                Text("create.external.step1.footer")
            }

            Section {
                Button {
                    importText(UIPasteboard.general.string ?? "")
                } label: {
                    Label("create.external.paste", systemImage: "doc.on.clipboard")
                }
                .accessibilityIdentifier("ax.create.external.paste")
                Button {
                    picksFile = true
                } label: {
                    Label("create.external.file", systemImage: "folder")
                }
                .accessibilityIdentifier("ax.create.external.file")
                TextField("create.external.field", text: $pasted, axis: .vertical)
                    .lineLimit(3...8)
                    .font(.footnote.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityIdentifier("ax.create.external.field")
                if !pasted.isEmpty {
                    Button("create.external.import") { importText(pasted) }
                        .accessibilityIdentifier("ax.create.external.import")
                }
            } header: {
                Text("create.external.step2")
            } footer: {
                Text("create.external.step2.footer")
            }

            if let error {
                errorSection(error)
            }
            if fileUnreadable {
                Section {
                    Label("create.external.error.file", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("create.external.title")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $picksFile, allowedContentTypes: [.json, .plainText]) { result in
            guard case .success(let url) = result, let text = Self.read(url) else {
                fileUnreadable = true
                return
            }
            importText(text)
        }
        .onAppear {
            if let initialText { importText(initialText) }
        }
    }

    private func errorSection(_ error: ExternalAI.ImportError) -> some View {
        Section {
            Label(Self.message(error), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            if case .invalid(let problems) = error {
                Text(verbatim: problems)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .environment(\.layoutDirection, .leftToRight)
                    .textSelection(.enabled)
            }
            Button {
                UIPasteboard.general.string = ExternalAI.fixRequest(for: error)
                fixCopied = true
            } label: {
                Label(fixCopied ? LocalizedStringKey("create.external.fixCopied") : "create.external.copyFix",
                      systemImage: fixCopied ? "checkmark.circle.fill" : "arrow.uturn.left.circle")
            }
            .accessibilityIdentifier("ax.create.external.copyFix")
        } header: {
            Text("create.external.error.title")
        } footer: {
            Text("create.external.error.footer")
        }
        .accessibilityIdentifier("ax.create.external.error")
    }

    private func importText(_ text: String) {
        fileUnreadable = false
        fixCopied = false
        do {
            let widget = try ExternalAI.importWidget(text, size: size)
            error = nil
            onImported(widget.design(language: language), widget.layout)
        } catch let importError as ExternalAI.ImportError {
            error = importError
        } catch {
            self.error = .noJSON
        }
    }

    static func message(_ error: ExternalAI.ImportError) -> LocalizedStringKey {
        switch error {
        case .empty: "create.external.error.empty"
        case .tooLarge: "create.external.error.tooLarge"
        case .noJSON: "create.external.error.noJSON"
        case .invalid: "create.external.error.invalid"
        }
    }

    /// A picked or shared file's text, at most `ExternalAI.maxImportBytes` (+ a little).
    static func read(_ url: URL) -> String? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: ExternalAI.maxImportBytes + 1) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
