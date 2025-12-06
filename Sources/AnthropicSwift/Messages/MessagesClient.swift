import Foundation

public struct MessagesClient: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    @discardableResult
    public func create(
        _ params: MessageCreateParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageResponse {
        let computedTimeout = computeNonStreamingTimeoutIfNeeded(params: params, options: options)
        var callOptions = options
        callOptions.timeout = computedTimeout ?? options.timeout

        let response: APIResponse<MessageResponse> = try await httpClient.sendJSON(
            path: "/v1/messages",
            method: .post,
            body: params,
            options: callOptions
        )
        return response.body
    }

    /// Convenience for apps expecting structured JSON in the message content.
    public func createStructured<T: Decodable>(
        _ params: MessageCreateParams,
        decodeAs: T.Type,
        options: RequestOptions = RequestOptions()
    ) async throws -> T {
        let message = try await create(params, options: options)
        let text = message.textContent()
        guard let data = text.data(using: .utf8) else {
            throw AnthropicError.decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unable to convert message text to UTF-8 data.")))
        }
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            throw AnthropicError.decodingError(error)
        }
    }

    public func countTokens(
        _ params: MessageCountTokensParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageTokenCountResponse {
        let response: APIResponse<MessageTokenCountResponse> = try await httpClient.sendJSON(
            path: "/v1/messages/count_tokens",
            method: .post,
            body: params,
            options: options
        )
        return response.body
    }

    private func computeNonStreamingTimeoutIfNeeded(params: MessageCreateParams, options: RequestOptions) -> TimeInterval? {
        guard params.stream != true else { return options.timeout }
        guard let maxTokens = params.maxTokens else { return options.timeout }
        let minimum: TimeInterval = 10 * 60
        let calculatedSeconds = (60.0 * 60.0 * Double(maxTokens)) / 128_000.0
        return max(minimum, calculatedSeconds)
    }
}
