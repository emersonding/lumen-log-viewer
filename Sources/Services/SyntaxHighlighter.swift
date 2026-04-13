//
//  SyntaxHighlighter.swift
//  LogViewer
//
//  Created on 2026-04-13.
//

import Foundation
import SwiftUI

/// Syntax highlighter for log entries
/// Converts LogEntry to AttributedString with color coding
final class SyntaxHighlighter {

    // Cache for highlighted content to avoid recomputation
    private let cache = NSCache<NSString, NSAttributedString>()

    init() {
        cache.countLimit = 10000 // Limit cache size
    }

    /// Highlight a log entry with color coding
    /// - Parameter entry: The log entry to highlight
    /// - Returns: AttributedString with syntax highlighting applied
    func highlight(_ entry: LogEntry) -> AttributedString {
        // Check cache first
        let cacheKey = entry.id.uuidString as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return AttributedString(cached)
        }

        var result = AttributedString(entry.rawLine)

        // Apply timestamp highlighting
        if entry.timestamp != nil {
            highlightTimestamp(in: &result, rawLine: entry.rawLine)
        }

        // Apply log level highlighting
        if let level = entry.level {
            highlightLogLevel(in: &result, level: level, rawLine: entry.rawLine)
        }

        // Apply quoted string highlighting
        highlightQuotedStrings(in: &result, rawLine: entry.rawLine)

        // Cache the result
        let nsAttributed = NSAttributedString(result)
        cache.setObject(nsAttributed, forKey: cacheKey)

        return result
    }

    // MARK: - Private Highlighting Methods

    private func highlightTimestamp(in attributedString: inout AttributedString, rawLine: String) {
        // Find timestamp patterns at the beginning of the line
        let timestampPatterns = [
            // ISO 8601: 2026-04-13T10:30:00Z or 2026-04-13T10:30:00+00:00
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:Z|[+-]\\d{2}:\\d{2})",
            // Syslog: Apr 13 10:30:00
            "^[A-Z][a-z]{2}\\s+\\d{1,2}\\s+\\d{2}:\\d{2}:\\d{2}",
            // Unix epoch: 1681385400 or 1681385400.123
            "^\\d{10}(?:\\.\\d+)?"
        ]

        for pattern in timestampPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: rawLine, range: NSRange(rawLine.startIndex..., in: rawLine)) {
                if let range = Range(match.range, in: rawLine) {
                    let attributedRange = range.lowerBound..<range.upperBound

                    // Apply monospace font and reduced opacity
                    if let swiftRange = Range<AttributedString.Index>(attributedRange, in: attributedString) {
                        attributedString[swiftRange].font = .system(.body, design: .monospaced)
                        attributedString[swiftRange].foregroundColor = Color.secondary
                    }
                }
                break // Only highlight first match
            }
        }
    }

    private func highlightLogLevel(in attributedString: inout AttributedString, level: LogLevel, rawLine: String) {
        // Find the log level keyword in the raw line
        let levelPattern = "\\[?\(level.rawValue)\\]?"

        guard let regex = try? NSRegularExpression(pattern: levelPattern, options: .caseInsensitive) else {
            return
        }

        if let match = regex.firstMatch(in: rawLine, range: NSRange(rawLine.startIndex..., in: rawLine)),
           let range = Range(match.range, in: rawLine) {
            let attributedRange = range.lowerBound..<range.upperBound

            if let swiftRange = Range<AttributedString.Index>(attributedRange, in: attributedString) {
                // Apply level-specific colors
                if let foreground = level.foregroundColor {
                    attributedString[swiftRange].foregroundColor = foreground
                }

                if let background = level.backgroundColor {
                    attributedString[swiftRange].backgroundColor = background
                }

                // Make level keywords bold for emphasis
                attributedString[swiftRange].font = .system(.body, design: .default, weight: .bold)
            }
        }
    }

    private func highlightQuotedStrings(in attributedString: inout AttributedString, rawLine: String) {
        // Match both double and single quoted strings
        let quotedPattern = #"\"[^\"]*\"|'[^']*'"#

        guard let regex = try? NSRegularExpression(pattern: quotedPattern) else {
            return
        }

        let matches = regex.matches(in: rawLine, range: NSRange(rawLine.startIndex..., in: rawLine))

        for match in matches {
            if let range = Range(match.range, in: rawLine) {
                let attributedRange = range.lowerBound..<range.upperBound

                if let swiftRange = Range<AttributedString.Index>(attributedRange, in: attributedString) {
                    // Color quoted strings in a distinct color (teal/cyan)
                    #if os(macOS)
                    attributedString[swiftRange].foregroundColor = Color(nsColor: .systemTeal)
                    #else
                    attributedString[swiftRange].foregroundColor = .teal
                    #endif
                }
            }
        }
    }
}

// MARK: - LogEntry Extension for Caching

extension LogEntry {
    /// Cached highlighted content
    /// Note: This is a computed property that uses SyntaxHighlighter's internal cache
    var highlightedContent: AttributedString {
        let highlighter = SyntaxHighlighter()
        return highlighter.highlight(self)
    }
}
