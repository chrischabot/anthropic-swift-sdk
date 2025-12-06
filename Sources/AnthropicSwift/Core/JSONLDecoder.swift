import Foundation

enum JSONLDecoder {
    static func decodeLines<T: Decodable & Sendable>(
        bytes: URLSession.AsyncBytes,
        as type: T.Type
    ) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        guard !line.isEmpty else { continue }
                        if let data = line.data(using: .utf8) {
                            let decoded = try JSONCoding.decoder.decode(T.self, from: data)
                            continuation.yield(decoded)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
