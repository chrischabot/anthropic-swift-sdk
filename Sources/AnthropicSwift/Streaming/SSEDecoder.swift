import Foundation

struct SSEDecoder {
    static func decodeLines(bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<StreamPayload, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var dataLines: [String] = []
                do {
                    for try await lineData in bytes.lines {
                        if lineData.isEmpty {
                            if !dataLines.isEmpty {
                                let dataString = dataLines.joined(separator: "\n")
                                if let payload = decodePayload(from: dataString) {
                                    continuation.yield(payload)
                                }
                                dataLines.removeAll()
                            }
                            continue
                        }

                        if lineData.hasPrefix("data:") {
                            let value = lineData.dropFirst("data:".count)
                            dataLines.append(String(value))
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

    private static func decodePayload(from dataString: String) -> StreamPayload? {
        guard let data = dataString.data(using: .utf8) else { return nil }
        return try? JSONCoding.decoder.decode(StreamPayload.self, from: data)
    }
}
