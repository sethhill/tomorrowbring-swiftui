
//
//  MovementGoal.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import Foundation

enum MovementGoalMode: String, Codable, CaseIterable, Identifiable {
    case trackingOnly = "Tracking only"
    case increase     = "General increase"
    case targeted     = "Targeted increase"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .trackingOnly: return "Logging without a directional goal."
        case .increase:     return "Building more movement over time — no fixed number."
        case .targeted:     return "A specific weekly session target to hit."
        }
    }

    var coachingNote: String {
        switch self {
        case .trackingOnly: return "no specific goal — tracking only"
        case .increase:     return "general increase — building consistency over time"
        case .targeted:     return "targeted increase with a weekly session goal"
        }
    }
}

struct MovementGoal: Codable, Equatable {
    var mode: MovementGoalMode
    /// Sessions per week. Only meaningful when `mode == .targeted`.
    var weeklySessionTarget: Int?

    static let `default` = MovementGoal(mode: .trackingOnly, weeklySessionTarget: nil)

    static func load() -> MovementGoal {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let goal = try? JSONDecoder().decode(MovementGoal.self, from: data)
        else { return .default }
        return goal
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static let storageKey = "movementGoal"
}
