import Foundation

public struct ClientConfiguration: Sendable {
    public var apiKey: String?
    public var baseURL: URL
    public var anthropicVersion: String
    public var defaultHeaders: [String: String]
    public var betaHeaders: [String]
    public var timeout: TimeInterval?
    public var maxRetries: Int
    public var logLevel: LogLevel

    public init(
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        anthropicVersion: String = "2023-06-01",
        defaultHeaders: [String: String] = [:],
        betaHeaders: [String] = [],
        timeout: TimeInterval? = nil,
        maxRetries: Int = 2,
        logLevel: LogLevel = .off
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.anthropicVersion = anthropicVersion
        self.defaultHeaders = defaultHeaders
        self.betaHeaders = betaHeaders
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.logLevel = logLevel
    }
}

public enum LogLevel: String, Sendable {
    case debug
    case info
    case warn
    case error
    case off
}
