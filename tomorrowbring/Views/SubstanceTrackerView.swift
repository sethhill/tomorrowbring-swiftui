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
            Text("Recent")
                .font(.appTitle3)
                .foregroundStyle(.secondary)

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
        """
        You are a direct, warm coach. Write in second person ("you") — never first person. \
        Two paragraphs: first, what this \(kind.rawValue) pattern suggests about how things feel \
        right now — translate data to felt experience, never quote numbers back. Second, one concrete \
        thing to do or stay aware of today. Lead with action. Never frame anything as a shortfall \
        or deficit. If there is nothing meaningful to say, keep it brief and forward-looking.
        """
    }

    /// Builds a short natural-language summary of recent use for the model.
    private func substanceContext() -> String {
        guard !logs.isEmpty else {
            return "They haven't logged any \(kind.rawValue) use yet."
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

        return "Over the last 7 days they used \(thisTotal) \(kind.unit) of \(kind.rawValue) across \(days) days, \(trend)."
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
