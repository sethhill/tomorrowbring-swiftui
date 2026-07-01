//
//  SubstanceTrackerView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData
import Charts

/// Shows the full tracker for a single substance: a 7-day bar chart, a 30-day
/// heatmap, a trend summary, suggestions, and a button to log consumption.
struct SubstanceTrackerView: View {
    let kind: SubstanceKind

    @Query private var logs: [SubstanceLog]
    @State private var isLogging = false

    init(kind: SubstanceKind) {
        self.kind = kind
        let raw = kind.rawValue
        _logs = Query(
            filter: #Predicate<SubstanceLog> { $0.kindRaw == raw },
            sort: \.timestamp,
            order: .reverse
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                weeklySection
                heatmapSection
                paragraph(title: "This week’s trend", text: Self.trendPlaceholder)
                paragraph(title: "Suggestions", text: Self.suggestionsPlaceholder)
            }
            .padding()
        }
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
    }

    // MARK: - Sections

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Last 7 days")
            WeeklyBarChart(days: dailyTotals(days: 7), tint: kind.tint, unit: kind.unit)
                .frame(height: 180)
        }
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Last 90 days")
            DailyHeatmap(days: dailyTotals(days: 90), tint: kind.tint)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func paragraph(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(title)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Aggregation

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

    // MARK: - Placeholder copy (replaced by AI later)

    private static let trendPlaceholder = "This is where a short, AI-generated summary of your recent trend will appear — for example whether your intake is rising, holding steady, or easing off compared with previous weeks, and any patterns worth noticing."

    private static let suggestionsPlaceholder = "This is where personalized, AI-generated suggestions will appear — small, encouraging nudges tailored to your recent patterns and goals, never judgmental."
}

/// A simple daily-total bar chart for the last several days.
private struct WeeklyBarChart: View {
    let days: [DayTotal]
    let tint: Color
    let unit: String

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value(unit, day.amount)
            )
            .foregroundStyle(tint)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
    }
}

#Preview {
    NavigationStack {
        SubstanceTrackerView(kind: .thc)
            .navigationTitle("THC")
    }
    .modelContainer(SubstancePreviewData.container)
}
