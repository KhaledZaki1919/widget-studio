import Foundation
import Testing
@testable import WidgetKitCore

/// Developer mode's "My widget" picker (M6 item 10): saved designs from SharedStore, then
/// templates, searchable; never an automatic choice.
struct WidgetPickerTests {
    func store() throws -> SharedStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WidgetPickerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return SharedStore(location: StoreLocation(directory: url, appGroupID: "group.com.khaled.widgetstudio", source: .compiled))
    }

    /// One customized template and one AI-made design, both small.
    func filled() throws -> (SharedStore, SavedDesign, SavedDesign) {
        let store = try store()
        let clock = try store.save(SavedDesign(name: "My clock", template: TemplateLibrary.load(id: "mono.clock.digital").get()))
        let reply = String(decoding: try aiFixture("spec-recreate"), as: UTF8.self)
        let generated = try AIWidgetParser.parse(reply, options: GenerationOptions(), id: "gen.test1234")
        let ai = try store.save(GeneratedWidget(spec: generated.spec, colors: generated.colors, model: "m", attempts: 1).design(language: "en"))
        return (store, clock, ai)
    }

    @Test func listsSavedDesignsFromSharedStoreFirst() throws {
        let (store, clock, ai) = try filled()
        let items = WidgetPicker.items(size: .small, store: store)
        let designs = items.filter(\.isDesign)
        #expect(Set(designs.map(\.id)) == ["design:\(clock.id)", "design:\(ai.id)"])
        #expect(items.prefix(2).allSatisfy(\.isDesign))
        #expect(items.contains { $0.id == "template:mono.clock.digital" && !$0.isDesign })
        // Medium widgets list the small designs too (they fit), large templates never fit small ones.
        #expect(WidgetPicker.items(size: .medium, store: store).filter(\.isDesign).count == 2)
        #expect(!items.contains { $0.family == .large })
    }

    @Test func searchMatchesBothLanguagesAndCategories() throws {
        let (store, clock, _) = try filled()
        let items = WidgetPicker.items(size: .small, store: store)
        #expect(WidgetPicker.search("my clock", in: items).map(\.id) == ["design:\(clock.id)"])
        #expect(WidgetPicker.search("ساعة", in: items).contains { $0.id == "template:mono.clock.digital" })
        #expect(WidgetPicker.search("  ", in: items).count == items.count)
    }

    @Test func nothingIsChosenAutomatically() throws {
        let (store, clock, _) = try filled()
        #expect(WidgetPicker.resolve(itemID: nil, store: store) == .none)
        #expect(WidgetPicker.resolve(itemID: "design:\(clock.id)", store: store) == .design(clock))
        #expect(WidgetPicker.resolve(itemID: "design:deleted", store: store) == .missingDesign)
        if case .template(let spec) = WidgetPicker.resolve(itemID: "template:mono.clock.digital", store: store) {
            #expect(spec.id == "mono.clock.digital")
        } else {
            Issue.record("template not resolved")
        }
    }
}
