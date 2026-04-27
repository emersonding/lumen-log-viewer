//
//  OpenedFile.swift
//  Lumen
//
//  Created on 2026-04-16.
//

import Foundation

struct OpenedFile: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let url: URL
    let openedAt: Date
    var displayName: String { url.lastPathComponent }
    var fullPath: String { url.path }

    init(id: UUID = UUID(), url: URL, openedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.openedAt = openedAt
    }

    func hash(into hasher: inout Hasher) { hasher.combine(url) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.url == rhs.url }

    var existsOnDisk: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

struct FileTabSnapshot: Codable, Sendable {
    var filterState: FilterState
    var searchQuery: String
    var searchMode: SearchMode
    var isCaseSensitive: Bool
    var timestampSortOrder: TimestampSortOrder
    var extractedFieldNames: [String]
}

struct OpenedFilesWorkspace: Codable, Sendable {
    var openedFiles: [OpenedFile]
    var activeTabPath: String?
    var tabSnapshotsByPath: [String: FileTabSnapshot]
}
