//
//  MovementInsightGenerator.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import Foundation
import FoundationModels

/// Two short paragraphs about the person's movement: their current condition,
/// and encouraging coaching.
@Generable
struct MovementInsight {
    @Guide(description: "One paragraph of 3 to 5 sentences describing the person's current movement condition and recent trend. Warm and factual.")
    var condition: String

    @Guide(description: "One paragraph of 3 to 5 sentences of encouraging, specific coaching for their movement. Supportive and concrete, never preachy.")
    var coaching: String
}

/// Generates a movement insight with Apple's on-device model. Returns `nil` when
/// the model is unavailable or declines, so callers can fall back to placeholders.
@MainActor
struct MovementInsightGenerator {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func generate(context: String) async -> MovementInsight? {
        guard Self.isAvailable else { return nil }

        let instructions = """
        You are a warm, encouraging movement coach. Write two short paragraphs about \
        the person's recent physical activity: first their current condition and trend, \
        then gentle, specific coaching. Be supportive and concrete, never preachy. \
        Speak directly to the person as "you".
        """
        let prompt = "The person's recent movement: \(context)"

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: prompt, generating: MovementInsight.self)
            return response.content
        } catch {
            return nil
        }
    }
}
