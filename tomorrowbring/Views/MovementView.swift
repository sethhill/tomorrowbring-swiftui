//
//  MovementView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

/// Tracker for movement (running, cycling, yoga, etc.).
/// Intended to integrate with Apple Health (HealthKit).
struct MovementView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.largeTitle)
                .foregroundColor(.brandOrange)

            Text("Movement")
                .font(.title)
                .bold()

            Text("Log running, cycling, yoga, and more — with Apple Health integration to come.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Movement")
    }
}

#Preview {
    MovementView()
}
