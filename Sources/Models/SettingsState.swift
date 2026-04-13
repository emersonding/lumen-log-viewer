//
//  SettingsState.swift
//  LogViewer
//
//  Created on 2026-04-13.
//

import Foundation

/// Application settings
struct SettingsState: Codable, Sendable {
    var searchMode: SearchMode
    var lineWrapDefault: Bool
    var fontSize: Double
    var autoRefreshEnabled: Bool
    var autoRefreshInterval: TimeInterval
    var customTimestampPattern: String?

    init(
        searchMode: SearchMode = .jumpToMatch,
        lineWrapDefault: Bool = false,
        fontSize: Double = 12.0,
        autoRefreshEnabled: Bool = true,
        autoRefreshInterval: TimeInterval = 2.0,
        customTimestampPattern: String? = nil
    ) {
        self.searchMode = searchMode
        self.lineWrapDefault = lineWrapDefault
        self.fontSize = fontSize
        self.autoRefreshEnabled = autoRefreshEnabled
        self.autoRefreshInterval = autoRefreshInterval
        self.customTimestampPattern = customTimestampPattern
    }

    /// Default settings instance
    static let `default` = SettingsState()
}
