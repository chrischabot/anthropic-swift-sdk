# Anthropic Swift SDK – Reference

This is a concise reference for every public entry point. Code is Swift 6, async/await, Foundation-only.

## Initialization

```swift
import AnthropicSwift

let client = AnthropicClient(
    configuration: ClientConfiguration(
        apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
        logLevel: .warn // .off|.error|.warn|.info|.debug
    )
)

// Shortcut:
let client = AnthropicClient(apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "")
```

`ClientConfiguration` fields:
- `apiKey: String?`
- `baseURL: URL` (default `https://api.anthropic.com`)
- `anthropicVersion: String` (default `2023-06-01`)
- `defaultHeaders: [String:String]`
- `betaHeaders: [String]`
- `timeout: TimeInterval?`
- `maxRetries: Int` (default 2)
- `logLevel: LogLevel` (`off|error|warn|info|debug`)
- `logger: Logger?` (protocol with `log(level:message:)`)

## Messages

### Create (non-streaming)
```swift
let message = try await client.messages.create(
    MessageCreateParams(
        model: "claude-3-5-sonnet-20241022",
        maxTokens: 128,
        messages: [.user("Hello")],
        system: [.system("You are concise")],
        temperature: 0.7,
        tools: [ToolDefinition(...)],      // optional tool calling
        toolChoice: .required(name: "fn")  // or .auto()
    )
)
```

`MessageCreateParams`:
- `model: String`
- `maxTokens: Int?`
- `system: [MessageInput]?`
- `messages: [MessageInput]`
- `stream: Bool?`
- `metadata: [String:String]?`
- `temperature: Double?`
- `tools: [ToolDefinition]?` (function calling)
- `toolChoice: ToolChoice?` (`.required(name:)` or `.auto()`)

`MessageInput` helpers: `.user(_:)`, `.assistant(_:)`, `.system(_:)` produce `ContentBlock.text`.

`MessageResponse`:
- `id, type, role, model`
- `content: [ContentBlock]` (text/tool_use)
- `stopReason, stopSequence`
- `usage: Usage?`
- `textContent()` concatenates text blocks.

`Usage`: `inputTokens`, `outputTokens`.

### Structured output from text
```swift
struct MyShape: Decodable { let foo: String }
let result: MyShape = try await client.messages.createStructured(params, decodeAs: MyShape.self)
```

### Token counting
```swift
let count = try await client.messages.countTokens(
    MessageCountTokensParams(model: "...", messages: [.user("Hi")])
)
// fields: inputTokens, cacheCreation
```

### Streaming
```swift
let stream = try await client.messages.stream(params)
for try await event in stream.stream {
    if let text = event.textDelta { print(text) }
}
let final = try await stream.finalMessage()
```

`MessageStreamEvent`:
- `type: String`
- `textDelta: String?`
- `stopReason: String?`
- `usage: Usage?`
- `raw: StreamPayloadPublic` (type/delta/partialJSON/stopReason/usage)

`MessageStream`:
- `stream: AsyncThrowingStream<MessageStreamEvent, Error>`
- `cancel(): Void`
- `finalMessage() -> MessageResponse`
- `forEach(_ handler: @Sendable (MessageStreamEvent) -> Void)`

## Batches

Create:
```swift
let batch = try await client.messages.batches.create(
    MessageBatchCreateParams(requests: [
        MessageBatchRequest(customId: "job-1", params: params1),
        MessageBatchRequest(customId: "job-2", params: params2)
    ])
)
```

List / paginate:
```swift
let page = try await client.messages.batches.list(limit: 10)
for batch in page.data { ... }

for try await batch in try await client.messages.batches.listAll(limit: 10) {
    ...
}
```

Cancel:
```swift
let canceled = try await client.messages.batches.cancel(id: batch.id)
```

Results streaming (JSONL):
```swift
let lines = try await client.messages.batches.results(id: batch.id)
for try await line in lines {
    print(line.customId, line.result.type)
    if let message = line.result.message { ... }
}
```

Models:
- `MessageBatch` fields: `id`, `processingStatus`, `requestCounts`, `createdAt`, `endedAt`, `resultsUrl`.
- `MessageBatchResultLine`: `customId`, `result`.
- `MessageBatchResult`: `type` + `message?` + `error?`.

## Models

```swift
let models = try await client.models.list()
print(models.data.map(\.id))
```

Models response: `ModelsListResponse` with `data: [ModelDescriptor]` (`id`, `displayName?`, `createdAt?`, `description?`).

## Tool runner helper

```swift
let runner = client.tools
let schema: [String: AnyCodable] = [
    "type": AnyCodable("object"),
    "properties": AnyCodable(["answer": AnyCodable(["type": "string"])]),
    "required": AnyCodable(["answer"])
]

struct Answer: Decodable { let answer: String }

let result: Answer = try await runner.runTool(
    toolName: "return_answer",
    description: "Return answer string",
    inputSchema: schema,
    params: MessageCreateParams(
        model: "claude-3-5-sonnet-20241022",
        maxTokens: 64,
        messages: [.user("Provide an answer")]
    )
)
```

## Beta APIs

`client.beta.messages.create(BetaMessageCreateParams(betas: [...], messageParams: ...))`
- Adds `anthropic-beta` header and `beta=true` query; otherwise same shape as messages.

Files:
```swift
let uploaded = try await client.beta.files.upload(
    file: UploadFile(data: Data("hi".utf8), filename: "hi.txt", contentType: "text/plain")
)
let list = try await client.beta.files.list()
let data = try await client.beta.files.download(id: uploaded.id)
let deleted = try await client.beta.files.delete(id: uploaded.id)
```

Skills:
```swift
let skill = try await client.beta.skills.create(
    name: "demo",
    description: "Says hi",
    code: nil // UploadFile for code if needed
)
let skillsPage = try await client.beta.skills.list()
let fetched = try await client.beta.skills.retrieve(id: skill.id)
let deleted = try await client.beta.skills.delete(id: skill.id)
```

Beta headers are auto-applied per feature (`files-api-2025-04-14`, `skills-2025-10-02`). You can append extra betas via the `betas:` array parameters.

## Logging
- `ClientConfiguration.logLevel` controls verbosity.
- `ClientConfiguration.logger` can override the default (which prints). Implement `Logger.log(level:message:)`.

## Testing patterns
- Unit: `swift test`
- Integration: set `ANTHROPIC_API_KEY`, then `swift test --filter IntegrationTests` or `--filter AgentUsageTests`.
- Do not hardcode API keys; always use environment variables.

## Utilities
- `AnyCodable` for JSON schemas and tool payloads.
- `MultipartFormDataBuilder` for uploads.
- `JSONLDecoder` to parse streamed batch results.
- Pagination: `Page<T>` and `PageSequence<T>` for async iteration.

## Error handling
- `AnthropicError` covers: `missingAPIKey`, `invalidURL`, `encodingError`, `decodingError`, `httpError(statusCode:message:requestID:)`, `networkError`, `timeout`, `maxRetriesExceeded`.
- Retryable errors: network/timeout, HTTP 408/409/429/5xx (except some 5xx), controlled by `maxRetries`.
