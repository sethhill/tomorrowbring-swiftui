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
    /// The theme this card was generated for, when applicable (used for caching).
    var theme: BriefingTheme? = nil
}

/// A Codable snapshot of a generated briefing, cached per time-of-day slot so it
/// regenerates at most a few times a day rather than on every launch.
private struct CachedBriefing: Codable {
    var slotKey: String
    var cards: [CachedCard]
}

private struct CachedCard: Codable {
    var title: String
    var message: String
    var themeRaw: String

    init(_ card: BriefingCard) {
        title = card.title
        message = card.message
        themeRaw = (card.theme ?? .thc).rawValue
    }

    /// Rebuilds a display card, restoring its icon and tint from the theme.
    var card: BriefingCard {
        let theme = BriefingTheme(rawValue: themeRaw) ?? .thc
        return BriefingCard(
            title: title,
            message: message,
            icon: theme.icon,
            tint: theme.tint,
            theme: theme
        )
    }
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

        /// Lowercase name used inside generation prompts.
        var promptName: String {
            switch self {
            case .morning: return "morning"
            case .afternoon: return "afternoon"
            case .evening: return "evening"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    private var timeOfDay: TimeOfDay { .current }

    /// Where the cards currently on screen came from.
    enum GenerationStatus {
        case idle
        case onDevice
        case fellBackUnavailable
        case fellBackDeclined

        var note: String? {
            switch self {
            case .idle: return nil
            case .onDevice: return "Generated on-device with Apple Intelligence."
            case .fellBackUnavailable: return "Showing sample content — Apple Intelligence is unavailable on this device."
            case .fellBackDeclined: return "Showing sample content — the on-device model declined to generate."
            }
        }
    }

    /// The cards currently shown. Starts with placeholder content, then is
    /// replaced by on-device generated cards when available.
    @State private var cards: [BriefingCard] = []
    @State private var isGenerating = false
    @State private var status: GenerationStatus = .idle

    /// The most recently generated briefing, persisted so it isn't regenerated
    /// on every launch within the same time-of-day slot.
    @AppStorage(BriefingView.cacheKey) private var cacheData = Data()

    private static let cacheKey = "briefingCache"

    /// Clears the cached briefing so the next appearance regenerates it (e.g.
    /// after a check-in, so the new answers are reflected).
    static func invalidateCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    /// Identifies the current day + time-of-day slot (morning/afternoon/evening),
    /// so generation happens at most once per slot (up to three times a day).
    private var currentSlotKey: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)-\(timeOfDay.promptName)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                ForEach(cards) { card in
                    BriefingCardView(card: card)
                }
                if let note = status.note {
                    Text(note)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Briefing")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Briefing")
                    .font(.appTitle3)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await generate(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isGenerating)
            }
        }
        .task {
            if cards.isEmpty { cards = BriefingView.cards(for: timeOfDay) }
            await generate()
        }
    }

    /// Shows the cached briefing for the current slot when available; otherwise
    /// generates on-device (falling back to placeholder content), caching any
    /// generated result. `forceRefresh` regenerates and replaces the cache.
    private func generate(forceRefresh: Bool = false) async {
        guard !isGenerating else { return }

        // Reuse this slot's cached briefing unless the user asked to refresh.
        if !forceRefresh,
           let cached = loadCache(),
           cached.slotKey == currentSlotKey,
           !cached.cards.isEmpty {
            cards = cached.cards.map(\.card)
            status = .onDevice
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        let available = BriefingGenerator.isAvailable
        let context = BriefingContextBuilder(modelContext: modelContext).build()
        let generator = BriefingGenerator()
        let generated = await withTimeout(seconds: 20) {
            await generator.generateCards(for: timeOfDay, context: context)
        }
        if let generated {
            cards = generated
            status = .onDevice
            saveCache(generated)
        } else {
            cards = BriefingView.cards(for: timeOfDay)
            status = available ? .fellBackDeclined : .fellBackUnavailable
        }
    }

    private func loadCache() -> CachedBriefing? {
        try? JSONDecoder().decode(CachedBriefing.self, from: cacheData)
    }

    private func saveCache(_ cards: [BriefingCard]) {
        let cached = CachedBriefing(slotKey: currentSlotKey, cards: cards.map(CachedCard.init))
        cacheData = (try? JSONEncoder().encode(cached)) ?? Data()
    }

    /// Runs `operation`, returning `nil` if it doesn't finish within `seconds`
    /// so a slow or wedged model can't leave the UI spinning indefinitely.
    private func withTimeout(
        seconds: Double,
        operation: @escaping () async -> [BriefingCard]?
    ) async -> [BriefingCard]? {
        await withTaskGroup(of: [BriefingCard]?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    /// Formats the header date as e.g. "Wednesday 1 July 2026".
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter
    }()

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(timeOfDay.greeting)
                    .font(.appLargeTitleSemibold)
                    .foregroundStyle(.brandGreen)
                Image(systemName: timeOfDay.icon)
                    .foregroundStyle(.brandGold)
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            Text(Self.dateFormatter.string(from: .now))
                .font(.appTitle3)
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
            message: "The morning is when the pull toward THC is at its quietest — notice the sharpness and the absence of fog. Let that feeling be the argument for tonight rather than a rule you're forcing on yourself. You don't have to do anything to earn it right now except notice it and carry it forward.",
            icon: "leaf.fill",
            tint: .brandGreen
        ),
        BriefingCard(
            title: "Nothing to manage yet",
            message: "The day is a blank slate — no decisions to make and no streak to defend. Keep it that way by not deciding anything now; the real choice lives in the evening. For now, just bank the calm of a morning that doesn't owe anything to last night.",
            icon: "wineglass.fill",
            tint: .brandOrange
        ),
        BriefingCard(
            title: "Move before the heat",
            message: "It won't be cooler than it is right now, so if there's a walk in today, the morning is your window. Keep it easy — steadiness beats intensity every time. Even ten gentle minutes keeps the streak alive and nudges things in the right direction.",
            icon: "figure.walk",
            tint: .brandGold
        ),
        BriefingCard(
            title: "Set a warm tone early",
            message: "The first small gesture of the day tends to set the weather for both of you. A coffee made without being asked, a question about her morning, a hand on the shoulder — these tiny bids are what keep the bond steady. It costs almost nothing and heads off quiet friction before it has a chance to build.",
            icon: "heart.fill",
            tint: .brandOrange
        )
    ]

    private static let afternoonCards: [BriefingCard] = [
        BriefingCard(
            title: "Ride out the afternoon dip",
            message: "The mid-afternoon lull is a sneaky one — the reach for something to take the edge off is usually energy talking, not real craving. Name it for what it is before you act on it, and more often than not it loosens its grip on its own. A short walk, a glass of water, or five minutes away from the screen does more than you'd expect.",
            icon: "leaf.fill",
            tint: .brandGreen
        ),
        BriefingCard(
            title: "Still steady, stay ahead of it",
            message: "The afternoon is a good time to picture how you want tonight to go, before the evening pull starts making the case for you. If you decide now that tonight leans toward tea and an early wind-down, the choice is already half made. Future-you wakes up grateful for the call you make this afternoon.",
            icon: "wineglass.fill",
            tint: .brandOrange
        ),
        BriefingCard(
            title: "A little still counts",
            message: "The afternoon still has room for a few easy minutes — movement doesn't have to be all-or-nothing. Even a short loop or some stretching keeps the streak intact and breaks up the sitting. Momentum is the goal, and small counts.",
            icon: "figure.walk",
            tint: .brandGold
        ),
        BriefingCard(
            title: "Plan the evening while it's calm",
            message: "Things are quieter now than they'll be tonight, so this is the moment to set up a gentle evening. A small plan — tea, a show you'll both enjoy, an earlier wind-down — gives the night something to steer toward instead of drift through. You don't need a grand gesture, just a shared intention.",
            icon: "heart.fill",
            tint: .brandOrange
        )
    ]

    private static let eveningCards: [BriefingCard] = [
        BriefingCard(
            title: "Outlast the evening call",
            message: "The pull usually crests and fades inside fifteen or twenty minutes — you don't have to fight it, just outlast it. Before you reach, ask what's actually underneath it tonight: fatigue, restlessness, or just the habit of the hour? A lighter evening buys you a sharper, more present morning, and that's worth more than the haze.",
            icon: "leaf.fill",
            tint: .brandGreen
        ),
        BriefingCard(
            title: "You're steady on the drinks",
            message: "No need to white-knuckle anything here — if the evening wants a ritual, let it be tea or a show rather than a pour. Every night you skip is a morning where you wake up ready instead of foggy. That version of you is worth protecting.",
            icon: "wineglass.fill",
            tint: .brandOrange
        ),
        BriefingCard(
            title: "Keep the streak going",
            message: "Consistency is doing the real work here, even when the sessions are short. A little gentle movement at home or some stretching keeps the momentum alive without overdoing it. Your body responds to exactly this — steady effort, lighter evenings, decent sleep.",
            icon: "figure.walk",
            tint: .brandGold
        ),
        BriefingCard(
            title: "Turn toward her tonight",
            message: "Notice the small bids she makes — a comment, a glance, a question — and turn toward them. Those tiny moments of being met are what keep the bond steady over time. One warm evening like this does more than any grand gesture.",
            icon: "heart.fill",
            tint: .brandOrange
        )
    ]
}

/// A single briefing coaching card: a headline, then the paragraph.
private struct BriefingCardView: View {
    let card: BriefingCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title.sentenceCased)
                .font(.appTitle3)
                .foregroundStyle(.brandGold)
            Text(card.message)
                .font(.appBody)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension String {
    var sentenceCased: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst().lowercased()
    }
}

#Preview {
    NavigationStack {
        BriefingView()
    }
}
