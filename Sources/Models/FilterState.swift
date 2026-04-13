//
//  FilterState.swift
//  LogViewer
//
//  Created on 2026-04-13.
//

import Foundation

/// State for log level and time range filtering
struct FilterState: Sendable {
    var enabledLevels: Set<LogLevel>
    var timeRangeStart: Date?
    var timeRangeEnd: Date?

    init(
        enabledLevels: Set<LogLevel> = Set(LogLevel.allCases),
        timeRangeStart: Date? = nil,
        timeRangeEnd: Date? = nil
    ) {
        self.enabledLevels = enabledLevels
        self.timeRangeStart = timeRangeStart
        self.timeRangeEnd = timeRangeEnd
    }

    /// Returns true if all filters are in their default state
    var isDefault: Bool {
        return enabledLevels.count == LogLevel.allCases.count &&
               timeRangeStart == nil &&
               timeRangeEnd == nil
    }
}
