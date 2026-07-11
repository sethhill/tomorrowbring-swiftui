//
//  WellbeingView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData
import Charts

/// Wellbeing readout driven by the latest check-in. Shows a 7-day trend
/// across energy, calm, and mood, plus an AI condition and coaching paragraph.
struct WellbeingView: View {
    @Query(sort: \CheckInEntry.timestamp, order: .reverse) private var checkIns: [CheckInEntry]

    @State private var condition = WellbeingView.placeholderCondition
    @State private var coaching = WellbeingView.placeholderCoaching
    @State private var isGeneratingInsight = false
    @State private var sleepHours: Double? = nil
    @State private var insightIsAIGenerated = false

    @AppStorage("wellbeingInsightCache") private var insightCacheData = Data()

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    Text("Wellbeing")
                        .font(.appLargeTitleSemibold)
                        .foregroundStyle(.brandGreen)
                    if isGeneratingInsight {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                barometerSection
                trendSection
                insightSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        // Re-fires when checkIns loads or changes, fixing the SwiftData timing issue.
        .task(id: dataSignature) { await loadOrGenerateInsight() }
    }

    // MARK: - Trend chart

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Past week")
                .font(.appTitle3)
                .foregroundStyle(.secondary)
            WellbeingTrendChart(points: wellbeingPoints)
        }
    }

    /// Parses the last 7 days of check-ins into normalised (0–1) data points.
    /// When multiple check-ins exist for a day, the latest one wins.
    private var wellbeingPoints: [WellbeingDataPoint] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(
            byAdding: .day, value: -6,
            to: calendar.startOfDay(for: .now)
        ) ?? .now
        let recent = checkIns.filter { $0.timestamp >= sevenDaysAgo }

        var byDay: [Date: CheckInEntry] = [:]
        for entry in recent.reversed() {
            let day = calendar.startOfDay(for: entry.timestamp)
            byDay[day] = entry
        }

        var points: [WellbeingDataPoint] = []
        for (day, entry) in byDay {
            for response in entry.responses {
                let p = response.prompt.lowercased()
                if p.contains("your energy") {
                    if let v = energyValue(response.answer) {
                        points.append(WellbeingDataPoint(date: day, metric: .energy, value: v))
                    }
                } else if p.contains("stress level") {
                    // Invert stress → calm
                    if let v = calmValue(response.answer) {
                        points.append(WellbeingDataPoint(date: day, metric: .calm, value: v))
                    }
                } else if p.contains("overall mood") {
                    if let v = moodValue(response.answer) {
                        points.append(WellbeingDataPoint(date: day, metric: .mood, value: v))
                    }
                }
            }
        }
        return points.sorted { $0.date < $1.date }
    }

    private func energyValue(_ answer: String) -> Double? {
        switch answer {
        case "Great":   return 1.0
        case "Good":    return 0.75
        case "Okay":    return 0.5
        case "Low":     return 0.25
        case "Drained": return 0.0
        default:        return nil
        }
    }

    private func calmValue(_ answer: String) -> Double? {
        switch answer {
        case "Chill":        return 1.0
        case "A bit":        return 0.67
        case "Stressed":     return 0.33
        case "Overwhelmed":  return 0.0
        default:             return nil
        }
    }

    private func moodValue(_ answer: String) -> Double? {
        switch answer {
        case "Good":    return 1.0
        case "Decent":  return 0.67
        case "Mixed":   return 0.33
        case "Low":     return 0.0
        default:        return nil
        }
    }

    // MARK: - Barometer section

    private var barometerReadings: [BarometerReading] {
        WellbeingMetric.allCases.compactMap { metric in
            let points = wellbeingPoints.filter { $0.metric == metric }
            guard let current = points.last?.value else { return nil }
            let trend: BarometerTrend
            if points.count >= 2 {
                let diff = current - points[points.count - 2].value
                trend = diff > 0.08 ? .up : (diff < -0.08 ? .down : .level)
            } else {
                trend = .level
            }
            return BarometerReading(metric: metric, current: current, trend: trend)
        }
    }

    @ViewBuilder
    private var barometerSection: some View {
        if !barometerReadings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.appTitle3)
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(barometerReadings.enumerated()), id: \.offset) { index, reading in
                        BarometerRow(metric: reading.metric, current: reading.current, trend: reading.trend)
                        if index < barometerReadings.count - 1 {
                            Divider().padding(.horizontal, 4)
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(.appWhite))
            }
        }
    }

    // MARK: - Insight section

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        .id(condition + coaching)
        .transition(.opacity)
    }

    // MARK: - Insight generation

    private var dataSignature: String {
        guard let latest = checkIns.first else { return "none" }
        return "\(Int(latest.timestamp.timeIntervalSince1970))"
    }

    private func fetchSleepData() async {
        #if canImport(HealthKit)
        guard HealthSleepStore.isAvailable else { return }
        let sleepStore = HealthSleepStore()
        await sleepStore.requestAuthorization()
        sleepHours = await sleepStore.lastNightSleepHours()
        #endif
    }

    private func loadOrGenerateInsight(forceRefresh: Bool = false) async {
        await fetchSleepData()
        guard !isGeneratingInsight else { return }
        let signature = dataSignature

        if !forceRefresh, let cached = loadInsightCache(), cached.signature == signature {
            condition = cached.condition
            coaching = cached.coaching
            insightIsAIGenerated = true
            return
        }

        isGeneratingInsight = true
        defer { isGeneratingInsight = false }

        let generator = InsightGenerator()
        let context = wellbeingContext()
        let insight = await withInsightTimeout(seconds: 20) {
            await generator.generate(instructions: instructions, context: context)
        }
        if let insight {
            withAnimation(.easeInOut(duration: 0.5)) {
                condition = insight.condition
                coaching = insight.coaching
                insightIsAIGenerated = true
            }
            saveInsightCache(signature: signature, insight: insight)
        } else {
            withAnimation(.easeInOut(duration: 0.5)) {
                condition = Self.placeholderCondition
                coaching = Self.placeholderCoaching
                insightIsAIGenerated = false
            }
        }
    }

    private var instructions: String {
        """
        VOICE RULE: Never use first person. Never write "I", "I'm", "I've", or "we". \
        You have no voice of your own. Address the reader as "you" only, always. \
        You are a direct wellbeing coach. Draw on the check-in responses provided. \
        First paragraph: what the check-in picture suggests about how things feel right now. \
        Weave energy, stress, mood, and sleep into a coherent felt experience — do not list them. \
        Never quote the raw answers back word for word. Translate to what they mean for how the day feels. \
        Never frame anything as a shortfall or deficit. Each sentence must introduce a distinct new idea. \
        Second paragraph: one concrete thing to do or stay aware of today, grounded in what the check-in revealed. \
        Lead with action. Connect to what is actually driving the person's state. \
        Each sentence must introduce a distinct new idea — never repeat.
        """
    }

    private func wellbeingContext() -> String {
        guard let latest = checkIns.first else {
            return "No check-in data available yet."
        }
        let calendar = Calendar.current
        let daysAgo = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: latest.timestamp),
            to: calendar.startOfDay(for: .now)
        ).day ?? 0
        let when = switch daysAgo {
        case 0: "today"
        case 1: "yesterday"
        default: "\(daysAgo) days ago"
        }
        let answers = latest.responses.map { "\($0.prompt) \($0.answer)." }.joined(separator: " ")
        var context = "Check-in (\(when)): \(answers)"
        if let hours = sleepHours {
            let quality: String
            switch hours {
            case 7.5...: quality = "well rested (\(String(format: "%.1f", hours))h)"
            case 5.5...: quality = "so-so (\(String(format: "%.1f", hours))h)"
            default:     quality = "poorly rested (\(String(format: "%.1f", hours))h)"
            }
            context += " Apple Health sleep data: \(quality)."
        }
        return context
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

    private static let placeholderCondition = "Complete your daily check-in to see a coaching readout here — it uses your energy, stress, mood, and sleep responses to build a picture of where things stand."
    private static let placeholderCoaching = "The check-in takes about thirty seconds and gives the coaching here enough context to be specific rather than generic."
}

