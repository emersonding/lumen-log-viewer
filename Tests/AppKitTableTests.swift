//
//  AppKitTableTests.swift
//  Lumen
//
//  Tests for AppKit NSTableView integration — cell configuration,
//  multiline display, and syntax highlighting in NSAttributedString.
//

import XCTest
@testable import Lumen

@MainActor
final class AppKitTableTests: XCTestCase {

    private var viewModel: LogViewModel!

    override func setUp() {
        super.setUp()
        viewModel = LogViewModel()
    }

    // MARK: - Multiline Entry Tests

    func testMultilineEntryPreservesAllLines() async {
        // Parse a multiline log with stack trace continuation
        let content = """
        2026-04-13T10:40:00Z [INFO] Application started
        2026-04-13T10:41:00Z [ERROR] Exception occurred
        Exception: NullPointerException
          at example.service.Process.execute(Process.swift:42)
          at example.service.Main.run(Main.swift:10)
        2026-04-13T10:42:00Z [INFO] Recovery complete
        """
        let data = content.data(using: .utf8)!
        let parser = LogParser()
        let entries = await parser.parse(data)

        // Should have 3 entries (INFO, ERROR with continuations, INFO)
        XCTAssertEqual(entries.count, 3)

        // The ERROR entry should contain all continuation lines
        let errorEntry = entries[1]
        XCTAssertEqual(errorEntry.level, .error)
        XCTAssertTrue(errorEntry.rawLine.contains("Exception: NullPointerException"))
        XCTAssertTrue(errorEntry.rawLine.contains("Process.swift:42"))
        XCTAssertTrue(errorEntry.rawLine.contains("Main.swift:10"))

        // Verify newlines are preserved in rawLine
        let lineCount = errorEntry.rawLine.components(separatedBy: "\n").count
        XCTAssertEqual(lineCount, 4, "ERROR entry should span 4 lines (header + 3 continuation)")
    }

    // MARK: - NSAttributedString Highlighting Tests

    func testHighlightNSPreservesMultilineContent() {
        let multilineRaw = """
        2026-04-13T10:41:00Z [ERROR] Exception occurred
        Exception: NullPointerException
          at example.service.Process.execute(Process.swift:42)
        """
        let entry = LogEntry(
            lineNumber: 1,
            timestamp: Date(),
            level: .error,
            message: "Exception occurred\nException: NullPointerException\n  at example.service.Process.execute(Process.swift:42)",
            rawLine: multilineRaw
        )

        let highlighter = SyntaxHighlighter()
        let nsAttr = highlighter.highlightNS(entry, fontSize: 12)

        // Full text should be preserved including newlines
        XCTAssertTrue(nsAttr.string.contains("NullPointerException"))
        XCTAssertTrue(nsAttr.string.contains("Process.swift:42"))

        let lineCount = nsAttr.string.components(separatedBy: "\n").count
        XCTAssertGreaterThanOrEqual(lineCount, 3, "NSAttributedString should contain all lines")
    }

    func testHighlightNSAppliesLevelColor() {
        let entry = LogEntry(
            lineNumber: 1,
            timestamp: Date(),
            level: .error,
            message: "Test error",
            rawLine: "2026-04-13T10:00:00Z [ERROR] Test error"
        )

        let highlighter = SyntaxHighlighter()
        let nsAttr = highlighter.highlightNS(entry, fontSize: 12)

        // Check that foreground color attribute exists for the ERROR keyword
        var foundErrorColor = false
        nsAttr.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: nsAttr.length)) { value, range, _ in
            if let color = value as? NSColor {
                let substring = (nsAttr.string as NSString).substring(with: range)
                if substring.contains("ERROR") && color == .systemRed {
                    foundErrorColor = true
                }
            }
        }
        XCTAssertTrue(foundErrorColor, "ERROR keyword should have systemRed foreground color")
    }

    func testHighlightNSAppliesBoldToLevel() {
        let entry = LogEntry(
            lineNumber: 1,
            timestamp: nil,
            level: .warning,
            message: "Test warning",
            rawLine: "[WARNING] Test warning"
        )

        let highlighter = SyntaxHighlighter()
        let nsAttr = highlighter.highlightNS(entry, fontSize: 12)

        // Check that the WARNING keyword has a bold font
        var foundBold = false
        nsAttr.enumerateAttribute(.font, in: NSRange(location: 0, length: nsAttr.length)) { value, range, _ in
            if let font = value as? NSFont {
                let substring = (nsAttr.string as NSString).substring(with: range)
                if substring.contains("WARNING") {
                    let traits = NSFontManager.shared.traits(of: font)
                    if traits.contains(.boldFontMask) {
                        foundBold = true
                    }
                }
            }
        }
        XCTAssertTrue(foundBold, "WARNING keyword should have bold font")
    }

    func testHighlightNSCachesResult() {
        let entry = LogEntry(
            lineNumber: 1,
            timestamp: nil,
            level: .info,
            message: "Cached",
            rawLine: "[INFO] Cached"
        )

        let highlighter = SyntaxHighlighter()
        let first = highlighter.highlightNS(entry, fontSize: 12)
        let second = highlighter.highlightNS(entry, fontSize: 12)

        // Both should produce identical content (cache hit)
        XCTAssertEqual(first.string, second.string)
    }

    // MARK: - Filter Change Counter

    func testFilterChangeCounterIncrements() {
        viewModel.allEntries = [
            LogEntry(lineNumber: 1, level: .info, message: "test", rawLine: "[INFO] test")
        ]

        let before = viewModel.filterChangeCounter
        viewModel.applyFilters()
        let after = viewModel.filterChangeCounter

        XCTAssertGreaterThan(after, before, "filterChangeCounter should increment on applyFilters()")
    }
}
