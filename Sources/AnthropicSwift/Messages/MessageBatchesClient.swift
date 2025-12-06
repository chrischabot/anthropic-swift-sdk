import Foundation

public struct MessageBatchesClient: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func create(
        _ params: MessageBatchCreateParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageBatch {
        let response: APIResponse<MessageBatch> = try await httpClient.sendJSON(
            path: "/v1/messages/batches",
            method: .post,
            body: params,
            options: options
        )
        return response.body
    }

    public func retrieve(
        id: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageBatch {
        let response: APIResponse<MessageBatch> = try await httpClient.sendJSON(
            path: "/v1/messages/batches/\(id)",
            method: .get,
            options: options
        )
        return response.body
    }

    public func cancel(
        id: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageBatch {
        struct Empty: Encodable, Sendable {}
        let response: APIResponse<MessageBatch> = try await httpClient.sendJSON(
            path: "/v1/messages/batches/\(id)/cancel",
            method: .post,
            body: Optional<Empty>.none,
            options: options
        )
        return response.body
    }

    /// Stream results of a completed batch as JSONL lines.
    public func results(
        id: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> AsyncThrowingStream<MessageBatchResultLine, Error> {
        let batch = try await retrieve(id: id, options: options)
        guard let resultsURL = batch.resultsUrl else {
            throw AnthropicError.httpError(statusCode: 409, message: "Batch not finished; no results_url yet", requestID: nil)
        }

        let (bytes, cancel) = try await httpClient.streamURL(
            urlString: resultsURL,
            headers: ["Accept": "application/binary"],
            options: options
        )

        let lines = JSONLDecoder.decodeLines(bytes: bytes, as: MessageBatchResultLine.self)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in lines {
                        continuation.yield(line)
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
    }

    public func list(
        limit: Int? = nil,
        after: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> Page<MessageBatch> {
        var query: [URLQueryItem] = []
        if let limit { query.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let after { query.append(URLQueryItem(name: "after", value: after)) }

        let response: APIResponse<Page<MessageBatch>> = try await httpClient.sendJSON(
            path: "/v1/messages/batches",
            method: .get,
            query: query,
            options: options
        )
        return response.body
    }

    public func listAll(
        limit: Int? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> PageSequence<MessageBatch> {
        let first = try await list(limit: limit, after: nil, options: options)
        return PageSequence(initialPage: first) { token in
            try await self.list(limit: limit, after: token, options: options)
        }
    }
}

public struct MessageBatchCreateParams: Encodable, Sendable {
    public var requests: [MessageBatchRequest]

    public init(requests: [MessageBatchRequest]) {
        self.requests = requests
    }
}

public struct MessageBatchRequest: Encodable, Sendable {
    public var customId: String
    public var params: MessageCreateParams

    public init(customId: String, params: MessageCreateParams) {
        self.customId = customId
        self.params = params
    }
}

public struct MessageBatch: Codable, Sendable {
    public let id: String
    public let processingStatus: String
    public let requestCounts: MessageBatchRequestCounts?
    public let createdAt: Date?
    public let endedAt: Date?
    public let resultsUrl: String?
}

public struct MessageBatchRequestCounts: Codable, Sendable {
    public let total: Int?
    public let succeeded: Int?
    public let errored: Int?
    public let canceled: Int?
}

public struct MessageBatchResultLine: Decodable, Sendable {
    public let customId: String
    public let result: MessageBatchResult
}

public struct MessageBatchResult: Decodable, Sendable {
    public let type: String
    public let message: MessageResponse?
    public let error: BatchErrorResponse?
}

public struct BatchErrorResponse: Decodable, Sendable {
    public let type: String?
    public let message: String?
}
