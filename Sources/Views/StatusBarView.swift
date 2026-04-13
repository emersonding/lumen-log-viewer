//
//  StatusBarView.swift
//  LogViewer
//
//  Created on 2026-04-13.
//

import SwiftUI

/// Status bar displaying line counts and active filter indicators
struct StatusBarView: View {
    // MARK: - Properties

    @Bindable var viewModel: LogViewModel

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Loading indicator
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .accessibilityLabel("Loading")
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Loading log entries")
            }

            // New content indicator
            if viewModel.hasNewContent {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("New content available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("New content available")
                .accessibilityHint("Refresh to view new log entries")
            }

            Spacer()

            // Line counts
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 8) {
                    Text(lineCountText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(lineCountText)

                    Divider()
                        .frame(height: 12)

                    // Filter indicators
                    Text(filterIndicator)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(filterIndicator)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(lineCountText), \(filterIndicator)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Computed Properties

    /// Text showing displayed lines vs total lines
    @MainActor
    private var lineCountText: String {
        let displayed = viewModel.displayedEntries.count
        let total = viewModel.allEntries.count

        if total == 0 {
            return "No lines"
        }

        if displayed == total {
            return "\(displayed) lines"
        }

        return "\(displayed) of \(total) lines"
    }

    /// Text showing active filters or "No filters"
    @MainActor
    private var filterIndicator: String {
        var activeFilters: [String] = []

        // Check log level filters
        let enabledLevels = viewModel.filterState.enabledLevels
        let allLevels = Set(LogLevel.allCases)

        if enabledLevels != allLevels {
            // Some levels are filtered out
            let disabledLevels = allLevels.subtracting(enabledLevels)
            let disabledNames = disabledLevels
                .sorted { $0.rawValue < $1.rawValue }
                .map { $0.rawValue }
            activeFilters.append(contentsOf: disabledNames)
        }

        // Check time range filter
        if viewModel.filterState.timeRangeStart != nil || viewModel.filterState.timeRangeEnd != nil {
            activeFilters.append("Time Range")
        }

        // Check search filter (in filter mode)
        if !viewModel.searchState.query.isEmpty && viewModel.searchState.mode == .filterToMatch {
            activeFilters.append("Search")
        }

        if activeFilters.isEmpty {
            return "No filters"
        }

        return "Filters: \(activeFilters.joined(separator: ", "))"
    }
}

// MARK: - Preview
// Note: Preview removed for Swift Package Manager compatibility
