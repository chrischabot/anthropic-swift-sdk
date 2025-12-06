import Foundation

public struct MessageCreateParams: Encodable, Sendable {
    public var model: String
    public var maxTokens: Int?
    public var system: [MessageInput]?
    public var messages: [MessageInput]
    public var stream: Bool?
    public var metadata: [String: String]?
    public var temperature: Double?
    public var tools: [ToolDefinition]?
    public var toolChoice: ToolChoice?

    public init(
        model: String,
        maxTokens: Int? = nil,
        system: [MessageInput]? = nil,
        messages: [MessageInput],
        stream: Bool? = nil,
        metadata: [String: String]? = nil,
        temperature: Double? = nil,
        tools: [ToolDefinition]? = nil,
        toolChoice: ToolChoice? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.messages = messages
        self.stream = stream
        self.metadata = metadata
        self.temperature = temperature
        self.tools = tools
        self.toolChoice = toolChoice
    }
}

public struct MessageCountTokensParams: Encodable, Sendable {
    public var model: String
    public var messages: [MessageInput]
    public var system: [MessageInput]?

    public init(model: String, messages: [MessageInput], system: [MessageInput]? = nil) {
        self.model = model
        self.messages = messages
        self.system = system
    }
}

public struct MessageInput: Codable, Sendable {
    public var role: String
    public var content: [ContentBlock]

    public init(role: String, content: [ContentBlock]) {
        self.role = role
        self.content = content
    }

    public static func user(_ text: String) -> MessageInput {
        MessageInput(role: "user", content: [.text(text)])
    }

    public static func assistant(_ text: String) -> MessageInput {
        MessageInput(role: "assistant", content: [.text(text)])
    }

    public static func system(_ text: String) -> MessageInput {
        MessageInput(role: "system", content: [.text(text)])
    }
}

public struct ContentBlock: Codable, Sendable {
    public var type: String
    public var text: String?
    public var name: String?
    public var input: [String: AnyCodable]?
    public var toolUseId: String?

    public init(type: String, text: String? = nil) {
        self.type = type
        self.text = text
    }

    public static func text(_ text: String) -> ContentBlock {
        ContentBlock(type: "text", text: text)
    }

    public var toolUse: ToolUseBlock? {
        guard type == "tool_use", let name, let toolUseId, let input else { return nil }
        return ToolUseBlock(id: toolUseId, name: name, input: input)
    }
}

public struct ToolUseBlock: Sendable {
    public let id: String
    public let name: String
    public let input: [String: AnyCodable]
}

public struct MessageResponse: Codable, Sendable {
    public let id: String
    public let type: String?
    public let role: String?
    public let model: String
    public let content: [ContentBlock]
    public let stopReason: String?
    public let stopSequence: String?
    public let usage: Usage?

    public func textContent() -> String {
        content.compactMap { $0.text }.joined()
    }
}

public struct Usage: Codable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
}

public struct MessageTokenCountResponse: Codable, Sendable {
    public let inputTokens: Int
    public let cacheCreation: CacheCreation?
}

public struct CacheCreation: Codable, Sendable {
    public let ephemeral1hInputTokens: Int?
    public let ephemeral5mInputTokens: Int?
}

public struct ToolDefinition: Codable, Sendable {
    public var name: String
    public var description: String?
    public var inputSchema: [String: AnyCodable]
    public var type: String = "function"

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
        case type
    }

    public init(name: String, description: String? = nil, inputSchema: [String: AnyCodable]) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public struct ToolChoice: Codable, Sendable {
    public var type: String
    public var name: String?

    public static func required(name: String) -> ToolChoice {
        ToolChoice(type: "tool", name: name)
    }

    public static func auto() -> ToolChoice {
        ToolChoice(type: "auto", name: nil)
    }
}
