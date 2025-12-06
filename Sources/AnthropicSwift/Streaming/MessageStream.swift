import Foundation

public struct MessageStreamEvent: Sendable {
    public let type: String
    public let textDelta: String?
    public let stopReason: String?
    public let usage: Usage?
    public let raw: StreamPayloadPublic
}

public struct MessageStream: Sendable {
    public let stream: AsyncThrowingStream<MessageStreamEvent, Error>
    public let cancel: @Sendable () -> Void

    /// Accumulate events into a final `MessageResponse` containing concatenated text.
    public func finalMessage() async throws -> MessageResponse {
        var contentBlocks: [ContentBlock] = []
        var usage: Usage?
        var stopReason: String?

        for try await event in stream {
            if let text = event.textDelta {
                contentBlocks.append(.text(text))
            }
            if let u = event.usage {
                usage = u
            }
            if let stop = event.stopReason {
                stopReason = stop
            }
        }

        return MessageResponse(
            id: UUID().uuidString,
            type: "message",
            role: "assistant",
            model: "",
            content: contentBlocks,
            stopReason: stopReason,
            stopSequence: nil,
            usage: usage
        )
    }

    /// Convenience: process each event with a handler.
    public func forEach(_ handler: @escaping @Sendable (MessageStreamEvent) -> Void) async throws {
        for try await event in stream {
            handler(event)
        }
    }
}

public struct StreamPayloadPublic: Sendable {
    public let type: String
    public let deltaText: String?
    public let partialJSON: String?
    public let stopReason: String?
    public let usage: Usage?
}

struct StreamPayload: Decodable, Sendable {
    let type: String
    let delta: DeltaPayload?
    let contentBlock: ContentBlockPayload?
    let message: MessageResponse?
    let stopReason: String?
    let usage: Usage?
    let error: StreamError?

    struct DeltaPayload: Decodable, Sendable {
        let text: String?
        let partialJson: String?

        enum CodingKeys: String, CodingKey {
            case text
            case partialJson = "partial_json"
        }
    }

    struct ContentBlockPayload: Decodable, Sendable {
        let type: String
        let text: String?
    }

    struct StreamError: Decodable, Sendable {
        let type: String
        let message: String
    }
}

extension MessageStreamEvent {
    static func from(payload: StreamPayload) -> MessageStreamEvent {
        let textDelta = payload.delta?.text ?? payload.contentBlock?.text
        let raw = StreamPayloadPublic(
            type: payload.type,
            deltaText: payload.delta?.text ?? payload.contentBlock?.text,
            partialJSON: payload.delta?.partialJson,
            stopReason: payload.stopReason,
            usage: payload.usage
        )
        return MessageStreamEvent(
            type: payload.type,
            textDelta: textDelta,
            stopReason: payload.stopReason,
            usage: payload.usage,
            raw: raw
        )
    }
}
