import Foundation

/// Helper to request structured output via a single required tool.
public struct ToolRunner: Sendable {
    private let messages: MessagesClient

    public init(messages: MessagesClient) {
        self.messages = messages
    }

    /// Send a tool-based request and decode the tool input as `T`.
    public func runTool<T: Decodable & Sendable>(
        toolName: String,
        description: String?,
        inputSchema: [String: AnyCodable],
        params: MessageCreateParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> T {
        var toolParams = params
        let tool = ToolDefinition(name: toolName, description: description, inputSchema: inputSchema)
        toolParams.tools = [tool]
        toolParams.toolChoice = .required(name: toolName)

        let response = try await messages.create(toolParams, options: options)
        guard let toolBlock = response.content.first(where: { $0.toolUse != nil })?.toolUse else {
            throw AnthropicError.decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No tool_use block in response")))
        }

        let data = try JSONSerialization.data(withJSONObject: toolBlock.input.mapValues { $0.value }, options: [])
        return try JSONCoding.decoder.decode(T.self, from: data)
    }
}
