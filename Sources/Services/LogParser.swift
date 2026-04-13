//
//  LogParser.swift
//  LogViewer
//
//  Created on 2026-04-13.
//

import Foundation

/// Parses raw log data into structured LogEntry objects.
///
/// Supports chunk-based streaming for large files: data is processed in 1MB chunks
/// with periodic yielding between chunks to keep the UI responsive.
actor LogParser {
    /// Default chunk size for processing: 1MB
    private let chunkSize = 1_048_576

    /// Parse raw data into an array of LogEntry objects.
    /// - Parameters:
    ///   - data: Raw log file data
    ///   - progress: Optional callback reporting parse progress (0.0 to 1.0)
    /// - Returns: Array of parsed log entries
    func parse(_ data: Data, progress: (@Sendable (Double) -> Void)? = nil) async -> [LogEntry] {
        let totalBytes = data.count

        guard totalBytes > 0 else {
            progress?(1.0)
            return []
        }

        // For small files (< chunkSize), use the fast single-pass path
        if totalBytes <= chunkSize {
            let content = decodeUTF8(data)
            let entries = parseContent(content, startLineNumber: 1)
            progress?(1.0)
            return entries
        }

        // Chunk-based streaming for large files
        return await parseInChunks(data: data, totalBytes: totalBytes, progress: progress)
    }

    // MARK: - Chunk-Based Parsing

    /// Parse data in chunks, yielding between each chunk for responsiveness.
    private func parseInChunks(
        data: Data,
        totalBytes: Int,
        progress: (@Sendable (Double) -> Void)?
    ) async -> [LogEntry] {
        var entries: [LogEntry] = []
        // Pre-allocate with estimate (~100 bytes per line)
        entries.reserveCapacity(totalBytes / 100)

        var currentEntry: PendingEntry?
        var lineNumber = 1
        var bytesProcessed = 0
        var lineBuffer = ""

        while bytesProcessed < totalBytes {
            let chunkEnd = min(bytesProcessed + chunkSize, totalBytes)
            let chunkData = data.subdata(in: bytesProcessed..<chunkEnd)
            var chunkString = decodeUTF8(chunkData)

            // Prepend any leftover partial line from previous chunk
            if !lineBuffer.isEmpty {
                chunkString = lineBuffer + chunkString
                lineBuffer = ""
            }

            // If not the last chunk, handle split at line boundary
            if chunkEnd < totalBytes {
                if let lastNewline = chunkString.lastIndex(where: { $0 == "\n" || $0 == "\r" }) {
                    let nextIndex = chunkString.index(after: lastNewline)
                    if nextIndex < chunkString.endIndex {
                        lineBuffer = String(chunkString[nextIndex...])
                        chunkString = String(chunkString[...lastNewline])
                    }
                } else {
                    // No newline in this chunk; buffer entirely and continue
                    lineBuffer = chunkString
                    bytesProcessed = chunkEnd
                    progress?(Double(bytesProcessed) / Double(totalBytes))
                    await Task.yield()
                    continue
                }
            }

            // Parse lines in this chunk
            let lines = chunkString.components(separatedBy: .newlines)

            for line in lines {
                // Skip blank lines
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    lineNumber += 1
                    continue
                }

                if isNewLogEntry(line) {
                    if let pending = currentEntry {
                        entries.append(pending.toLogEntry())
                    }
                    currentEntry = parseLine(line, lineNumber: lineNumber)
                    lineNumber += 1
                } else {
                    if var pending = currentEntry {
                        pending.appendContinuation(line)
                        currentEntry = pending
                    } else {
                        currentEntry = PendingEntry(
                            lineNumber: lineNumber,
                            timestamp: nil,
                            level: nil,
                            message: line,
                            rawLine: line
                        )
                    }
                    lineNumber += 1
                }
            }

            bytesProcessed = chunkEnd
            progress?(Double(bytesProcessed) / Double(totalBytes))

            // Yield between chunks to avoid blocking
            await Task.yield()
        }

        // Handle any remaining buffered content
        if !lineBuffer.isEmpty {
            let lines = lineBuffer.components(separatedBy: .newlines)
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    lineNumber += 1
                    continue
                }

                if isNewLogEntry(line) {
                    if let pending = currentEntry {
                        entries.append(pending.toLogEntry())
                    }
                    currentEntry = parseLine(line, lineNumber: lineNumber)
                    lineNumber += 1
                } else {
                    if var pending = currentEntry {
                        pending.appendContinuation(line)
                        currentEntry = pending
                    } else {
                        currentEntry = PendingEntry(
                            lineNumber: lineNumber,
                            timestamp: nil,
                            level: nil,
                            message: line,
                            rawLine: line
                        )
                    }
                    lineNumber += 1
                }
            }
        }

        // Flush the last entry
        if let pending = currentEntry {
            entries.append(pending.toLogEntry())
        }

        progress?(1.0)
        return entries
    }

    // MARK: - Single-Pass Parsing (small files)

    /// Parse content string in a single pass. Used for small files and refresh payloads.
    private func parseContent(_ content: String, startLineNumber: Int) -> [LogEntry] {
        guard !content.isEmpty else { return [] }

        let lines = content.components(separatedBy: .newlines)
        var entries: [LogEntry] = []
        var currentEntry: PendingEntry?
        var lineNumber = startLineNumber

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                lineNumber += 1
                continue
            }

            if isNewLogEntry(line) {
                if let pending = currentEntry {
                    entries.append(pending.toLogEntry())
                }
                currentEntry = parseLine(line, lineNumber: lineNumber)
                lineNumber += 1
            } else {
                if var pending = currentEntry {
                    pending.appendContinuation(line)
                    currentEntry = pending
                } else {
                    currentEntry = PendingEntry(
                        lineNumber: lineNumber,
                        timestamp: nil,
                        level: nil,
                        message: line,
                        rawLine: line
                    )
                }
                lineNumber += 1
            }
        }

        if let pending = currentEntry {
            entries.append(pending.toLogEntry())
        }

        return entries
    }

    // MARK: - UTF-8 Decoding

    /// Decode data to string, replacing invalid UTF-8 with U+FFFD.
    private func decodeUTF8(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }

    // MARK: - Private Helper Methods

    /// Determines if a line starts a new log entry
    private func isNewLogEntry(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Check for timestamp patterns
        if hasTimestamp(trimmed) {
            return true
        }

        // Check for log level at the start
        if hasLogLevelAtStart(trimmed) {
            return true
        }

        return false
    }

    /// Checks if line starts with a timestamp
    private func hasTimestamp(_ line: String) -> Bool {
        // ISO 8601: starts with 4-digit year
        if line.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil {
            return true
        }

        // Syslog: starts with month abbreviation
        let syslogPattern = #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d+"#
        if line.range(of: syslogPattern, options: .regularExpression) != nil {
            return true
        }

        // Unix epoch: starts with 10-13 digit number (possibly with decimal)
        if line.range(of: #"^\d{10,13}(\.\d+)?"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    /// Checks if line starts with a log level keyword
    private func hasLogLevelAtStart(_ line: String) -> Bool {
        let logLevelPattern = #"^(FATAL|CRITICAL|ERROR|WARN|WARNING|INFO|DEBUG|TRACE)\b"#
        return line.range(of: logLevelPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Parse a single line into a PendingEntry
    private func parseLine(_ line: String, lineNumber: Int) -> PendingEntry {
        var remaining = line

        // Extract timestamp
        let timestamp = extractTimestamp(&remaining)

        // Extract log level
        let level = extractLogLevel(&remaining)

        // What's left is the message
        let message = remaining.trimmingCharacters(in: .whitespaces)

        return PendingEntry(
            lineNumber: lineNumber,
            timestamp: timestamp,
            level: level,
            message: message,
            rawLine: line
        )
    }

    /// Extract timestamp from the beginning of a string
    private func extractTimestamp(_ line: inout String) -> Date? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Try ISO 8601 format
        if let isoDate = tryParseISO8601(trimmed, consumedLength: &line) {
            return isoDate
        }

        // Try syslog format
        if let syslogDate = tryParseSyslog(trimmed, consumedLength: &line) {
            return syslogDate
        }

        // Try Unix epoch
        if let epochDate = tryParseEpoch(trimmed, consumedLength: &line) {
            return epochDate
        }

        return nil
    }

    /// Try to parse ISO 8601 timestamp
    private func tryParseISO8601(_ line: String, consumedLength: inout String) -> Date? {
        // Pattern: 2026-04-13T10:30:00Z or 2026-04-13T10:30:00+08:00
        let pattern = #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?)"#

        guard let range = line.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let timestampString = String(line[range])
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: timestampString)

        // Try without fractional seconds if that fails
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: timestampString)
        }

        if date != nil {
            // Remove the timestamp from the line
            consumedLength = String(line[range.upperBound...])
        }

        return date
    }

    /// Try to parse syslog timestamp (e.g., "Apr 13 10:30:00")
    private func tryParseSyslog(_ line: String, consumedLength: inout String) -> Date? {
        let pattern = #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})"#

        guard let range = line.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let timestampString = String(line[range])

        // Create a date formatter for syslog format
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Syslog doesn't include year, assume current year
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let fullTimestamp = "\(timestampString) \(currentYear)"
        formatter.dateFormat = "MMM d HH:mm:ss yyyy"

        if let date = formatter.date(from: fullTimestamp) {
            consumedLength = String(line[range.upperBound...])
            return date
        }

        return nil
    }

    /// Try to parse Unix epoch timestamp
    private func tryParseEpoch(_ line: String, consumedLength: inout String) -> Date? {
        let pattern = #"^(\d{10,13}(?:\.\d+)?)"#

        guard let range = line.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let epochString = String(line[range])

        if let epochValue = Double(epochString) {
            // Unix epoch is in seconds, but could be milliseconds if > 10 digits
            let timestamp = epochValue > 10000000000 ? epochValue / 1000 : epochValue
            let date = Date(timeIntervalSince1970: timestamp)
            consumedLength = String(line[range.upperBound...])
            return date
        }

        return nil
    }

    /// Extract log level from the beginning of a string
    private func extractLogLevel(_ line: inout String) -> LogLevel? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Map of keywords to log levels (including aliases)
        let levelMap: [String: LogLevel] = [
            "FATAL": .fatal,
            "CRITICAL": .fatal,  // CRITICAL -> FATAL
            "ERROR": .error,
            "WARN": .warning,    // WARN -> WARNING
            "WARNING": .warning,
            "INFO": .info,
            "DEBUG": .debug,
            "TRACE": .trace
        ]

        // Try to match log level at the start (case-insensitive)
        for (keyword, level) in levelMap {
            let pattern = "^" + keyword + "\\b"
            if let range = trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                // Remove the log level from the line
                line = String(trimmed[range.upperBound...])
                return level
            }
        }

        // No log level found, leave line as-is
        line = trimmed
        return nil
    }
}

// MARK: - Helper Structures

/// Temporary structure for building a log entry while parsing continuation lines
private struct PendingEntry {
    let lineNumber: Int
    let timestamp: Date?
    let level: LogLevel?
    var message: String
    var rawLine: String

    mutating func appendContinuation(_ line: String) {
        message += "\n" + line
        rawLine += "\n" + line
    }

    func toLogEntry() -> LogEntry {
        LogEntry(
            lineNumber: lineNumber,
            timestamp: timestamp,
            level: level,
            message: message,
            rawLine: rawLine
        )
    }
}
