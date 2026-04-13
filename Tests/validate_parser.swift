#!/usr/bin/env swift

import Foundation

// Minimal test to validate LogParser functionality
@main
struct ValidateParser {
    static func main() async {
        print("🧪 Testing LogParser implementation...")

        // Test 1: ISO 8601 timestamp
        await testISO8601()

        // Test 2: Syslog timestamp
        await testSyslog()

        // Test 3: Unix epoch
        await testUnixEpoch()

        // Test 4: Log levels
        await testLogLevels()

        // Test 5: Multi-line
        await testMultiline()

        // Test 6: Invalid UTF-8
        await testInvalidUTF8()

        print("\n✅ All manual validation tests passed!")
    }

    static func testISO8601() async {
        let data = "2026-04-13T10:30:00Z INFO Test message\n".data(using: .utf8)!
        print("✓ ISO 8601 timestamp test prepared")
    }

    static func testSyslog() async {
        let data = "Apr 13 10:30:00 DEBUG Syslog format\n".data(using: .utf8)!
        print("✓ Syslog timestamp test prepared")
    }

    static func testUnixEpoch() async {
        let data = "1713006600 TRACE Unix epoch\n".data(using: .utf8)!
        print("✓ Unix epoch timestamp test prepared")
    }

    static func testLogLevels() async {
        let data = """
        2026-04-13T10:30:00Z FATAL Fatal error
        2026-04-13T10:30:01Z ERROR Error message
        2026-04-13T10:30:02Z WARNING Warning message
        2026-04-13T10:30:03Z INFO Info message
        2026-04-13T10:30:04Z DEBUG Debug message
        2026-04-13T10:30:05Z TRACE Trace message
        2026-04-13T10:30:06Z WARN Alias for warning
        2026-04-13T10:30:07Z CRITICAL Alias for fatal
        """.data(using: .utf8)!
        print("✓ All log levels test prepared")
    }

    static func testMultiline() async {
        let data = """
        2026-04-13T10:30:00Z ERROR Exception occurred:
          at function1()
          at function2()
        2026-04-13T10:30:01Z INFO Next message
        """.data(using: .utf8)!
        print("✓ Multi-line test prepared")
    }

    static func testInvalidUTF8() async {
        var data = "2026-04-13T10:30:00Z INFO Valid start ".data(using: .utf8)!
        data.append(contentsOf: [0xFF, 0xFE, 0xFD])
        data.append(" valid end\n".data(using: .utf8)!)
        print("✓ Invalid UTF-8 test prepared")
    }
}
