//
//  InsightGenerator.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import Foundation
import FoundationModels

/// Two short paragraphs: the person's current condition, and encouraging coaching.
@Generable
struct Insight {
    @Guide(description: "Exactly 3 sentences. Always write all 3 — never stop at 2. What the current pattern suggests about how things feel right now. Second person ('you') only. Translate data to felt experience — never quote numbers, never frame as a shortfall. Each sentence introduces a distinct new idea.")
    var condition: String

    @Guide(description: "Exactly 3 sentences. Always write all 3 — never stop at 2. First: one concrete action to take today. Second: a practical detail (when, what kind, or how long). Third: why it connects to the bigger picture. Second person ('you') only. Each sentence introduces a distinct new idea.")
    var coaching: String
}

/// A Codable snapshot of a generated insight, cached by a data signature so it
/// only regenerates when the underlying data changes.
struct CachedInsight: Codable {
    var signature: String
    var condition: String
    var coaching: String
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
            let response = try await session.respond(to: context, generating: Insight.self)
            return response.content
        } catch {
            return nil
        }
    }
}
