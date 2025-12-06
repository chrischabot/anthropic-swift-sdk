import Foundation

public struct BetaSkillsClient: Sendable {
    private let httpClient: HTTPClient
    private let skillsBeta = "skills-2025-10-02"

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func create(
        name: String,
        description: String?,
        code: UploadFile?,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> Skill {
        var headers = options.headers
        headers["anthropic-beta"] = ([skillsBeta] + betas).joined(separator: ",")

        let boundary = UUID().uuidString
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"

        var builder = MultipartFormDataBuilder(boundary: boundary)
        builder = builder.appendField(name: "name", value: name)
        if let description {
            builder = builder.appendField(name: "description", value: description)
        }
        if let code {
            builder = builder.appendFile(fieldName: "code", file: code)
        }

        let body = builder.build()
        var callOptions = options
        callOptions.headers = headers

        let response: APIResponse<Skill> = try await httpClient.sendRaw(
            path: "/v1/skills?beta=true",
            method: .post,
            headers: headers,
            body: body,
            options: callOptions
        )
        return response.body
    }

    public func retrieve(
        id: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> Skill {
        var headers = options.headers
        headers["anthropic-beta"] = ([skillsBeta] + betas).joined(separator: ",")
        var callOptions = options
        callOptions.headers = headers

        let response: APIResponse<Skill> = try await httpClient.sendJSON(
            path: "/v1/skills/\(id)?beta=true",
            method: .get,
            options: callOptions
        )
        return response.body
    }

    public func list(
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> Page<Skill> {
        var headers = options.headers
        headers["anthropic-beta"] = ([skillsBeta] + betas).joined(separator: ",")
        var callOptions = options
        callOptions.headers = headers

        let response: APIResponse<Page<Skill>> = try await httpClient.sendJSON(
            path: "/v1/skills?beta=true",
            method: .get,
            options: callOptions
        )
        return response.body
    }

    public func delete(
        id: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> SkillDeleteResponse {
        var headers = options.headers
        headers["anthropic-beta"] = ([skillsBeta] + betas).joined(separator: ",")
        var callOptions = options
        callOptions.headers = headers

        let response: APIResponse<SkillDeleteResponse> = try await httpClient.sendJSON(
            path: "/v1/skills/\(id)?beta=true",
            method: .delete,
            options: callOptions
        )
        return response.body
    }
}

public struct Skill: Codable, Sendable {
    public let id: String
    public let name: String?
    public let description: String?
    public let createdAt: Date?
}

public struct SkillDeleteResponse: Codable, Sendable {
    public let id: String
    public let deleted: Bool
}
