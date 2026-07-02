//
//  DailyHeatmap.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import SwiftUI

/// A GitHub-contributions-style heatmap: one cell per day, arranged in
/// weekday-aligned week columns, shaded by relative intensity. Cells are sized
/// from the measured width so the grid never exceeds its container.
struct DailyHeatmap: View {
    let days: [DayTotal]
    let tint: Color

    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = false

    private let spacing: CGFloat = 3
    @State private var cellSize: CGFloat = 12

    private var maxAmount: Double {
        max(days.map(\.amount).max() ?? 0, 1)
    }

    /// Pads the front so the first day lands on its correct weekday row.
    private var paddedCells: [DayTotal?] {
        guard let first = days.first else { return [] }
        let weekday = Calendar.current.component(.weekday, from: first.date) // 1=Sun … 7=Sat
        // Sunday start: Sun=0, Mon=1 … Sat=6
        // Monday start: Mon=0, Tue=1 … Sun=6
        let leadingCount = weekStartsOnMonday ? (weekday - 2 + 7) % 7 : weekday - 1
        let leadingBlanks = Array<DayTotal?>(repeating: nil, count: leadingCount)
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
            grid
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { width in
                    updateCellSize(forWidth: width)
                }
            legend
        }
    }

    private var grid: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { row in
                        cell(row < week.count ? week[row] : nil)
                    }
                }
            }
        }
    }

    /// Computes the largest whole-point cell size whose columns fit `width`.
    private func updateCellSize(forWidth width: CGFloat) {
        let columns = CGFloat(max(weeks.count, 1))
        let available = width - spacing * (columns - 1)
        cellSize = max(floor(available / columns), 1)
    }

    private func cell(_ day: DayTotal?) -> some View {
        Group {
            if let day {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: day))
            } else {
                // Leading alignment blanks and future slots are invisible so
                // only real past days are visible in the grid.
                Color.clear
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private func color(for day: DayTotal) -> Color {
        guard day.amount > 0 else { return Color.secondary.opacity(0.12) }
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
