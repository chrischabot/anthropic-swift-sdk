import Foundation

public struct BetaFilesClient: Sendable {
    private let httpClient: HTTPClient
    private let filesBeta = "files-api-2025-04-14"

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func list(
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> Page<FileMetadata> {
        var headers = options.headers
        headers["anthropic-beta"] = ([filesBeta] + betas).joined(separator: ",")
        var callOptions = options
        callOptions.headers = headers

        let response: APIResponse<Page<FileMetadata>> = try await httpClient.sendJSON(
            path: "/v1/files",
            method: .get,
            options: callOptions
        )
        return response.body
    }

    public func upload(
        file: UploadFile,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> FileMetadata {
        var headers = options.headers
        headers["anthropic-beta"] = ([filesBeta] + betas).joined(separator: ",")

        let boundary = UUID().uuidString
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"

        let body = MultipartFormDataBuilder(boundary: boundary)
            .appendFile(fieldName: "file", file: file)
            .build()

        var callOptions = options
        callOptions.headers = headers

        let response: APIResponse<FileMetadata> = try await httpClient.sendRaw(
            path: "/v1/files",
            method: .post,
            headers: headers,
            body: body,
            options: callOptions
        )
        return response.body
    }

    public func download(
        id: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> Data {
        var headers = options.headers
        headers["anthropic-beta"] = ([filesBeta] + betas).joined(separator: ",")
        headers["Accept"] = "application/binary"
        var callOptions = options
        callOptions.headers = headers

        let response = try await httpClient.download(
            path: "/v1/files/\(id)/content",
            headers: headers,
            options: callOptions
        )
        return response
    }

    public func delete(
        id: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> FileDeletedResponse {
        var headers = options.headers
        headers["anthropic-beta"] = ([filesBeta] + betas).joined(separator: ",")
        var callOptions = options
        callOptions.headers = headers

        let response: APIResponse<FileDeletedResponse> = try await httpClient.sendJSON(
            path: "/v1/files/\(id)",
            method: .delete,
            options: callOptions
        )
        return response.body
    }
}

public struct UploadFile: Sendable {
    public let data: Data
    public let filename: String
    public let contentType: String

    public init(data: Data, filename: String, contentType: String) {
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }
}

public struct FileMetadata: Codable, Sendable {
    public let id: String
    public let name: String?
    public let size: Int?
    public let createdAt: Date?
}

public struct FileDeletedResponse: Codable, Sendable {
    public let id: String
    public let deleted: Bool
}
