//
//  ContentView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

/// The top-level sections of the app.
enum AppSection: String, CaseIterable, Identifiable {
    case briefing = "Briefing"
    case wellbeing = "Wellbeing"
    case movement = "Movement"
    case substances = "Substances"
    case checkIn = "Check In"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .briefing:   return "sun.max.fill"
        case .wellbeing:  return "heart.fill"
        case .movement:   return "figure.run"
        case .substances: return "wineglass.fill"
        case .checkIn:    return "checkmark.circle.fill"
        case .settings:   return "gearshape.fill"
        }
    }

    var menuTint: Color {
        switch self {
        case .briefing:   return .brandGreen
        case .wellbeing:  return .brandGreen
        case .movement:   return .brandGold
        case .substances: return .brandOrange
        case .checkIn:    return .brandGreen
        case .settings:   return .white
        }
    }
}

/// Root view: a NavigationStack behind a full-screen menu overlay.
/// Section state lives here so the menu can switch sections.
struct ContentView: View {
    @Environment(AppLock.self) private var lock
    @State private var currentSection: AppSection
    @State private var showMenu = false

    // Watch substance goals so the Substances section appears/disappears reactively.
    @AppStorage("substanceGoal-THC") private var thcGoalData = Data()
    @AppStorage("substanceGoal-Alcohol") private var alcoholGoalData = Data()

    private var anySubstanceTracked: Bool {
        SubstanceGoal.isTracked(data: thcGoalData) || SubstanceGoal.isTracked(data: alcoholGoalData)
    }

    private var visibleSections: [AppSection] {
        var sections: [AppSection] = [.briefing, .wellbeing, .movement]
        if anySubstanceTracked { sections.append(.substances) }
        return sections
    }

    init(initialSection: AppSection = .briefing) {
        _currentSection = State(initialValue: initialSection)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                sectionView
                    .toolbar {
                        if currentSection != .checkIn {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showMenu = true
                                    }
                                } label: {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
            }

            if showMenu {
                AppMenuOverlay(currentSection: $currentSection, isShowing: $showMenu, sections: visibleSections)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showMenu)
        // Reset the idle timer on any touch so the app doesn't lock during active use.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in lock.resetIdleTimer() }
        )
        .onChange(of: currentSection) { lock.resetIdleTimer() }
        .onChange(of: anySubstanceTracked) { _, tracked in
            if !tracked && currentSection == .substances {
                currentSection = .briefing
            }
        }
    }

    @ViewBuilder
    private var sectionView: some View {
        switch currentSection {
        case .briefing:
            BriefingView()
        case .wellbeing:
            WellbeingView()
        case .movement:
            MovementView()
        case .substances:
            SubstancesView()
        case .checkIn:
            CheckInView(onComplete: {
                BriefingView.invalidateCache()
                currentSection = .briefing
            })
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Menu overlay

private struct AppMenuOverlay: View {
    @Binding var currentSection: AppSection
    @Binding var isShowing: Bool
    let sections: [AppSection]

    var body: some View {
        ZStack {
            Color.black.opacity(0.93)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(20)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        Button {
                            currentSection = section
                            dismiss()
                        } label: {
                            HStack(alignment: .center, spacing: 20) {
                                Image(systemName: section.icon)
                                    .font(.title2)
                                    .foregroundStyle(section.menuTint)
                                    .frame(width: 30)
                                Text(section.rawValue)
                                    .font(.appLargeTitleSemibold)
                                    .foregroundStyle(
                                        currentSection == section
                                            ? Color.white
                                            : Color.white.opacity(0.45)
                                    )
                            }
                            .padding(.horizontal, 36)
                            .padding(.vertical, 14)
                        }
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 36)
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                Button {
                    currentSection = .settings
                    dismiss()
                } label: {
                    HStack(alignment: .center, spacing: 20) {
                        Image(systemName: AppSection.settings.icon)
                            .font(.callout)
                            .foregroundStyle(Color.white.opacity(0.4))
                            .frame(width: 30)
                        Text(AppSection.settings.rawValue)
                            .font(.appTitle3)
                            .foregroundStyle(
                                currentSection == .settings
                                    ? Color.white.opacity(0.8)
                                    : Color.white.opacity(0.4)
                            )
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 10)
                }

                Spacer()
                Spacer()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowing = false
        }
    }
}

#Preview {
    ContentView()
}
