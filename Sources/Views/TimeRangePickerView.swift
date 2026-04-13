//
//  TimeRangePickerView.swift
//  LogViewer
//
//  Created on 2026-04-13.
//

import SwiftUI

/// Time range filter with date pickers and quick presets
struct TimeRangePickerView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    @State private var isStartDateEnabled: Bool = false
    @State private var isEndDateEnabled: Bool = false
    @State private var localStartDate: Date = Date()
    @State private var localEndDate: Date = Date()

    var body: some View {
        HStack(spacing: 12) {
            Text("Time Range:")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            // Start date picker
            HStack(spacing: 4) {
                Toggle("From:", isOn: $isStartDateEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .onChange(of: isStartDateEnabled) { _, newValue in
                        startDate = newValue ? localStartDate : nil
                    }
                    .accessibilityLabel("Enable start date filter")
                    .accessibilityValue(isStartDateEnabled ? "enabled" : "disabled")

                DatePicker(
                    "",
                    selection: $localStartDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .disabled(!isStartDateEnabled)
                .onChange(of: localStartDate) { _, newValue in
                    if isStartDateEnabled {
                        startDate = newValue
                    }
                }
                .frame(width: 180)
                .accessibilityLabel("Start date and time")
                .accessibilityHint("Select the beginning of the time range filter")
            }

            // End date picker
            HStack(spacing: 4) {
                Toggle("To:", isOn: $isEndDateEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .onChange(of: isEndDateEnabled) { _, newValue in
                        endDate = newValue ? localEndDate : nil
                    }
                    .accessibilityLabel("Enable end date filter")
                    .accessibilityValue(isEndDateEnabled ? "enabled" : "disabled")

                DatePicker(
                    "",
                    selection: $localEndDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .disabled(!isEndDateEnabled)
                .onChange(of: localEndDate) { _, newValue in
                    if isEndDateEnabled {
                        endDate = newValue
                    }
                }
                .frame(width: 180)
                .accessibilityLabel("End date and time")
                .accessibilityHint("Select the end of the time range filter")
            }

            Divider()
                .frame(height: 16)

            // Quick presets
            Text("Quick:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button("Last 5 min") {
                applyPreset(minutes: 5)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .accessibilityLabel("Filter to last 5 minutes")
            .accessibilityHint("Shows only log entries from the last 5 minutes")

            Button("Last 1 hour") {
                applyPreset(hours: 1)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .accessibilityLabel("Filter to last hour")
            .accessibilityHint("Shows only log entries from the last hour")

            Button("Last 24 hours") {
                applyPreset(hours: 24)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .accessibilityLabel("Filter to last 24 hours")
            .accessibilityHint("Shows only log entries from the last 24 hours")

            Button("Today") {
                applyTodayPreset()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .accessibilityLabel("Filter to today")
            .accessibilityHint("Shows only log entries from today")

            Divider()
                .frame(height: 16)

            // Clear button
            Button("Clear") {
                clearTimeRange()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .foregroundColor(.red)
            .help("Clear time range filter")
            .accessibilityLabel("Clear time range filter")
            .accessibilityHint("Removes the time range filter and shows all log entries")

            Spacer()
        }
        .onAppear {
            // Initialize local dates from bindings
            if let start = startDate {
                localStartDate = start
                isStartDateEnabled = true
            }
            if let end = endDate {
                localEndDate = end
                isEndDateEnabled = true
            }
        }
    }

    // MARK: - Preset Actions

    private func applyPreset(minutes: Int = 0, hours: Int = 0) {
        let now = Date()
        let timeInterval = TimeInterval(minutes * 60 + hours * 3600)
        let start = now.addingTimeInterval(-timeInterval)

        localStartDate = start
        localEndDate = now
        isStartDateEnabled = true
        isEndDateEnabled = true

        startDate = start
        endDate = now
    }

    private func applyTodayPreset() {
        let calendar = Calendar.current
        let now = Date()

        // Start of today (midnight)
        guard let startOfDay = calendar.startOfDay(for: now) as Date? else {
            return
        }

        localStartDate = startOfDay
        localEndDate = now
        isStartDateEnabled = true
        isEndDateEnabled = true

        startDate = startOfDay
        endDate = now
    }

    private func clearTimeRange() {
        isStartDateEnabled = false
        isEndDateEnabled = false
        startDate = nil
        endDate = nil
    }
}

// MARK: - Previews

struct TimeRangePickerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TimeRangePickerView(
                startDate: .constant(nil),
                endDate: .constant(nil)
            )
            .frame(width: 900)
            .padding()
            .previewDisplayName("Empty")

            TimeRangePickerView(
                startDate: .constant(Date().addingTimeInterval(-3600)),
                endDate: .constant(Date())
            )
            .frame(width: 900)
            .padding()
            .previewDisplayName("With Range")

            TimeRangePickerView(
                startDate: .constant(nil),
                endDate: .constant(nil)
            )
            .frame(width: 900)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
