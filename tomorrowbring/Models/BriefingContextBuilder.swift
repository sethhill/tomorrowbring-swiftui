//
//  BriefingContextBuilder.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import Foundation
import SwiftData

/// Summarizes the user's recent logged data into a short natural-language
/// paragraph, used as context for on-device briefing generation.
@MainActor
struct BriefingContextBuilder {
    let modelContext: ModelContext

    /// Builds the context string. Returns an encouraging general note when
    /// nothing has been logged yet.
    func build(now: Date = .now) -> String {
        let calendar = Calendar.current
        let parts = [
            substanceSummary(now: now, calendar: calendar),
            wellbeingSummary(now: now, calendar: calendar),
            checkInSummary(now: now, calendar: calendar)
        ].compactMap { $0 }

        if parts.isEmpty {
            return "They haven't logged anything yet, so keep the guidance general, warm, and encouraging."
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Substances

    private func substanceSummary(now: Date, calendar: Calendar) -> String? {
        let logs = (try? modelContext.fetch(FetchDescriptor<SubstanceLog>())) ?? []
        guard !logs.isEmpty,
              let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)
        else { return nil }

        func total(_ kind: SubstanceKind, from: Date, to: Date) -> Double {
            logs.filter { $0.kind == kind && $0.timestamp >= from && $0.timestamp < to }
                .reduce(0) { $0 + $1.amount }
        }

        var lines: [String] = []
        for kind in SubstanceKind.allCases {
            let thisWeek = total(kind, from: weekAgo, to: now)
            let priorWeek = total(kind, from: twoWeeksAgo, to: weekAgo)
            guard thisWeek > 0 || priorWeek > 0 else { continue }

            let trend: String
            if priorWeek == 0 {
                trend = ""
            } else if thisWeek < priorWeek * 0.9 {
                trend = ", down from \(number(priorWeek)) \(kind.unit) the week before"
            } else if thisWeek > priorWeek * 1.1 {
                trend = ", up from \(number(priorWeek)) \(kind.unit) the week before"
            } else {
                trend = ", about the same as the week before"
            }
            lines.append("\(kind.rawValue): \(number(thisWeek)) \(kind.unit) over the last 7 days\(trend).")
        }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    // MARK: - Wellbeing

    private func wellbeingSummary(now: Date, calendar: Calendar) -> String? {
        var descriptor = FetchDescriptor<WellbeingEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let latest = (try? modelContext.fetch(descriptor))?.first else { return nil }

        let when = relativeDay(from: latest.timestamp, now: now, calendar: calendar)
        return "Their most recent wellbeing check (\(when)) was calm \(latest.calm)/5, energy \(latest.energy)/5, mood \(latest.mood)/5."
    }

    // MARK: - Check-in

    private func checkInSummary(now: Date, calendar: Calendar) -> String? {
        var descriptor = FetchDescriptor<CheckInEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let latest = (try? modelContext.fetch(descriptor))?.first,
              !latest.responses.isEmpty
        else { return nil }

        let when = relativeDay(from: latest.timestamp, now: now, calendar: calendar)
        let answers = latest.responses
            .map { "\($0.prompt) \($0.answer)" }
            .joined(separator: "; ")
        return "In their latest check-in (\(when)) they said — \(answers)."
    }

    // MARK: - Helpers

    private func number(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private func relativeDay(from date: Date, now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        default: return "\(days) days ago"
        }
    }
}
