import Foundation

public struct BetaMessagesClient: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    @discardableResult
    public func create(
        _ params: BetaMessageCreateParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageResponse {
        var headers = options.headers
        headers["anthropic-beta"] = params.betasHeader()
        var callOptions = options
        callOptions.headers = headers

        let response: APIResponse<MessageResponse> = try await httpClient.sendJSON(
            path: "/v1/messages",
            method: .post,
            query: [URLQueryItem(name: "beta", value: "true")],
            body: params.asMessageParams(),
            options: callOptions
        )
        return response.body
    }

    public func stream(
        _ params: BetaMessageCreateParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageStream {
        var headers = options.headers
        headers["anthropic-beta"] = params.betasHeader()
        var callOptions = options
        callOptions.headers = headers

        let (bytes, cancel) = try await httpClient.stream(
            path: "/v1/messages",
            method: .post,
            query: [URLQueryItem(name: "beta", value: "true")],
            headers: callOptions.headers,
            body: params.asMessageParams(),
            options: callOptions
        )

        let events = SSEDecoder.decodeLines(bytes: bytes).map(MessageStreamEvent.from)
        let stream = AsyncThrowingStream<MessageStreamEvent, Error> { continuation in
            let task = Task {
                do {
                    for try await payload in events {
                        continuation.yield(payload)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                cancel()
            }
        }

        return MessageStream(stream: stream, cancel: cancel)
    }
}

public struct BetaMessageCreateParams: Encodable, Sendable {
    public var betas: [String]
    public var messageParams: MessageCreateParams

    public init(betas: [String], messageParams: MessageCreateParams) {
        self.betas = betas
        self.messageParams = messageParams
    }

    func betasHeader() -> String {
        betas.joined(separator: ",")
    }

    func asMessageParams() -> MessageCreateParams {
        messageParams
    }
}
