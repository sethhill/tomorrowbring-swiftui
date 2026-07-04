//
//  LogMovementSheet.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import SwiftUI
import SwiftData

/// A sheet for manually logging a workout not tracked by Apple Health.
struct LogMovementSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var type: MovementType = .running
    @State private var durationMinutes: Double = 30
    @State private var date: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    Picker("Type", selection: $type) {
                        ForEach(MovementType.allCases) { type in
                            Label(type.name, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section("Duration") {
                    Stepper("\(Int(durationMinutes)) min", value: $durationMinutes, in: 5...300, step: 5)
                }

                Section("When") {
                    DatePicker("Time", selection: $date, in: ...Date.now)
                }
            }
            .navigationTitle("Log Workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(
            MovementEntry(type: type, date: date, durationMinutes: durationMinutes)
        )
        dismiss()
    }
}

#Preview {
    LogMovementSheet()
        .modelContainer(for: MovementEntry.self, inMemory: true)
}
