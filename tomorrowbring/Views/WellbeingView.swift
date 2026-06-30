//
//  WellbeingView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

/// General mood tracker across three metrics: calm, energy, and mood.
struct WellbeingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.largeTitle)
                .foregroundColor(.brandGreen)

            Text("Wellbeing")
                .font(.title)
                .bold()

            Text("Track your calm, energy, and mood here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Wellbeing")
    }
}

#Preview {
    WellbeingView()
}