// MARK: - Chart types

private struct WellbeingDataPoint: Identifiable {
    var id: String { "\(Int(date.timeIntervalSince1970))|\(metric.rawValue)" }
    let date: Date
    let metric: WellbeingMetric
    let value: Double
}

private enum WellbeingMetric: String, CaseIterable {
    case mood   = "Mood"
    case energy = "Energy"
    case calm   = "Calm"

    var color: Color {
        switch self {
        case .mood:   return .brandGold
        case .energy: return .brandOrange
        case .calm:   return .brandGreen
        }
    }

    // Small vertical nudge so overlapping lines stay visually distinct.
    var displayOffset: Double {
        switch self {
        case .mood:   return  0.03
        case .energy: return  0.0
        case .calm:   return -0.03
        }
    }

    var zIndex: Double {
        switch self {
        case .mood:   return 2
        case .energy: return 1
        case .calm:   return 0
        }
    }
}

private struct WellbeingTrendChart: View {
    let points: [WellbeingDataPoint]

    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let end = calendar.date(byAdding: .hour, value: 12, to: today) ?? today
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Custom legend — avoids duplicate entries from LineMark + PointMark.
            HStack(spacing: 14) {
                ForEach(WellbeingMetric.allCases, id: \.rawValue) { metric in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(metric.color)
                            .frame(width: 7, height: 7)
                        Text(metric.rawValue)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if points.isEmpty {
                Text("Check in to start seeing trends here.")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 110)
            } else {
                Chart(points) { point in
                    let displayValue = point.value + point.metric.displayOffset
                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Score", displayValue),
                        series: .value("Metric", point.metric.rawValue)
                    )
                    .foregroundStyle(point.metric.color)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 6, lineCap: .round))
                    .zIndex(point.metric.zIndex)


                }
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: -0.05...1.05)
                .chartXScale(domain: xDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                            .font(.appCaption2)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 165)
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.appWhite))
    }
}

// MARK: - Barometer types

private enum BarometerTrend: Equatable {
    case up, down, level

    var systemImageName: String {
        switch self {
        case .up:    return "arrow.up"
        case .down:  return "arrow.down"
        case .level: return "equal"
        }
    }
}

private struct BarometerReading {
    let metric: WellbeingMetric
    let current: Double
    let trend: BarometerTrend
}

private struct BarometerRow: View {
    let metric: WellbeingMetric
    let current: Double
    let trend: BarometerTrend

    var body: some View {
        HStack(spacing: 12) {
            Text(metric.rawValue)
                .font(.appBodySemibold)
                .foregroundStyle(metric.color)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(metric.color.opacity(0.15))
                        .frame(height: 10)

                    Capsule()
                        .fill(metric.color)
                        .frame(width: max(0, geo.size.width * current), height: 10)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)

            Image(systemName: trend.systemImageName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(metric.color)
                .frame(width: 20, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        WellbeingView()
    }
    .modelContainer(for: CheckInEntry.self, inMemory: true)
}
