import Foundation

public protocol Logger: Sendable {
    func log(level: LogLevel, message: String)
}

struct DefaultLogger: Logger {
    func log(level: LogLevel, message: String) {
        guard level != .off else { return }
        print("[\(level.rawValue.uppercased())] \(message)")
    }
}
