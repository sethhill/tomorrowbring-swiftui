//
//  BriefingView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

/// AI-generated summary of the current state of things plus coaching suggestions
/// for the day. Content is expected to vary by time of day.
struct BriefingView: View {
    /// The part of day the briefing is tailored to.
    enum TimeOfDay: String {
        case morning = "Morning"
        case afternoon = "Afternoon"
        case evening = "Evening"

        /// Derives the current part of day from the hour.
        static var current: TimeOfDay {
            switch Calendar.current.component(.hour, from: Date()) {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            default: return .evening
            }
        }
    }

    private let timeOfDay = TimeOfDay.current

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.max.fill")
                .font(.largeTitle)
                .foregroundColor(.brandGold)

            Text("\(timeOfDay.rawValue) Briefing")
                .font(.title)
                .bold()

            Text("Your daily summary and coaching will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Briefing")
    }
}

#Preview {
    BriefingView()
}
