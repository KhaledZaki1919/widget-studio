import Foundation
@testable import WidgetKitCore

/// A recorded provider response from `Fixtures/AI`.
func aiFixture(_ name: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/AI") else {
        throw AIValidationError("missing fixture \(name)")
    }
    return try Data(contentsOf: url)
}

/// Answers URL requests from memory (no network in tests). Each session gets its own id in a
/// header, so tests running in parallel never see each other's stubs.
final class StubURLProtocol: URLProtocol {
    enum Reply {
        case http(status: Int, body: Data)
        case failure(URLError.Code)
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies: [String: [Reply]] = [:]
    nonisolated(unsafe) private static var seen: [String: [URLRequest]] = [:]
    /// Used when the session header doesn't reach the protocol; suites using stubs are serialized.
    nonisolated(unsafe) private static var latest = ""

    /// A session whose requests get `replies` in order (the last one repeats).
    static func session(_ replies: [Reply]) -> (URLSession, String) {
        let id = UUID().uuidString
        lock.withLock {
            self.replies[id] = replies
            latest = id
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Stub-ID": id]
        return (URLSession(configuration: configuration), id)
    }

    static func requests(_ id: String) -> [URLRequest] {
        lock.withLock { seen[id] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let header = request.value(forHTTPHeaderField: "X-Stub-ID")
        let reply: Reply? = Self.lock.withLock {
            let id = header ?? Self.latest
            Self.seen[id, default: []].append(request)
            guard var queue = Self.replies[id], let first = queue.first else { return nil }
            if queue.count > 1 { queue.removeFirst() }
            Self.replies[id] = queue
            return first
        }
        switch reply {
        case .http(let status, let body)?:
            let url = request.url ?? URL(fileURLWithPath: "/")
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)
            if let response { client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code)?:
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        }
    }

    override func stopLoading() {}
}

/// Replies from a script, recording every request (StructuredAI and generator tests).
final class ScriptedProvider: AIProvider, @unchecked Sendable {
    let kind: AIProviderKind
    private let lock = NSLock()
    private var script: [Result<String, AIError>]
    private(set) var requests: [(request: AIRequest, structured: Bool)] = []

    init(kind: AIProviderKind = .anthropic, _ script: [Result<String, AIError>]) {
        self.kind = kind
        self.script = script
    }

    var calls: Int { lock.withLock { requests.count } }

    func complete(_ request: AIRequest, model: String, structured: Bool) async throws -> AIResponse {
        let next: Result<String, AIError> = lock.withLock {
            requests.append((request, structured))
            return script.count > 1 ? script.removeFirst() : (script.first ?? .failure(.network))
        }
        switch next {
        case .success(let text): return AIResponse(text: text, usage: nil, model: model)
        case .failure(let error): throw error
        }
    }

    func listModels() async throws -> [String] { [] }
}

/// Keys in memory instead of the Keychain.
final class MemoryKeyStorage: AIKeyStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func readKey(account: String) -> String? { lock.withLock { values[account] } }
    func writeKey(_ value: String, account: String) throws { lock.withLock { values[account] = value } }
    func removeKey(account: String) { lock.withLock { values[account] = nil } }
}

/// A private UserDefaults suite per test.
func testDefaults() -> UserDefaults {
    let name = "WidgetKitCoreTests-\(UUID().uuidString)"
    return UserDefaults(suiteName: name) ?? .standard
}

extension JSONValue {
    /// Decodes a request body that the providers built.
    static func parse(_ data: Data?) -> JSONValue? {
        data.flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }
    }
}
