//
//  SubstancesView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

/// Tracker for substances: THC and alcohol.
struct SubstancesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wineglass.fill")
                .font(.largeTitle)
                .foregroundColor(.brandGold)

            Text("Substances")
                .font(.title)
                .bold()

            Text("Track THC and alcohol here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Substances")
    }
}

#Preview {
    SubstancesView()
}
