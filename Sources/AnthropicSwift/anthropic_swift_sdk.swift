import Foundation

public actor AnthropicClient {
    public let configuration: ClientConfiguration
    private let httpClient: HTTPClient

    public let messages: MessagesClient

    public init(configuration: ClientConfiguration) {
        self.configuration = configuration
        self.httpClient = HTTPClient(configuration: configuration)
        self.messages = MessagesClient(httpClient: httpClient)
    }

    public init(apiKey: String) {
        let config = ClientConfiguration(apiKey: apiKey)
        self.configuration = config
        self.httpClient = HTTPClient(configuration: config)
        self.messages = MessagesClient(httpClient: httpClient)
    }
}
