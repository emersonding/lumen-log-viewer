//
//  SyntaxHighlighterManualTest.swift
//  LogViewerTests
//
//  Manual verification test for SyntaxHighlighter
//

import Foundation
import SwiftUI

// Note: This is a manual verification file, not an XCTest
// Run this to verify SyntaxHighlighter works independently

/*
func manualTest() {
    let highlighter = SyntaxHighlighter()

    // Test 1: FATAL level
    let fatalEntry = LogEntry(
        lineNumber: 1,
        timestamp: Date(),
        level: .fatal,
        message: "System crash",
        rawLine: "2026-04-13T10:30:00Z [FATAL] System crash"
    )
    let fatalResult = highlighter.highlight(fatalEntry)
    print("FATAL highlighted: \(fatalResult)")

    // Test 2: ERROR level with quoted strings
    let errorEntry = LogEntry(
        lineNumber: 2,
        timestamp: Date(),
        level: .error,
        message: "Failed to connect to \"database\"",
        rawLine: "2026-04-13T10:30:00Z [ERROR] Failed to connect to \"database\""
    )
    let errorResult = highlighter.highlight(errorEntry)
    print("ERROR highlighted: \(errorResult)")

    // Test 3: No level, no timestamp
    let plainEntry = LogEntry(
        lineNumber: 3,
        level: nil,
        message: "Plain log line",
        rawLine: "Plain log line"
    )
    let plainResult = highlighter.highlight(plainEntry)
    print("Plain highlighted: \(plainResult)")

    print("All manual tests completed successfully!")
}
*/
