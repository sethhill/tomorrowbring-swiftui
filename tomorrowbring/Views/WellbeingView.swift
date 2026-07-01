//
//  WellbeingView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

/// General mood tracker across three metrics: calm, energy, and mood. Ratings
/// are logged (1–5) and persisted, with recent entries listed below.
struct WellbeingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WellbeingEntry.timestamp, order: .reverse) private var entries: [WellbeingEntry]

    @State private var calm = 3
    @State private var energy = 3
    @State private var mood = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("How are you feeling?")
                    .font(.appTitle2)

                MetricRatingRow(title: "Calm", icon: "leaf.fill", tint: .brandGreen, value: $calm)
                MetricRatingRow(title: "Energy", icon: "bolt.fill", tint: .brandOrange, value: $energy)
                MetricRatingRow(title: "Mood", icon: "face.smiling.fill", tint: .brandGold, value: $mood)

                Button("Save entry", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(.brandGreen)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                if !entries.isEmpty {
                    recentSection
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Wellbeing")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Wellbeing")
                    .font(.appTitle3)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.appTitle3)

            ForEach(entries.prefix(10)) { entry in
                HStack {
                    Text(entry.timestamp, format: .dateTime.month().day().hour().minute())
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    metricBadge("C", entry.calm, .brandGreen)
                    metricBadge("E", entry.energy, .brandOrange)
                    metricBadge("M", entry.mood, .brandGold)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                )
            }
        }
    }

    private func metricBadge(_ label: String, _ value: Int, _ tint: Color) -> some View {
        Text("\(label) \(value)")
            .font(.appCaptionSemibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
    }

    private func save() {
        modelContext.insert(WellbeingEntry(calm: calm, energy: energy, mood: mood))
    }
}

/// A labeled 1–5 rating control for a single wellbeing metric.
private struct MetricRatingRow: View {
    let title: String
    let icon: String
    let tint: Color
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.appTitle3)
                .foregroundStyle(tint)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { rating in
                    Circle()
                        .fill(rating <= value ? tint : Color.secondary.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text("\(rating)")
                                .font(.appSubheadline)
                                .foregroundStyle(rating <= value ? .white : .secondary)
                        )
                        .onTapGesture { value = rating }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WellbeingView()
    }
    .modelContainer(for: WellbeingEntry.self, inMemory: true)
}
