//
//  MovementEntry.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import Foundation
import SwiftData

/// A kind of movement activity, used for manual logging and display.
enum MovementType: String, CaseIterable, Identifiable {
    case running, cycling, walking, hiking, yoga, strength, swimming, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .strength: return "Strength"
        case .swimming: return "Swimming"
        case .other: return "Workout"
        }
    }

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .yoga: return "figure.yoga"
        case .strength: return "figure.strengthtraining.traditional"
        case .swimming: return "figure.pool.swim"
        case .other: return "figure.mixed.cardio"
        }
    }
}

/// A manually logged workout, persisted with SwiftData.
@Model
final class MovementEntry {
    var id: UUID
    var typeRaw: String
    var date: Date
    var durationMinutes: Double

    init(type: MovementType, date: Date = .now, durationMinutes: Double) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.date = date
        self.durationMinutes = durationMinutes
    }

    var type: MovementType {
        MovementType(rawValue: typeRaw) ?? .other
    }
}

/// A unified movement activity for display, sourced from either Apple Health or
/// a manual entry.
struct MovementActivity: Identifiable {
    enum Source {
        case health
        case manual
    }

    let id: String
    let type: MovementType
    let date: Date
    let durationMinutes: Double
    let distanceMeters: Double?
    let source: Source
}
