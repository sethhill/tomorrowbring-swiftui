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
                .font(.largeTitle)
                .foregroundColor(.brandGreen)
            
            Text("Settings Page")
                .font(.title)
                .bold()
            
            Text("Manage your preferences here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
