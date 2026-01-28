import Foundation

/// Generates filenames based on configurable templates
public final class FilenameGenerator {
    public static let shared = FilenameGenerator()

    private var dailyCounter: Int = 1
    private var lastCounterDate: String = ""

    private init() {}

    /// Generates a filename from a template for a capture result
    public func generate(for result: CaptureResult) -> String {
        let config = ConfigManager.shared.config
        return generate(
            template: config.output.filenameTemplate,
            mode: result.mode,
            sourceApp: result.sourceApp,
            timestamp: result.timestamp
        )
    }

    /// Generates a filename from a template
    public func generate(
        template: String,
        mode: CaptureMode,
        sourceApp: String?,
        timestamp: Date = Date()
    ) -> String {
        var result = template

        // {datetime} - Full date and time: 2025-01-26_143052
        let datetimeFormatter = DateFormatter()
        datetimeFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        result = result.replacingOccurrences(of: "{datetime}", with: datetimeFormatter.string(from: timestamp))

        // {date} - Date only: 2025-01-26
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: timestamp)
        result = result.replacingOccurrences(of: "{date}", with: dateString)

        // {time} - Time only: 143052
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"
        result = result.replacingOccurrences(of: "{time}", with: timeFormatter.string(from: timestamp))

        // {timestamp} - Unix timestamp
        let unixTimestamp = Int(timestamp.timeIntervalSince1970)
        result = result.replacingOccurrences(of: "{timestamp}", with: String(unixTimestamp))

        // {mode} - Capture mode: area, full, window
        result = result.replacingOccurrences(of: "{mode}", with: mode.rawValue)

        // {app} - Source application name
        let appName = sourceApp ?? "Unknown"
        let sanitizedAppName = sanitizeForFilename(appName)
        result = result.replacingOccurrences(of: "{app}", with: sanitizedAppName)

        // {counter} - Daily counter: 001, 002, etc.
        let counter = getNextCounter(for: dateString)
        result = result.replacingOccurrences(of: "{counter}", with: String(format: "%03d", counter))

        // Ensure filename is valid
        return sanitizeForFilename(result)
    }

    /// Gets the next counter value, resetting daily
    private func getNextCounter(for date: String) -> Int {
        if date != lastCounterDate {
            lastCounterDate = date
            dailyCounter = 1
        }
        let counter = dailyCounter
        dailyCounter += 1
        return counter
    }

    /// Resets the daily counter (for testing)
    public func resetCounter() {
        dailyCounter = 1
        lastCounterDate = ""
    }

    /// Sanitizes a string for use in a filename
    public func sanitizeForFilename(_ input: String) -> String {
        // Characters not allowed in filenames
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var sanitized = input

        // Remove or replace invalid characters
        sanitized = sanitized.components(separatedBy: invalidCharacters).joined(separator: "-")

        // Trim whitespace and dots from beginning/end
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        // Replace multiple consecutive dashes with single dash
        while sanitized.contains("--") {
            sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
        }

        // Ensure not empty
        if sanitized.isEmpty {
            sanitized = "screenshot"
        }

        // Limit length
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
        }

        return sanitized
    }

    /// Returns available template variables with descriptions
    public static var availableVariables: [(variable: String, description: String, example: String)] {
        return [
            ("{datetime}", "Full date and time", "2025-01-26_143052"),
            ("{date}", "Date only", "2025-01-26"),
            ("{time}", "Time only", "143052"),
            ("{timestamp}", "Unix timestamp", "1706280652"),
            ("{mode}", "Capture mode", "area, full, window"),
            ("{app}", "Source application", "Safari, Finder"),
            ("{counter}", "Daily counter", "001, 002")
        ]
    }
}
