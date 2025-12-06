import Foundation
import Testing
@testable import AnthropicSwift

@Suite struct IntegrationTests {
    let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]

    @Test func modelsList() async throws {
        guard let key = apiKey else { return }
        let client = AnthropicClient(apiKey: key)
        let models = try await client.models.list()
        #expect(!models.data.isEmpty)
    }

    @Test func messagesCreate() async throws {
        guard let key = apiKey else { return }
        let client = AnthropicClient(apiKey: key)
        let params = MessageCreateParams(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 64,
            messages: [
                .user("Say hello in one sentence.")
            ]
        )
        do {
            let message = try await client.messages.create(params)
            #expect(!message.textContent().isEmpty)
        } catch let error as AnthropicError {
            if case let .httpError(status, message, _) = error, status == 400, (message ?? "").contains("credit balance") {
                return
            }
            throw error
        }
    }
}
