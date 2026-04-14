//
//  integration_openfile_test.swift
//  Lumen Integration Test
//
//  Manual test to verify openFile implementation
//

import Foundation
@testable import Lumen

@MainActor
func testOpenFile() async {
    print("=== Testing openFile Implementation ===\n")

    // Create test data directory
    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory.appendingPathComponent("lumen-test")
    try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

    // Create test log file
    let testLogContent = """
    2026-04-13T10:00:00Z INFO Application started
    2026-04-13T10:00:01Z DEBUG Loading configuration
    2026-04-13T10:00:02Z ERROR Failed to connect to database
    2026-04-13T10:00:03Z WARNING Retrying connection
    2026-04-13T10:00:04Z INFO Connected successfully
    """

    let testLogURL = tempDir.appendingPathComponent("test.log")
    try? testLogContent.write(to: testLogURL, atomically: true, encoding: .utf8)

    print("1. Testing successful file open...")
    let viewModel1 = LogViewModel()
    await viewModel1.openFile(url: testLogURL)

    assert(viewModel1.errorMessage == nil, "Should have no error")
    assert(!viewModel1.isLoading, "Should not be loading")
    assert(viewModel1.allEntries.count == 5, "Should have 5 entries, got \(viewModel1.allEntries.count)")
    assert(viewModel1.displayedEntries.count == 5, "Should display 5 entries")
    assert(viewModel1.currentFileURL == testLogURL, "Should store file URL")
    assert(viewModel1.currentFileOffset != nil && viewModel1.currentFileOffset! > 0, "Should store file offset")
    print("✓ Success: Loaded \(viewModel1.allEntries.count) entries")

    print("\n2. Testing file not found...")
    let viewModel2 = LogViewModel()
    let nonExistentURL = tempDir.appendingPathComponent("nonexistent.log")
    await viewModel2.openFile(url: nonExistentURL)

    assert(viewModel2.errorMessage != nil, "Should have error message")
    assert(viewModel2.allEntries.isEmpty, "Should have no entries")
    print("✓ Success: Handled file not found - \(viewModel2.errorMessage ?? "")")

    print("\n3. Testing binary file detection...")
    let binaryURL = tempDir.appendingPathComponent("binary.bin")
    var binaryData = Data("Some text".utf8)
    binaryData.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Add null bytes
    try? binaryData.write(to: binaryURL)

    let viewModel3 = LogViewModel()
    await viewModel3.openFile(url: binaryURL)

    assert(viewModel3.errorMessage != nil, "Should detect binary file")
    assert(viewModel3.errorMessage?.contains("binary") ?? false, "Error should mention binary")
    assert(viewModel3.allEntries.isEmpty, "Should have no entries")
    print("✓ Success: Detected binary file - \(viewModel3.errorMessage ?? "")")

    print("\n4. Testing filter application...")
    let viewModel4 = LogViewModel()
    viewModel4.filterState.enabledLevels = [.error]
    await viewModel4.openFile(url: testLogURL)

    assert(viewModel4.allEntries.count == 5, "Should parse all 5 entries")
    assert(viewModel4.displayedEntries.count == 1, "Should display only ERROR entry, got \(viewModel4.displayedEntries.count)")
    assert(viewModel4.displayedEntries.first?.level == .error, "Displayed entry should be ERROR level")
    print("✓ Success: Filters applied - showing \(viewModel4.displayedEntries.count) of \(viewModel4.allEntries.count) entries")

    print("\n5. Testing nil level entries always shown...")
    let viewModel5 = LogViewModel()
    viewModel5.allEntries = [
        LogEntry(lineNumber: 1, level: .error, message: "Error", rawLine: "ERROR Error"),
        LogEntry(lineNumber: 2, level: nil, message: "No level", rawLine: "No level")
    ]
    viewModel5.filterState.enabledLevels = [.error]
    viewModel5.applyFilters()

    assert(viewModel5.displayedEntries.count == 2, "Should show both ERROR and nil level, got \(viewModel5.displayedEntries.count)")
    print("✓ Success: Nil level entries always shown")

    print("\n6. Testing time range filter...")
    let now = Date()
    let hourAgo = now.addingTimeInterval(-3600)
    let twoHoursAgo = now.addingTimeInterval(-7200)

    let viewModel6 = LogViewModel()
    viewModel6.allEntries = [
        LogEntry(lineNumber: 1, timestamp: twoHoursAgo, level: .info, message: "Old", rawLine: "INFO Old"),
        LogEntry(lineNumber: 2, timestamp: hourAgo, level: .info, message: "Recent", rawLine: "INFO Recent"),
        LogEntry(lineNumber: 3, timestamp: now, level: .info, message: "Now", rawLine: "INFO Now")
    ]
    viewModel6.filterState.timeRangeStart = hourAgo
    viewModel6.applyFilters()

    assert(viewModel6.displayedEntries.count == 2, "Should show 2 entries after time filter, got \(viewModel6.displayedEntries.count)")
    print("✓ Success: Time range filter working")

    // Cleanup
    try? fileManager.removeItem(at: tempDir)

    print("\n=== All Tests Passed! ===")
}

// Run the test
Task { @MainActor in
    await testOpenFile()
    exit(0)
}

RunLoop.main.run()
