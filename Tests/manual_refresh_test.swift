#!/usr/bin/env swift
//
//  manual_refresh_test.swift
//  LogViewer
//
//  Manual test for refresh functionality
//

import Foundation

// Add the source path
#if canImport(LogViewer)
import LogViewer
#else
// Inline minimal types for standalone execution
@MainActor
class TestViewModel {
    var allEntries: [String] = []
    var currentFileOffset: Int? = nil
    var partialLineBuffer: String? = nil

    func refresh(fileURL: URL) async throws {
        guard let currentOffset = currentFileOffset else {
            print("❌ No offset stored")
            return
        }

        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        try fileHandle.seek(toOffset: UInt64(currentOffset))
        let newData = fileHandle.readDataToEndOfFile()

        var newContent = String(data: newData, encoding: .utf8) ?? ""

        if let bufferedLine = partialLineBuffer {
            newContent = bufferedLine + newContent
            partialLineBuffer = nil
        }

        let endsWithNewline = newContent.hasSuffix("\n")

        if !endsWithNewline && !newContent.isEmpty {
            if let lastNewlineIndex = newContent.lastIndex(where: { $0 == "\n" }) {
                let nextIndex = newContent.index(after: lastNewlineIndex)
                partialLineBuffer = String(newContent[nextIndex...])
                newContent = String(newContent[...lastNewlineIndex])
            } else {
                partialLineBuffer = newContent
                newContent = ""
            }
        }

        if !newContent.isEmpty {
            let lines = newContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            allEntries.append(contentsOf: lines)

            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attrs[.size] as? Int64) ?? 0
            currentFileOffset = Int(fileSize) - (partialLineBuffer?.utf8.count ?? 0)
        }
    }
}
#endif

@MainActor
func runTests() async {
    print("🧪 Manual Refresh Logic Tests\n")

    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("refresh_test_\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: testDir)
    }

    // Test 1: Incremental read
    print("Test 1: Incremental read only new bytes")
    do {
        let fileURL = testDir.appendingPathComponent("test1.log")
        let initial = "Line 1\nLine 2\n"
        try initial.write(to: fileURL, atomically: true, encoding: .utf8)

        let vm = TestViewModel()
        vm.currentFileOffset = initial.utf8.count
        vm.allEntries = ["Line 1", "Line 2"]

        // Append new content
        let handle = try FileHandle(forWritingTo: fileURL)
        handle.seekToEndOfFile()
        handle.write("Line 3\n".data(using: .utf8)!)
        try handle.close()

        try await vm.refresh(fileURL: fileURL)

        if vm.allEntries.count == 3 && vm.allEntries.last == "Line 3" {
            print("✅ PASS: New line appended correctly")
        } else {
            print("❌ FAIL: Expected 3 entries, got \(vm.allEntries.count)")
        }
    } catch {
        print("❌ FAIL: \(error)")
    }

    // Test 2: Partial line handling
    print("\nTest 2: Partial line handling")
    do {
        let fileURL = testDir.appendingPathComponent("test2.log")
        let initial = "Complete line\nIncomplete"
        try initial.write(to: fileURL, atomically: true, encoding: .utf8)

        let vm = TestViewModel()
        vm.currentFileOffset = 0

        try await vm.refresh(fileURL: fileURL)

        if vm.allEntries.count == 1 && vm.partialLineBuffer == "Incomplete" {
            print("✅ PASS: Partial line buffered correctly")
        } else {
            print("❌ FAIL: Expected 1 entry and buffered line, got \(vm.allEntries.count) entries")
        }

        // Complete the line
        let handle = try FileHandle(forWritingTo: fileURL)
        handle.seekToEndOfFile()
        handle.write(" line completed\n".data(using: .utf8)!)
        try handle.close()

        try await vm.refresh(fileURL: fileURL)

        if vm.allEntries.count == 2 && vm.allEntries.last?.contains("Incomplete line completed") == true {
            print("✅ PASS: Partial line completed and parsed")
        } else {
            print("❌ FAIL: Expected completed line, got: \(vm.allEntries.last ?? "nil")")
        }
    } catch {
        print("❌ FAIL: \(error)")
    }

    // Test 3: Empty refresh
    print("\nTest 3: Empty refresh (no new data)")
    do {
        let fileURL = testDir.appendingPathComponent("test3.log")
        let initial = "Line 1\n"
        try initial.write(to: fileURL, atomically: true, encoding: .utf8)

        let vm = TestViewModel()
        vm.currentFileOffset = initial.utf8.count
        vm.allEntries = ["Line 1"]

        try await vm.refresh(fileURL: fileURL)

        if vm.allEntries.count == 1 {
            print("✅ PASS: No change when no new data")
        } else {
            print("❌ FAIL: Expected 1 entry, got \(vm.allEntries.count)")
        }
    } catch {
        print("❌ FAIL: \(error)")
    }

    // Test 4: Multiple partial lines
    print("\nTest 4: Multiple refreshes with partial lines")
    do {
        let fileURL = testDir.appendingPathComponent("test4.log")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let vm = TestViewModel()
        vm.currentFileOffset = 0

        // First refresh: partial line
        var handle = try FileHandle(forWritingTo: fileURL)
        handle.seekToEndOfFile()
        handle.write("First par".data(using: .utf8)!)
        try handle.close()

        try await vm.refresh(fileURL: fileURL)

        if vm.partialLineBuffer == "First par" && vm.allEntries.isEmpty {
            print("✅ PASS: First partial buffered")
        } else {
            print("❌ FAIL: First partial not buffered correctly")
        }

        // Second refresh: complete first, start second
        handle = try FileHandle(forWritingTo: fileURL)
        handle.seekToEndOfFile()
        handle.write("t\nSecond par".data(using: .utf8)!)
        try handle.close()

        try await vm.refresh(fileURL: fileURL)

        if vm.allEntries.count == 1 && vm.allEntries[0] == "First part" && vm.partialLineBuffer == "Second par" {
            print("✅ PASS: First completed, second buffered")
        } else {
            print("❌ FAIL: Got \(vm.allEntries.count) entries, buffer: \(vm.partialLineBuffer ?? "nil")")
            print("   Entries: \(vm.allEntries)")
        }

        // Third refresh: complete second
        handle = try FileHandle(forWritingTo: fileURL)
        handle.seekToEndOfFile()
        handle.write("t\n".data(using: .utf8)!)
        try handle.close()

        try await vm.refresh(fileURL: fileURL)

        if vm.allEntries.count == 2 && vm.allEntries[1] == "Second part" && vm.partialLineBuffer == nil {
            print("✅ PASS: Second completed, buffer cleared")
        } else {
            print("❌ FAIL: Expected 2 entries, got \(vm.allEntries.count)")
            print("   Entries: \(vm.allEntries)")
            print("   Buffer: \(vm.partialLineBuffer ?? "nil")")
        }
    } catch {
        print("❌ FAIL: \(error)")
    }

    print("\n🎉 Refresh logic tests complete")
}

// Run tests
await runTests()
