//
//  SettingsView.swift
//  Lumen
//
//  Created on 2026-04-13.
//

import SwiftUI

/// Preferences window for application settings
struct SettingsView: View {
    // MARK: - AppStorage Properties

    @AppStorage("searchMode") private var searchMode: SearchMode = .jumpToMatch
    @AppStorage("lineWrapDefault") private var lineWrapDefault: Bool = false
    @AppStorage("fontSize") private var fontSize: Double = 12.0
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled: Bool = true
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval: Double = 2.0
    @AppStorage("customTimestampPattern") private var customTimestampPattern: String = ""

    // MARK: - Environment

    @Environment(LogViewModel.self) private var viewModel

    // MARK: - Body

    var body: some View {
        @Bindable var vm = viewModel

        Form {
            // MARK: Search Settings
            Section {
                Picker("Search mode:", selection: $searchMode) {
                    Text("Jump to Match").tag(SearchMode.jumpToMatch)
                    Text("Filter to Matches").tag(SearchMode.filterToMatch)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: searchMode) { _, newValue in
                    vm.searchState.mode = newValue
                    vm.applyFilters()
                }
                .accessibilityLabel("Search mode")
                .accessibilityHint("Choose how search results are displayed")
            } header: {
                Text("Search")
                    .font(.headline)
            }

            // MARK: Display Settings
            Section {
                Toggle("Line wrap by default", isOn: $lineWrapDefault)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Line wrap by default")
                    .accessibilityValue(lineWrapDefault ? "enabled" : "disabled")
                    .accessibilityHint("Wraps long log lines to fit window width")

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Font size:")
                        Spacer()
                        Text("\(Int(fontSize)) pt")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $fontSize, in: 10...24, step: 1) {
                        Text("Font size")
                    }
                    .onChange(of: fontSize) { _, newValue in
                        vm.settingsState.fontSize = newValue
                    }
                    .accessibilityLabel("Font size")
                    .accessibilityValue("\(Int(fontSize)) points")
                    .accessibilityHint("Adjust the size of log text from 10 to 24 points")
                }
            } header: {
                Text("Display")
                    .font(.headline)
            }

            // MARK: Auto-Refresh Settings
            Section {
                Toggle("Enable auto-refresh", isOn: $autoRefreshEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: autoRefreshEnabled) { _, newValue in
                        vm.settingsState.autoRefreshEnabled = newValue
                    }
                    .accessibilityLabel("Enable auto-refresh")
                    .accessibilityValue(autoRefreshEnabled ? "enabled" : "disabled")
                    .accessibilityHint("Automatically reload log file when it changes")

                Picker("Refresh interval:", selection: $autoRefreshInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                }
                .pickerStyle(.menu)
                .disabled(!autoRefreshEnabled)
                .onChange(of: autoRefreshInterval) { _, newValue in
                    vm.settingsState.autoRefreshInterval = newValue
                }
                .accessibilityLabel("Refresh interval")
                .accessibilityHint("How often to check for file changes")
            } header: {
                Text("Auto-Refresh")
                    .font(.headline)
            }

            // MARK: Advanced Settings
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom timestamp regex pattern")
                        .font(.subheadline)

                    TextField("Optional regex pattern", text: $customTimestampPattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: customTimestampPattern) { _, newValue in
                            vm.settingsState.customTimestampPattern = newValue.isEmpty ? nil : newValue
                        }
                        .accessibilityLabel("Custom timestamp regex pattern")
                        .accessibilityHint("Advanced option for custom timestamp formats")

                    Text("Advanced users only. Leave blank to use built-in timestamp patterns (ISO 8601, syslog, Unix epoch).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Advanced")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 450)
        .padding()
        .onAppear {
            // Sync AppStorage values to ViewModel on appear
            vm.searchState.mode = searchMode
            vm.settingsState.lineWrapDefault = lineWrapDefault
            vm.settingsState.fontSize = fontSize
            vm.settingsState.autoRefreshEnabled = autoRefreshEnabled
            vm.settingsState.autoRefreshInterval = autoRefreshInterval
            vm.settingsState.customTimestampPattern = customTimestampPattern.isEmpty ? nil : customTimestampPattern
        }
    }
}

// MARK: - SearchMode AppStorage Support

extension SearchMode: RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "Jump to Match":
            self = .jumpToMatch
        case "Filter to Matches":
            self = .filterToMatch
        default:
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .jumpToMatch:
            return "Jump to Match"
        case .filterToMatch:
            return "Filter to Matches"
        }
    }
}

// MARK: - Preview
// Note: Preview removed for Swift Package Manager compatibility
