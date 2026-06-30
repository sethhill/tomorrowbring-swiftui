//
//  ContentView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Welcome to the Home Screen!")
                    .padding()
                
                NavigationLink("Go to Settings", destination: SettingsView())
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Home") // Adds a top title bar
        }
    }
}

#Preview {
    ContentView()
}
