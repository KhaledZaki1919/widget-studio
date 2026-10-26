import Foundation

/// Canned widget specs for UI tests (`-uiTestingStubAI`): no network, no key. Never used otherwise.
public struct UITestingAIProvider: AIProvider {
    public let kind = AIProviderKind.gemini

    public init() {}

    public static let widgetName = "Stub Clock"

    public func complete(_ request: AIRequest, model: String, structured: Bool) async throws -> AIResponse {
        // A short pause so the generating state is visible.
        try await Task.sleep(nanoseconds: 300_000_000)
        let photo = request.userText.contains("\"source\": \"user_image\"")
        return AIResponse(text: photo ? Self.photoSpec : Self.recreateSpec, usage: AIUsage(inputTokens: 1500, outputTokens: 600),
                          model: "stub-model")
    }

    public func listModels() async throws -> [String] { ["stub-model"] }

    static let recreateSpec = """
    {"name":{"en":"\(widgetName)","ar":"ساعة تجريبية"},"family":"small","theme":"dark",\
    "palette":{"bg":"#101418","fg":"#F5F5F5","accent":"#FF5A36"},\
    "background":{"type":"solid","color":"@bg","colors":null,"angle":null,"outerColor":null},"fields":[],\
    "layers":[{"type":"text","value":{"en":"{{time.hh}}:{{time.mm}}","ar":"{{time.hh}}:{{time.mm}}"},\
    "font":{"family":"dot","size":44,"weight":"black"},"color":"@fg","align":"center","maxLines":1,"live":null,\
    "frame":{"x":12,"y":56,"w":146,"h":58},"opacity":null,"mirror":null},\
    {"type":"text","value":{"en":"{{date.EEEE}}","ar":"{{date.EEEE}}"},"font":{"family":"system","size":13,"weight":"semibold"},\
    "color":"@accent","align":"center","maxLines":1,"live":null,"frame":{"x":12,"y":122,"w":146,"h":18},"opacity":null,"mirror":null}]}
    """

    static let photoSpec = """
    {"name":{"en":"Stub Photo","ar":"صورة تجريبية"},"family":"small","theme":"light",\
    "palette":{"bg":"#FAF6F0","fg":"#1E1B18","accent":"#C8553D"},\
    "background":{"type":"solid","color":"@bg","colors":null,"angle":null,"outerColor":null},\
    "fields":[{"key":"photo","type":"image","label":{"en":"Photo","ar":"الصورة"},"default":null}],\
    "layers":[{"type":"image","source":"user_image","fit":"fill","mask":"roundedRect","cornerRadius":18,"filter":"none",\
    "frame":{"x":10,"y":10,"w":150,"h":116},"opacity":null,"mirror":null},\
    {"type":"text","value":{"en":"{{date.EEEE}}","ar":"{{date.EEEE}}"},"font":{"family":"system","size":13,"weight":"semibold"},\
    "color":"@fg","align":"leading","maxLines":1,"live":null,"frame":{"x":14,"y":136,"w":142,"h":18},"opacity":null,"mirror":true}]}
    """
}
