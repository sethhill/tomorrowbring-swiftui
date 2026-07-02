//
//  SubstanceTrackerView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

/// Shows the full tracker for a single substance: this-week metrics, a 90-day
/// heatmap, an on-device insight (condition + coaching), recent entries, and a
/// button to log consumption.
struct SubstanceTrackerView: View {
    let kind: SubstanceKind

    @Query private var logs: [SubstanceLog]

    /// Cached insight, keyed per substance so THC and Alcohol don't collide.
    @AppStorage private var insightCacheData: Data

    @State private var isLogging = false
    @State private var condition: String
    @State private var coaching: String
    @State private var isGeneratingInsight = false
    @State private var isRecentExpanded = false

    init(kind: SubstanceKind) {
        self.kind = kind
        let raw = kind.rawValue
        _logs = Query(
            filter: #Predicate<SubstanceLog> { $0.kindRaw == raw },
            sort: \.timestamp,
            order: .reverse
        )
        _insightCacheData = AppStorage(wrappedValue: Data(), "substanceInsight-\(raw)")
        _condition = State(initialValue: SubstanceTrackerView.placeholderCondition)
        _coaching = State(initialValue: SubstanceTrackerView.placeholderCoaching)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                summarySection
                heatmapSection
                insightSection
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
                Label("Log \(kind.unit == "drinks" ? "a Drink" : kind.rawValue)", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(kind.tint)
            .controlSize(.large)
            .padding()
        }
        .sheet(isPresented: $isLogging) {
            LogConsumptionSheet(kind: kind)
                .presentationDetents([.medium])
        }
        .task { await loadOrGenerateInsight() }
        .onChange(of: logs.count) { _, _ in
            Task { await loadOrGenerateInsight() }
        }
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
    }

    // MARK: - This week

    private var thisWeekLogs: [SubstanceLog] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return logs.filter { $0.timestamp >= weekAgo }
    }

    private var daysUsedThisWeek: Int {
        Set(thisWeekLogs.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week")
                .font(.appTitle3)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                statCard(
                    value: "\(Int(thisWeekLogs.reduce(0) { $0 + $1.amount }))",
                    label: kind.unit
                )
                statCard(value: "\(daysUsedThisWeek)", label: "days")
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.appDisplaySemibold)
                .foregroundStyle(kind.tint)
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 90 days")
                .font(.appTitle3)
                .foregroundStyle(.secondary)
            DailyHeatmap(days: dailyTotals(days: 90), tint: kind.tint)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        }
    }

    /// Totals the logged amount per calendar day for the most recent `days`
    /// days, oldest first, including days with no logs (amount 0).
    private func dailyTotals(days: Int) -> [DayTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var totals: [Date: Double] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.timestamp)
            totals[day, default: 0] += log.amount
        }

        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayTotal(date: day, amount: totals[day] ?? 0)
        }
    }

    // MARK: - Insight

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

    // MARK: - Recent

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isRecentExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Recent entries")
                        .font(.appTitle3)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isRecentExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isRecentExpanded {
                if logs.isEmpty {
                    Text("No entries yet. Log your first below.")
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(logs.prefix(20)) { log in
                        HStack(spacing: 12) {
                            Image(systemName: kind.icon)
                                .foregroundStyle(kind.tint)
                                .frame(width: 28)
                            Text(log.timestamp, format: .dateTime.month().day().hour().minute())
                                .font(.appSubheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(log.amount)) \(kind.unit)")
                                .font(.appSubheadlineSemibold)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                    }
                }
            }
        }
    }

    // MARK: - Insight generation

    /// A signature of the current data. Changes when a log is added, triggering
    /// regeneration.
    private var dataSignature: String {
        let latest = logs.first?.timestamp.timeIntervalSince1970 ?? 0
        return "\(logs.count)|\(Int(latest))"
    }

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
        let context = substanceContext()
        let insight = await withInsightTimeout(seconds: 20) {
            await generator.generate(instructions: instructions, context: context)
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

    private var instructions: String {
        let goal = SubstanceGoal.load(for: kind)
        let goalNote: String
        switch goal.mode {
        case .trackingOnly:
            goalNote = "They are tracking only with no directional goal — be observational, not prescriptive."
        case .reduction:
            goalNote = "Their goal is general reduction — focus on trend direction, not a fixed number."
        case .targeted:
            goalNote = "Their goal is a targeted weekly limit. When near the limit, use cost-benefit language: what does staying within it make possible? Never use compliance framing."
        case .elimination:
            goalNote = "Their goal is total elimination. Acknowledge any progress, address urges directly, and connect staying clean to something they actually care about."
        }
        return """
        VOICE RULE: Never use first person. Never write "I", "I'm", "I've", or "we". \
        You have no voice of your own. Address the reader as "you" only, always. \
        You are a direct coach. Two paragraphs: first, what this \(kind.rawValue) pattern suggests \
        about how things feel right now — translate data to felt experience, never quote numbers back. \
        Second, one concrete thing to do or stay aware of today. Lead with action. \
        Never frame anything as a shortfall or deficit. \(goalNote)
        """
    }

    /// Builds a natural-language summary of recent use and goal context for the model.
    private func substanceContext() -> String {
        let goal = SubstanceGoal.load(for: kind)
        let goalLine = goalContext(goal)

        guard !logs.isEmpty else {
            return "\(goalLine) No \(kind.rawValue) use logged yet."
        }
        let calendar = Calendar.current
        let now = Date.now
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        let thisWeek = logs.filter { $0.timestamp >= weekAgo }
        let prior = logs.filter { $0.timestamp >= twoWeeksAgo && $0.timestamp < weekAgo }
        let thisTotal = Int(thisWeek.reduce(0) { $0 + $1.amount })
        let priorTotal = Int(prior.reduce(0) { $0 + $1.amount })
        let days = Set(thisWeek.map { calendar.startOfDay(for: $0.timestamp) }).count

        let trend: String
        if priorTotal == 0 {
            trend = "up from none the previous week"
        } else if thisTotal > priorTotal {
            trend = "up from \(priorTotal) \(kind.unit) the previous week"
        } else if thisTotal < priorTotal {
            trend = "down from \(priorTotal) \(kind.unit) the previous week"
        } else {
            trend = "about the same as the previous week"
        }

        var parts = [goalLine, "This week: \(thisTotal) \(kind.unit) across \(days) days, \(trend)."]
        if goal.mode == .targeted, let limit = goal.weeklyLimit {
            let remaining = max(0, Int(limit) - thisTotal)
            parts.append("Limit: \(Int(limit)) \(kind.unit)/week. Remaining: \(remaining) \(kind.unit).")
        }
        return parts.joined(separator: " ")
    }

    private func goalContext(_ goal: SubstanceGoal) -> String {
        "Goal: \(goal.mode.coachingNote)."
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

    private static let placeholderCondition = "Once you've logged some entries, a summary of your recent use and trend will appear here."
    private static let placeholderCoaching = "Encouraging, personalized coaching will appear here."
}

#Preview {
    NavigationStack {
        SubstanceTrackerView(kind: .thc)
            .navigationTitle("THC")
    }
    .modelContainer(SubstancePreviewData.container)
}
