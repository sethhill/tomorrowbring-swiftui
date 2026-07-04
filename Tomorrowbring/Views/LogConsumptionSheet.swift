//
//  LogConsumptionSheet.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

/// A sheet for logging a single consumption event for a given substance.
struct LogConsumptionSheet: View {
    let kind: SubstanceKind

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double
    @State private var timestamp: Date = .now

    init(kind: SubstanceKind) {
        self.kind = kind
        _amount = State(initialValue: kind.defaultAmount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        TextField("Amount", value: $amount, format: .number)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text(kind.unit)
                            .foregroundStyle(.secondary)
                    }
                    Stepper(
                        "Adjust",
                        value: $amount,
                        in: 0...1000,
                        step: kind.amountStep
                    )
                }

                Section("When") {
                    DatePicker("Time", selection: $timestamp, in: ...Date.now)
                }
            }
            .navigationTitle("Log \(kind.rawValue)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(amount <= 0)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(
            SubstanceLog(kind: kind, amount: amount, timestamp: timestamp)
        )
        dismiss()
    }
}

#Preview {
    LogConsumptionSheet(kind: .thc)
        .modelContainer(for: SubstanceLog.self, inMemory: true)
}
