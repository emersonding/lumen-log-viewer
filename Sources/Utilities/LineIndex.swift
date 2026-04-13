//
//  LineIndex.swift
//  LogViewer
//
//  Created on 2026-04-13.
//

import Foundation

/// Maps line numbers to byte offsets within a file or data buffer for O(1) line access.
///
/// `LineIndex` scans raw data to record the byte offset where each line begins.
/// This enables fast random access to any line without re-scanning the entire file.
///
/// The index is built incrementally in chunks to avoid blocking on large files,
/// and supports appending when new data is added (e.g., during incremental refresh).
struct LineIndex: Sendable {
    /// Byte offsets where each line starts. `offsets[0]` is always 0 (first line).
    private(set) var offsets: [Int]

    /// Total number of indexed lines.
    var lineCount: Int { offsets.count }

    /// Whether the index is empty (no lines indexed).
    var isEmpty: Bool { offsets.isEmpty }

    // MARK: - Initialization

    /// Create an empty line index.
    init() {
        self.offsets = []
    }

    /// Create a line index from pre-computed offsets.
    init(offsets: [Int]) {
        self.offsets = offsets
    }

    // MARK: - Building

    /// Build a line index from raw data by scanning for newline characters.
    ///
    /// Processes data in chunks (default 1MB) and yields between chunks to
    /// avoid blocking the caller for large files.
    ///
    /// - Parameters:
    ///   - data: The raw data to index.
    ///   - chunkSize: Size of each processing chunk in bytes (default: 1MB).
    ///   - progress: Optional callback reporting fraction complete (0.0 to 1.0).
    /// - Returns: A populated `LineIndex`.
    static func build(
        from data: Data,
        chunkSize: Int = 1_048_576,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async -> LineIndex {
        let totalBytes = data.count

        guard totalBytes > 0 else {
            return LineIndex()
        }

        // Pre-allocate with a reasonable estimate (average ~100 bytes per line)
        var offsets: [Int] = []
        offsets.reserveCapacity(max(totalBytes / 100, 1024))

        // First line always starts at offset 0
        offsets.append(0)

        let newlineByte = UInt8(ascii: "\n")
        var bytesProcessed = 0

        // Process in chunks
        while bytesProcessed < totalBytes {
            let chunkEnd = min(bytesProcessed + chunkSize, totalBytes)

            data.withUnsafeBytes { rawBuffer in
                guard let basePtr = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }

                for i in bytesProcessed..<chunkEnd {
                    if basePtr[i] == newlineByte {
                        let nextLineOffset = i + 1
                        // Only add if there is content after the newline
                        if nextLineOffset < totalBytes {
                            offsets.append(nextLineOffset)
                        }
                    }
                }
            }

            bytesProcessed = chunkEnd

            // Report progress
            progress?(Double(bytesProcessed) / Double(totalBytes))

            // Yield between chunks to keep the system responsive
            await Task.yield()
        }

        return LineIndex(offsets: offsets)
    }

    // MARK: - Access

    /// Get the byte offset for a given line number (0-based).
    ///
    /// - Parameter lineIndex: Zero-based line index.
    /// - Returns: Byte offset, or nil if out of range.
    func offset(forLine lineIndex: Int) -> Int? {
        guard lineIndex >= 0, lineIndex < offsets.count else {
            return nil
        }
        return offsets[lineIndex]
    }

    /// Get the byte range for a given line (0-based).
    ///
    /// - Parameters:
    ///   - lineIndex: Zero-based line index.
    ///   - dataLength: Total length of the data buffer (used for the last line).
    /// - Returns: Range of bytes for the line, or nil if out of range.
    func byteRange(forLine lineIndex: Int, dataLength: Int) -> Range<Int>? {
        guard let start = offset(forLine: lineIndex) else {
            return nil
        }

        let end: Int
        if lineIndex + 1 < offsets.count {
            end = offsets[lineIndex + 1]
        } else {
            end = dataLength
        }

        return start..<end
    }

    /// Extract the raw bytes for a specific line from data.
    ///
    /// - Parameters:
    ///   - lineIndex: Zero-based line index.
    ///   - data: The data buffer.
    /// - Returns: The line's data (without trailing newline), or nil if out of range.
    func lineData(at lineIndex: Int, in data: Data) -> Data? {
        guard let range = byteRange(forLine: lineIndex, dataLength: data.count) else {
            return nil
        }

        var lineBytes = data.subdata(in: range)

        // Strip trailing newline characters
        while let last = lineBytes.last, last == UInt8(ascii: "\n") || last == UInt8(ascii: "\r") {
            lineBytes = lineBytes.dropLast()
        }

        return lineBytes
    }

    /// Extract a line as a String from data.
    ///
    /// - Parameters:
    ///   - lineIndex: Zero-based line index.
    ///   - data: The data buffer.
    /// - Returns: The line as a string, or nil if out of range.
    func lineString(at lineIndex: Int, in data: Data) -> String? {
        guard let bytes = lineData(at: lineIndex, in: data) else {
            return nil
        }
        return String(data: bytes, encoding: .utf8) ?? String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - Incremental Update

    /// Append line offsets for newly appended data.
    ///
    /// Call this when data is appended to the file (e.g., during incremental refresh).
    ///
    /// - Parameters:
    ///   - newData: The newly appended data.
    ///   - baseOffset: The byte offset in the full file where `newData` begins.
    mutating func appendIndex(for newData: Data, baseOffset: Int) {
        let newlineByte = UInt8(ascii: "\n")

        // If this is the first data ever, record offset 0
        if offsets.isEmpty {
            offsets.append(baseOffset)
        }

        newData.withUnsafeBytes { rawBuffer in
            guard let basePtr = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }

            for i in 0..<newData.count {
                if basePtr[i] == newlineByte {
                    let nextLineOffset = baseOffset + i + 1
                    // Only add if within bounds of possible future data
                    if nextLineOffset < baseOffset + newData.count {
                        offsets.append(nextLineOffset)
                    }
                }
            }
        }
    }
}
