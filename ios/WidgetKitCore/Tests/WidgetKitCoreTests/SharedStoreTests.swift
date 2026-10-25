import CoreGraphics
import Foundation
import Testing
@testable import WidgetKitCore

private func tempLocation(shared: Bool) throws -> StoreLocation {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("SharedStoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return StoreLocation(directory: url, appGroupID: shared ? "group.com.khaled.widgetstudio" : nil, source: shared ? .compiled : nil)
}

private func template(_ id: String = "mono.weather.forecast") throws -> WidgetSpec {
    try TemplateLibrary.load(id: id).get()
}

/// A 4×4 red test image.
private func redImage() -> CGImage? {
    let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    context?.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context?.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    return context?.makeImage()
}

/// ADR-015: the same store works with and without an App Group.
struct SharedStoreTests {
    @Test(arguments: [true, false])
    func savesListsAndReloadsDesigns(shared: Bool) throws {
        let store = SharedStore(location: try tempLocation(shared: shared))
        #expect(store.isShared == shared)
        #expect(store.designs().isEmpty)

        var design = SavedDesign.new(from: try template(), language: "en", now: Date(timeIntervalSince1970: 100))
        design.fieldValues["city"] = .localized(en: "Alexandria", ar: "الإسكندرية")
        design.theme = .light
        design.colors["accent"] = "#0A84FF"
        try store.save(design, now: Date(timeIntervalSince1970: 200))

        let reopened = SharedStore(location: store.location)
        let loaded = try #require(reopened.design(id: design.id))
        #expect(loaded.name == "Forecast")
        #expect(loaded.fieldValues["city"] == .localized(en: "Alexandria", ar: "الإسكندرية"))
        #expect(loaded.theme == .light)
        #expect(loaded.colors == ["accent": "#0A84FF"])
        #expect(loaded.spec == design.spec)
        #expect(loaded.updated == Date(timeIntervalSince1970: 200))
    }

    @Test func newestFirstAndReplaceByID() throws {
        let store = SharedStore(location: try tempLocation(shared: false))
        let first = try store.save(SavedDesign.new(from: try template(), language: "en"), now: Date(timeIntervalSince1970: 1))
        let second = try store.save(SavedDesign.new(from: try template("mono.clock.analog"), language: "en"),
                                    now: Date(timeIntervalSince1970: 2))
        #expect(store.designs().map(\.id) == [second.id, first.id])
        var edited = first
        edited.name = "Edited"
        try store.save(edited, now: Date(timeIntervalSince1970: 3))
        #expect(store.designs().map(\.id) == [first.id, second.id])
        #expect(store.designs().count == 2)
        #expect(store.design(id: first.id)?.name == "Edited")
    }

    @Test func renameDuplicateDelete() throws {
        let store = SharedStore(location: try tempLocation(shared: true))
        var design = SavedDesign.new(from: try template("mono.photo.square"), language: "ar")
        let image = try #require(redImage())
        design.imageFile = try store.storeImage(image, designID: design.id, lossless: false)
        try store.save(design)

        try store.rename(id: design.id, to: "صورتي")
        #expect(store.design(id: design.id)?.name == "صورتي")

        let copy = try #require(try store.duplicate(id: design.id, name: "نسخة"))
        #expect(copy.id != design.id)
        #expect(copy.imageFile != nil && copy.imageFile != design.imageFile)
        #expect(store.image(named: copy.imageFile ?? "") != nil)
        #expect(store.designs().count == 2)

        try store.delete(id: design.id)
        #expect(store.designs().map(\.id) == [copy.id])
        #expect(store.image(named: design.imageFile ?? "") == nil)
        #expect(store.image(named: copy.imageFile ?? "") != nil)
    }

    @Test func imagesRoundTripInBothFormats() throws {
        let store = SharedStore(location: try tempLocation(shared: false))
        let image = try #require(redImage())
        for lossless in [true, false] {
            let file = try store.storeImage(image, designID: "d", lossless: lossless)
            #expect(file.hasSuffix(lossless ? ".png" : ".jpg"))
            let loaded = try #require(store.image(named: file))
            #expect(loaded.width == 4 && loaded.height == 4)
        }
    }

    @Test func removesUnusedImages() throws {
        let store = SharedStore(location: try tempLocation(shared: false))
        let image = try #require(redImage())
        var design = SavedDesign.new(from: try template("mono.photo.square"), language: "en")
        design.imageFile = try store.storeImage(image, designID: design.id, lossless: false)
        try store.save(design)
        let orphan = try store.storeImage(image, designID: design.id, lossless: false)
        store.removeUnusedImages()
        #expect(store.image(named: orphan) == nil)
        #expect(store.image(named: design.imageFile ?? "") != nil)
    }

    @Test func corruptFileReadsAsEmpty() throws {
        let store = SharedStore(location: try tempLocation(shared: false))
        try FileManager.default.createDirectory(at: store.folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.designsURL)
        #expect(store.designs().isEmpty)
    }

    @Test func fittingSizesFilterDesigns() throws {
        let store = SharedStore(location: try tempLocation(shared: true))
        try store.save(SavedDesign.new(from: try template("mono.clock.analog"), language: "en"))
        try store.save(SavedDesign.new(from: try template("mono.weather.forecast"), language: "en"))
        #expect(store.designs(fitting: .small).map(\.templateID) == ["mono.clock.analog"])
        #expect(store.designs(fitting: .medium).count == 2)
    }

    @Test func designContextCarriesEdits() throws {
        var design = SavedDesign.new(from: try template(), language: "en")
        design.fieldValues["city"] = "Aswan"
        design.colors["accent"] = "#00FF00"
        design.theme = .light
        let context = design.renderContext(language: "en", data: .sample())
        #expect(context.theme == .light)
        #expect(context.tokenOverrides["accent"] == "#00FF00")
        #expect(BindingResolver(spec: design.spec, context: context).render("{{field.city}}") == "Aswan")
        let resolved = design.spec.resolvingTokens(theme: context.theme, overrides: context.tokenOverrides)
        let json = String(decoding: try JSONEncoder().encode(resolved), as: UTF8.self)
        #expect(json.contains("#FFFFFF"))  // light @bg
    }
}
