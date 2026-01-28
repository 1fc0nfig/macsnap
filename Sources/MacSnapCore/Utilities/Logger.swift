import Foundation

/// Simple logging utility for MacSnap with conditional compilation
public enum Logger {
    /// Log levels
    public enum Level: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        public static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }

        var prefix: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            }
        }
    }

    /// Current minimum log level (can be changed at runtime)
    public static var minimumLevel: Level = {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }()

    /// Whether logging is enabled
    public static var isEnabled: Bool = true

    /// Log a debug message (only in DEBUG builds by default)
    public static func debug(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message(), file: file, function: function, line: line)
    }

    /// Log an info message
    public static func info(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message(), file: file, function: function, line: line)
    }

    /// Log a warning message
    public static func warning(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message(), file: file, function: function, line: line)
    }

    /// Log an error message
    public static func error(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message(), file: file, function: function, line: line)
    }

    private static func log(level: Level, message: String, file: String, function: String, line: Int) {
        guard isEnabled, level >= minimumLevel else { return }

        let filename = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())

        #if DEBUG
        print("[\(timestamp)] MacSnap [\(level.prefix)] \(filename):\(line) - \(message)")
        #else
        // In release builds, only log warnings and errors to NSLog
        if level >= .warning {
            NSLog("MacSnap [\(level.prefix)]: \(message)")
        }
        #endif
    }
}
