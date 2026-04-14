//
//  LumenApp.swift
//  Lumen - a macOS log reviewer
//
//  Created on 2026-04-13.
//

import SwiftUI

/// Notification for triggering search focus
extension Notification.Name {
    static let focusSearchField = Notification.Name("focusSearchField")
}

@main
@MainActor
struct LumenApp: App {
    @State private var viewModel = LogViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .onAppear {
                    // Ensure app shows in dock and comes to front when run as bare binary
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    handleCommandLineArguments()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    openFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Refresh") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil)
            }

            CommandGroup(after: .textEditing) {
                Divider()

                Button("Find...") {
                    NotificationCenter.default.post(name: .focusSearchField, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil)

                Button("Toggle Line Wrap") {
                    viewModel.settingsState.lineWrapDefault.toggle()
                }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil)
            }

            CommandMenu("View") {
                Button("Toggle FATAL Filter") {
                    toggleLogLevel(.fatal)
                }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil)

                Button("Toggle ERROR Filter") {
                    toggleLogLevel(.error)
                }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil)

                Button("Toggle WARNING Filter") {
                    toggleLogLevel(.warning)
                }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil)

                Button("Toggle INFO Filter") {
                    toggleLogLevel(.info)
                }
                .keyboardShortcut("4", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil)

                Button("Toggle DEBUG Filter") {
                    toggleLogLevel(.debug)
                }
                .keyboardShortcut("5", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil)

                Button("Toggle TRACE Filter") {
                    toggleLogLevel(.trace)
                }
                .keyboardShortcut("6", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil)
            }

            CommandGroup(after: .textEditing) {
                Divider()

                Button("Find Next") {
                    viewModel.nextMatch()
                }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(viewModel.currentFileURL == nil || !viewModel.searchState.hasMatches)

                Button("Find Previous") {
                    viewModel.previousMatch()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(viewModel.currentFileURL == nil || !viewModel.searchState.hasMatches)
            }
        }

        Settings {
            SettingsView()
                .environment(viewModel)
        }
    }

    /// Toggle a log level filter
    private func toggleLogLevel(_ level: LogLevel) {
        if viewModel.filterState.enabledLevels.contains(level) {
            viewModel.filterState.enabledLevels.remove(level)
        } else {
            viewModel.filterState.enabledLevels.insert(level)
        }
        viewModel.applyFilters()
    }

    /// Handle command-line arguments: first arg treated as file path
    private func handleCommandLineArguments() {
        let arguments = CommandLine.arguments

        // Skip the executable path (first argument)
        if arguments.count > 1 {
            let filePath = arguments[1]
            let fileURL = URL(fileURLWithPath: filePath)

            // Open the file
            Task {
                await viewModel.openFile(url: fileURL)
            }
        }
    }

    /// Open system file picker
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .init(filenameExtension: "log")!,
            .init(filenameExtension: "txt")!,
            .data  // All files
        ]
        panel.message = "Select a log file to open"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await viewModel.openFile(url: url)
                }
            }
        }
    }
}
