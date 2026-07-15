import Foundation
import os

enum AppLog {
    private static let logger = Logger(subsystem: "org.draken.usagi", category: "app")

    static func debug(_ message: String, file: String = #fileID, line: Int = #line) {
        #if DEBUG
        logger.debug("[\(file):\(line)] \(message, privacy: .public)")
        #endif
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String, error: Error? = nil) {
        if let error {
            logger.error("\(message, privacy: .public) — \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
    }
}
