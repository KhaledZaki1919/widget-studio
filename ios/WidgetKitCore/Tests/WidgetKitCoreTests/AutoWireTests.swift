import Foundation
import Testing
@testable import WidgetKitCore

/// The post-pass (ADR-027): recognizers, and the shared vectors the Kotlin port runs too.
struct AutoWireTests {
    @Test func recognizers() {
        #expect(AutoWire.TextShape.isClock("08:36") && AutoWire.TextShape.isClock("4:23") && AutoWire.TextShape.isClock("11:02 PM"))
        #expect(!AutoWire.TextShape.isClock("80:36") && !AutoWire.TextShape.isClock("Room 4"))
        #expect(AutoWire.TextShape.isPercent("22 %") && AutoWire.TextShape.isPercent("100%") && !AutoWire.TextShape.isPercent("22"))
        #expect(AutoWire.TextShape.isTemperature("24°") && AutoWire.TextShape.isTemperature("24°C") && AutoWire.TextShape.isTemperature("-3 °"))
        #expect(AutoWire.TextShape.isDuration("8H 32M") && AutoWire.TextShape.isDuration("7h") && AutoWire.TextShape.isDuration("45 min"))
        #expect(AutoWire.TextShape.isStepCount("12,345") && !AutoWire.TextShape.isStepCount("123"))
        #expect(AutoWire.TextShape.dateTemplate("Thursday 22") == "{{date.EEEE}} {{date.d}}")
        #expect(AutoWire.TextShape.dateTemplate("Nov 3, 2026") == "{{date.MMM}} {{date.d}} {{date.yyyy}}")
        #expect(AutoWire.TextShape.dateTemplate("Hello 22") == nil && AutoWire.TextShape.dateTemplate("22") == nil)
    }

    struct Vector: Decodable {
        let name: String
        let spec: WidgetSpec
        let inventory: [String]?
        /// Binding and action ids that must end up in the spec.
        let wired: [String]
        /// Ids that must not appear (wrong guesses).
        let notWired: [String]?
    }

    static let vectors: [Vector] = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/AutoWire/vectors.json")
        guard let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([Vector].self, from: data) else { return [] }
        return decoded
    }()

    @Test func vectorsPass() throws {
        #expect(Self.vectors.count >= 8, "Fixtures/AutoWire/vectors.json did not load")
        for vector in Self.vectors {
            let outcome = AutoWire.apply(vector.spec, inventory: vector.inventory ?? [])
            let ids = WiringScore.ids(in: outcome.spec)
            for id in vector.wired { #expect(ids.contains(id), "\(vector.name): \(id) missing; got \(ids.sorted()); log \(outcome.changes)") }
            for id in vector.notWired ?? [] { #expect(!ids.contains(id), "\(vector.name): \(id) must not be wired; log \(outcome.changes)") }
            let checked = SpecValidator(mode: .ai, checksTextOverlaps: false).validate(outcome.spec)
            if case .failure(let issues) = checked { Issue.record("\(vector.name): \(issues)") }
        }
    }

    /// Running it twice changes nothing: what is wired stays wired.
    @Test func isIdempotent() {
        for vector in Self.vectors {
            let once = AutoWire.apply(vector.spec, inventory: vector.inventory ?? [])
            let twice = AutoWire.apply(once.spec, inventory: vector.inventory ?? [])
            #expect(twice.spec == once.spec, "\(vector.name): \(twice.changes)")
        }
    }

    /// A plain clock design gains no buttons and loses nothing.
    @Test func leavesPlainDesignsAlone() throws {
        let spec = try #require(TemplateLibrary.template(id: "mono.clock.digital"))
        let outcome = AutoWire.apply(spec)
        #expect(outcome.spec.layers.count == spec.layers.count)
    }
}
