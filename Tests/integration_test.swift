// Integration test for LogParser
// Compile and run with: swiftc -parse-as-library Tests/integration_test.swift && ./integration_test

import Foundation

// Copy the essential models inline for standalone testing
enum LogLevel: String, CaseIterable {
    case fatal = "FATAL"
    case error = "ERROR"
    case warning = "WARNING"
    case info = "INFO"
    case debug = "DEBUG"
    case trace = "TRACE"
}

struct LogEntry {
    let lineNumber: Int
    let timestamp: Date?
    let level: LogLevel?
    let message: String
    let rawLine: String
}

// Simplified LogParser for integration testing
actor LogParser {
    func parse(_ data: Data) async -> [LogEntry] {
        let content = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        guard !content.isEmpty else { return [] }

        let lines = content.components(separatedBy: .newlines)
        var entries: [LogEntry] = []
        var currentEntry: PendingEntry?
        var lineNumber = 1

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

    private func isNewLogEntry(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d+"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^\d{10,13}(\.\d+)?"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^(FATAL|CRITICAL|ERROR|WARN|WARNING|INFO|DEBUG|TRACE)\b"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        return false
    }

    private func parseLine(_ line: String, lineNumber: Int) -> PendingEntry {
        var remaining = line
        let timestamp = extractTimestamp(&remaining)
        let level = extractLogLevel(&remaining)
        let message = remaining.trimmingCharacters(in: .whitespaces)
        return PendingEntry(lineNumber: lineNumber, timestamp: timestamp, level: level, message: message, rawLine: line)
    }

    private func extractTimestamp(_ line: inout String) -> Date? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // ISO 8601
        let isoPattern = #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?)"#
        if let range = trimmed.range(of: isoPattern, options: .regularExpression) {
            let timestampString = String(trimmed[range])
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var date = formatter.date(from: timestampString)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: timestampString)
            }
            if date != nil {
                line = String(trimmed[range.upperBound...])
                return date
            }
        }

        // Syslog
        let syslogPattern = #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})"#
        if let range = trimmed.range(of: syslogPattern, options: .regularExpression) {
            let timestampString = String(trimmed[range])
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d HH:mm:ss yyyy"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let currentYear = Calendar.current.component(.year, from: Date())
            if let date = formatter.date(from: "\(timestampString) \(currentYear)") {
                line = String(trimmed[range.upperBound...])
                return date
            }
        }

        // Unix epoch
        let epochPattern = #"^(\d{10,13}(?:\.\d+)?)"#
        if let range = trimmed.range(of: epochPattern, options: .regularExpression) {
            let epochString = String(trimmed[range])
            if let epochValue = Double(epochString) {
                let timestamp = epochValue > 10000000000 ? epochValue / 1000 : epochValue
                line = String(trimmed[range.upperBound...])
                return Date(timeIntervalSince1970: timestamp)
            }
        }

        return nil
    }

    private func extractLogLevel(_ line: inout String) -> LogLevel? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let levelMap: [String: LogLevel] = [
            "FATAL": .fatal, "CRITICAL": .fatal, "ERROR": .error,
            "WARN": .warning, "WARNING": .warning, "INFO": .info,
            "DEBUG": .debug, "TRACE": .trace
        ]

        for (keyword, level) in levelMap {
            let pattern = "^" + keyword + "\\b"
            if let range = trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                line = String(trimmed[range.upperBound...])
                return level
            }
        }

        line = trimmed
        return nil
    }

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
            LogEntry(lineNumber: lineNumber, timestamp: timestamp, level: level, message: message, rawLine: rawLine)
        }
    }
}

