import Foundation

public enum AnthropicError: Error, LocalizedError, Sendable {
    case missingAPIKey
    case invalidURL
    case decodingError(Error)
    case encodingError(Error)
    case httpError(statusCode: Int, message: String?, requestID: String?)
    case networkError(Error)
    case timeout
    case maxRetriesExceeded(lastError: Error)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured. Provide an Anthropic API key."
        case .invalidURL:
            return "The request URL could not be constructed."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .httpError(let status, let message, let requestID):
            var base = "HTTP error \(status)"
            if let message, !message.isEmpty {
                base += ": \(message)"
            }
            if let requestID {
                base += " (request-id: \(requestID))"
            }
            return base
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out."
        case .maxRetriesExceeded(let lastError):
            return "Request failed after retries: \(lastError.localizedDescription)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .timeout:
            return true
        case .httpError(let status, _, _):
            return status == 408 || status == 409 || status == 429 || (500...599).contains(status)
        default:
            return false
        }
    }
}
