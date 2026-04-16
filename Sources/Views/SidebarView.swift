//
//  SidebarView.swift
//  Lumen
//
//  Created on 2026-04-16.
//

import SwiftUI

@MainActor
struct SidebarView: View {
    @Environment(LogViewModel.self) private var viewModel

    var body: some View {
        List {
            openedFilesSection
            historySection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220)
    }

    // MARK: - Opened Files

    private var openedFilesSection: some View {
        Section("Opened") {
            if viewModel.openedFiles.isEmpty {
                Text("No files open")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            } else {
                ForEach(viewModel.openedFiles) { file in
                    openedFileRow(file)
                }
            }
        }
    }

    private func openedFileRow(_ file: OpenedFile) -> some View {
        let isActive = viewModel.currentFileURL == file.url
        return Button {
            Task { await viewModel.switchToFile(file) }
        } label: {
            HStack {
                Image(systemName: isActive ? "doc.text.fill" : "doc.text")
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.displayName)
                        .font(.body)
                        .fontWeight(isActive ? .semibold : .regular)
                    Text(file.fullPath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Close") {
                viewModel.closeOpenedFile(file)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        Section("History") {
            let historyItems = viewModel.fileHistory.filter { historyFile in
                !viewModel.openedFiles.contains(where: { $0.url == historyFile.url })
            }
            if historyItems.isEmpty {
                Text("No history")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            } else {
                ForEach(historyItems) { file in
                    historyRow(file)
                }
                Button("Clear History") {
                    viewModel.clearHistory()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func historyRow(_ file: OpenedFile) -> some View {
        let exists = file.existsOnDisk
        return Button {
            if exists {
                Task { await viewModel.switchToFile(file) }
            }
        } label: {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(exists ? .secondary : .tertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.displayName)
                        .font(.body)
                        .foregroundStyle(exists ? .primary : .tertiary)
                        .italic(!exists)
                    Text(file.fullPath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!exists)
        .contextMenu {
            Button("Remove from History") {
                viewModel.removeFromHistory(file)
            }
        }
    }
}
