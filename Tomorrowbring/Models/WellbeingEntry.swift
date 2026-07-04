//
//  WellbeingEntry.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import Foundation
import SwiftData

/// A single wellbeing check, rating three metrics from 1 to 5.
@Model
final class WellbeingEntry {
    var timestamp: Date
    var calm: Int
    var energy: Int
    var mood: Int

    init(timestamp: Date = .now, calm: Int, energy: Int, mood: Int) {
        self.timestamp = timestamp
        self.calm = calm
        self.energy = energy
        self.mood = mood
    }
}
