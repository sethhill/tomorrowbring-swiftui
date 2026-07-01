//
//  DailyHeatmap.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import SwiftUI

/// A GitHub-contributions-style heatmap: one cell per day, arranged in
/// weekday-aligned week columns, shaded by relative intensity. The grid fills
/// the available width, with cells sized to stay square.
struct DailyHeatmap: View {
    let days: [DayTotal]
    let tint: Color

    private let spacing: CGFloat = 3

    private var maxAmount: Double {
        max(days.map(\.amount).max() ?? 0, 1)
    }

    /// Pads the front so the first day lands on its correct weekday row.
    private var paddedCells: [DayTotal?] {
        guard let first = days.first else { return [] }
        let weekday = Calendar.current.component(.weekday, from: first.date) // 1 = Sunday
        let leadingBlanks = Array<DayTotal?>(repeating: nil, count: weekday - 1)
        return leadingBlanks + days.map { Optional($0) }
    }

    /// Groups the padded cells into columns of 7 (one column per week).
    private var weeks: [[DayTotal?]] {
        let cells = paddedCells
        return stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start..<min(start + 7, cells.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            cell(row < week.count ? week[row] : nil)
                        }
                    }
                }
            }
            // Fill the width while keeping cells square (columns : 7 rows).
            .aspectRatio(CGFloat(weeks.count) / 7, contentMode: .fit)
            legend
        }
    }

    private func cell(_ day: DayTotal?) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color(for: day))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func color(for day: DayTotal?) -> Color {
        guard let day, day.amount > 0 else { return Color.secondary.opacity(0.12) }
        let intensity = day.amount / maxAmount
        return tint.opacity(0.3 + 0.7 * intensity)
    }

    private var legend: some View {
        HStack(spacing: spacing) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach([0.12, 0.3, 0.5, 0.7, 1.0], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level == 0.12 ? Color.secondary.opacity(0.12) : tint.opacity(level))
                    .frame(width: 10, height: 10)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
