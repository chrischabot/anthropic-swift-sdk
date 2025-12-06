import Foundation

public struct APIResponse<Body: Decodable & Sendable>: Sendable {
    public let body: Body
    public let statusCode: Int
    public let requestID: String?
    public let headers: [String: String]
}

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

public struct RequestOptions: Sendable {
    public var headers: [String: String]
    public var timeout: TimeInterval?
    public var maxRetries: Int?
    public var idempotencyKey: String?

    public init(
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        maxRetries: Int? = nil,
        idempotencyKey: String? = nil
    ) {
        self.headers = headers
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.idempotencyKey = idempotencyKey
    }
}

actor HTTPClient {
    private let config: ClientConfiguration
    private let session: URLSession

    init(configuration: ClientConfiguration) {
        self.config = configuration

        let urlConfig = URLSessionConfiguration.ephemeral
        // Use caller-specified timeout if present; otherwise rely on per-request.
        urlConfig.timeoutIntervalForRequest = 60
        urlConfig.timeoutIntervalForResource = 60 * 15
        self.session = URLSession(configuration: urlConfig)
    }

    func sendJSON<Request: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        query: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        body: Request? = Optional<Request>.none,
        options: RequestOptions = RequestOptions()
    ) async throws -> APIResponse<Response> {
        guard let apiKey = config.apiKey, !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false)
        // Normalize leading slash
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let basePath = components?.path ?? ""
        components?.path = basePath + normalizedPath
        if let query, !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else {
            throw AnthropicError.invalidURL
        }

        let mergedHeaders = mergeHeaders(requestHeaders: headers, optionHeaders: options.headers, apiKey: apiKey)

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (key, value) in mergedHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let timeout = options.timeout ?? config.timeout {
            request.timeoutInterval = timeout
        }
        if let body = body {
            do {
                request.httpBody = try JSONCoding.encoder.encode(body)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } catch {
                throw AnthropicError.encodingError(error)
            }
        }
        if let idempotencyKey = options.idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        let maxRetries = options.maxRetries ?? config.maxRetries
        var attempt = 0
        var lastError: Error = AnthropicError.invalidURL

        while attempt <= maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AnthropicError.invalidURL
                }
                let status = httpResponse.statusCode
                let headers = Self.normalizeHeaders(httpResponse.allHeaderFields)
                let requestID = httpResponse.value(forHTTPHeaderField: "request-id")

                if (200...299).contains(status) {
                    do {
                        let decoded = try JSONCoding.decoder.decode(Response.self, from: data)
                        return APIResponse(body: decoded, statusCode: status, requestID: requestID, headers: headers)
                    } catch {
                        throw AnthropicError.decodingError(error)
                    }
                } else {
                    let message = Self.extractErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: status)
                    throw AnthropicError.httpError(statusCode: status, message: message, requestID: requestID)
                }
            } catch {
                let convertedError: Error
                if let anthropicError = error as? AnthropicError {
                    convertedError = anthropicError
                } else if let urlError = error as? URLError {
                    if urlError.code == .timedOut {
                        convertedError = AnthropicError.timeout
                    } else {
                        convertedError = AnthropicError.networkError(urlError)
                    }
                } else {
                    convertedError = error
                }

                lastError = convertedError

                if let anthropicError = convertedError as? AnthropicError, anthropicError.isRetryable, attempt < maxRetries {
                    attempt += 1
                    let delaySeconds = backoffDelay(forAttempt: attempt)
                    try? await Task.sleep(for: .seconds(delaySeconds))
                    continue
                } else {
                    throw convertedError
                }
            }
        }

        throw AnthropicError.maxRetriesExceeded(lastError: lastError)
    }

    private func mergeHeaders(requestHeaders: [String: String], optionHeaders: [String: String], apiKey: String) -> [String: String] {
        var headers: [String: String] = [
            "x-api-key": apiKey,
            "anthropic-version": config.anthropicVersion,
            "Accept": "application/json"
        ]
        if !config.betaHeaders.isEmpty {
            headers["anthropic-beta"] = config.betaHeaders.joined(separator: ",")
        }
        headers.merge(config.defaultHeaders, uniquingKeysWith: { _, new in new })
        headers.merge(requestHeaders, uniquingKeysWith: { _, new in new })
        headers.merge(optionHeaders, uniquingKeysWith: { _, new in new })
        return headers
    }

    private func backoffDelay(forAttempt attempt: Int) -> TimeInterval {
        let base: TimeInterval = 1.0
        let cap: TimeInterval = 30.0
        let exp = pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.25)
        return min(base * exp + jitter, cap)
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any] {
                if let message = error["message"] as? String { return message }
                if let type = error["type"] as? String { return type }
            }
            if let message = object["message"] as? String {
                return message
            }
        }
        return String(data: data, encoding: .utf8)
    }

    private static func normalizeHeaders(_ raw: [AnyHashable: Any]) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in raw {
            guard let keyString = key as? String else { continue }
            if let stringValue = value as? String {
                headers[keyString.lowercased()] = stringValue
            } else {
                headers[keyString.lowercased()] = "\(value)"
            }
        }
        return headers
    }
}
