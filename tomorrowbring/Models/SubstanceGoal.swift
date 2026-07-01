
//
//  SubstanceGoal.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import Foundation

/// The four goal modes available per substance.
enum SubstanceGoalMode: String, Codable, CaseIterable, Identifiable {
    case trackingOnly = "Tracking only"
    case reduction    = "General reduction"
    case targeted     = "Targeted reduction"
    case elimination  = "Total elimination"

    var id: String { rawValue }

    /// Short description shown in the settings card.
    var detail: String {
        switch self {
        case .trackingOnly: return "Logging without a directional goal."
        case .reduction:    return "Trending lighter over time — no fixed number."
        case .targeted:     return "A specific weekly limit to stay within."
        case .elimination:  return "Zero use is the goal."
        }
    }

    /// Compact phrase included in the AI coaching context.
    var coachingNote: String {
        switch self {
        case .trackingOnly: return "no specific goal — tracking only"
        case .reduction:    return "general reduction — directional, no fixed target"
        case .targeted:     return "targeted reduction with a weekly limit"
        case .elimination:  return "total elimination — goal is zero use"
        }
    }
}

/// A substance-specific goal, persisted per substance via UserDefaults.
struct SubstanceGoal: Codable, Equatable {
    var mode: SubstanceGoalMode
    /// Only meaningful when `mode == .targeted`.
    var weeklyLimit: Double?

    static let `default` = SubstanceGoal(mode: .trackingOnly, weeklyLimit: nil)

    // MARK: - Persistence

    static func load(for kind: SubstanceKind) -> SubstanceGoal {
        guard let data = UserDefaults.standard.data(forKey: storageKey(for: kind)),
              let goal = try? JSONDecoder().decode(SubstanceGoal.self, from: data)
        else { return .default }
        return goal
    }

    func save(for kind: SubstanceKind) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey(for: kind))
    }

    static func storageKey(for kind: SubstanceKind) -> String {
        "substanceGoal-\(kind.rawValue)"
    }
}
