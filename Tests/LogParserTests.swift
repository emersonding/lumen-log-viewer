//
//  LogParserTests.swift
//  LogViewer
//
//  Created on 2026-04-13.
//

import XCTest
@testable import LogViewer

final class LogParserTests: XCTestCase {
    var parser: LogParser!

    override func setUp() {
        super.setUp()
        parser = LogParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Timestamp Parsing Tests

    func testParseISO8601Timestamp() async {
        let logData = """
        2026-04-13T10:30:00Z INFO Test message
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertNotNil(entries[0].timestamp)
        XCTAssertEqual(entries[0].level, .info)
        XCTAssertEqual(entries[0].message, "Test message")
    }

    func testParseISO8601WithTimezone() async {
        let logData = """
        2026-04-13T10:30:00+08:00 ERROR Error with timezone
        2026-04-13T10:30:00-05:00 WARNING Warning with negative offset
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 2)
        XCTAssertNotNil(entries[0].timestamp)
        XCTAssertEqual(entries[0].level, .error)
        XCTAssertNotNil(entries[1].timestamp)
        XCTAssertEqual(entries[1].level, .warning)
    }

    func testParseSyslogTimestamp() async {
        let logData = """
        Apr 13 10:30:00 DEBUG Syslog format
        Jan  1 00:00:00 INFO New year message
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 2)
        XCTAssertNotNil(entries[0].timestamp)
        XCTAssertEqual(entries[0].level, .debug)
        XCTAssertNotNil(entries[1].timestamp)
        XCTAssertEqual(entries[1].level, .info)
    }

    func testParseUnixEpochTimestamp() async {
        let logData = """
        1713006600 TRACE Unix epoch integer
        1713006600.123456 DEBUG Unix epoch float
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 2)
        XCTAssertNotNil(entries[0].timestamp)
        XCTAssertEqual(entries[0].level, .trace)
        XCTAssertNotNil(entries[1].timestamp)
        XCTAssertEqual(entries[1].level, .debug)
    }

    // MARK: - Log Level Tests

    func testParseAllLogLevels() async {
        let logData = """
        2026-04-13T10:30:00Z FATAL Fatal error
        2026-04-13T10:30:01Z ERROR Error message
        2026-04-13T10:30:02Z WARNING Warning message
        2026-04-13T10:30:03Z INFO Info message
        2026-04-13T10:30:04Z DEBUG Debug message
        2026-04-13T10:30:05Z TRACE Trace message
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 6)
        XCTAssertEqual(entries[0].level, .fatal)
        XCTAssertEqual(entries[1].level, .error)
        XCTAssertEqual(entries[2].level, .warning)
        XCTAssertEqual(entries[3].level, .info)
        XCTAssertEqual(entries[4].level, .debug)
        XCTAssertEqual(entries[5].level, .trace)
    }

    func testParseLogLevelAliases() async {
        let logData = """
        2026-04-13T10:30:00Z WARN This is a warning
        2026-04-13T10:30:01Z CRITICAL This is critical
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].level, .warning) // WARN → WARNING
        XCTAssertEqual(entries[1].level, .fatal)   // CRITICAL → FATAL
    }

    func testParseNoLogLevel() async {
        let logData = """
        2026-04-13T10:30:00Z Just a message without level
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries[0].level)
        XCTAssertEqual(entries[0].message, "Just a message without level")
    }

    func testParseNoTimestamp() async {
        let logData = """
        ERROR Message without timestamp
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries[0].timestamp)
        XCTAssertEqual(entries[0].level, .error)
    }

    // MARK: - Multi-line Tests

    func testParseMultilineMessage() async {
        let logData = """
        2026-04-13T10:30:00Z ERROR Exception occurred:
          at function1()
          at function2()
          at function3()
        2026-04-13T10:30:01Z INFO Next message
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries[0].message.contains("Exception occurred"))
        XCTAssertTrue(entries[0].message.contains("at function1()"))
        XCTAssertTrue(entries[0].message.contains("at function2()"))
        XCTAssertTrue(entries[0].message.contains("at function3()"))
        XCTAssertEqual(entries[1].message, "Next message")
    }

    func testParseStackTrace() async {
        let logData = """
        2026-04-13T10:30:00Z FATAL Uncaught exception:
        java.lang.NullPointerException: null
            at com.example.MyClass.method(MyClass.java:42)
            at com.example.Main.main(Main.java:15)
        2026-04-13T10:30:01Z INFO Recovery attempt
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].level, .fatal)
        XCTAssertTrue(entries[0].message.contains("Uncaught exception"))
        XCTAssertTrue(entries[0].message.contains("NullPointerException"))
        XCTAssertTrue(entries[0].message.contains("MyClass.java:42"))
    }

    // MARK: - Line Number Tests

    func testLineNumbersPreserved() async {
        let logData = """
        2026-04-13T10:30:00Z INFO Line 1
        2026-04-13T10:30:01Z INFO Line 2
        2026-04-13T10:30:02Z INFO Line 3
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].lineNumber, 1)
        XCTAssertEqual(entries[1].lineNumber, 2)
        XCTAssertEqual(entries[2].lineNumber, 3)
    }

    func testLineNumbersWithMultiline() async {
        let logData = """
        2026-04-13T10:30:00Z INFO First message
        continuation line
        2026-04-13T10:30:01Z INFO Second message
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].lineNumber, 1)
        XCTAssertEqual(entries[1].lineNumber, 3)
    }

    // MARK: - Edge Cases

    func testParseEmptyInput() async {
        let logData = Data()

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 0)
    }

    func testParseInvalidUTF8() async {
        // Create data with invalid UTF-8 sequences
        var invalidData = "2026-04-13T10:30:00Z INFO Valid start ".data(using: .utf8)!
        invalidData.append(contentsOf: [0xFF, 0xFE, 0xFD]) // Invalid UTF-8
        invalidData.append(" valid end\n".data(using: .utf8)!)

        let entries = await parser.parse(invalidData)

        XCTAssertEqual(entries.count, 1)
        // Should contain replacement character U+FFFD
        XCTAssertTrue(entries[0].message.contains("Valid start"))
        XCTAssertTrue(entries[0].message.contains("valid end"))
    }

    func testParseBlankLines() async {
        let logData = """
        2026-04-13T10:30:00Z INFO First


        2026-04-13T10:30:01Z INFO Second
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        // Blank lines should be skipped
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].message, "First")
        XCTAssertEqual(entries[1].message, "Second")
    }

    func testParseMixedFormats() async {
        let logData = """
        2026-04-13T10:30:00Z INFO ISO format
        Apr 13 10:30:01 DEBUG Syslog format
        1713006602 TRACE Unix epoch
        ERROR No timestamp
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 4)
        XCTAssertNotNil(entries[0].timestamp)
        XCTAssertNotNil(entries[1].timestamp)
        XCTAssertNotNil(entries[2].timestamp)
        XCTAssertNil(entries[3].timestamp)
    }

    func testParseCaseInsensitiveLogLevels() async {
        let logData = """
        2026-04-13T10:30:00Z error lowercase error
        2026-04-13T10:30:01Z Error Mixed case error
        2026-04-13T10:30:02Z ERROR Uppercase error
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].level, .error)
        XCTAssertEqual(entries[1].level, .error)
        XCTAssertEqual(entries[2].level, .error)
    }

    func testRawLinePreserved() async {
        let logData = """
        2026-04-13T10:30:00Z INFO   Preserve   extra   spaces
        """.data(using: .utf8)!

        let entries = await parser.parse(logData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].rawLine, "2026-04-13T10:30:00Z INFO   Preserve   extra   spaces")
    }

    // MARK: - Performance Tests

    func testLargeFileYielding() async {
        // Generate 100k lines to test yielding behavior
        var largeLog = ""
        for i in 1...100000 {
            largeLog += "2026-04-13T10:30:00Z INFO Message \(i)\n"
        }
        let logData = largeLog.data(using: .utf8)!

        let startTime = Date()
        let entries = await parser.parse(logData)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(entries.count, 100000)
        // Should complete in reasonable time (< 5 seconds for 100k lines)
        XCTAssertLessThan(duration, 5.0)
    }
}
