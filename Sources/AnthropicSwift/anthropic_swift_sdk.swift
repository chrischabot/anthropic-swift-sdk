import Foundation

public actor AnthropicClient {
    public let configuration: ClientConfiguration
    private let httpClient: HTTPClient

    public let messages: MessagesClient
    public let models: ModelsClient
    public let beta: BetaClient
    public let tools: ToolRunner

    public init(configuration: ClientConfiguration) {
        self.configuration = configuration
        self.httpClient = HTTPClient(configuration: configuration)
        self.messages = MessagesClient(httpClient: httpClient)
        self.models = ModelsClient(httpClient: httpClient)
        self.beta = BetaClient(httpClient: httpClient)
        self.tools = ToolRunner(messages: messages)
    }

    public init(apiKey: String) {
        let config = ClientConfiguration(apiKey: apiKey)
        self.configuration = config
        self.httpClient = HTTPClient(configuration: config)
        self.messages = MessagesClient(httpClient: httpClient)
        self.models = ModelsClient(httpClient: httpClient)
        self.beta = BetaClient(httpClient: httpClient)
        self.tools = ToolRunner(messages: messages)
    }
}
