# Anthropic Swift SDK

Swift should talk to Claude without ceremony. This package gives you a native, async/await-friendly client for the Anthropic API on iOS 18, macOS 15, and visionOS 2.

## Quick start
Add to `Package.swift`:

```swift
.package(url: "https://github.com/chrischabot/anthropic-swift-sdk.git", from: "0.1.0")
```

Use it:

```swift
import AnthropicSwift

let client = AnthropicClient(apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "")

let message = try await client.messages.create(
    MessageCreateParams(
        model: "claude-3-5-sonnet-20241022",
        maxTokens: 64,
        messages: [.user("Explain what a semaphore is in one friendly sentence.")]
    )
)
print(message.textContent())
```

## Structured output (two ways)
If the model returns JSON as text, decode it in one call:

```swift
struct WriterResponse: Decodable { let markdown: String }

let draft: WriterResponse = try await client.messages.createStructured(
    MessageCreateParams(
        model: "claude-3-5-sonnet-20241022",
        maxTokens: 256,
        messages: [.user("Return {\"markdown\": \"Hello\"}")]
    ),
    decodeAs: WriterResponse.self
)
```

Or force a single tool call with a required schema:

```swift
let runner = client.tools
let schema: [String: AnyCodable] = [
    "type": AnyCodable("object"),
    "properties": AnyCodable([
        "summary": AnyCodable(["type": "string"])
    ]),
    "required": AnyCodable(["summary"])
]

struct Summary: Decodable { let summary: String }

let summary: Summary = try await runner.runTool(
    toolName: "return_summary",
    description: "Return a summary string",
    inputSchema: schema,
    params: MessageCreateParams(
        model: "claude-3-5-sonnet-20241022",
        maxTokens: 64,
        messages: [.user("Summarize Swift concurrency in one sentence.")]
    )
)
```

## Streaming

```swift
let stream = try await client.messages.stream(
    MessageCreateParams(
        model: "claude-3-5-sonnet-20241022",
        maxTokens: 128,
        messages: [.user("Count to five, one number per event.")]
    )
)

for try await event in stream.stream {
    if let text = event.textDelta { print(text, terminator: "") }
}
```

Need the final assembled message?

```swift
let final = try await stream.finalMessage()
print(final.textContent())
```

Prefer callbacks? Use `forEach`:

```swift
try await stream.forEach { event in
    if let text = event.textDelta { print(text, terminator: "") }
}
```

## Token counting

```swift
let count = try await client.messages.countTokens(
    MessageCountTokensParams(
        model: "claude-3-5-sonnet-20241022",
        messages: [.user("How many tokens is this?")]
    )
)
print(count.inputTokens)
```

## Batches (async pagination included)

```swift
let batch = try await client.messages.batches.create(
    MessageBatchCreateParams(requests: [
        MessageBatchRequest(customId: "a", params: MessageCreateParams(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 32,
            messages: [.user("Hello A")]
        )),
        MessageBatchRequest(customId: "b", params: MessageCreateParams(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 32,
            messages: [.user("Hello B")]
        )),
    ])
)

let page = try await client.messages.batches.list(limit: 10)
for batch in page.data { print(batch.id) }

// Stream results once the batch completes (JSONL)
let results = try await client.messages.batches.results(id: batch.id)
for try await line in results {
    print(line.customId, line.result.type)
}
```

## Models

```swift
let models = try await client.models.list()
print(models.data.map(\.id))
```

## Beta APIs (files, skills, beta messages)

```swift
// Beta messages with explicit beta headers
let betaMessage = try await client.beta.messages.create(
    BetaMessageCreateParams(
        betas: ["some-beta-flag"],
        messageParams: MessageCreateParams(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 32,
            messages: [.user("Hi from beta")]
        )
    )
)

// Files: upload + download
let fileData = Data("hello".utf8)
let uploaded = try await client.beta.files.upload(
    file: UploadFile(data: fileData, filename: "hello.txt", contentType: "text/plain")
)
let downloaded = try await client.beta.files.download(id: uploaded.id)
print(downloaded.count)

// Skills: create/list/delete
let skill = try await client.beta.skills.create(
    name: "demo-skill",
    description: "Says hi",
    code: nil
)
let skillsPage = try await client.beta.skills.list()
print(skillsPage.data.map(\.id))
```

## Testing
- Unit tests: `swift test`
- Integration smoke tests: set `ANTHROPIC_API_KEY` to enable live calls; otherwise they skip.
  - `ANTHROPIC_API_KEY=sk-... swift test --filter IntegrationTests`

## Notes
- No external dependencies; pure Foundation + async/await.
- JSON uses snake_case coding with ISO8601 dates.
- Retries cover common transient errors with exponential backoff.
- Keep your API key in the environment; never commit it. The client reads `ANTHROPIC_API_KEY`.

## Current status
- Messages: create, streaming (SSE), structured output helper, tool runner, token counting, batches (list/create/cancel/results streaming).
- Models: list.
- Beta: messages, files (multipart upload/download/delete/list), skills (multipart create/list/retrieve/delete).
- Logging: pluggable logger with log levels.
- Pagination + JSONL decoding helpers.

## Roadmap
- Richer streaming event helpers (typed events, text aggregation shortcuts).
- More coverage for beta features as the API evolves.
