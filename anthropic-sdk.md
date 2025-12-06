Anthropic Swift SDK – Implementation Plan
=========================================

Goal & constraints
------------------
- Build a native Swift 6 SDK for the Anthropic REST API that works on iOS 18/visionOS 2/macOS 15 targets (Xcode 16 SDKs), is SwiftUI-friendly, and stays isolated from the existing app (ship as a standalone Swift Package).
- Match the core capabilities of the official TypeScript SDK (`./anthropic-sdk-typescript`) and the REST docs (https://platform.claude.com/docs/en/api/overview), including streaming, token counting, batches, file/skill betas, and error semantics.
- Keep surface area Swifty: async/await, `AsyncSequence` for streaming/pagination, `Codable`/`Sendable` models, minimal singletons, no external dependencies.

Fit for current agents (Writer, Researcher)
-------------------------------------------
- Current agents issue non-streaming chat calls with structured JSON outputs (OpenAI-style `response_format: json_schema`) and no web search/tooling today. The SDK must offer equivalent structured outputs and robust JSON decoding.
- Strategy for structured outputs:
  - If Anthropic `response_format` is available: expose it and provide a helper to decode a single message content into a `Decodable` payload, with optional retry-on-decode-failure.
  - If not: send a single tool whose `input_schema` matches the expected JSON (e.g., `submit_writer_response`, `submit_research_topics`, `submit_research_item`) and return the parsed tool input; wrap this behind a “structuredOutput” helper to minimize call-site changes.
- WriterAgent needs: one long-form message create call, large `max_tokens`, generous non-streaming timeout, model selection (e.g., `claude-3.5-sonnet-latest`), and a safe `String` extraction for JSON decoding. Plan’s timeout heuristics + non-streaming create cover this.
- ResearcherAgent needs: two sequential structured calls (identify topics, then per-topic research). Same helper as Writer covers both; no streaming, uploads, or batches required.
- Ergonomics: add an OpenAI-compatibility shim (light wrapper) that mirrors `chatCompletion(messages:model:responseFormat:) -> choices[0].message.content` to reduce agent churn during migration.

What we learned from the TypeScript SDK
---------------------------------------
- Resources: `messages` (create/stream/count_tokens), `messages.batches` (create/list/retrieve/results/cancel), `models`, legacy `completions`; beta namespaces for `messages` (beta header passthrough), `files` (list/upload/download/delete/metadata), `skills` (+ versions), and helper tooling.
- Transport features: default `anthropic-version: 2023-06-01`, `x-api-key` auth, optional `anthropic-beta`, retries on network/408/409/429/5xx, long request timeout heuristics for non-streaming max_tokens, SSE streaming, multipart uploads, request-id capture, logging hooks.
- Helpers: MessageStream accumulation and event callbacks, tool-runner abstractions, pagination iterators.

High-level architecture
-----------------------
- Package layout: `AnthropicSwift` (Sources/AnthropicSwift). Submodules by responsibility:
  - `Core`: configuration, HTTP client, request builder, response decoding, retry/backoff, logging hooks, environment (app info) headers.
  - `Resources`: typed clients per endpoint (Messages, MessageBatches, Models, Completions, Beta.Messages, Beta.Files, Beta.Skills/Versions).
  - `Streaming`: SSE parser + `AsyncThrowingStream` surface, message accumulation helpers.
  - `Models`: Codable/Sendable request & response types, pagination containers, error types.
  - `Uploads`: multipart builder supporting Data/URL/file handles.
  - `Helpers`: optional tool runner abstractions mirroring TS helpers.
- Dependency strategy: Foundation + `URLSession` only; allow injection of custom `URLSession`/`URLProtocol` for testing and proxies.
- Namespacing: top-level `AnthropicClient` with `messages`, `models`, `completions`, `beta` (containing `messages`, `files`, `skills`), `messages.batches`.

Configuration & transport
-------------------------
- `AnthropicClient.Configuration`: `apiKey`, `baseURL` (default `https://api.anthropic.com`), `anthropicVersion` (default `2023-06-01`), default headers, optional `betaHeaders` array, `timeout`, `maxRetries` (default 2), `logLevel`, `requestIDCapture` toggle, `userAgent`/app metadata, `dangerouslyAllowBrowserLike` equivalent unnecessary in native.
- `HTTPClient`: builds `URLRequest`, sets headers (`x-api-key`, `anthropic-version`, optional `anthropic-beta`, `Content-Type`), encodes JSON with snake_case strategies, decodes responses with matching strategies. Supports per-request overrides for headers/timeout/retries/idempotency keys.
- Retry/backoff: exponential backoff with jitter for connection errors, 408, 409, 429, and >=500 (excluding 501/505), honoring `Retry-After` when present. Respect streaming opt-out from retries after body is sent unless explicitly requested.
- Timeouts: default 10 minutes; for non-streaming messages with large `max_tokens`, compute dynamic timeout similar to TS (`max(10m, 60m * max_tokens / 128k)`).
- Request-id: capture `request-id` header onto responses for logging/debugging.
- Logging: pluggable logger protocol (default no-op). Emit request line, status, duration, truncated bodies when logLevel >= debug.

Models & data mapping
---------------------
- Define `Codable & Sendable` structs/enums for:
  - Messages: `Message`, `MessageContentBlock` (text, image, tool_use, tool_result, citation), tool schemas, `Usage`, `CacheCreation`, `SafetySetting/Result`, etc.
  - Message params: `MessageCreateParams`, `MessageCountTokensParams` with role/content unions (text, images via base64/file_id, document blocks).
  - Streaming events: `MessageStreamEvent` cases (message_start, content_block_start, text, tool_* variants, message_stop, error, ping).
  - Batches: `MessageBatch`, `MessageBatchResult/Status`, `MessageBatchRequest` with `custom_id` + params, `MessageBatchResultItem`.
  - Files beta: `FileMetadata`, `FileDeleteResponse`, `FileDownload` (raw data/URLResponse wrapper).
  - Skills beta: `Skill`, `SkillVersion`, `SkillCreateResponse`, `SkillListPageCursor`.
  - Models list + legacy completion models.
  - Error envelope: status, type (BadRequest, Authentication, PermissionDenied, NotFound, Unprocessable, RateLimit, Internal), message, `requestID`, and raw body for debugging.
- JSON strategies: snake_case keys; tolerant decoding for future fields via `@unknown default` and optional properties.

Resource clients
----------------
- `MessagesClient`
  - `create(_ params, options?)` -> `Message`.
  - `createStream(_ params, options?)` -> `MessageEventStream` (AsyncThrowingStream of events) plus helper to accumulate `finalMessage()`.
  - `countTokens(_ params, options?)` -> token count struct.
  - Internally set timeout heuristics, warn on deprecated model map (optional console/log hook).
- `MessageBatchesClient`
  - `create`, `retrieve`, `cancel`, `list`, `results(batchID)` (paginated async sequence or iterator).
  - Pagination helpers: `Page<T>` with `nextPageToken`; `AsyncPageSequence` for `for await` usage.
- `ModelsClient`
  - `list()` returning page/async sequence.
- `CompletionsClient` (legacy)
  - Basic parity for older apps; mark deprecated in docs.
- `Beta` namespace
  - `MessagesClient` variant that injects `anthropic-beta` header (`params.betas` + required tool/file betas).
  - `FilesClient`: `list`, `upload(multipart)`, `download` (binary), `retrieveMetadata`, `delete`, header `files-api-2025-04-14` plus user betas.
  - `SkillsClient`: `create` (multipart), `retrieve`, `list`, `delete`, nested `versions` CRUD, header `skills-2025-10-02` plus user betas.

Streaming design
----------------
- SSE parser reading from `URLSession` data task with `AsyncBytes` or delegate; parse `event:`/`data:` chunks into `MessageStreamEvent`.
- Expose `MessageEventStream: AsyncSequence` yielding events; provide helpers:
  - `onText`, `onToolUse`, `onMessageStart/Stop` callbacks.
  - `finalMessage()` accumulator building `Message` from events (mirrors TS `MessageStream`).
- Cancellation: task cancellation and explicit `stream.cancel()` that calls `URLSessionTask.cancel()`; surface cancellation errors distinctly.

Uploads & downloads
-------------------
- Multipart builder that streams body to avoid loading large files in memory; support `Data`, `URL` (file path), `InputStream`.
- Set `Content-Type` from caller or guess (MIME lookup) but allow override (TS recommends explicit type).
- Downloads return `URLResponse` + `Data` or `AsyncSequence<Data>` for large files; allow writing to file URL.

Tooling helpers (optional layer)
--------------------------------
- `ToolDescriptor` (name, description, input schema via Swift `Codable`), `ToolRun` closure returning `ToolResult`.
- `ToolRunner` convenience that inspects streamed tool calls, executes registered tools, and feeds results back via follow-up message call (mirroring TS helpers). Implement after core parity to keep risk isolated.

Platform & SwiftUI considerations
---------------------------------
- All public types `Sendable`. Avoid `AnyObject` unless necessary; favor structs.
- Provide `@MainActor` convenience wrappers for SwiftUI integration (e.g., `MessageViewModel` sample) in a Samples target, not in core library.
- Use `URLSessionConfiguration.ephemeral` default; allow caller to inject config for proxy/caching.
- Concurrency: async/await; no Combine dependency. Provide completion-handler shims for UIKit/AppKit callers if needed (low priority).

Testing & validation
--------------------
- Unit tests with `XCTest` using custom `URLProtocol` stubs for request building, headers, retries, and SSE parsing.
- Streaming tests with recorded SSE fixtures from TS SDK samples.
- Multipart tests asserting boundaries and content-disposition.
- Pagination tests to ensure `for await` walks multiple pages.
- Error mapping tests for each status code and request-id propagation.
- Integration smoke tests gated by `ANTHROPIC_API_KEY` env (optional, off by default) hitting `/v1/models`.

Documentation & samples
-----------------------
- DocC catalog with quickstart, streaming example, tool-use example, file upload example, and SwiftUI sample view.
- README for the package explaining configuration, supported endpoints, beta usage, and limitations.

Implementation phases
---------------------
1) Scaffold package: `Package.swift`, core config/error types, HTTP client with retries, JSON coding strategies, logging hook.  
2) Implement Messages (create, stream, countTokens) + streaming parser + accumulation helper; add structured-output helper (response_format or single-tool) with `Decodable` decode + retry-on-decode option; basic tests.  
3) Implement MessageBatches + pagination utilities; add Models + legacy Completions.  
4) Implement Beta namespace: messages (beta headers), files (multipart, download), skills (with versions).  
5) Add optional ToolRunner helper; polish public API ergonomics and async sequence helpers.  
6) DocC + README + sample SwiftUI view; finalize tests (unit + optional live smoke).  
7) Wire into the app via Swift Package (keep dependency one-way to preserve isolation).
