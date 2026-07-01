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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lock)
                .background(Color.appBackground.ignoresSafeArea())
        }
        .modelContainer(for: [SubstanceLog.self, CheckInEntry.self, WellbeingEntry.self])
    }
}