// Test runner
@main
struct IntegrationTest {
    static func main() async {
        print("🧪 Running LogParser Integration Tests\n")

        let parser = LogParser()
        var passCount = 0
        var failCount = 0

        // Test 1: ISO 8601 timestamp
        do {
            let data = "2026-04-13T10:30:00Z INFO Test message\n".data(using: .utf8)!
            let entries = await parser.parse(data)
            assert(entries.count == 1, "Expected 1 entry, got \(entries.count)")
            assert(entries[0].level == .info, "Expected INFO level")
            assert(entries[0].message == "Test message", "Unexpected message: \(entries[0].message)")
            assert(entries[0].timestamp != nil, "Expected timestamp")
            print("✅ Test 1: ISO 8601 timestamp")
            passCount += 1
        } catch {
            print("❌ Test 1 failed: \(error)")
            failCount += 1
        }

        // Test 2: All log levels
        do {
            let data = """
            2026-04-13T10:30:00Z FATAL Fatal error
            2026-04-13T10:30:01Z ERROR Error message
            2026-04-13T10:30:02Z WARNING Warning message
            2026-04-13T10:30:03Z INFO Info message
            2026-04-13T10:30:04Z DEBUG Debug message
            2026-04-13T10:30:05Z TRACE Trace message
            """.data(using: .utf8)!
            let entries = await parser.parse(data)
            assert(entries.count == 6, "Expected 6 entries, got \(entries.count)")
            assert(entries[0].level == .fatal, "Expected FATAL")
            assert(entries[1].level == .error, "Expected ERROR")
            assert(entries[2].level == .warning, "Expected WARNING")
            assert(entries[3].level == .info, "Expected INFO")
            assert(entries[4].level == .debug, "Expected DEBUG")
            assert(entries[5].level == .trace, "Expected TRACE")
            print("✅ Test 2: All log levels")
            passCount += 1
        } catch {
            print("❌ Test 2 failed: \(error)")
            failCount += 1
        }

        // Test 3: Log level aliases
        do {
            let data = """
            2026-04-13T10:30:00Z WARN Warning alias
            2026-04-13T10:30:01Z CRITICAL Fatal alias
            """.data(using: .utf8)!
            let entries = await parser.parse(data)
            assert(entries.count == 2, "Expected 2 entries")
            assert(entries[0].level == .warning, "WARN should map to WARNING")
            assert(entries[1].level == .fatal, "CRITICAL should map to FATAL")
            print("✅ Test 3: Log level aliases (WARN→WARNING, CRITICAL→FATAL)")
            passCount += 1
        } catch {
            print("❌ Test 3 failed: \(error)")
            failCount += 1
        }

        // Test 4: Multi-line message
        do {
            let data = """
            2026-04-13T10:30:00Z ERROR Exception occurred:
              at function1()
              at function2()
            2026-04-13T10:30:01Z INFO Next message
            """.data(using: .utf8)!
            let entries = await parser.parse(data)
            assert(entries.count == 2, "Expected 2 entries, got \(entries.count)")
            assert(entries[0].message.contains("Exception occurred"), "Missing first line")
            assert(entries[0].message.contains("at function1()"), "Missing continuation 1")
            assert(entries[0].message.contains("at function2()"), "Missing continuation 2")
            assert(entries[1].message == "Next message", "Second entry incorrect")
            print("✅ Test 4: Multi-line message grouping")
            passCount += 1
        } catch {
            print("❌ Test 4 failed: \(error)")
            failCount += 1
        }

        // Test 5: Syslog timestamp
        do {
            let data = "Apr 13 10:30:00 DEBUG Syslog format\n".data(using: .utf8)!
            let entries = await parser.parse(data)
            assert(entries.count == 1, "Expected 1 entry")
            assert(entries[0].timestamp != nil, "Expected timestamp")
            assert(entries[0].level == .debug, "Expected DEBUG level")
            print("✅ Test 5: Syslog timestamp")
            passCount += 1
        } catch {
            print("❌ Test 5 failed: \(error)")
            failCount += 1
        }

        // Test 6: Unix epoch timestamp
        do {
            let data = "1713006600 TRACE Unix epoch\n".data(using: .utf8)!
            let entries = await parser.parse(data)
            assert(entries.count == 1, "Expected 1 entry")
            assert(entries[0].timestamp != nil, "Expected timestamp")
            assert(entries[0].level == .trace, "Expected TRACE level")
            print("✅ Test 6: Unix epoch timestamp")
            passCount += 1
        } catch {
            print("❌ Test 6 failed: \(error)")
            failCount += 1
        }

        // Test 7: Line numbers
        do {
            let data = """
            2026-04-13T10:30:00Z INFO Line 1
            2026-04-13T10:30:01Z INFO Line 2
            2026-04-13T10:30:02Z INFO Line 3
            """.data(using: .utf8)!
            let entries = await parser.parse(data)
            assert(entries[0].lineNumber == 1, "Expected line 1")
            assert(entries[1].lineNumber == 2, "Expected line 2")
            assert(entries[2].lineNumber == 3, "Expected line 3")
            print("✅ Test 7: Line numbers preserved")
            passCount += 1
        } catch {
            print("❌ Test 7 failed: \(error)")
            failCount += 1
        }

        // Test 8: Empty input
        do {
            let data = Data()
            let entries = await parser.parse(data)
            assert(entries.count == 0, "Expected 0 entries for empty input")
            print("✅ Test 8: Empty input handling")
            passCount += 1
        } catch {
            print("❌ Test 8 failed: \(error)")
            failCount += 1
        }

        // Summary
        print("\n" + "=".repeated(50))
        print("Test Results: \(passCount) passed, \(failCount) failed")
        if failCount == 0 {
            print("🎉 All tests passed!")
        } else {
            print("⚠️  Some tests failed")
        }
    }
}

extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
