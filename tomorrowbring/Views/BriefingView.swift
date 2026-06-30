//
//  BriefingView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

/// A single coaching card in the briefing: a short headline plus a paragraph.
struct BriefingCard: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let tint: Color
}

/// AI-generated summary of the current state of things plus coaching suggestions
/// for the day, shown as a series of themed cards that vary by time of day.
struct BriefingView: View {
    /// The part of day the briefing is tailored to.
    enum TimeOfDay {
        case morning, afternoon, evening

        /// Derives the current part of day from the hour.
        static var current: TimeOfDay {
            switch Calendar.current.component(.hour, from: Date()) {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            default: return .evening
            }
        }

        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            }
        }

        var icon: String {
            switch self {
            case .morning: return "sun.horizon.fill"
            case .afternoon: return "sun.max.fill"
            case .evening: return "moon.stars.fill"
            }
        }
    }

    private let timeOfDay = TimeOfDay.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                ForEach(BriefingView.cards(for: timeOfDay)) { card in
                    BriefingCardView(card: card)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Briefing")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: timeOfDay.icon)
                    .foregroundStyle(.brandGold)
                Text(timeOfDay.greeting)
                    .font(.largeTitle)
                    .bold()
            }
            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Placeholder content (replaced by AI generation later)

extension BriefingView {
    /// Themed coaching cards for the given time of day. Placeholder copy for now.
    static func cards(for timeOfDay: TimeOfDay) -> [BriefingCard] {
        switch timeOfDay {
        case .morning: return morningCards
        case .afternoon: return afternoonCards
        case .evening: return eveningCards
        }
    }

    private static let morningCards: [BriefingCard] = [
        BriefingCard(
            title: "Bank the clear morning",
            message: "Waking up clear-headed is the whole point — it's the dividend a lighter evening pays out, and the morning is when the pull toward THC is at its quietest. You don't have to do anything to earn it right now except notice it: the sharpness, the readiness, the absence of fog. Let that feeling be the argument for tonight rather than a rule you're forcing on yourself. Carry the momentum into the day and let the easy hours stay easy.",
            icon: "leaf.fill",
            tint: .brandGreen
        ),
        BriefingCard(
            title: "Nothing to manage yet",
            message: "The day is a blank slate on the drinks, and that's exactly where you want to be in the morning — no decisions to make and no streak to defend. Keep it that way by not deciding anything now; the choice actually lives in the evening. For now, just bank the calm of a morning that doesn't owe anything to last night. That clean start is worth protecting later.",
            icon: "wineglass.fill",
            tint: .brandOrange
        ),
        BriefingCard(
            title: "Move before the heat",
            message: "It won't be cooler than it is right now, so if there's a walk in today, the morning is your window. Keep it easy and short — the foot is still mending and steadiness beats intensity every time. Even ten gentle minutes keeps the streak alive and nudges your weight in the direction it's already heading. No need to chase running yet; the easy miles are doing real work.",
            icon: "figure.walk",
            tint: .brandGold
        ),
        BriefingCard(
            title: "Set a warm tone early",
            message: "However last night landed, the first small gesture of the day tends to set the weather for both of you. A coffee made without being asked, a question about her morning, a hand on the shoulder — these tiny bids are what keep the bond steady. It costs almost nothing and it heads off the quiet friction before it has a chance to build. Start warm and let the day follow.",
            icon: "heart.fill",
            tint: .brandOrange
        )
    ]

