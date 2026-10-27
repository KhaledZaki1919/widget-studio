import Foundation

/// Anthropic Messages API, called directly with the user's key.
/// Structured output goes through a tool: the schema is the input schema of one `strict` tool
/// the model is told to call, and its `input` is the answer (ADR-018). `tool_choice` stays
/// `auto`, because forcing a tool returns 400 on current models with thinking (Claude Opus 5.5,
/// Sonnet 5.5, Fable 5.1). A reply that answers in text instead is still read as JSON.
public struct AnthropicProvider: AIProvider {
    public let kind = AIProviderKind.anthropic
    private let apiKey: String
    private let session: URLSession
    static let baseURL = "https://api.anthropic.com/v1"

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    var headers: [String: String] {
        ["x-api-key": apiKey, "anthropic-version": "2023-06-01"]
    }

    /// Effort control exists on the Claude 4.6+ generation; older models reject it.
    static func supportsEffort(_ model: String) -> Bool {
        ["claude-haiku-5", "claude-sonnet-5", "claude-opus-5", "claude-fable-5",
         "claude-opus-4-6", "claude-opus-4-7", "claude-opus-4-8", "claude-sonnet-4-6"].contains { model.hasPrefix($0) }
    }

    static func toolName(_ request: AIRequest) -> String { request.schemaName }

    func body(for request: AIRequest, model: String, structured: Bool) -> JSONValue {
        var content: [JSONValue] = request.images.map { jpeg in
            ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": .string(jpeg.base64EncodedString())]]
        }
        var userText = request.userText
        if structured {
            userText += "\n\nAnswer by calling the tool \"\(Self.toolName(request))\" exactly once. Write no other text."
        }
        content.append(["type": "text", "text": .string(userText)])

        var body: [String: JSONValue] = [
            "model": .string(model),
            "max_tokens": .int(request.maxOutputTokens),
            // The long, static system prompt is marked cacheable (prompt caching).
            "system": [["type": "text", "text": .string(request.system), "cache_control": ["type": "ephemeral"]]],
            "messages": [["role": "user", "content": .array(content)]],
        ]
        if structured {
            body["tools"] = [[
                "name": .string(Self.toolName(request)),
                "description": "Returns the result as structured data.",
                "input_schema": request.schema,
                "strict": true,
            ]]
            body["tool_choice"] = ["type": "auto"]
        }
        if Self.supportsEffort(model) { body["output_config"] = ["effort": "low"] }
        return .object(body)
    }

    public func complete(_ request: AIRequest, model: String, structured: Bool) async throws -> AIResponse {
        guard let url = URL(string: "\(Self.baseURL)/messages") else { throw AIError.network }
        let urlRequest = try AIHTTP.jsonRequest(url: url, headers: headers, body: body(for: request, model: model, structured: structured))
        let data = try await AIHTTP.send(urlRequest, session: session, retryTransient: true)
        return try Self.parse(data, model: model)
    }

    struct MessagesResponse: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
            let name: String?
            let input: JSONValue?
        }

        struct Usage: Decodable {
            let inputTokens: Int
            let outputTokens: Int
            let cacheReadInputTokens: Int?
            let cacheCreationInputTokens: Int?
        }

        let content: [Block]
        let usage: Usage?
        let stopReason: String?
        let model: String?
    }

    /// The tool call's input (as JSON text) when there is one, else the text blocks.
    static func parse(_ data: Data, model: String) throws -> AIResponse {
        guard let response = try? AIHTTP.snakeCaseDecoder.decode(MessagesResponse.self, from: data) else {
            throw AIError.invalidOutput("unreadable response")
        }
        if response.stopReason == "refusal" { throw AIError.refused }
        if response.stopReason == "max_tokens" { throw AIError.truncated }
        let text: String
        if let input = response.content.first(where: { $0.type == "tool_use" })?.input {
            text = input.jsonString()
        } else {
            text = response.content.filter { $0.type == "text" }.compactMap(\.text).joined()
        }
        if text.isEmpty { throw AIError.invalidOutput("empty reply") }
        return AIResponse(
            text: text,
            usage: response.usage.map {
                AIUsage(inputTokens: $0.inputTokens + ($0.cacheReadInputTokens ?? 0) + ($0.cacheCreationInputTokens ?? 0),
                        outputTokens: $0.outputTokens)
            },
            model: response.model ?? model
        )
    }

    public func listModels() async throws -> [String] {
        guard let url = URL(string: "\(Self.baseURL)/models?limit=100") else { return [] }
        let data = try await AIHTTP.send(AIHTTP.getRequest(url: url, headers: headers), session: session)
        struct List: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }
        return (try? JSONDecoder().decode(List.self, from: data))?.data.map(\.id) ?? []
    }
}
