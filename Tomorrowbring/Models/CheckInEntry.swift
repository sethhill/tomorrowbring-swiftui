//
//  CheckInEntry.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import Foundation
import SwiftData

/// A single question-and-answer pair captured during a check-in.
struct CheckInResponse: Codable, Hashable {
    var prompt: String
    var answer: String
}

/// A completed check-in, persisted with SwiftData.
@Model
final class CheckInEntry {
    var timestamp: Date
    var responses: [CheckInResponse]

    init(timestamp: Date = .now, responses: [CheckInResponse]) {
        self.timestamp = timestamp
        self.responses = responses
    }
}
