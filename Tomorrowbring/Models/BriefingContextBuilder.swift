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

    /// Builds the context string. Pass `weatherContext` to include current
    /// conditions (used by the movement card). Returns an encouraging general
    /// note when nothing has been logged yet.
    func build(weatherContext: String? = nil, now: Date = .now) -> String {
        let calendar = Calendar.current
        var parts = [
            movementSummary(now: now, calendar: calendar),
            substanceSummary(now: now, calendar: calendar),
            wellbeingSummary(now: now, calendar: calendar),
            checkInSummary(now: now, calendar: calendar)
        ].compactMap { $0 }

        if let weather = weatherContext {
            parts.insert("Weather: \(weather)", at: 0)
        }

        if parts.isEmpty {
            return "They haven't logged anything yet, so keep the guidance general, warm, and encouraging."
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Movement

    private func movementSummary(now: Date, calendar: Calendar) -> String? {
        let descriptor = FetchDescriptor<MovementEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        guard !entries.isEmpty else { return nil }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let thisWeek = entries.filter { $0.date >= weekAgo }
        let priorWeek = entries.filter { $0.date >= twoWeeksAgo && $0.date < weekAgo }
        let thisMinutes = Int(thisWeek.reduce(0) { $0 + $1.durationMinutes })
        let priorMinutes = Int(priorWeek.reduce(0) { $0 + $1.durationMinutes })

        let trend: String
        if priorMinutes == 0 {
            trend = ""
        } else if thisMinutes < Int(Double(priorMinutes) * 0.9) {
            trend = ", down from \(priorMinutes) min the week before"
        } else if thisMinutes > Int(Double(priorMinutes) * 1.1) {
            trend = ", up from \(priorMinutes) min the week before"
        } else {
            trend = ", about the same as the week before"
        }

        let daysSince: String
        if let latest = entries.first {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: latest.date),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            daysSince = switch days {
            case 0: " Last session today."
            case 1: " Last session yesterday."
            default: " Last session \(days) days ago."
            }
        } else {
            daysSince = ""
        }

        let goal = MovementGoal.load()
        var line = "Movement goal: \(goal.mode.coachingNote)."
        if !thisWeek.isEmpty {
            line += " \(thisWeek.count) workouts this week (\(thisMinutes) min\(trend)).\(daysSince)"
        } else if !priorWeek.isEmpty {
            line += " No workouts logged this week (\(priorMinutes) min last week).\(daysSince)"
        }
        if goal.mode == .targeted, let target = goal.weeklySessionTarget {
            let remaining = max(0, target - thisWeek.count)
            line += " Target: \(target)/week, \(remaining) remaining."
        }
        return line
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

        let todayStart = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        var lines: [String] = []
        for kind in SubstanceKind.allCases {
            let thisWeek = total(kind, from: weekAgo, to: now)
            let priorWeek = total(kind, from: twoWeeksAgo, to: weekAgo)
            let today = total(kind, from: todayStart, to: tomorrow)
            let goal = SubstanceGoal.load(for: kind)

            guard goal.mode != .notTracking else { continue }
            guard thisWeek > 0 || priorWeek > 0 || goal.mode != .trackingOnly else { continue }

            let trend: String
            if priorWeek == 0 {
                trend = ""
            } else if thisWeek < priorWeek * 0.9 {
                trend = ", down from \(number(priorWeek)) \(kind.unit) last week"
            } else if thisWeek > priorWeek * 1.1 {
                trend = ", up from \(number(priorWeek)) \(kind.unit) last week"
            } else {
                trend = ", similar to last week"
            }

            // Explicit today vs history — prevents the model from treating weekly
            // totals as if they happened today.
            let todayNote = today > 0 ? "\(number(today)) today" : "none today"

            var line = "\(kind.rawValue) goal: \(goal.mode.coachingNote)."
            if thisWeek > 0 || priorWeek > 0 {
                line += " \(number(thisWeek)) \(kind.unit) this week (\(todayNote))\(trend)."
            }
            if goal.mode == .targeted, let limit = goal.weeklyLimit {
                let remaining = max(0, Int(limit) - Int(thisWeek))
                line += " Limit: \(Int(limit)) \(kind.unit)/week, \(remaining) remaining."
            }
            lines.append(line)
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
