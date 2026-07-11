//
//  BriefingView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

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
            case .fellBackUnavailable: return "Showing programmatic content—Apple Intelligence is unavailable on this device."
            case .fellBackDeclined: return "Showing programmatic content—the on-device model declined to generate."
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
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
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
            if cards.isEmpty { cards = BriefingView.contextualCards(for: timeOfDay, modelContext: modelContext) }
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
            cards = BriefingView.contextualCards(for: timeOfDay, modelContext: modelContext)
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
            Image(systemName: timeOfDay.icon)
                .font(.system(size: 80))
                .foregroundStyle(.brandGold)
                .padding(.bottom, 4)
            HStack(spacing: 10) {
                Text(timeOfDay.greeting)
                    .font(.appLargeTitleSemibold)
                    .foregroundStyle(.brandGreen)
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

// MARK: - Contextual fallback cards

extension BriefingView {

    /// Signals extracted from local data, used to select appropriate fallback copy.
    private struct Signals {
        var energyAnswer: String?
        var workoutsThisWeek: Int
        var daysSinceLastWorkout: Int?
        var thcThisWeek: Double
        var thcGoalMode: SubstanceGoalMode
        var thcWeeklyLimit: Double?
        var alcoholThisWeek: Double
        var alcoholGoalMode: SubstanceGoalMode
        var alcoholWeeklyLimit: Double?

        init(modelContext: ModelContext, now: Date = .now) {
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

            var ciDesc = FetchDescriptor<CheckInEntry>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            ciDesc.fetchLimit = 1
            energyAnswer = (try? modelContext.fetch(ciDesc))?.first?.responses
                .first(where: { $0.prompt.lowercased().contains("your energy") })?.answer

            let movements = (try? modelContext.fetch(
                FetchDescriptor<MovementEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            )) ?? []
            let thisWeekMoves = movements.filter { $0.date >= weekAgo }
            workoutsThisWeek = thisWeekMoves.count
            if let latest = movements.first {
                daysSinceLastWorkout = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: latest.date),
                    to: calendar.startOfDay(for: now)
                ).day
            } else {
                daysSinceLastWorkout = nil
            }

            let allLogs = (try? modelContext.fetch(FetchDescriptor<SubstanceLog>())) ?? []
            thcThisWeek = allLogs.filter { $0.kind == .thc && $0.timestamp >= weekAgo }
                .reduce(0) { $0 + $1.amount }
            let thcGoal = SubstanceGoal.load(for: .thc)
            thcGoalMode = thcGoal.mode
            thcWeeklyLimit = thcGoal.weeklyLimit

            alcoholThisWeek = allLogs.filter { $0.kind == .alcohol && $0.timestamp >= weekAgo }
                .reduce(0) { $0 + $1.amount }
            let alcoholGoal = SubstanceGoal.load(for: .alcohol)
            alcoholGoalMode = alcoholGoal.mode
            alcoholWeeklyLimit = alcoholGoal.weeklyLimit
        }
    }

    /// Generates fallback cards using local data signals when Apple Intelligence is unavailable.
    static func contextualCards(for timeOfDay: TimeOfDay, modelContext: ModelContext) -> [BriefingCard] {
        let s = Signals(modelContext: modelContext)
        return [
            wellbeingCard(timeOfDay: timeOfDay, energyAnswer: s.energyAnswer),
            movementCard(timeOfDay: timeOfDay, workoutsThisWeek: s.workoutsThisWeek, daysSinceLastWorkout: s.daysSinceLastWorkout),
            thcCard(timeOfDay: timeOfDay, thisWeek: s.thcThisWeek, goalMode: s.thcGoalMode, weeklyLimit: s.thcWeeklyLimit),
            alcoholCard(timeOfDay: timeOfDay, thisWeek: s.alcoholThisWeek, goalMode: s.alcoholGoalMode, weeklyLimit: s.alcoholWeeklyLimit)
        ]
    }

    private static func wellbeingCard(timeOfDay: TimeOfDay, energyAnswer: String?) -> BriefingCard {
        let (title, message): (String, String) = switch energyAnswer {
        case "Great", "Good":
            ("Make the most of it",
             "You're coming in with real energy — that's a resource worth steering, not spending. Notice where it goes in the first couple of hours, because that window tends to set the tone for everything that follows. Point it at the thing that calls for actual focus.")
        case "Low", "Drained":
            ("Work with what you have",
             "Your energy is running lean today, and that's honest data worth taking seriously. The instinct to push through tends to cost more than it returns. Give yourself a narrower scope than usual and protect whatever capacity you have rather than trying to manufacture more.")
        default:
            ("Read the morning",
             "Your check-in gives you a starting point — use it to set the tone rather than just react to the day. Notice where your energy actually is, not where you think it should be. That honest read is the best tool you have for the next few hours.")
        }
        return BriefingCard(title: title, message: message, icon: "heart.fill", tint: .brandGreen)
    }

    private static func movementCard(
        timeOfDay: TimeOfDay,
        workoutsThisWeek: Int,
        daysSinceLastWorkout: Int?
    ) -> BriefingCard {
        let (title, message): (String, String)
        if let days = daysSinceLastWorkout, days >= 3 {
            (title, message) = (
                "Reset the clock",
                "It's been a few days since your last session, and the useful goal is closing the gap rather than making up for it. A short reset today — even ten or fifteen minutes — ends the pause and gives you something to build from. The size of the session doesn't matter nearly as much as the fact of it."
            )
        } else if workoutsThisWeek >= 3 {
            (title, message) = (
                "Momentum is doing its work",
                "You've been showing up consistently this week, and that's the habit working. The useful question now isn't whether to go again but whether to add time or protect the frequency — either lever is valid, so pick the one the day actually has room for."
            )
        } else if workoutsThisWeek > 0 {
            (title, message) = (
                "Keep the thread going",
                "You've got some movement in this week and the thread is alive. Keeping it going matters more than the size of the next session — even a short one extends the pattern and gives you something to build on. Steadiness beats intensity when the goal is making this a habit."
            )
        } else {
            (title, message) = switch timeOfDay {
            case .morning:
                ("Move before the day fills up",
                 "The morning window is the one that closes fastest — once the day gets going, movement gets pushed. Even ten easy minutes now keeps momentum alive and shifts the morning in a direction you'll feel later. Steadiness beats intensity every time.")
            case .afternoon:
                ("A little still counts",
                 "The afternoon still has room for a few easy minutes — movement doesn't have to be all-or-nothing. Even a short loop or some stretching keeps things alive and breaks up the sitting. Momentum is the goal, and small counts.")
            case .evening:
                ("Keep the streak going",
                 "Consistency is doing the real work here, even when the sessions are short. A little gentle movement at home or some stretching keeps the momentum alive without overdoing it. Steady effort, lighter evenings, decent sleep.")
            }
        }
        return BriefingCard(title: title, message: message, icon: "figure.walk", tint: .brandGold)
    }

    private static func thcCard(
        timeOfDay: TimeOfDay,
        thisWeek: Double,
        goalMode: SubstanceGoalMode,
        weeklyLimit: Double?
    ) -> BriefingCard {
        let (title, message): (String, String)
        switch goalMode {
        case .elimination:
            if thisWeek > 0 {
                (title, message) = (
                    "Today is the reset",
                    "If things didn't go the way you planned, today is the reset — not a setback. Urges tend to cluster for a day or two after a slip; notice when the pull starts building and name what's actually underneath it before acting on it. That pause is where the real choice lives."
                )
            } else {
                let anchor = switch timeOfDay {
                case .morning: "The morning is when the pull is usually at its quietest — notice the sharpness and carry it forward into the day."
                case .afternoon: "The afternoon dip is when the case for using tends to start forming quietly — naming it early takes most of its power away."
                case .evening: "The evening is when the pull tends to peak; cravings crest and fade in fifteen to twenty minutes if you give them room to pass."
                }
                (title, message) = (
                    "Building something real",
                    "Each day that goes this way adds to a clearer baseline — not just a streak, but actual signal about how you feel when things are clean. \(anchor) Decide how you want to handle the next few hours before the pull starts making its case."
                )
            }
        case .reduction, .targeted:
            if let limit = weeklyLimit, limit > 0, thisWeek / limit >= 0.8 {
                (title, message) = (
                    "Stay ahead of the math",
                    "You're close to your weekly range with time still to go — that tends to get tighter than expected. The useful framing isn't restriction; it's what staying within it makes possible for the rest of the week. Notice whether the next one is a genuine choice or just the habit of the hour."
                )
            } else {
                (title, message) = (
                    "Notice where the habit is",
                    "You're within your weekly range and the pattern is holding. The most useful thing to watch for is the point where habit takes over from choice — that's when it's worth slowing down and checking whether you actually want this one. The awareness itself tends to change the decision."
                )
            }
        case .trackingOnly:
            (title, message) = (
                "Bank the clear morning",
                "The morning is when the pull toward cannabis is at its quietest — notice the sharpness and the absence of fog. Let that feeling be the argument for tonight rather than a rule you're forcing on yourself. Carry it forward."
            )
        }
        return BriefingCard(title: title, message: message, icon: "leaf.fill", tint: .brandGreen)
    }

    private static func alcoholCard(
        timeOfDay: TimeOfDay,
        thisWeek: Double,
        goalMode: SubstanceGoalMode,
        weeklyLimit: Double?
    ) -> BriefingCard {
        let (title, message): (String, String)
        if let limit = weeklyLimit, limit > 0, thisWeek / limit >= 0.8 {
            (title, message) = (
                "Worth pausing tonight",
                "You're close to your weekly limit and the week still has days left — that math tends to get tighter than it looks. The question tonight isn't about willpower; it's about what you'd rather wake up with tomorrow. Decide now, before the evening starts making the case for you."
            )
        } else if thisWeek == 0 && goalMode != .trackingOnly {
            let anchor = switch timeOfDay {
            case .morning: "The slate is clean — keep tonight's intention light and specific rather than a rule."
            case .afternoon: "Preview the evening choice now, before the pull starts making the case."
            case .evening: "Tonight's already going well; what you skip now is a morning that starts cleaner."
            }
            (title, message) = (
                "Nothing to manage yet",
                "The week has been clean on drinks so far, and that gives you useful signal about how you've been feeling. \(anchor) Notice whether the difference shows up in sleep, energy, or how the mornings feel — that's the data worth carrying forward."
            )
        } else {
            (title, message) = (
                "Steady on the drinks",
                "You're tracking within your range and the week has room. The useful thing isn't managing a number; it's deciding whether tonight actually calls for a drink or just the ritual of winding down. Those are different things, and knowing which one you're reaching for changes the decision."
            )
        }
        return BriefingCard(title: title, message: message, icon: "wineglass.fill", tint: .brandOrange)
    }
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
