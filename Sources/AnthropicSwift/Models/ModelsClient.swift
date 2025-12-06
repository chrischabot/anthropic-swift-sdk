import Foundation

public struct ModelsClient: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func list(options: RequestOptions = RequestOptions()) async throws -> ModelsListResponse {
        let response: APIResponse<ModelsListResponse> = try await httpClient.sendJSON(
            path: "/v1/models",
            method: .get,
            options: options
        )
        return response.body
    }
}

public struct ModelsListResponse: Codable, Sendable {
    public let data: [ModelDescriptor]
}

public struct ModelDescriptor: Codable, Sendable {
    public let id: String
    public let displayName: String?
    public let createdAt: Date?
    public let description: String?
}
