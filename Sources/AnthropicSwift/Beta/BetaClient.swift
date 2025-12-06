import Foundation

public struct BetaClient: Sendable {
    public let messages: BetaMessagesClient
    public let files: BetaFilesClient
    public let skills: BetaSkillsClient

    init(httpClient: HTTPClient) {
        self.messages = BetaMessagesClient(httpClient: httpClient)
        self.files = BetaFilesClient(httpClient: httpClient)
        self.skills = BetaSkillsClient(httpClient: httpClient)
    }
}
