//
//  InsightGenerator.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import Foundation
import FoundationModels

/// The display model returned to callers — a headline and two joined paragraphs.
struct Insight {
    var headline: String
    var condition: String
    var coaching: String
}

/// Seven focused fields — a headline then six one-sentence fields. Structured generation
/// guarantees every field is populated, enforcing exactly 3 sentences per paragraph.
@Generable
struct GeneratedInsight {
    @Guide(description: "3 to 5 words. A punchy, specific headline that captures the single most useful thing from this insight. Sentence case. No trailing period. No clichés like 'making progress' or 'keep it up'.")
    var headline: String

    @Guide(description: "One sentence. The immediate felt state — what the check-in data means as a single lived experience. Second person. No numbers.")
    var conditionSentence1: String

    @Guide(description: "One sentence. The forward implication — what that state means for energy or focus today. A new idea, not a restatement of the previous sentence.")
    var conditionSentence2: String

    @Guide(description: "One sentence. One specific thing to watch for as the day unfolds. A new angle not covered in the previous two sentences.")
    var conditionSentence3: String

    @Guide(description: "One sentence. One concrete action to take today. Begin with a verb. Second person.")
    var coachingSentence1: String

    @Guide(description: "One sentence. A practical detail about that action — when to do it, what kind, or how long. Not a restatement of the previous sentence.")
    var coachingSentence2: String

    @Guide(description: "One sentence. The deeper reason this action matters — what it protects or enables beyond just the goal.")
    var coachingSentence3: String
}

/// A Codable snapshot of a generated insight, cached by a data signature so it
/// only regenerates when the underlying data changes.
struct CachedInsight: Codable {
    var signature: String
    var headline: String?
    var condition: String
    var coaching: String
}

private func capitalizeFirst(_ s: String) -> String {
    guard let first = s.first else { return s }
    return first.uppercased() + s.dropFirst()
}

/// Generates an `Insight` with Apple's on-device model. Returns `nil` when the
/// model is unavailable or declines, so callers can fall back to placeholders.
@MainActor
struct InsightGenerator {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func generate(instructions: String, context: String) async -> Insight? {
        guard Self.isAvailable else { return nil }

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(
                to: context,
                generating: GeneratedInsight.self,
                options: GenerationOptions(temperature: 0.5)
            )
            let g = response.content
            var headline = capitalizeFirst(g.headline.lowercased())
            if headline.hasSuffix(".") { headline = String(headline.dropLast()) }
            return Insight(
                headline: headline,
                condition: [g.conditionSentence1, g.conditionSentence2, g.conditionSentence3].map(capitalizeFirst).joined(separator: " "),
                coaching: [g.coachingSentence1, g.coachingSentence2, g.coachingSentence3].map(capitalizeFirst).joined(separator: " ")
            )
        } catch {
            return nil
        }
    }
}
