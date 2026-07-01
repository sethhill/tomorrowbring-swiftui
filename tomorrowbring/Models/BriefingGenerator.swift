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
            return """
            cannabis urges and what might actually be driving them right now — fatigue, frustration, \
            hunger, or boredom. Name the real driver gently and suggest a physical or social interrupt. \
            Tailor to time of day: morning (urges quiet — help set up the day), afternoon (craving \
            forming in the background — surface what's driving it, name it so it gets smaller), evening \
            (craving active — lean into grounding, ritual, and outlasting it; cravings peak and pass \
            in 15–20 minutes). Connect mindful use to something the person cares about beyond the goal.
            """
        case .alcohol:
            return """
            alcohol and how it interplays with THC urges today — the combined pull in the evening, \
            how the two reinforce each other, what to stay aware of. When near a weekly limit, focus \
            on what's gained by holding back, not what's remaining. Ask what skipping tonight makes \
            possible tomorrow.
            """
        case .movement:
            return """
            a specific, realistic movement suggestion for today. If weather data is provided, weave \
            it in naturally — only mention weather here. Lead with what to do, not what's been done.
            """
        case .connection:
            return "a small, specific gesture toward their partner — realistic for the time of day."
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
        You are a warm, direct wellbeing coach. Always write in second person ("you") — never \
        first person. Write one flowing paragraph of 3–5 sentences weaving together the situation, \
        what it means, and what to do — no lists or separated thoughts. Lead with action, not the \
        metric. Never frame anything as a shortfall or deficit. Never say "you haven't" — if there \
        is nothing constructive to offer for an area, skip it. Never quote wellbeing scores as \
        numbers — translate to felt experience ("you've got fuel today", not "energy is 4/5"). \
        Treat data as lived experience, not a report card. Connect substance guidance to what the \
        person actually cares about, not just a goal number.
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
