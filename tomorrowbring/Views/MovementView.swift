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

    @State private var condition = MovementView.placeholderCondition
    @State private var coaching = MovementView.placeholderCoaching
    @State private var isGeneratingInsight = false

    /// Cached insight, keyed by a signature of the movement data so it
    /// regenerates whenever a new activity (Health or manual) is recorded.
    @AppStorage("movementInsightCache") private var insightCacheData = Data()

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
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Movement")
                    .font(.appLargeTitleSemibold)
                    .foregroundStyle(.brandGreen)
                summarySection
                heatmapSection
                insightSection

                if let healthNote {
                    Text(healthNote)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                recentSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
        .safeAreaInset(edge: .bottom) {
            Button {
                isLogging = true
            } label: {
                Label("Log Workout", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandGold)
            .controlSize(.large)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Movement")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Movement")
                    .font(.appTitle3)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadOrGenerateInsight(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isGeneratingInsight)
            }
        }
        .sheet(isPresented: $isLogging) {
            LogMovementSheet()
                .presentationDetents([.medium])
        }
        .task {
            await loadHealthWorkouts()
            await loadOrGenerateInsight()
        }
        .onChange(of: manualEntries.count) { _, _ in
            // A newly logged workout changes the data signature; refresh insight.
            Task { await loadOrGenerateInsight() }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week")
                .font(.appTitle3)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                statCard(value: "\(thisWeek.count)", label: "workouts")
                statCard(
                    value: "\(Int(thisWeek.reduce(0) { $0 + $1.durationMinutes }))",
                    label: "minutes"
                )
            }
        }
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 90 days")
                .font(.appTitle3)
                .foregroundStyle(.secondary)
            DailyHeatmap(days: dailyTotals(days: 90), tint: .brandGold)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        }
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                if isGeneratingInsight {
                    ProgressView().controlSize(.small)
                }
                Text(condition)
                    .font(.appBody)
                    .foregroundStyle(.primary)
            }
            Text(coaching)
                .font(.appBody)
                .foregroundStyle(.primary)
        }
    }

    /// Total minutes moved per calendar day for the most recent `days` days,
    /// oldest first, including days with no activity (0 minutes).
    private func dailyTotals(days: Int) -> [DayTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var totals: [Date: Double] = [:]
        for activity in activities {
            let day = calendar.startOfDay(for: activity.date)
            totals[day, default: 0] += activity.durationMinutes
        }

        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayTotal(date: day, amount: totals[day] ?? 0)
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.appDisplaySemibold)
                .foregroundStyle(.brandGold)
            Text(label)
                .font(.appCaption)
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
                .font(.appTitle3)
                .foregroundStyle(.secondary)

            if activities.isEmpty {
                Text("No workouts yet. Log one below, or grant Apple Health access to see your recorded activity.")
                    .font(.appSubheadline)
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
                .foregroundStyle(.brandGold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.type.name)
                    .font(.appBodySemibold)
                Text(activity.date, format: .dateTime.month().day().hour().minute())
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(activity.durationMinutes)) min")
                    .font(.appSubheadline)
                if let distance = activity.distanceMeters {
                    Text(distanceText(distance))
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Text(activity.source == .health ? "Health" : "Manual")
                    .font(.appCaption2)
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

    // MARK: - Insight generation

    /// A signature of the current movement data. Changes whenever an activity is
    /// added (from Health or manually), triggering regeneration.
    private var dataSignature: String {
        let latest = activities.first?.date.timeIntervalSince1970 ?? 0
        return "\(activities.count)|\(Int(latest))"
    }

    /// Shows the cached insight for the current data, or generates a fresh one
    /// on-device (falling back to placeholder text) and caches it.
    private func loadOrGenerateInsight(forceRefresh: Bool = false) async {
        guard !isGeneratingInsight else { return }
        let signature = dataSignature

        if !forceRefresh, let cached = loadInsightCache(), cached.signature == signature {
            condition = cached.condition
            coaching = cached.coaching
            return
        }

        isGeneratingInsight = true
        defer { isGeneratingInsight = false }

        let generator = InsightGenerator()
        let context = movementContext()
        let insight = await withInsightTimeout(seconds: 20) {
            await generator.generate(instructions: Self.instructions, context: context)
        }
        if let insight {
            condition = insight.condition
            coaching = insight.coaching
            saveInsightCache(signature: signature, insight: insight)
        } else {
            condition = Self.placeholderCondition
            coaching = Self.placeholderCoaching
        }
    }

    /// Builds a short natural-language summary of recent movement for the model.
    private func movementContext() -> String {
        guard !activities.isEmpty else {
            return "They haven't recorded any workouts yet."
        }
        let calendar = Calendar.current
        let now = Date.now
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        let thisWeekActs = activities.filter { $0.date >= weekAgo }
        let priorActs = activities.filter { $0.date >= twoWeeksAgo && $0.date < weekAgo }
        let thisMinutes = Int(thisWeekActs.reduce(0) { $0 + $1.durationMinutes })
        let priorMinutes = Int(priorActs.reduce(0) { $0 + $1.durationMinutes })

        let typeCounts = Dictionary(grouping: thisWeekActs, by: { $0.type.name }).mapValues(\.count)
        let typesText = typeCounts.isEmpty
            ? "no workouts"
            : typeCounts.map { "\($0.value) \($0.key)" }.joined(separator: ", ")

        let trend: String
        if priorMinutes == 0 {
            trend = "up from nothing the previous week"
        } else if thisMinutes > priorMinutes {
            trend = "up from \(priorMinutes) min the previous week"
        } else if thisMinutes < priorMinutes {
            trend = "down from \(priorMinutes) min the previous week"
        } else {
            trend = "about the same as the previous week"
        }

        return "Over the last 7 days: \(thisWeekActs.count) workouts totaling \(thisMinutes) minutes (\(typesText)), \(trend)."
    }

    private func loadInsightCache() -> CachedInsight? {
        try? JSONDecoder().decode(CachedInsight.self, from: insightCacheData)
    }

    private func saveInsightCache(signature: String, insight: Insight) {
        let cached = CachedInsight(
            signature: signature,
            condition: insight.condition,
            coaching: insight.coaching
        )
        insightCacheData = (try? JSONEncoder().encode(cached)) ?? Data()
    }

    /// Runs `operation`, returning `nil` if it doesn't finish within `seconds`,
    /// so a slow or wedged model can't leave the insight spinning forever.
    private func withInsightTimeout(
        seconds: Double,
        operation: @escaping () async -> Insight?
    ) async -> Insight? {
        await withTaskGroup(of: Insight?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private static let instructions = """
    You are a direct, warm movement coach. Write in second person ("you") — never first person. \
    Two paragraphs: first, what the recent movement pattern suggests about where things stand — \
    translate data to felt momentum or energy, never quote numbers as a report. Second, one specific \
    realistic action for today. Lead with what to do. Never frame anything as a shortfall or mention \
    what's missing. If there is nothing constructive to say, keep it brief and forward-looking.
    """

    private static let placeholderCondition = "Once you've recorded some movement, a summary of your recent activity and trend will appear here."
    private static let placeholderCoaching = "Encouraging, personalized coaching for your movement will appear here."

    /// Loads recent workouts from Apple Health when available.
    private func loadHealthWorkouts() async {
        #if canImport(HealthKit)
        guard HealthMovementStore.isAvailable else {
            healthNote = "Apple Health isn't available on this device."
            return
        }
        let store = HealthMovementStore()
        await store.requestAuthorization()
        let since = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
        healthActivities = await store.recentWorkouts(since: since)
        healthNote = nil
        #else
        healthNote = "Apple Health isn't available on this platform — showing manual entries only."
        #endif
    }
}

#Preview {
    NavigationStack {
        MovementView()
    }
    .modelContainer(for: MovementEntry.self, inMemory: true)
}
