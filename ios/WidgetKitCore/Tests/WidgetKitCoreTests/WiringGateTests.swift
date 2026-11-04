import Foundation
import Testing
@testable import WidgetKitCore

/// The best eval run's score (ADR-027), kept in `docs/ai-eval/wiring-best.json`.
struct WiringBest: Codable {
    var score: Double
    var model: String
    var prompt: String
    var cases: [String: Double]
}

/// Every push replays the best run's recorded model replies through today's parser and post-pass,
/// with no network: if the wiring score drops below that run, CI fails. The Kotlin test does the same.
struct WiringGateTests {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../docs/ai-eval").standardizedFileURL

    static func best() -> WiringBest? {
        (try? Data(contentsOf: folder.appendingPathComponent("wiring-best.json"))).flatMap { try? JSONDecoder().decode(WiringBest.self, from: $0) }
    }

    @Test func replayedScoreHoldsTheBestRun() throws {
        guard let best = Self.best() else { return }
        struct Case: Decodable {
            let file: String
            let size: String
            let wiring: [String]?
        }
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: Self.folder.appendingPathComponent("cases.json")))
        var scores: [Double] = []
        for item in cases {
            guard let wiring = item.wiring else { continue }
            let name = (item.file as NSString).deletingPathExtension
            guard let reply = try? String(contentsOf: Self.folder.appendingPathComponent("recorded/\(name).json"), encoding: .utf8) else { continue }
            let options = GenerationOptions(size: SizeChoice(rawValue: item.size) ?? .auto)
            let parsed = try AIWidgetParser.parseWidget(reply, options: options, id: "gate", enforceLayout: false)
            let score = WiringScore.score(parsed.spec, expected: wiring)
            #expect(score + 0.0001 >= (best.cases[name] ?? 0), "\(name) dropped to \(score); missing \(wiring.filter { !WiringScore.hits(parsed.spec, expected: [$0]).contains($0) })")
            scores.append(score)
        }
        #expect(!scores.isEmpty, "wiring-best.json exists but no recorded replies do")
        #expect(scores.reduce(0, +) / Double(max(scores.count, 1)) + 0.0001 >= best.score)
    }
}
