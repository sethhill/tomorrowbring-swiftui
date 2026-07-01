//
//  SettingsView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.fill")
                .font(.appLargeTitle)
                .foregroundColor(.brandGreen)

            Text("Settings Page")
                .font(.appTitle)

            Text("Manage your preferences here.")
                .font(.appSubheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
