//
//  BriefingGenerator.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import Foundation
import SwiftUI
import FoundationModels

/// A coaching theme the briefing covers, carrying its presentation details and
/// the seed used to prompt the on-device model.
enum BriefingTheme: String, CaseIterable {
    case thc
    case alcohol
    case movement
    case connection

    var icon: String {
        switch self {
        case .thc: return "leaf.fill"
        case .alcohol: return "wineglass.fill"
        case .movement: return "figure.walk"
        case .connection: return "heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .thc: return .brandGreen
        case .alcohol: return .brandOrange
        case .movement: return .brandGold
        case .connection: return .brandOrange
        }
    }

    /// What this card should focus on, woven into the prompt.
    var focus: String {
        switch self {
        case .thc:
            return "keeping their cannabis/THC use light and riding out any craving"
        case .alcohol:
            return "staying within their drinking goals, with a gentle alcohol-free ritual if the evening wants one"
        case .movement:
            return "a little gentle movement that fits their day and energy"
        case .connection:
            return "a small, warm gesture toward their partner"
        }
    }
}

/// The structured shape we ask the on-device model to fill in for one card.
@Generable
struct GeneratedBriefingCard {
    @Guide(description: "A short, punchy headline of 3 to 6 words")
    var title: String

    @Guide(description: "A warm, encouraging coaching paragraph of 3 to 5 sentences, supportive and specific, never preachy")
    var message: String
}

/// Generates briefing cards using Apple's on-device language model, one card per
/// theme. Falls back gracefully (returns `nil`) whenever the model is
/// unavailable or declines, so callers can show placeholder content instead.
@MainActor
struct BriefingGenerator {
    /// Whether the on-device model is ready to use on this device right now.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Human-readable reason the model can't be used, for diagnostics.
    static var availabilityDescription: String {
        String(describing: SystemLanguageModel.default.availability)
    }

    /// Generates a coaching card for each theme. Returns `nil` if the model is
    /// unavailable or every theme is declined. Individual themes that fail are
    /// simply omitted from the result.
    func generateCards(
        for timeOfDay: BriefingView.TimeOfDay,
        context: String
    ) async -> [BriefingCard]? {
        guard Self.isAvailable else { return nil }

        var cards: [BriefingCard] = []
        for theme in BriefingTheme.allCases {
            if let card = await generateCard(for: theme, timeOfDay: timeOfDay, context: context) {
                cards.append(card)
            }
        }
        return cards.isEmpty ? nil : cards
    }

    /// Generates a single card, returning `nil` if the model declines or errors.
    private func generateCard(
        for theme: BriefingTheme,
        timeOfDay: BriefingView.TimeOfDay,
        context: String
    ) async -> BriefingCard? {
        let instructions = """
        You are a warm, non-judgmental wellbeing coach helping someone with their \
        daily habits. Write a single short coaching card: a brief headline and an \
        encouraging paragraph. Be supportive, specific, and gentle — never preachy \
        or clinical. Speak directly to the person as "you".
        """

        let prompt = """
        Time of day: \(timeOfDay.promptName).
        About the person right now: \(context)
        Write one card focused on \(theme.focus).
        """

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedBriefingCard.self
            )
            return BriefingCard(
                title: response.content.title,
                message: response.content.message,
                icon: theme.icon,
                tint: theme.tint,
                theme: theme
            )
        } catch {
            // Unavailable, declined by guardrails, context-window, etc.
            return nil
        }
    }
}
