import Foundation

/// The AI providers a user can bring a key for (brief D4, ADR-008). Ported from Lakhas.
public enum AIProviderKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case gemini, anthropic, openai, openrouter

    public var id: String { rawValue }

    /// Product names stay in Latin script in both languages.
    public var displayName: String {
        switch self {
        case .gemini: "Google Gemini"
        case .anthropic: "Anthropic Claude"
        case .openai: "OpenAI"
        case .openrouter: "OpenRouter"
        }
    }

    /// Where the user creates an API key.
    public var keyPageURL: URL? {
        switch self {
        case .gemini: URL(string: "https://aistudio.google.com/apikey")
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")
        case .openai: URL(string: "https://platform.openai.com/api-keys")
        case .openrouter: URL(string: "https://openrouter.ai/keys")
        }
    }

    /// Fast, low-cost vision model used by default. IDs checked in each provider's model docs
    /// on 2026-10-26 (ADR-018): Gemini 3.8 Flash is stable and free of charge on the free tier.
    public var recommendedModel: String {
        switch self {
        case .gemini: "gemini-3.8-flash"
        case .anthropic: "claude-haiku-5-5"
        case .openai: "gpt-6-luna"
        case .openrouter: "google/gemini-3.8-flash"
        }
    }

    /// Suggested when the default model is rate limited (free Gemini keys).
    public var alternativeModel: String {
        switch self {
        case .gemini: "gemini-3.5-flash-lite"
        case .anthropic: "claude-sonnet-5-5"
        case .openai: "gpt-6.1-sol"
        case .openrouter: "anthropic/claude-haiku-5.5"
        }
    }

    /// Shown before a key is set; the provider's live list replaces it afterwards.
    public var builtInModels: [String] {
        switch self {
        case .gemini: ["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-3.6-flash"]
        case .anthropic: ["claude-haiku-5-5", "claude-sonnet-5-5"]
        case .openai: ["gpt-6-luna", "gpt-6.1-sol"]
        case .openrouter: ["google/gemini-3.8-flash", "anthropic/claude-haiku-5.5", "openai/gpt-6-luna"]
        }
    }

    public func makeProvider(apiKey: String, session: URLSession = .shared) -> AIProvider {
        switch self {
        case .gemini: GeminiProvider(apiKey: apiKey, session: session)
        case .anthropic: AnthropicProvider(apiKey: apiKey, session: session)
        case .openai, .openrouter: OpenAICompatibleProvider(kind: self, apiKey: apiKey, session: session)
        }
    }
}

/// What an AI request is for (diagnostics).
public enum AIFeature: String, Codable, Sendable, CaseIterable {
    case generateWidget, connectionTest
}

public struct AIRequest: Sendable, Equatable {
    public var system: String
    public var userText: String
    /// JPEG images, already downscaled with metadata stripped.
    public var images: [Data]
    /// JSON Schema of the expected answer.
    public var schema: JSONValue
    public var schemaName: String
    public var maxOutputTokens: Int

    public init(system: String, userText: String, images: [Data] = [], schema: JSONValue,
                schemaName: String = "result", maxOutputTokens: Int = 2048) {
        self.system = system
        self.userText = userText
        self.images = images
        self.schema = schema
        self.schemaName = schemaName
        self.maxOutputTokens = maxOutputTokens
    }

    /// For providers without native structured output, or after a provider rejected it.
    public func withSchemaInstructions() -> AIRequest {
        var copy = self
        copy.system += "\n\nReply with only one JSON object, no prose and no code fences. It must match this JSON Schema:\n"
            + schema.jsonString()
        return copy
    }

    /// The one retry after an invalid answer.
    public func withRetryNote(_ problem: String) -> AIRequest {
        var copy = self
        copy.userText += "\n\n<validation_error>Your previous reply was not valid: \(problem). "
            + "Reply again with only the corrected JSON object.</validation_error>"
        return copy
    }
}

public struct AIUsage: Sendable, Equatable, Codable {
    public let inputTokens: Int
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public struct AIResponse: Sendable, Equatable {
    public let text: String
    public let usage: AIUsage?
    public let model: String

    public init(text: String, usage: AIUsage?, model: String) {
        self.text = text
        self.usage = usage
        self.model = model
    }
}

public enum AIError: Error, Equatable, Sendable {
    case noKey
    case invalidKey
    case insufficientCredit
    case rateLimited
    case modelNotFound
    /// The provider declined the request or flagged the image (brief §8).
    case refused
    case truncated
    /// Still invalid after the one retry; the text says what was wrong.
    case invalidOutput(String)
    case network
    case providerUnavailable
    case badRequest(String)
    /// No answer before the app's hard deadline (`AIDeadline`) or the request timed out.
    case timedOut
    /// The user cancelled.
    case cancelled
}

/// One provider implementation (plain URLSession, no SDKs).
public protocol AIProvider: Sendable {
    var kind: AIProviderKind { get }
    /// `structured`: ask the provider to enforce `request.schema` natively.
    func complete(_ request: AIRequest, model: String, structured: Bool) async throws -> AIResponse
    func listModels() async throws -> [String]
}
