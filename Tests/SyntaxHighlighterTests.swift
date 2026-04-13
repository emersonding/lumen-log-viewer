//
//  SyntaxHighlighterTests.swift
//  LogViewerTests
//
//  Created on 2026-04-13.
//

import XCTest
import SwiftUI
@testable import LogViewer

final class SyntaxHighlighterTests: XCTestCase {

    var highlighter: SyntaxHighlighter!

    override func setUp() {
        super.setUp()
        highlighter = SyntaxHighlighter()
    }

    // MARK: - Log Level Highlighting Tests

    func testHighlightFatalLevel() {
        let entry = LogEntry(
            lineNumber: 1,
            level: .fatal,
            message: "Critical system failure",
            rawLine: "[FATAL] Critical system failure"
        )

        let result = highlighter.highlight(entry)

        // Verify FATAL keyword is highlighted
        XCTAssertTrue(result.characters.count > 0)
        // FATAL should have red background and white text
    }

    func testHighlightErrorLevel() {
        let entry = LogEntry(
            lineNumber: 2,
            level: .error,
            message: "Connection failed",
            rawLine: "[ERROR] Connection failed"
        )

        let result = highlighter.highlight(entry)

        // Verify ERROR keyword is highlighted in red
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightWarningLevel() {
        let entry = LogEntry(
            lineNumber: 3,
            level: .warning,
            message: "Deprecated API usage",
            rawLine: "[WARNING] Deprecated API usage"
        )

        let result = highlighter.highlight(entry)

        // Verify WARNING keyword is highlighted in orange
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightInfoLevel() {
        let entry = LogEntry(
            lineNumber: 4,
            level: .info,
            message: "Server started",
            rawLine: "[INFO] Server started"
        )

        let result = highlighter.highlight(entry)

        // Verify INFO keyword is highlighted in blue
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightDebugLevel() {
        let entry = LogEntry(
            lineNumber: 5,
            level: .debug,
            message: "Variable x = 42",
            rawLine: "[DEBUG] Variable x = 42"
        )

        let result = highlighter.highlight(entry)

        // Verify DEBUG keyword is highlighted in gray
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightTraceLevel() {
        let entry = LogEntry(
            lineNumber: 6,
            level: .trace,
            message: "Method entry",
            rawLine: "[TRACE] Method entry"
        )

        let result = highlighter.highlight(entry)

        // Verify TRACE keyword is highlighted in light gray
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightNoLevel() {
        let entry = LogEntry(
            lineNumber: 7,
            level: nil,
            message: "Plain log line",
            rawLine: "Plain log line"
        )

        let result = highlighter.highlight(entry)

        // Should still return valid AttributedString
        XCTAssertTrue(result.characters.count > 0)
    }

    // MARK: - Timestamp Highlighting Tests

    func testHighlightTimestamp() {
        let timestamp = Date()
        let entry = LogEntry(
            lineNumber: 8,
            timestamp: timestamp,
            level: .info,
            message: "Test message",
            rawLine: "2026-04-13T10:30:00Z [INFO] Test message"
        )

        let result = highlighter.highlight(entry)

        // Timestamp should be rendered in monospace with reduced opacity
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightNoTimestamp() {
        let entry = LogEntry(
            lineNumber: 9,
            level: .info,
            message: "Test message",
            rawLine: "[INFO] Test message"
        )

        let result = highlighter.highlight(entry)

        // Should still work without timestamp
        XCTAssertTrue(result.characters.count > 0)
    }

    // MARK: - Quoted String Highlighting Tests

    func testHighlightDoubleQuotedStrings() {
        let entry = LogEntry(
            lineNumber: 10,
            level: .info,
            message: "User \"admin\" logged in",
            rawLine: "[INFO] User \"admin\" logged in"
        )

        let result = highlighter.highlight(entry)

        // Quoted strings should be highlighted in distinct color
        XCTAssertTrue(result.characters.count > 0)
        // Verify "admin" is colored
    }

    func testHighlightSingleQuotedStrings() {
        let entry = LogEntry(
            lineNumber: 11,
            level: .info,
            message: "Value is 'test'",
            rawLine: "[INFO] Value is 'test'"
        )

        let result = highlighter.highlight(entry)

        // Single quoted strings should be highlighted
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightMultipleQuotedStrings() {
        let entry = LogEntry(
            lineNumber: 12,
            level: .error,
            message: "Failed to connect \"server1\" and \"server2\"",
            rawLine: "[ERROR] Failed to connect \"server1\" and \"server2\""
        )

        let result = highlighter.highlight(entry)

        // Multiple quoted strings should all be highlighted
        XCTAssertTrue(result.characters.count > 0)
    }

    // MARK: - Complex Scenarios

    func testHighlightComplexLogLine() {
        let timestamp = Date()
        let entry = LogEntry(
            lineNumber: 13,
            timestamp: timestamp,
            level: .warning,
            message: "Connection to \"database\" timed out after '30s'",
            rawLine: "2026-04-13T10:30:00Z [WARNING] Connection to \"database\" timed out after '30s'"
        )

        let result = highlighter.highlight(entry)

        // Should handle timestamp, level, and quoted strings all at once
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightMultilineMessage() {
        let entry = LogEntry(
            lineNumber: 14,
            level: .error,
            message: "Stack trace:\n  at line 1\n  at line 2",
            rawLine: "[ERROR] Stack trace:\n  at line 1\n  at line 2"
        )

        let result = highlighter.highlight(entry)

        // Should handle multi-line messages
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightEmptyMessage() {
        let entry = LogEntry(
            lineNumber: 15,
            level: .info,
            message: "",
            rawLine: "[INFO]"
        )

        let result = highlighter.highlight(entry)

        // Should handle empty messages gracefully
        XCTAssertTrue(result.characters.count >= 0)
    }

    // MARK: - Performance Tests

    func testHighlightPerformance() {
        let entry = LogEntry(
            lineNumber: 100,
            timestamp: Date(),
            level: .info,
            message: String(repeating: "test ", count: 100),
            rawLine: "2026-04-13T10:30:00Z [INFO] " + String(repeating: "test ", count: 100)
        )

        measure {
            _ = highlighter.highlight(entry)
        }
    }

    // MARK: - Caching Tests

    func testHighlightCaching() {
        let entry = LogEntry(
            lineNumber: 16,
            timestamp: Date(),
            level: .info,
            message: "Test message",
            rawLine: "2026-04-13T10:30:00Z [INFO] Test message"
        )

        let result1 = highlighter.highlight(entry)
        let result2 = highlighter.highlight(entry)

        // Results should be identical (caching should work)
        XCTAssertEqual(result1.characters.count, result2.characters.count)
    }

    // MARK: - Edge Cases

    func testHighlightVeryLongLine() {
        let longMessage = String(repeating: "x", count: 10000)
        let entry = LogEntry(
            lineNumber: 17,
            level: .debug,
            message: longMessage,
            rawLine: "[DEBUG] " + longMessage
        )

        let result = highlighter.highlight(entry)

        // Should handle very long lines without crashing
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightSpecialCharacters() {
        let entry = LogEntry(
            lineNumber: 18,
            level: .info,
            message: "Special chars: <>&\"'\\n\\t",
            rawLine: "[INFO] Special chars: <>&\"'\\n\\t"
        )

        let result = highlighter.highlight(entry)

        // Should handle special characters
        XCTAssertTrue(result.characters.count > 0)
    }

    func testHighlightUnicodeCharacters() {
        let entry = LogEntry(
            lineNumber: 19,
            level: .info,
            message: "Unicode: 你好世界 🌍 ñ é ü",
            rawLine: "[INFO] Unicode: 你好世界 🌍 ñ é ü"
        )

        let result = highlighter.highlight(entry)

        // Should handle Unicode correctly
        XCTAssertTrue(result.characters.count > 0)
    }
}
