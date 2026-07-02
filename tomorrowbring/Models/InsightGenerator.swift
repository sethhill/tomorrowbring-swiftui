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
    @Guide(description: "One paragraph of 3 to 5 sentences about what the pattern suggests and how things feel right now. Always second person ('you') — never use 'I', 'I'm', or 'we'. Translate data to felt experience, never quote numbers. Never frame as a shortfall. Each sentence must introduce a distinct new idea.")
    var condition: String

    @Guide(description: "One paragraph of 3 to 5 sentences of specific, action-first coaching. Lead with one concrete thing to do today, then add practical detail (when, what kind, how long), then connect to the bigger picture. Always second person ('you') — never use 'I', 'I'm', or 'we'. Each sentence must introduce a distinct new idea.")
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
