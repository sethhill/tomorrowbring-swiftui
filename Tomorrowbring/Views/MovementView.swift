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

    @State private var headline = ""
    @State private var condition = MovementView.placeholderCondition
    @State private var coaching = MovementView.placeholderCoaching
    @State private var isGeneratingInsight = false
    @State private var isRecentExpanded = false
    @State private var insightIsAIGenerated = false

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
        List {
            HStack(spacing: 10) {
                Text("Movement")
                    .font(.appLargeTitleSemibold)
                    .foregroundStyle(.brandGreen)
                if isGeneratingInsight {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .listRowBackground(Color.appBackground)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))

            summarySection
                .listRowBackground(Color.appBackground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            heatmapSection
                .listRowBackground(Color.appBackground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            insightSection
                .listRowBackground(Color.appBackground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 8, trailing: 16))

            if let healthNote {
                Text(healthNote)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.appBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            recentSectionHeader
                .listRowBackground(Color.appBackground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

            if isRecentExpanded {
                if activities.isEmpty {
                    Text("No workouts yet. Log one below, or grant Apple Health access to see your recorded activity.")
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.appBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 16, trailing: 16))
                } else {
                    ForEach(activities.prefix(20)) { activity in
                        activityRow(activity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                if activity.source == .manual {
                                    Button(role: .destructive) {
                                        deleteManualActivity(activity)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadOrGenerateInsight(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isGeneratingInsight)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isLogging = true
            } label: {
                Label("Log workout", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass(.regular.tint(.brandGold)))
            .font(.appBodySemibold)
            .foregroundStyle(.white)
            .controlSize(.large)
            .padding()
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
            Task { await loadOrGenerateInsight() }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Past week")
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
                .background(RoundedRectangle(cornerRadius: 16).fill(.appWhite))
        }
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !headline.isEmpty {
                Text(headline)
                    .font(.appTitle3)
                    .foregroundStyle(.brandGold)
            }
            Text(condition)
                .font(.appBody)
                .foregroundStyle(.primary)
            Text(coaching)
                .font(.appBody)
                .foregroundStyle(.primary)
            if insightIsAIGenerated {
                Text("Generated on-device with Apple Intelligence.")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .id(headline + condition + coaching)
        .transition(.opacity)
    }

    private var recentSectionHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isRecentExpanded.toggle()
            }
        } label: {
            HStack {
                Text("Recent entries")
                    .font(.appTitle3)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isRecentExpanded ? 90 : 0))
            }
        }
        .buttonStyle(.plain)
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
        .background(RoundedRectangle(cornerRadius: 12).fill(.appWhite))
    }

    private func deleteManualActivity(_ activity: MovementActivity) {
        let entryId = activity.id.replacingOccurrences(of: "manual-", with: "")
        if let entry = manualEntries.first(where: { $0.id.uuidString == entryId }) {
            modelContext.delete(entry)
        }
    }

    // MARK: - Helpers

    private func distanceText(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
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
        .background(RoundedRectangle(cornerRadius: 16).fill(.appWhite))
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
            headline = cached.headline ?? ""
            condition = cached.condition
            coaching = cached.coaching
            insightIsAIGenerated = true
            return
        }

        isGeneratingInsight = true
        defer { isGeneratingInsight = false }

        let generator = InsightGenerator()
        let context = movementContext()
        let insight = await withInsightTimeout(seconds: 20) {
            await generator.generate(instructions: instructions, context: context)
        }
        if let insight {
            withAnimation(.easeInOut(duration: 0.5)) {
                headline = insight.headline
                condition = insight.condition
                coaching = insight.coaching
                insightIsAIGenerated = true
            }
            saveInsightCache(signature: signature, insight: insight)
        } else {
            withAnimation(.easeInOut(duration: 0.5)) {
                headline = ""
                condition = Self.placeholderCondition
                coaching = Self.placeholderCoaching
                insightIsAIGenerated = false
            }
        }
    }

    /// Builds a natural-language summary of recent movement and goal context for the model.
    private func movementContext() -> String {
        let goal = MovementGoal.load()
        let goalLine = "Goal: \(goal.mode.coachingNote)."

        guard !activities.isEmpty else {
            return "\(goalLine) No workouts logged yet."
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
            ? "none"
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

        // Days since most recent session (across all time, not just this week)
        let daysSinceLast: String
        if let mostRecent = activities.first {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: mostRecent.date),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            daysSinceLast = switch days {
            case 0: "last session was today"
            case 1: "last session was yesterday"
            default: "last session was \(days) days ago"
            }
        } else {
            daysSinceLast = "no sessions recorded"
        }

        let avgMinutes = thisWeekActs.isEmpty ? 0 : thisMinutes / thisWeekActs.count

        var parts = [goalLine, "Last 7 days: \(thisWeekActs.count) workouts, \(thisMinutes) min total (\(typesText)), \(trend)."]
        if !thisWeekActs.isEmpty {
            parts.append("Average session this week: \(avgMinutes) min.")
        }
        parts.append("\(daysSinceLast.prefix(1).uppercased() + daysSinceLast.dropFirst()).")
        if goal.mode == .targeted, let target = goal.weeklySessionTarget {
            let remaining = max(0, target - thisWeekActs.count)
            parts.append("Target: \(target) sessions/week. Remaining this week: \(remaining).")
        }
        return parts.joined(separator: " ")
    }

    private func loadInsightCache() -> CachedInsight? {
        try? JSONDecoder().decode(CachedInsight.self, from: insightCacheData)
    }

    private func saveInsightCache(signature: String, insight: Insight) {
        let cached = CachedInsight(
            signature: signature,
            headline: insight.headline,
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

    private var instructions: String {
        let goal = MovementGoal.load()
        let goalNote: String
        switch goal.mode {
        case .trackingOnly:
            goalNote = "They are tracking only with no directional goal — be observational, not prescriptive."
        case .increase:
            goalNote = "Their goal is general increase — focus on upward trend and building consistency over time."
        case .targeted:
            goalNote = "Their goal is a targeted weekly session count. When near the target, encourage completing it with a specific plan. When at or past it, acknowledge the achievement and note whether adding duration or protecting recovery is the smarter next move."
        }
        return """
        VOICE RULE: Never use first person. Never write "I", "I'm", "I've", or "we". \
        You have no voice of your own. Address the reader as "you" only, always. \
        You are a direct movement coach. Each sentence must introduce a distinct new idea — never repeat. \
        First paragraph: what the pattern suggests about momentum and consistency right now — trend \
        direction, what the gap since the last session means, whether the habit is holding or slipping. \
        Translate to felt experience, never quote numbers. \
        Second paragraph: one specific action for today. If there has been a gap, frame it as resetting \
        the clock — a short session ends the gap and that is enough. If the week is going well, note \
        whether duration or frequency is the better lever. Never frame anything as a shortfall. \
        \(goalNote)
        """
    }

    private static let placeholderCondition = "Movement tracking gives you more signal the more consistently you log it. Frequency tells you whether the habit is holding; duration tells you whether the effort is growing. The two together give you a trend line, and the trend line is where the useful information lives."
    private static let placeholderCoaching = "Log your next session when it happens, even if it was short. The first few entries matter most because they give every future session something to compare against. A weekly target works best when it reflects what you can hit most weeks — not what's possible when everything goes right."

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
