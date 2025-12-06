import Foundation
import Testing
@testable import AnthropicSwift

@Suite struct AgentUsageTests {
    let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]

    @Test func writerFlowStructuredOutput() async throws {
        guard let key = apiKey else { return }
        let client = AnthropicClient(apiKey: key)

        struct WriterResponse: Decodable {
            let markdown: String
            let wordCount: Int
        }

        let params = MessageCreateParams(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 128,
            messages: [
                .user("Return JSON exactly with keys markdown and word_count; markdown:'Hello world', word_count:2")
            ]
        )

        do {
            let response: WriterResponse = try await client.messages.createStructured(
                params,
                decodeAs: WriterResponse.self
            )
            #expect(!response.markdown.isEmpty)
            #expect(response.wordCount > 0)
        } catch let error as AnthropicError {
            if case let .httpError(status, message, _) = error, status == 400, (message ?? "").contains("credit balance") {
                return
            }
            throw error
        }
    }

    @Test func noteTakerFlow() async throws {
        guard let key = apiKey else { return }
        let client = AnthropicClient(apiKey: key)

        let params = MessageCreateParams(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 96,
            messages: [
                .user("Summarize: User discussed building a native Swift SDK for Claude. Keep it one sentence.")
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

    @Test func researcherFlowStructuredTopics() async throws {
        guard let key = apiKey else { return }
        let client = AnthropicClient(apiKey: key)

        struct ResearchTopics: Decodable {
            let topics: [Topic]
            struct Topic: Decodable {
                let topic: String
                let why: String
            }
        }

        let params = MessageCreateParams(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 160,
            messages: [
                .user("""
                    Return JSON with key "topics" as an array of objects {{ "topic": string, "why": string }} about what to research in iOS SDK design.
                    Use two entries max.
                    """)
            ]
        )

        do {
            let result: ResearchTopics = try await client.messages.createStructured(
                params,
                decodeAs: ResearchTopics.self
            )
            #expect(!result.topics.isEmpty)
        } catch let error as AnthropicError {
            if case let .httpError(status, message, _) = error, status == 400, (message ?? "").contains("credit balance") {
                return
            }
            throw error
        }
    }
}
