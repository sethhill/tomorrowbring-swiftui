//
//  MovementView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

/// Tracker for movement. Merges workouts read from Apple Health with manually
/// logged entries into a weekly summary and a recent-activity list.
struct MovementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovementEntry.date, order: .reverse) private var manualEntries: [MovementEntry]

    @State private var healthActivities: [MovementActivity] = []
    @State private var healthNote: String?
    @State private var isLogging = false

    /// All activities (Health + manual), most recent first.
    private var activities: [MovementActivity] {
        let manual = manualEntries.map { entry in
            MovementActivity(
                id: "manual-\(entry.id.uuidString)",
                type: entry.type,
                date: entry.date,
                durationMinutes: entry.durationMinutes,
                distanceMeters: nil,
                source: .manual
            )
        }
        return (manual + healthActivities).sorted { $0.date > $1.date }
    }

    private var thisWeek: [MovementActivity] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return activities.filter { $0.date >= weekAgo }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summarySection

                if let healthNote {
                    Text(healthNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                recentSection
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isLogging = true
            } label: {
                Label("Log Workout", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandOrange)
            .controlSize(.large)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Movement")
        .sheet(isPresented: $isLogging) {
            LogMovementSheet()
                .presentationDetents([.medium])
        }
        .task { await loadHealthWorkouts() }
    }

    // MARK: - Sections

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week")
                .font(.headline)
            HStack(spacing: 12) {
                statCard(value: "\(thisWeek.count)", label: "workouts")
                statCard(
                    value: "\(Int(thisWeek.reduce(0) { $0 + $1.durationMinutes }))",
                    label: "minutes"
                )
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .bold()
                .foregroundStyle(.brandOrange)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)

            if activities.isEmpty {
                Text("No workouts yet. Log one below, or grant Apple Health access to see your recorded activity.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activities.prefix(20)) { activity in
                    activityRow(activity)
                }
            }
        }
    }

    private func activityRow(_ activity: MovementActivity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: activity.type.icon)
                .foregroundStyle(.brandOrange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.type.name)
                    .font(.body)
                    .bold()
                Text(activity.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(activity.durationMinutes)) min")
                    .font(.subheadline)
                if let distance = activity.distanceMeters {
                    Text(distanceText(distance))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(activity.source == .health ? "Health" : "Manual")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
    }

    // MARK: - Helpers

    private func distanceText(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }

    /// Loads recent workouts from Apple Health when available.
    private func loadHealthWorkouts() async {
        #if canImport(HealthKit)
        guard HealthMovementStore.isAvailable else {
            healthNote = "Apple Health isn’t available on this device."
            return
        }
        let store = HealthMovementStore()
        await store.requestAuthorization()
        let since = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        healthActivities = await store.recentWorkouts(since: since)
        healthNote = nil
        #else
        healthNote = "Apple Health isn’t available on this platform — showing manual entries only."
        #endif
    }
}

#Preview {
    NavigationStack {
        MovementView()
    }
    .modelContainer(for: MovementEntry.self, inMemory: true)
}
