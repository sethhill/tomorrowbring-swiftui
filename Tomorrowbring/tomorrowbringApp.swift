//
//  tomorrowbringApp.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

@main
struct tomorrowbringApp: App {
    @State private var lock = AppLock()
    @State private var weatherStore = WeatherStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lock)
                .environment(weatherStore)
                .background(Color.appBackground.ignoresSafeArea())
                .task { await weatherStore.load() }
        }
        .modelContainer(for: [SubstanceLog.self, CheckInEntry.self, WellbeingEntry.self, MovementEntry.self])
    }
}
