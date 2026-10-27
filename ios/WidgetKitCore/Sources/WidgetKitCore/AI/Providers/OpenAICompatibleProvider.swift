import Foundation

/// OpenAI Chat Completions, also used for OpenRouter (same request format).
/// - OpenAI: strict `response_format = {type: "json_schema", json_schema: {name, strict, schema}}`.
/// - OpenRouter: JSON mode (`{type: "json_object"}`) with the schema in the system prompt, since
///   strict schemas depend on which upstream endpoint serves the model (ADR-018).
public struct OpenAICompatibleProvider: AIProvider {
    public let kind: AIProviderKind
    private let apiKey: String
    private let session: URLSession

    public init(kind: AIProviderKind, apiKey: String, session: URLSession = .shared) {
        self.kind = kind == .openrouter ? .openrouter : .openai
        self.apiKey = apiKey
        self.session = session
    }

    var baseURL: String {
        kind == .openrouter ? "https://openrouter.ai/api/v1" : "https://api.openai.com/v1"
    }

    var headers: [String: String] {
        var headers = ["Authorization": "Bearer \(apiKey)"]
        if kind == .openrouter { headers["X-Title"] = "Widget Studio" }
        return headers
    }

    /// Reasoning models take an effort; low keeps image analysis fast. Others reject the field
    /// and are retried once without it (see `complete`).
    static func usesReasoningEffort(_ model: String) -> Bool {
        let id = model.lowercased().replacingOccurrences(of: "openai/", with: "")
        return ["gpt-5", "gpt-6", "o3", "o4"].contains { id.hasPrefix($0) }
    }

    func body(for request: AIRequest, model: String, structured: Bool, reasoning: Bool) -> JSONValue {
        var system = request.system
        if kind == .openrouter && structured {
            system = request.withSchemaInstructions().system
        }
        var userContent: [JSONValue] = [["type": "text", "text": .string(request.userText)]]
        userContent += request.images.map { jpeg in
            ["type": "image_url", "image_url": ["url": .string("data:image/jpeg;base64,\(jpeg.base64EncodedString())")]]
        }
        var body: [String: JSONValue] = [
            "model": .string(model),
            "messages": [
                ["role": "system", "content": .string(system)],
                ["role": "user", "content": .array(userContent)],
            ],
        ]
        // OpenAI renamed the limit for current models; OpenRouter keeps the classic name.
        body[kind == .openai ? "max_completion_tokens" : "max_tokens"] = .int(request.maxOutputTokens)
        if reasoning { body["reasoning_effort"] = "low" }
        if structured {
            if kind == .openrouter {
                body["response_format"] = ["type": "json_object"]
            } else {
                body["response_format"] = [
                    "type": "json_schema",
                    "json_schema": ["name": .string(request.schemaName), "strict": true, "schema": request.schema],
                ]
            }
        } else if kind == .openai {
            // Prompt-only fallback: OpenAI still guarantees a JSON object; OpenRouter models
            // that rejected JSON mode get the plain request.
            body["response_format"] = ["type": "json_object"]
        }
        return .object(body)
    }

    public func complete(_ request: AIRequest, model: String, structured: Bool) async throws -> AIResponse {
        let reasoning = kind == .openai && Self.usesReasoningEffort(model)
        do {
            return try await send(request, model: model, structured: structured, reasoning: reasoning)
        } catch AIError.badRequest(let message) where reasoning && message.lowercased().contains("reasoning") {
            return try await send(request, model: model, structured: structured, reasoning: false)
        }
    }

    private func send(_ request: AIRequest, model: String, structured: Bool, reasoning: Bool) async throws -> AIResponse {
        guard let url = URL(string: "\(baseURL)/chat/completions") else { throw AIError.network }
        let body = body(for: request, model: model, structured: structured, reasoning: reasoning)
        let urlRequest = try AIHTTP.jsonRequest(url: url, headers: headers, body: body)
        let data = try await AIHTTP.send(urlRequest, session: session, retryTransient: true)
        return try Self.parse(data, model: model)
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
                let refusal: String?
            }

            let message: Message
            let finishReason: String?
        }

        struct Usage: Decodable {
            let promptTokens: Int
            let completionTokens: Int
        }

        let choices: [Choice]
        let usage: Usage?
        let model: String?
    }

    static func parse(_ data: Data, model: String) throws -> AIResponse {
        guard let response = try? AIHTTP.snakeCaseDecoder.decode(ChatResponse.self, from: data),
              let choice = response.choices.first else {
            // OpenRouter can return 200 with an error object when the upstream provider fails.
            if let message = AIHTTP.errorMessage(data) { throw AIError.badRequest(message) }
            throw AIError.invalidOutput("unreadable response")
        }
        if let refusal = choice.message.refusal, !refusal.isEmpty { throw AIError.refused }
        if choice.finishReason == "content_filter" { throw AIError.refused }
        if choice.finishReason == "length" { throw AIError.truncated }
        let text = choice.message.content ?? ""
        if text.isEmpty { throw AIError.invalidOutput("empty reply") }
        return AIResponse(
            text: text,
            usage: response.usage.map { AIUsage(inputTokens: $0.promptTokens, outputTokens: $0.completionTokens) },
            model: response.model ?? model
        )
    }

    public func listModels() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/models") else { return [] }
        let data = try await AIHTTP.send(AIHTTP.getRequest(url: url, headers: headers), session: session)
        return Self.parseModels(data, kind: kind)
    }

    static func parseModels(_ data: Data, kind: AIProviderKind) -> [String] {
        struct List: Decodable {
            struct Model: Decodable {
                struct Architecture: Decodable { let inputModalities: [String]? }
                let id: String
                let architecture: Architecture?
            }

            let data: [Model]
        }
        let models = (try? AIHTTP.snakeCaseDecoder.decode(List.self, from: data))?.data ?? []
        if kind == .openrouter {
            // Only models that take images.
            return models.filter { $0.architecture?.inputModalities?.contains("image") ?? false }.map(\.id).sorted()
        }
        // OpenAI also lists embedding, audio and image models; keep the chat families.
        return models.map(\.id).filter { $0.hasPrefix("gpt") || $0.hasPrefix("o") || $0.hasPrefix("chatgpt") }
            .filter { !["audio", "realtime", "image", "tts", "transcribe", "search"].contains(where: $0.contains) }
            .sorted()
    }
}
