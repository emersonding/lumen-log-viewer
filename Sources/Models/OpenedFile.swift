//
//  OpenedFile.swift
//  Lumen
//
//  Created on 2026-04-16.
//

import Foundation

struct OpenedFile: Identifiable, Hashable {
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
