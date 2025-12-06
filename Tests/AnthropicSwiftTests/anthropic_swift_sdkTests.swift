import Testing
@testable import AnthropicSwift

@Test func configurationDefaults() {
    let config = ClientConfiguration(apiKey: "test_key")
    #expect(config.baseURL.absoluteString == "https://api.anthropic.com")
    #expect(config.anthropicVersion == "2023-06-01")
    #expect(config.maxRetries == 2)
}
