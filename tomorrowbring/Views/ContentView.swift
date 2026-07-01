//
//  ContentView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

/// The top-level sections of the app, shown in the sidebar.
enum AppSection: String, CaseIterable, Identifiable {
    case briefing = "Briefing"
    case wellbeing = "Wellbeing"
    case movement = "Movement"
    case substances = "Substances"
    case checkIn = "Check In"
    case settings = "Settings"

    var id: String { rawValue }

    /// SF Symbol shown next to the section in the sidebar.
    var icon: String {
        switch self {
        case .briefing: return "sun.max"
        case .wellbeing: return "heart"
        case .movement: return "figure.run"
        case .substances: return "wineglass"
        case .checkIn: return "checkmark.circle"
        case .settings: return "gearshape"
        }
    }
}

/// Root navigation: an adaptive sidebar listing every section, with the
/// selected section shown in the detail area.
struct ContentView: View {
    @State private var selection: AppSection?

    init(initialSection: AppSection = .briefing) {
        _selection = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("tomorrowbring")
        } detail: {
            NavigationStack {
                detail(for: selection ?? .briefing)
            }
        }
    }

    /// Resolves a section to its destination view.
    @ViewBuilder
    private func detail(for section: AppSection) -> some View {
        switch section {
        case .briefing: BriefingView()
        case .wellbeing: WellbeingView()
        case .movement: MovementView()
        case .substances: SubstancesView()
        case .checkIn: CheckInView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    ContentView()
}
