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
            alcohol and how it interplays with THC urges. Tailor to time of day: morning (slate is \
            clean — set a light, clear intention for tonight), afternoon (preview the evening choice \
            before the pull starts), evening (what's gained by holding back; what skipping tonight \
            makes possible tomorrow). When near a weekly limit, focus on what's gained, not what's \
            remaining.
            """
        case .movement:
            return """
            a specific, realistic movement suggestion. Tailor to time of day: morning (ideal window \
            — move before the day fills up), afternoon (a break in the middle of the day keeps \
            momentum alive), evening (gentle movement to wind down, not intensity). Lead with what \
            to do, not what's been done.
            """
        case .connection:
            return """
            a small, specific gesture toward their partner. Tailor to time of day: morning (a warm \
            send-off or shared coffee), afternoon (a quick check-in or message), evening (turning \
            toward each other to end the day well).
            """
        }
    }
}

/// The structured shape we ask the on-device model to fill in for one card.
/// Three separate sentence fields guarantee exactly 3 sentences — the model
/// cannot stop early because every field must be populated.
@Generable
struct GeneratedBriefingCard {
    @Guide(description: "3 to 5 words. A punchy, specific headline. Sentence case — first word capitalized, rest lowercase. No trailing period.")
    var title: String

    @Guide(description: "One sentence. The felt experience right now — what the data means for how this person feels, not what the numbers say. Second person. No numbers.")
    var sentence1: String

    @Guide(description: "One sentence. The one thing to do or stay aware of today. Begin with an action word. Not a restatement of sentence 1.")
    var sentence2: String

    @Guide(description: "One sentence. Why this matters beyond the goal — what it protects, enables, or connects to in their life.")
    var sentence3: String
}

private func capitalizeFirst(_ s: String) -> String {
    guard let first = s.first else { return s }
    return first.uppercased() + s.dropFirst()
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
        VOICE RULE: Never use first person. Never write "I", "I'm", "I've", or "we". \
        You have no voice of your own. Address the reader as "you" only, always. \
        TIME OF DAY RULE: The prompt states the time of day. You MUST match your advice to it — \
        morning cards set up the day ahead, afternoon cards stay grounded mid-day, evening cards \
        help outlast urges and wind down. Never give evening advice in a morning card. \
        CONTENT RULE: Lead with action, not the metric. Never frame anything as a shortfall. \
        Never quote wellbeing scores as numbers. Treat data as lived experience. \
        Connect substance guidance to what the person actually cares about, not just a goal number. \
        Each sentence field is exactly one complete sentence — no more, no less.
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
                generating: GeneratedBriefingCard.self,
                options: GenerationOptions(temperature: 0.5)
            )
            let g = response.content
            var title = g.title
            if title.hasSuffix(".") { title = String(title.dropLast()) }
            let message = [g.sentence1, g.sentence2, g.sentence3].map(capitalizeFirst).joined(separator: " ")
            return BriefingCard(
                title: title,
                message: message,
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
