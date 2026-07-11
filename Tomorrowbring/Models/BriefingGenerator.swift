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
    case wellbeing
    case movement
    case substances

    var icon: String {
        switch self {
        case .wellbeing:   return "heart.fill"
        case .movement:    return "figure.walk"
        case .substances:  return "wineglass.fill"
        }
    }

    var tint: Color {
        switch self {
        case .wellbeing:   return .brandGreen
        case .movement:    return .brandGold
        case .substances:  return .brandOrange
        }
    }

    /// What this card should focus on, woven into the prompt.
    var focus: String {
        switch self {
        case .wellbeing:
            return "the person's energy, mood, and stress from the latest check-in — " +
                   "translate to felt experience (no raw words), connect to something " +
                   "they can concretely notice or protect today."
        case .movement:
            return "a specific, realistic movement suggestion matched to time of day — " +
                   "morning: move before the day fills up; afternoon: a break keeps momentum; " +
                   "evening: gentle, not intense. Lead with what to do, not what's been done."
        case .substances:
            return "the person's relationship with whatever substances they're tracking today — " +
                   "focus on urges and what's actually driving them (fatigue, boredom, habit), " +
                   "then the decision point ahead. Morning: set a light intention; " +
                   "afternoon: preview the choice before the pull starts; " +
                   "evening: what's gained by pausing, not what's lost. " +
                   "Address whichever substances appear in the context data. Never encourage use."
        }
    }
}

/// The structured shape for one briefing card.
@Generable
struct GeneratedBriefingCard {
    @Guide(description: "3 to 7 words. Punchy, specific. Sentence case. No trailing period. No clichés.")
    var title: String

    @Guide(description: "Exactly four sentences as one cohesive paragraph. Sentence 1: the felt experience right now, translated from data to lived reality — second person, no raw numbers. Sentence 2: the one concrete thing to do or notice today, beginning with an action verb. Sentence 3: a specific consequence or shift that deepens the advice — not a generic restatement. Sentence 4: a closing thought that makes the advice stick — an image, an analogy, or a direct challenge. No fragments, no run-ons.")
    var paragraph: String
}

/// Container that generates all three cards in a single model call so the model
/// can vary language, angle, and metaphor across them naturally.
@Generable
struct AllBriefingCards {
    @Guide(description: "Wellbeing card — energy, mood, and stress translated to felt experience.")
    var wellbeing: GeneratedBriefingCard

    @Guide(description: "Movement card — a specific, time-of-day-appropriate activity suggestion.")
    var movement: GeneratedBriefingCard

    @Guide(description: "Substances card — urges, their real driver, and the decision point ahead. Address whichever substances (THC and/or alcohol) appear in the context. Never encourage use.")
    var substances: GeneratedBriefingCard
}

private func capitalizeFirst(_ s: String) -> String {
    guard let first = s.first else { return s }
    return first.uppercased() + s.dropFirst()
}

/// Generates briefing cards using Apple's on-device language model, all four
/// themes in a single session so the model can naturally vary them.
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

    /// Generates coaching cards in one session. Returns `nil` if the model is
    /// unavailable or declines. Non-tracked substances are omitted from the result.
    func generateCards(
        for timeOfDay: BriefingView.TimeOfDay,
        context: String,
        trackedSubstances: Set<SubstanceKind> = Set(SubstanceKind.allCases)
    ) async -> [BriefingCard]? {
        guard Self.isAvailable else { return nil }

        let instructions = """
        VOICE: Never first person. No "I", "I'm", "I've", or "we". Address the reader as "you" only.

        TIME: You are writing for \(timeOfDay.promptName). Every card must match this — \
        morning cards set up the day ahead, afternoon cards stay grounded mid-day, \
        evening cards help wind down and outlast urges. Never give evening advice in a morning card.

        STRICT LANES — each card draws only from its own data. Do not cross-reference:
        - Wellbeing card: only check-in responses (energy, mood, stress). Ignore substance amounts and movement.
        - Movement card: only movement history. Ignore substances and wellbeing scores.
        - Substances card: only substance patterns (THC and/or alcohol, whichever appear in the data). Ignore movement data and wellbeing scores.

        NO INVENTED LIMITS: Never mention a weekly limit, quota, or cap unless the context \
        explicitly states one with a number. If the goal is tracking-only or reduction, \
        there is no limit — do not invent one, do not say the person is "nearing" anything.

        NO INVENTED CONNECTIONS: Never link data across lanes. Low energy does not imply substance use \
        caused it — do not say so. Weekly substance totals span the past 7 days; the context will tell \
        you how much was today. Never say "you've already had X" or "you've been using X" unless \
        the context explicitly shows today's logged use. Never construct a causal story the data does not state.

        SUBSTANCE SAFETY — ABSOLUTE RULE: Never encourage, suggest, normalise, or depict \
        alcohol or cannabis consumption in any form. This includes: describing the person \
        as currently consuming ("as you sip", "while you enjoy", "as you use"), framing use \
        as a reward or ritual, implying use is a reasonable or expected outcome of the evening, \
        or treating any amount of use as positive. This rule applies regardless of goal mode — \
        even tracking-only users must receive guidance oriented toward awareness and restraint, \
        never toward use. If the card has nothing useful to say without implying use, write \
        about the urge, the decision point, or what the person gains by pausing instead.

        CONTENT: Lead with action, not the metric. Never frame anything as a shortfall. \
        Treat check-in answers as lived experience, not labels to echo back.

        DISTINCTNESS: All cards must feel clearly different — different angles, structures, metaphors. \
        No phrase or idea should recur across cards.

        FORMAT: Each paragraph field is exactly four complete sentences — no fragments, no run-ons, no bullet points.
        """

        let prompt = """
        Time of day: \(timeOfDay.promptName).
        About the person right now: \(context)

        Write three briefing cards. Each must stay strictly within its assigned data lane \
        and use different language from the others.

        Wellbeing card focus: \(BriefingTheme.wellbeing.focus)
        Movement card focus: \(BriefingTheme.movement.focus)
        Substances card focus: \(BriefingTheme.substances.focus)
        """

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(
                to: prompt,
                generating: AllBriefingCards.self,
                options: GenerationOptions(temperature: 0.7)
            )
            let all = response.content
            var cards: [BriefingCard] = [
                makeCard(all.wellbeing, theme: .wellbeing),
                makeCard(all.movement, theme: .movement)
            ]
            if !trackedSubstances.isEmpty {
                cards.append(makeCard(all.substances, theme: .substances))
            }
            return cards
        } catch {
            return nil
        }
    }

    private func makeCard(_ g: GeneratedBriefingCard, theme: BriefingTheme) -> BriefingCard {
        var title = g.title
        if title.hasSuffix(".") { title = String(title.dropLast()) }
        return BriefingCard(title: title, message: capitalizeFirst(g.paragraph), icon: theme.icon, tint: theme.tint, theme: theme)
    }
}