    private static let afternoonCards: [BriefingCard] = [
        BriefingCard(
            title: "Ride out the afternoon dip",
            message: "The mid-afternoon lull is a sneaky one — the reach for something to take the edge off is usually energy talking, not real craving. Name it for what it is before you act on it, and more often than not it loosens its grip on its own. A short walk, a glass of water, or five minutes away from the screen does more than you'd expect. You've already got the morning's clear head in the bank; don't spend it now.",
            icon: "leaf.fill",
            tint: .brandGreen
        ),
        BriefingCard(
            title: "Still steady, stay ahead of it",
            message: "You're comfortably within your week and there's nothing to undo here. The afternoon is a good time to picture how you want tonight to go, before the evening pull starts making the case for you. If you decide now that tonight leans toward tea and an early wind-down, the choice is already half made. Future-you wakes up grateful for the call you make this afternoon.",
            icon: "wineglass.fill",
            tint: .brandOrange
        ),
        BriefingCard(
            title: "A little still counts",
            message: "If the morning got away from you, the afternoon still has room for a few easy minutes — movement doesn't have to be all-or-nothing. Keep it gentle on the foot; the win is consistency, not mileage. Even a short loop or some stretching keeps the streak intact and breaks up the sitting. Momentum is the goal, and small counts.",
            icon: "figure.walk",
            tint: .brandGold
        ),
        BriefingCard(
            title: "Plan the evening while it's calm",
            message: "Things are quieter now than they'll be tonight, so this is the moment to set up a gentle evening with Nina. A small plan — tea, a show you'll both enjoy, an earlier wind-down — gives the night something to steer toward instead of drift through. You don't need a grand gesture, just a shared intention. Decide it now and the evening gets easier.",
            icon: "heart.fill",
            tint: .brandOrange
        )
    ]

    private static let eveningCards: [BriefingCard] = [
        BriefingCard(
            title: "Outlast the evening call",
            message: "This is the part of the day when the pull toward THC gets loud — work's behind you, the house goes quiet, and your mind starts reaching for the wind-down. Before you reach back, ask what's actually underneath it tonight: is it fatigue, restlessness, or just the habit of the hour? If you can sit with it, the craving usually crests and fades inside fifteen or twenty minutes — you don't have to fight it, just outlast it. Tonight try landing at 10 and noticing how much sharper and more present you feel in the morning; that clear-headed start is what a lighter evening buys you, and it's worth more than the haze.",
            icon: "leaf.fill",
            tint: .brandGreen
        ),
        BriefingCard(
            title: "You're steady on the drinks",
            message: "You've kept it dry today and stayed comfortably within your week — no need to white-knuckle anything here. If the evening wants a ritual, let it be tea or a show with Nina rather than a pour. Every night you skip is a morning where you wake up ready instead of foggy, and that's the version of you the running comeback needs.",
            icon: "wineglass.fill",
            tint: .brandOrange
        ),
        BriefingCard(
            title: "Three walks already, keep moving",
            message: "Three walks this week is real momentum, especially with your foot still mending — every easy mile is a win right now, no need to rush back to running. With ninety degrees and thunderstorms rolling in tonight, this is an indoor evening: a little gentle movement at home or some stretching keeps the streak alive without testing the foot or the weather. Your weight's already trending down, and it responds to exactly this — steady walks, lighter evenings, decent sleep — so just keep pulling those same threads and let it follow.",
            icon: "figure.walk",
            tint: .brandGold
        ),
        BriefingCard(
            title: "Turn toward her tonight",
            message: "You mentioned the cats were stressful this morning — small friction like that has a way of quietly setting the tone for a couple, so tonight is a good night to reset it with Nina. With the storm keeping you both in, lean into the closeness of it: make the tea, put on something you'll both enjoy, and let the rainy evening be a reason to slow down together rather than scatter. Notice the small bids she makes — a comment, a glance, a question — and turn toward them; those tiny moments of being met are what keep the bond steady. One warm evening like this does more than any grand gesture.",
            icon: "heart.fill",
            tint: .brandOrange
        )
    ]
}

/// A single briefing coaching card: accent icon + headline, then the paragraph.
private struct BriefingCardView: View {
    let card: BriefingCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: card.icon)
                    .font(.headline)
                    .foregroundStyle(card.tint)
                Text(card.title)
                    .font(.headline)
            }
            Text(card.message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }
}

#Preview {
    NavigationStack {
        BriefingView()
    }
}
