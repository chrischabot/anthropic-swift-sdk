# Agent Playbook

## Mission
Build and exercise the Anthropic Swift SDK (Swift 6, iOS 18 / macOS 15 / visionOS 2) without leaking secrets. Keep edits surgical and tests fast.

## Repo layout (what matters)
- `Package.swift` — platforms + targets.
- `Sources/AnthropicSwift/` — library code.
  - `Core/` — config, errors, HTTP client, JSON coding.
  - `Messages/` — messages client, batches.
  - `Models/` — models client.
  - `Streaming/` — SSE parser and message stream helper.
  - `Pagination/` — page + async sequence helper.
- `Tests/AnthropicSwiftTests/` — unit + opt-in integration tests.

## Building blocks (current state)
- `AnthropicClient` exposes `messages`, `messages.batches`, `models`.
- Messages:
  - `create(params)` -> `MessageResponse`.
  - `createStructured(params, decodeAs:)` -> decodes JSON from text content.
  - `stream(params)` -> `MessageStream` (`AsyncThrowingStream` + `finalMessage()` accumulator).
  - `countTokens(params)`.
- Batches: create/retrieve/cancel/list + async pagination via `PageSequence`.
- Models: list.
- HTTP:
  - `ClientConfiguration` for apiKey/baseURL/version/betas/timeout/retries/logging placeholder.
  - Retries with exponential backoff on retryable errors.
  - Streaming via SSE (`URLSession.bytes`).
  - JSON coder uses snake_case, ISO8601 dates.

## How to test
- Unit tests: `swift test` (fast, no network).
- Integration smoke tests: require `ANTHROPIC_API_KEY` in the environment; otherwise they no-op.
  - Run: `ANTHROPIC_API_KEY=sk-... swift test --filter IntegrationTests`.
  - They call `/v1/models` and `/v1/messages` with a tiny prompt. They tolerate credit errors.

## Coding guidelines for agents
- Do not hardcode API keys. Always read `ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]`.
- Default to `AsyncSequence` for streaming and pagination.
- Keep models `Codable` + `Sendable`. Use snake_case coding strategies.
- Prefer pure Foundation; no third-party deps.
- Add lightweight comments only where intent is non-obvious.
- For new endpoints, mirror the TypeScript SDK shape but stay Swifty in naming.
- When adding tests, prefer `URLProtocol` stubs for unit coverage; keep live calls opt-in.

## Common commands
- Build/test: `swift test`
- Lint/format: use `swift-format` if added; otherwise keep Swift style idiomatic.
- Generate docs (future): `swift package generate-documentation` (requires DocC toolchain).

## Future work (top of mind)
- Beta namespaces: files (multipart), skills, messages beta header support.
- Tool-runner helper for structured output via tools when response_format is unavailable.
- Logging hooks and user-agent metadata.
